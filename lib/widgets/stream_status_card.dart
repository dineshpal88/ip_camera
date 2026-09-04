import 'package:flutter/material.dart';

import '../models/stream_info.dart';

class StreamStatusCard extends StatelessWidget {
  const StreamStatusCard({
    super.key,
    required this.info,
    required this.onCopyUrl,
  });

  final StreamInfo info;
  final VoidCallback onCopyUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ipLabel = info.hasWifiIp ? info.ip : 'Wi-Fi IP unavailable';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _row('Camera', info.camera),
            _row('Streaming', info.streaming ? 'ON' : 'OFF'),
            _row('Device IP', ipLabel),
            _row('Port', '${info.port}'),
            _row('Stream path', info.path),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RTSP URL', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 4),
                      SelectableText(
                        info.rtspUrl.isNotEmpty ? info.rtspUrl : 'Not available',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (info.mjpegUrl.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Web MJPEG URL', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 4),
                        SelectableText(
                          info.mjpegUrl,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copy RTSP URL',
                  onPressed: info.rtspUrl.isNotEmpty ? onCopyUrl : null,
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
