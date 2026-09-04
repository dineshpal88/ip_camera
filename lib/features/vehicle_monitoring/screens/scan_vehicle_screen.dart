import 'package:flutter/material.dart';

import '../models/monitored_camera.dart';
import '../services/camera_repository.dart';
import '../services/vehicle_number_detector.dart';
import '../widgets/camera_preview_card.dart';

class ScanVehicleScreen extends StatefulWidget {
  const ScanVehicleScreen({
    super.key,
    required this.onAddCamera,
  });

  final VoidCallback onAddCamera;

  @override
  State<ScanVehicleScreen> createState() => _ScanVehicleScreenState();
}

class _ScanVehicleScreenState extends State<ScanVehicleScreen> {
  final _repo = CameraRepository.instance;
  final _detector = createVehicleNumberDetector();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _repo.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _repo.load();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _removeCamera(MonitoredCamera camera) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove camera?'),
        content: Text('Remove "${camera.name}" from Scan Vehicle?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo.remove(camera.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_repo.isLoaded) {
      return const Center(child: Text('Loading cameras...'));
    }

    final cameras = _repo.cameras;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 2 : 1;
        return CustomScrollView(
          slivers: [
            if (!_detector.isAvailable)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Card(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_detector.unavailableMessage),
                    ),
                  ),
                ),
              ),
            if (cameras.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('No cameras added yet.'),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: widget.onAddCamera,
                          icon: const Icon(Icons.add_a_photo_rounded),
                          label: const Text('Add Camera'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final spacing = 12.0;
                    final width = constraints.crossAxisExtent;
                    final itemWidth = columns == 1
                        ? width
                        : (width - spacing) / 2;
                    return SliverToBoxAdapter(
                      child: Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final camera in cameras)
                            SizedBox(
                              width: itemWidth,
                              child: CameraPreviewCard(
                                key: ValueKey(camera.id),
                                camera: camera,
                                detectionLabel: _detector.isAvailable
                                    ? 'Detection enabled'
                                    : null,
                                onRemove: () => _removeCamera(camera),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Center(
                    child: FilledButton.icon(
                      onPressed: widget.onAddCamera,
                      icon: const Icon(Icons.add_a_photo_rounded),
                      label: const Text('Add Camera'),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
