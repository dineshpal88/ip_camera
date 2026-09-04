import 'package:flutter/material.dart';

enum AppShellDestination {
  home,
  scanVehicle,
  addVehicleDetails,
  detectedVehicleNumber,
  addCamera,
}

extension AppShellDestinationX on AppShellDestination {
  String get label => switch (this) {
        AppShellDestination.home => 'Home',
        AppShellDestination.scanVehicle => 'Scan Vehicle',
        AppShellDestination.addVehicleDetails => 'Add Vehicle Details',
        AppShellDestination.detectedVehicleNumber => 'Detected Vehicle Number',
        AppShellDestination.addCamera => 'Add Camera',
      };

  IconData get icon => switch (this) {
        AppShellDestination.home => Icons.home_outlined,
        AppShellDestination.scanVehicle => Icons.directions_car_outlined,
        AppShellDestination.addVehicleDetails => Icons.edit_note_outlined,
        AppShellDestination.detectedVehicleNumber => Icons.pin_outlined,
        AppShellDestination.addCamera => Icons.videocam_outlined,
      };

  IconData get selectedIcon => switch (this) {
        AppShellDestination.home => Icons.home_rounded,
        AppShellDestination.scanVehicle => Icons.directions_car_rounded,
        AppShellDestination.addVehicleDetails => Icons.edit_note_rounded,
        AppShellDestination.detectedVehicleNumber => Icons.pin_rounded,
        AppShellDestination.addCamera => Icons.videocam_rounded,
      };

  String get routeName => switch (this) {
        AppShellDestination.home => '/home',
        AppShellDestination.scanVehicle => '/scan-vehicle',
        AppShellDestination.addVehicleDetails => '/add-vehicle-details',
        AppShellDestination.detectedVehicleNumber => '/detected-vehicle-number',
        AppShellDestination.addCamera => '/add-camera',
      };
}

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.destination,
    required this.onDestinationSelected,
    required this.body,
  });

  final AppShellDestination destination;
  final ValueChanged<AppShellDestination> onDestinationSelected;
  final Widget body;

  static const destinations = AppShellDestination.values;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSidebar = constraints.maxWidth >= 900;
        if (useSidebar) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: constraints.maxWidth >= 1100,
                  selectedIndex: destination.index,
                  onDestinationSelected: (index) {
                    onDestinationSelected(destinations[index]);
                  },
                  labelType: constraints.maxWidth >= 1100
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Icon(
                      Icons.security_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  destinations: [
                    for (final item in destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: Text(item.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(destination.label),
          ),
          drawer: Drawer(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  DrawerHeader(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        'Vehicle Monitoring',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                  for (final item in destinations)
                    ListTile(
                      leading: Icon(
                        destination == item ? item.selectedIcon : item.icon,
                      ),
                      title: Text(item.label),
                      selected: destination == item,
                      onTap: () {
                        Navigator.of(context).pop();
                        onDestinationSelected(item);
                      },
                    ),
                ],
              ),
            ),
          ),
          body: body,
        );
      },
    );
  }
}
