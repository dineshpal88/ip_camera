import 'package:flutter/material.dart';

import '../../../screens/rtsp_viewer_screen.dart';
import '../models/camera_stream_state.dart';
import '../models/monitored_camera.dart';
import 'live_stream_preview.dart';

class CameraPreviewCard extends StatefulWidget {
  const CameraPreviewCard({
    super.key,
    required this.camera,
    this.detectionLabel,
    this.onRemove,
  });

  final MonitoredCamera camera;
  final String? detectionLabel;
  final VoidCallback? onRemove;

  @override
  State<CameraPreviewCard> createState() => _CameraPreviewCardState();
}

class _CameraPreviewCardState extends State<CameraPreviewCard> {
  CameraStreamState _streamState = const CameraStreamState(
    status: CameraStreamStatus.connecting,
    message: 'Connecting...',
  );

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RtspViewerScreen(rtspUrl: widget.camera.streamUrl),
      ),
    );
  }

  Color _statusColor(ThemeData theme) {
    return switch (_streamState.status) {
      CameraStreamStatus.live => Colors.green,
      CameraStreamStatus.connecting => theme.colorScheme.primary,
      CameraStreamStatus.unsupported => theme.colorScheme.tertiary,
      CameraStreamStatus.offline || CameraStreamStatus.idle =>
        theme.colorScheme.error,
    };
  }

  String _statusText() {
    return switch (_streamState.status) {
      CameraStreamStatus.live => 'Live',
      CameraStreamStatus.connecting => 'Connecting...',
      CameraStreamStatus.unsupported => 'Unsupported',
      CameraStreamStatus.offline => 'Camera offline',
      CameraStreamStatus.idle => 'Idle',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.camera.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.circle, size: 10, color: _statusColor(theme)),
                const SizedBox(width: 6),
                Text(_statusText(), style: theme.textTheme.labelMedium),
                IconButton(
                  tooltip: 'Fullscreen',
                  onPressed: _openFullscreen,
                  icon: const Icon(Icons.fullscreen_rounded),
                ),
                if (widget.onRemove != null)
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: LiveStreamPreview(
              camera: widget.camera,
              onStatusChanged: (state) {
                if (!mounted) return;
                setState(() => _streamState = state);
              },
            ),
          ),
          if (widget.detectionLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Text(
                widget.detectionLabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}
