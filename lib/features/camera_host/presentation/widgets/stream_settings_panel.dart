import 'package:flutter/material.dart';

import '../../domain/entities/stream_settings.dart';

class StreamSettingsPanel extends StatelessWidget {
  const StreamSettingsPanel({
    super.key,
    required this.settings,
    required this.enabled,
    required this.onResolutionChanged,
    required this.onFpsChanged,
    required this.onBitrateChanged,
    required this.onLanOnlyChanged,
  });

  final StreamSettings settings;
  final bool enabled;
  final ValueChanged<Map<String, int>> onResolutionChanged;
  final ValueChanged<int> onFpsChanged;
  final ValueChanged<int> onBitrateChanged;
  final ValueChanged<bool> onLanOnlyChanged;

  @override
  Widget build(BuildContext context) {
    final currentResolution = '${settings.width}x${settings.height}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: currentResolution,
              decoration: const InputDecoration(labelText: 'Resolution'),
              items: StreamSettings.resolutions
                  .map(
                    (r) => DropdownMenuItem(
                      value: '${r['width']}x${r['height']}',
                      child: Text('${r['width']}x${r['height']}'),
                    ),
                  )
                  .toList(),
              onChanged: enabled
                  ? (value) {
                      final match = StreamSettings.resolutions.firstWhere(
                        (r) => '${r['width']}x${r['height']}' == value,
                      );
                      onResolutionChanged(match);
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: settings.fps,
              decoration: const InputDecoration(labelText: 'FPS'),
              items: StreamSettings.fpsOptions
                  .map((fps) => DropdownMenuItem(value: fps, child: Text('$fps')))
                  .toList(),
              onChanged: enabled
                  ? (fps) {
                      if (fps != null) onFpsChanged(fps);
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: settings.bitrate,
              decoration: const InputDecoration(labelText: 'Bitrate'),
              items: StreamSettings.bitrateOptions
                  .map(
                    (b) => DropdownMenuItem(
                      value: b['value'] as int,
                      child: Text(b['label'] as String),
                    ),
                  )
                  .toList(),
              onChanged: enabled
                  ? (bitrate) {
                      if (bitrate != null) onBitrateChanged(bitrate);
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow LAN connections only'),
              subtitle: const Text('Recommended for local network use'),
              value: settings.lanOnly,
              onChanged: enabled ? onLanOnlyChanged : null,
            ),
            if (!enabled)
              Text(
                'Stop streaming to change encoder settings.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
