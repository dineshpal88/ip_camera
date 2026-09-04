import 'package:flutter/material.dart';

import '../services/camera_repository.dart';
import '../widgets/app_shell.dart';
import 'add_vehicle_details_screen.dart';
import 'detected_vehicle_number_screen.dart';
import 'scan_vehicle_screen.dart';
import 'vehicle_home_screen.dart';
import '../../../screens/connect_camera_screen.dart';

/// Root shell that hosts the five required destinations without breaking
/// existing Camera Screen / RTSP flows (opened via Add Camera).
class VehicleMonitoringRoot extends StatefulWidget {
  const VehicleMonitoringRoot({super.key});

  @override
  State<VehicleMonitoringRoot> createState() => _VehicleMonitoringRootState();
}

class _VehicleMonitoringRootState extends State<VehicleMonitoringRoot> {
  AppShellDestination _destination = AppShellDestination.home;

  @override
  void initState() {
    super.initState();
    CameraRepository.instance.load();
  }

  void _select(AppShellDestination destination) {
    setState(() => _destination = destination);
  }

  Widget _pageFor(AppShellDestination destination) {
    return switch (destination) {
      AppShellDestination.home => const VehicleHomeScreen(),
      AppShellDestination.scanVehicle => ScanVehicleScreen(
          onAddCamera: () => _select(AppShellDestination.addCamera),
        ),
      AppShellDestination.addVehicleDetails =>
        const AddVehicleDetailsScreen(),
      AppShellDestination.detectedVehicleNumber =>
        const DetectedVehicleNumberScreen(),
      AppShellDestination.addCamera => ConnectCameraScreen(
          embedded: true,
          onCameraSaved: () => _select(AppShellDestination.scanVehicle),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Material(
            elevation: 0,
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                _destination.label,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        Expanded(
          child: _pageFor(_destination),
        ),
      ],
    );

    return AppShell(
      destination: _destination,
      onDestinationSelected: _select,
      body: body,
    );
  }
}
