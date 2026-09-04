import 'package:flutter/material.dart';

import '../../domain/entities/app_destination.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.destination,
    required this.onDestinationSelected,
    required this.body,
  });

  final AppDestination destination;
  final ValueChanged<AppDestination> onDestinationSelected;
  final Widget body;

  static const destinations = AppDestination.values;

  IconData _icon(AppDestination item, {required bool selected}) {
    return switch (item) {
      AppDestination.home =>
        selected ? Icons.home_rounded : Icons.home_outlined,
      AppDestination.scanVehicle => selected
          ? Icons.directions_car_rounded
          : Icons.directions_car_outlined,
      AppDestination.addVehicleDetails =>
        selected ? Icons.edit_note_rounded : Icons.edit_note_outlined,
      AppDestination.detectedVehicleNumber =>
        selected ? Icons.pin_rounded : Icons.pin_outlined,
      AppDestination.addCamera =>
        selected ? Icons.videocam_rounded : Icons.videocam_outlined,
    };
  }

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
                        icon: Icon(_icon(item, selected: false)),
                        selectedIcon: Icon(_icon(item, selected: true)),
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
          appBar: AppBar(title: Text(destination.label)),
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
                        _icon(item, selected: destination == item),
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
