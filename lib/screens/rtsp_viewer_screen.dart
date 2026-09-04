import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../services/rtsp_player_config.dart';
import '../services/stream_platform.dart';
import '../widgets/mjpeg_view.dart';

class RtspViewerScreen extends StatefulWidget {
  const RtspViewerScreen({super.key, required this.rtspUrl});

  final String rtspUrl;

  @override
  State<RtspViewerScreen> createState() => _RtspViewerScreenState();
}

class _RtspViewerScreenState extends State<RtspViewerScreen> {
  Player? _player;
  VideoController? _controller;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _connectTimeout;

  String? _error;
  String _status = 'Preparing player…';
  bool _connecting = true;
  bool _hasVideo = false;
  bool _usingMjpeg = false;
  String? _playbackUrl;

  @override
  void initState() {
    super.initState();
    _initAndPlay();
  }

  Future<void> _initAndPlay() async {
    await _disposePlayer();
    if (!mounted) return;

    final playback = playbackUrlForPlatform(widget.rtspUrl);
    if (playback == null) {
      setState(() {
        _connecting = false;
        _hasVideo = false;
        _status = 'Unsupported';
        _error = kWebRtspUnsupportedMessage;
        _usingMjpeg = false;
        _playbackUrl = null;
      });
      return;
    }

    // Web + derived MJPEG (or direct http mjpeg/hls).
    if (kIsWeb && (isMjpegUrl(playback) || isWebCompatibleStreamUrl(playback))) {
      if (isMjpegUrl(playback) || playback.toLowerCase().contains('.mjpg')) {
        setState(() {
          _usingMjpeg = true;
          _playbackUrl = playback;
          _connecting = true;
          _hasVideo = false;
          _error = null;
          _status = 'Connecting to $playback';
        });
        // onLoad from MjpegView will clear connecting.
        return;
      }
    }

    if (kIsWeb && isRtspUrl(widget.rtspUrl) && !isWebCompatibleStreamUrl(playback)) {
      setState(() {
        _usingMjpeg = false;
        _connecting = false;
        _hasVideo = false;
        _status = 'Unsupported on Web';
        _error = kWebRtspUnsupportedMessage;
        _playbackUrl = playback;
      });
      return;
    }

    setState(() {
      _usingMjpeg = false;
      _playbackUrl = playback;
      _connecting = true;
      _hasVideo = false;
      _error = null;
      _status = 'Preparing player…';
    });

    try {
      final player = Player(
        configuration: const PlayerConfiguration(
          title: 'IP Camera Viewer',
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

      _player = player;
      _controller = controller;
      _attachListeners(player);

      if (isRtspUrl(playback)) {
        await configureRtspNativePlayer(player);
      }

      if (!mounted) return;
      setState(() {
        _status = 'Connecting to $playback';
      });

      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted || _player != player) return;

      _connectTimeout?.cancel();
      _connectTimeout = Timer(const Duration(seconds: 20), () {
        if (!mounted || _hasVideo || _error != null) return;
        setState(() {
          _connecting = false;
          _error =
              'No video received.\nCheck that the camera phone is streaming and both devices are on the same Wi-Fi.';
          _status = 'Timed out';
        });
      });

      await player.open(Media(playback), play: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = 'Failed to connect: $e';
        _status = 'Connection failed';
      });
    }
  }

  void _attachListeners(Player player) {
    _subscriptions.add(
      player.stream.error.listen((message) {
        if (!mounted || message.trim().isEmpty) return;
        setState(() {
          _connecting = false;
          _error = message;
          _status = 'Error';
        });
      }),
    );
    _subscriptions.add(
      player.stream.playing.listen((playing) {
        if (!mounted || !playing) return;
        setState(() {
          _status = 'Streaming';
          _error = null;
        });
      }),
    );
    _subscriptions.add(
      player.stream.width.listen((width) {
        if (!mounted || width == null || width <= 0) return;
        _connectTimeout?.cancel();
        setState(() {
          _hasVideo = true;
          _connecting = false;
          _error = null;
          _status = 'Streaming';
        });
      }),
    );
    _subscriptions.add(
      player.stream.buffering.listen((buffering) {
        if (!mounted || _hasVideo) return;
        if (buffering) {
          setState(() => _status = 'Buffering…');
        }
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

  Future<void> _copyUrl() async {
    final text = (_playbackUrl ?? widget.rtspUrl).trim();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $text')),
    );
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = _controller;
    final mjpegUrl = _playbackUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Camera'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColoredBox(
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_usingMjpeg && mjpegUrl != null)
                          MjpegView(
                            url: mjpegUrl,
                            onLoaded: () {
                              if (!mounted) return;
                              setState(() {
                                _hasVideo = true;
                                _connecting = false;
                                _error = null;
                                _status = 'Streaming (MJPEG)';
                              });
                            },
                            onError: (message) {
                              if (!mounted) return;
                              setState(() {
                                _connecting = false;
                                _hasVideo = false;
                                _error = message;
                                _status = 'MJPEG offline';
                              });
                            },
                          )
                        else if (!_usingMjpeg && controller != null)
                          Video(
                            controller: controller,
                            controls: NoVideoControls,
                            fill: Colors.black,
                            fit: BoxFit.contain,
                          ),
                        if (_connecting || (!_hasVideo && _error == null))
                          ColoredBox(
                            color: Colors.black.withValues(alpha: 0.45),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Text(
                                    _status,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_error != null)
                          ColoredBox(
                            color: Colors.black.withValues(alpha: 0.7),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: _initAndPlay,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Retry'),
                                  ),
                                  if (kIsWeb) ...[
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: _copyUrl,
                                      icon: const Icon(Icons.copy_rounded),
                                      label: const Text('Copy stream URL'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Card(
                child: ListTile(
                  leading: Icon(
                    _hasVideo
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    color: _hasVideo
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                  title: Text(_hasVideo ? 'Video received' : _status),
                  subtitle: Text(_playbackUrl ?? widget.rtspUrl),
                  trailing: IconButton(
                    tooltip: 'Retry',
                    onPressed: _initAndPlay,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
