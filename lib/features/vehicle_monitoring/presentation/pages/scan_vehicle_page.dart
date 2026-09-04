import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/monitored_camera.dart';
import '../bloc/cameras/cameras_cubit.dart';
import '../bloc/cameras/cameras_state.dart';
import '../bloc/detections/detections_cubit.dart';
import '../bloc/shell/shell_cubit.dart';
import '../widgets/camera_preview_card.dart';

class ScanVehiclePage extends StatelessWidget {
  const ScanVehiclePage({super.key});

  Future<void> _removeCamera(
    BuildContext context,
    MonitoredCamera camera,
  ) async {
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
    if (confirmed != true || !context.mounted) return;
    await context.read<CamerasCubit>().removeCamera(camera.id);
  }

  @override
  Widget build(BuildContext context) {
    final detector = context.read<DetectionsCubit>().detector;

    return BlocBuilder<CamerasCubit, CamerasState>(
      builder: (context, state) {
        if (state.isLoading && state.cameras.isEmpty) {
          return const Center(child: Text('Loading cameras...'));
        }

        final cameras = state.cameras;

        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 700 ? 2 : 1;
            return CustomScrollView(
              slivers: [
                if (!detector.isAvailable)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Card(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(detector.unavailableMessage),
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
                              onPressed: () =>
                                  context.read<ShellCubit>().openAddCamera(),
                              icon: const Icon(Icons.add_a_photo_rounded),
                              label: const Text('Add Camera'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  ContainedCameraGrid(
                    cameras: cameras,
                    columns: columns,
                    detectionEnabled: detector.isAvailable,
                    onRemove: (camera) => _removeCamera(context, camera),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Center(
                        child: FilledButton.icon(
                          onPressed: () =>
                              context.read<ShellCubit>().openAddCamera(),
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
      },
    );
  }
}

class ContainedCameraGrid extends StatelessWidget {
  const ContainedCameraGrid({
    super.key,
    required this.cameras,
    required this.columns,
    required this.detectionEnabled,
    required this.onRemove,
  });

  final List<MonitoredCamera> cameras;
  final int columns;
  final bool detectionEnabled;
  final ValueChanged<MonitoredCamera> onRemove;

  @override
  Widget build(BuildContext context) {
    return ContainedSliverPadding(
      cameras: cameras,
      columns: columns,
      detectionEnabled: detectionEnabled,
      onRemove: onRemove,
    );
  }
}

class ContainedSliverPadding extends StatelessWidget {
  const ContainedSliverPadding({
    super.key,
    required this.cameras,
    required this.columns,
    required this.detectionEnabled,
    required this.onRemove,
  });

  final List<MonitoredCamera> cameras;
  final int columns;
  final bool detectionEnabled;
  final ValueChanged<MonitoredCamera> onRemove;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          const spacing = 12.0;
          final width = constraints.crossAxisExtent;
          final itemWidth =
              columns == 1 ? width : (width - spacing) / 2;
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
                      detectionLabel:
                          detectionEnabled ? 'Detection enabled' : null,
                      onRemove: () => onRemove(camera),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
