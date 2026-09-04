import '../entities/detected_vehicle.dart';

abstract class DetectionRepository {
  List<DetectedVehicle> get detections;
  Duration get cooldown;
  set cooldown(Duration value);

  bool addIfNotDuplicate(DetectedVehicle vehicle);
  void clear();
}
