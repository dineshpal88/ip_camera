import '../../domain/entities/detected_vehicle.dart';
import '../../domain/repositories/detection_repository.dart';

class DetectionRepositoryImpl implements DetectionRepository {
  final List<DetectedVehicle> _detections = [];
  final Map<String, DateTime> _lastSeen = {};

  @override
  Duration cooldown = const Duration(seconds: 20);

  @override
  List<DetectedVehicle> get detections => List.unmodifiable(_detections);

  @override
  bool addIfNotDuplicate(DetectedVehicle vehicle) {
    final key = vehicle.vehicleNumber.trim().toUpperCase();
    if (key.isEmpty) return false;

    final now = vehicle.detectedAt;
    final previous = _lastSeen[key];
    if (previous != null && now.difference(previous) < cooldown) {
      return false;
    }

    _lastSeen[key] = now;
    _detections.insert(0, vehicle);
    return true;
  }

  @override
  void clear() {
    _detections.clear();
    _lastSeen.clear();
  }
}
