/// Navigation destinations for the vehicle monitoring shell.
enum AppDestination {
  home,
  scanVehicle,
  addVehicleDetails,
  detectedVehicleNumber,
  addCamera,
}

extension AppDestinationX on AppDestination {
  String get label => switch (this) {
        AppDestination.home => 'Home',
        AppDestination.scanVehicle => 'Scan Vehicle',
        AppDestination.addVehicleDetails => 'Add Vehicle Details',
        AppDestination.detectedVehicleNumber => 'Detected Vehicle Number',
        AppDestination.addCamera => 'Add Camera',
      };

  String get routeName => switch (this) {
        AppDestination.home => '/home',
        AppDestination.scanVehicle => '/scan-vehicle',
        AppDestination.addVehicleDetails => '/add-vehicle-details',
        AppDestination.detectedVehicleNumber => '/detected-vehicle-number',
        AppDestination.addCamera => '/add-camera',
      };
}
