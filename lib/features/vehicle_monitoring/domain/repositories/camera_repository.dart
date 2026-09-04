import '../entities/monitored_camera.dart';

abstract class CameraRepository {
  List<MonitoredCamera> get cameras;
  bool get isLoaded;

  Future<void> load();
  Future<void> refresh();
  Future<void> add(MonitoredCamera camera);
  Future<void> remove(String id);
}
