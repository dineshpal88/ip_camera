import 'package:flutter/foundation.dart';

import '../models/detected_vehicle.dart';

/// In-memory detection events with duplicate suppression.
class DetectedVehicleRepository extends ChangeNotifier {
  DetectedVehicleRepository._();

  static final DetectedVehicleRepository instance =
      DetectedVehicleRepository._();

  final List<DetectedVehicle> _detections = [];
  final Map<String, DateTime> _lastSeen = {};

  /// Same plate ignored during this window.
  Duration cooldown = const Duration(seconds: 20);

  List<DetectedVehicle> get detections => List.unmodifiable(_detections);

  /// Returns true if the detection was accepted (not a duplicate).
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
    notifyListeners();
    return true;
  }

  void clear() {
    _detections.clear();
    _lastSeen.clear();
    notifyListeners();
  }
}
