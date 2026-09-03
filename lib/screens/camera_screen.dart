import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/stream_info.dart';
import '../models/stream_settings.dart';
import '../services/camera_platform_service.dart';
import '../widgets/camera_preview.dart';
import '../widgets/stream_settings_panel.dart';
import '../widgets/stream_status_card.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  StreamInfo _info = const StreamInfo();
  StreamSettings _settings = const StreamSettings();
  bool _loading = false;
  StreamSubscription<Map<String, dynamic>>? _eventsSub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await CameraPlatformService.initialize();
      _eventsSub = CameraPlatformService.events.listen(_onNativeEvent);
      await _refreshInfo();
    } catch (e) {
      _showError('Failed to initialize camera: $e');
    }
  }

  Future<void> _refreshInfo() async {
    final info = await CameraPlatformService.getStreamInfo();
    if (!mounted) return;
    setState(() => _info = info);
  }

  void _onNativeEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    switch (type) {
      case 'streamingStarted':
      case 'streamingStopped':
      case 'clientConnected':
      case 'clientDisconnected':
      case 'stateChanged':
      case 'ipChanged':
        _refreshInfo();
      case 'error':
      case 'encoderError':
      case 'cameraError':
        _showError(event['message']?.toString() ?? 'Unknown error');
        _refreshInfo();
    }
  }

  Future<void> _startStream() async {
    setState(() => _loading = true);
    try {
      final info = await CameraPlatformService.startStream();
      if (!mounted) return;
      setState(() {
        _info = info;
        _loading = false;
      });
      if (info.rtspUrl.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Streaming on ${info.rtspUrl}')),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.message ?? 'Failed to start stream');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('$e');
    }
  }

  Future<void> _stopStream() async {
    setState(() => _loading = true);
    await CameraPlatformService.stopStream();
    await _refreshInfo();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _switchCamera() async {
    if (_info.streaming) return;
    final info = await CameraPlatformService.switchCamera();
    if (!mounted) return;
    setState(() => _info = info);
  }

  Future<void> _copyUrl() async {
    if (_info.rtspUrl.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _info.rtspUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('RTSP URL copied')),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  String _connectionLabel() {
    if (!_info.streaming) return 'Stream not started';
    if (_info.clientCount <= 0) return 'Waiting for RTSP client...';
    if (_info.clientCount == 1) return '1 client connected';
    return '${_info.clientCount} clients connected';
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    if (!_info.streaming) {
      CameraPlatformService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final streaming = _info.streaming;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Android IP Camera'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth > 720 ? 720.0 : constraints.maxWidth;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    StreamStatusCard(info: _info, onCopyUrl: _copyUrl),
                    const SizedBox(height: 16),
                    const CameraPreview(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _loading || streaming ? null : _startStream,
                            icon: _loading && !streaming
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.play_arrow_rounded),
                            label: const Text('Start Stream'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loading || !streaming ? null : _stopStream,
                            icon: const Icon(Icons.stop_rounded),
                            label: const Text('Stop Stream'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loading || streaming ? null : _switchCamera,
                      icon: const Icon(Icons.cameraswitch_rounded),
                      label: Text('Switch Camera (${_info.camera})'),
                    ),
                    const SizedBox(height: 16),
                    StreamSettingsPanel(
                      settings: _settings,
                      enabled: !streaming,
                      onResolutionChanged: (value) async {
                        final next = _settings.copyWith(
                          width: value['width'],
                          height: value['height'],
                        );
                        setState(() => _settings = next);
                        await CameraPlatformService.setResolution(
                          next.width,
                          next.height,
                        );
                      },
                      onFpsChanged: (fps) async {
                        setState(() => _settings = _settings.copyWith(fps: fps));
                        await CameraPlatformService.setFps(fps);
                      },
                      onBitrateChanged: (bitrate) async {
                        setState(
                          () => _settings = _settings.copyWith(bitrate: bitrate),
                        );
                        await CameraPlatformService.setBitrate(bitrate);
                      },
                      onLanOnlyChanged: (enabled) async {
                        setState(
                          () => _settings = _settings.copyWith(lanOnly: enabled),
                        );
                        await CameraPlatformService.setLanOnly(enabled);
                      },
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: Icon(
                          _info.clientCount > 0
                              ? Icons.link_rounded
                              : Icons.link_off_rounded,
                        ),
                        title: const Text('Connection'),
                        subtitle: Text(_connectionLabel()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Security',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Use only on a trusted network. RTSP authentication/TLS is not enabled in this version.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Battery optimization',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Some Android vendors (including Vivo) may stop background apps. If streaming stops when the screen locks, allow the app to run in the background and disable battery restrictions for this app in system settings.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
