import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/detected_vehicle.dart';
import '../bloc/detections/detections_cubit.dart';
import '../bloc/detections/detections_state.dart';

class DetectedVehicleNumberPage extends StatelessWidget {
  const DetectedVehicleNumberPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DetectionsCubit, DetectionsState>(
      builder: (context, state) {
        final items = state.detections;
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 800;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!state.detectionAvailable)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Card(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(state.unavailableMessage),
                      ),
                    ),
                  ),
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Text('No vehicle numbers detected yet.'),
                        )
                      : wide
                          ? _DetectedTable(items: items)
                          : _DetectedList(items: items),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DetectedList extends StatelessWidget {
  const _DetectedList({required this.items});

  final List<DetectedVehicle> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            leading: item.photoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.photoUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.image),
                    ),
                  )
                : const Icon(Icons.directions_car_rounded),
            title: Text(
              item.vehicleNumber,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              [
                if (item.cameraName != null && item.cameraName!.isNotEmpty)
                  item.cameraName!,
                item.detectedAt.toLocal().toString().split('.').first,
                if (item.confidence != null)
                  'Confidence ${(item.confidence! * 100).toStringAsFixed(0)}%',
              ].join(' · '),
            ),
          ),
        );
      },
    );
  }
}

class _DetectedTable extends StatelessWidget {
  const _DetectedTable({required this.items});

  final List<DetectedVehicle> items;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Vehicle number')),
          DataColumn(label: Text('Camera')),
          DataColumn(label: Text('Detected at')),
          DataColumn(label: Text('Confidence')),
          DataColumn(label: Text('Photo')),
        ],
        rows: [
          for (final item in items)
            DataRow(
              cells: [
                DataCell(Text(item.vehicleNumber)),
                DataCell(Text(item.cameraName ?? item.cameraId ?? '—')),
                DataCell(
                  Text(item.detectedAt.toLocal().toString().split('.').first),
                ),
                DataCell(
                  Text(
                    item.confidence == null
                        ? '—'
                        : '${(item.confidence! * 100).toStringAsFixed(0)}%',
                  ),
                ),
                DataCell(
                  item.photoUrl == null
                      ? const Text('—')
                      : const Icon(Icons.image_outlined),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
