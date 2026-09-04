import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../services/rtsp_player_config.dart';
import '../../../services/stream_platform.dart';
import '../../../widgets/mjpeg_view.dart';
import '../models/camera_stream_state.dart';
import '../models/monitored_camera.dart';

/// Compact live preview reused by Scan Vehicle cards.
/// Isolates player failures so one camera cannot blank the grid.
class LiveStreamPreview extends StatefulWidget {
  const LiveStreamPreview({
    super.key,
    required this.camera,
    this.onStatusChanged,
    this.compact = true,
  });

  final MonitoredCamera camera;
  final ValueChanged<CameraStreamState>? onStatusChanged;
  final bool compact;

  @override
  State<LiveStreamPreview> createState() => _LiveStreamPreviewState();
}

class _LiveStreamPreviewState extends State<LiveStreamPreview> {
  Player? _player;
  VideoController? _controller;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _connectTimeout;

  CameraStreamStatus _status = CameraStreamStatus.connecting;
  String? _message;
  bool _hasVideo = false;
  bool _usingMjpeg = false;
  String? _playbackUrl;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant LiveStreamPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera.streamUrl != widget.camera.streamUrl) {
      _start();
    }
  }

  void _emit(CameraStreamStatus status, [String? message]) {
    _status = status;
    _message = message;
    widget.onStatusChanged?.call(
      CameraStreamState(status: status, message: message),
    );
    if (mounted) setState(() {});
  }

  Future<void> retry() => _start();

  Future<void> _start() async {
    final generation = ++_generation;
    await _disposePlayer();
    if (!mounted || generation != _generation) return;

    _hasVideo = false;
    _usingMjpeg = false;
    _playbackUrl = null;

    final playback = playbackUrlForPlatform(widget.camera.streamUrl);
    if (playback == null) {
      _emit(
        CameraStreamStatus.unsupported,
        'No playable stream URL for this platform.',
      );
      return;
    }
    _playbackUrl = playback;

    if (kIsWeb && isMjpegUrl(playback)) {
      _usingMjpeg = true;
      _emit(CameraStreamStatus.connecting, 'Connecting...');
      return;
    }

    if (kIsWeb && isRtspUrl(widget.camera.streamUrl)) {
      _emit(
        CameraStreamStatus.unsupported,
        'Start streaming on the camera phone, then retry. '
        'Web uses http://${Uri.tryParse(widget.camera.streamUrl)?.host ?? "IP"}:8080/stream.mjpg',
      );
      return;
    }

    _emit(CameraStreamStatus.connecting, 'Connecting...');

    try {
      final player = Player(
        configuration: PlayerConfiguration(
          title: widget.camera.name,
          muted: true,
          bufferSize: 2 * 1024 * 1024,
        ),
      );
      final controller = VideoController(
        player,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );

      if (!mounted || generation != _generation) {
        await player.dispose();
        return;
      }

      _player = player;
      _controller = controller;
      _attachListeners(player, generation);

      if (isRtspUrl(playback)) {
        await configureRtspNativePlayer(player);
      }

      if (!mounted || generation != _generation) return;

      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted || generation != _generation || _player != player) return;

      _connectTimeout?.cancel();
      _connectTimeout = Timer(const Duration(seconds: 18), () {
        if (!mounted || generation != _generation || _hasVideo) return;
        _emit(CameraStreamStatus.offline, 'Camera offline');
      });

      await player.open(Media(playback), play: true);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      _emit(CameraStreamStatus.offline, 'Camera offline');
    }
  }

  void _attachListeners(Player player, int generation) {
    _subscriptions.add(
      player.stream.error.listen((message) {
        if (!mounted || generation != _generation || message.trim().isEmpty) {
          return;
        }
        _emit(CameraStreamStatus.offline, 'Camera offline');
      }),
    );
    _subscriptions.add(
      player.stream.width.listen((width) {
        if (!mounted ||
            generation != _generation ||
            width == null ||
            width <= 0) {
          return;
        }
        _connectTimeout?.cancel();
        _hasVideo = true;
        _emit(CameraStreamStatus.live, 'Live');
      }),
    );
  }

  Future<void> _disposePlayer() async {
    _connectTimeout?.cancel();
    _connectTimeout = null;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    final player = _player;
    _player = null;
    _controller = null;
    if (player != null) {
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final mjpegUrl = _playbackUrl;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_usingMjpeg && mjpegUrl != null)
            MjpegView(
              key: ValueKey(mjpegUrl),
              url: mjpegUrl,
              onLoaded: () {
                if (!mounted) return;
                _hasVideo = true;
                _emit(CameraStreamStatus.live, 'Live');
              },
              onError: (_) {
                if (!mounted) return;
                _emit(
                  CameraStreamStatus.offline,
                  'MJPEG offline — start stream on camera phone',
                );
              },
            )
          else if (controller != null &&
              (_status == CameraStreamStatus.live ||
                  _status == CameraStreamStatus.connecting))
            Video(
              controller: controller,
              controls: NoVideoControls,
              fill: Colors.black,
              fit: BoxFit.contain,
            ),
          if (_status == CameraStreamStatus.connecting)
            const Center(child: CircularProgressIndicator()),
          if (_status == CameraStreamStatus.offline ||
              _status == CameraStreamStatus.unsupported)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _status == CameraStreamStatus.unsupported
                        ? Icons.web_asset_off_rounded
                        : Icons.videocam_off_rounded,
                    color: Colors.white70,
                    size: widget.compact ? 28 : 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _message ?? 'Camera offline',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (_status == CameraStreamStatus.offline) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: retry,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
