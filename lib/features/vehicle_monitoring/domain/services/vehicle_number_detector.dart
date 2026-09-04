import '../entities/detected_vehicle.dart';

/// Platform-agnostic plate detection hook.
///
/// No ML/OCR stack is wired yet — use [UnavailableVehicleNumberDetector]
/// until a reliable Android/Web implementation is available.
abstract class VehicleNumberDetector {
  bool get isAvailable;

  String get unavailableMessage;

  /// Attempt detection from an opaque frame payload.
  Future<DetectedVehicle?> detectFromFrame({
    required Object frame,
    required String cameraId,
    required String cameraName,
  });
}

class UnavailableVehicleNumberDetector implements VehicleNumberDetector {
  const UnavailableVehicleNumberDetector();

  @override
  bool get isAvailable => false;

  @override
  String get unavailableMessage =>
      'Vehicle number detection is not available on this platform.';

  @override
  Future<DetectedVehicle?> detectFromFrame({
    required Object frame,
    required String cameraId,
    required String cameraName,
  }) async =>
      null;
}

VehicleNumberDetector createVehicleNumberDetector() {
  return const UnavailableVehicleNumberDetector();
}
