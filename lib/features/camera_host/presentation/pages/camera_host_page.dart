import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/widgets/camera_preview.dart';
import '../bloc/camera_host_cubit.dart';
import '../widgets/stream_settings_panel.dart';
import '../widgets/stream_status_card.dart';

class CameraHostPage extends StatefulWidget {
  const CameraHostPage({super.key});

  @override
  State<CameraHostPage> createState() => _CameraHostPageState();
}

class _CameraHostPageState extends State<CameraHostPage> {
  late final CameraHostCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<CameraHostCubit>();
    _cubit.initialize();
  }

  @override
  void dispose() {
    _cubit.disposeHost();
    super.dispose();
  }

  Future<void> _copyUrl(String url) async {
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('RTSP URL copied')),
    );
  }

  String _connectionLabel(CameraHostState state) {
    if (!state.info.streaming) return 'Stream not started';
    if (state.info.clientCount <= 0) return 'Waiting for RTSP client...';
    if (state.info.clientCount == 1) return '1 client connected';
    return '${state.info.clientCount} clients connected';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<CameraHostCubit, CameraHostState>(
      listenWhen: (prev, next) =>
          prev.message != next.message && next.message != null,
      listener: (context, state) {
        final message = state.message;
        if (message == null) return;
        final isError = state.status == CameraHostStatus.failure ||
            message.toLowerCase().contains('fail') ||
            message.toLowerCase().contains('error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isError ? Colors.red.shade700 : null,
          ),
        );
      },
      builder: (context, state) {
        final streaming = state.isStreaming;
        final loading = state.isBusy;
        final cubit = context.read<CameraHostCubit>();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Android IP Camera'),
            centerTitle: true,
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth =
                    constraints.maxWidth > 720 ? 720.0 : constraints.maxWidth;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        StreamStatusCard(
                          info: state.info,
                          onCopyUrl: () => _copyUrl(state.info.rtspUrl),
                        ),
                        const SizedBox(height: 16),
                        const CameraPreview(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed:
                                    loading || streaming ? null : cubit.startStream,
                                icon: loading && !streaming
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.play_arrow_rounded),
                                label: const Text('Start Stream'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    loading || !streaming ? null : cubit.stopStream,
                                icon: const Icon(Icons.stop_rounded),
                                label: const Text('Stop Stream'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed:
                              loading || streaming ? null : cubit.switchCamera,
                          icon: const Icon(Icons.cameraswitch_rounded),
                          label: Text('Switch Camera (${state.info.camera})'),
                        ),
                        const SizedBox(height: 16),
                        StreamSettingsPanel(
                          settings: state.settings,
                          enabled: !streaming,
                          onResolutionChanged: (value) {
                            cubit.updateResolution(
                              value['width']!,
                              value['height']!,
                            );
                          },
                          onFpsChanged: cubit.updateFps,
                          onBitrateChanged: cubit.updateBitrate,
                          onLanOnlyChanged: cubit.updateLanOnly,
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: ListTile(
                            leading: Icon(
                              state.info.clientCount > 0
                                  ? Icons.link_rounded
                                  : Icons.link_off_rounded,
                            ),
                            title: const Text('Connection'),
                            subtitle: Text(_connectionLabel(state)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          color: theme.colorScheme.errorContainer
                              .withValues(alpha: 0.35),
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
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
