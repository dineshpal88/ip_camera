import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/app_destination.dart';
import '../bloc/shell/shell_cubit.dart';
import '../widgets/app_shell.dart';
import 'add_vehicle_details_page.dart';
import 'detected_vehicle_number_page.dart';
import 'scan_vehicle_page.dart';
import 'vehicle_home_page.dart';
import '../../../stream_connect/presentation/pages/connect_camera_page.dart';

class VehicleMonitoringRootPage extends StatelessWidget {
  const VehicleMonitoringRootPage({super.key});

  Widget _pageFor(AppDestination destination) {
    return switch (destination) {
      AppDestination.home => const VehicleHomePage(),
      AppDestination.scanVehicle => const ScanVehiclePage(),
      AppDestination.addVehicleDetails => const AddVehicleDetailsPage(),
      AppDestination.detectedVehicleNumber =>
        const DetectedVehicleNumberPage(),
      AppDestination.addCamera => const ConnectCameraPage(embedded: true),
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShellCubit, AppDestination>(
      builder: (context, destination) {
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
                    destination.label,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            Expanded(child: _pageFor(destination)),
          ],
        );

        return AppShell(
          destination: destination,
          onDestinationSelected: context.read<ShellCubit>().select,
          body: body,
        );
      },
    );
  }
}
