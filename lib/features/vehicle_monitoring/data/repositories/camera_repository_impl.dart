import '../../domain/entities/monitored_camera.dart';
import '../../domain/repositories/camera_repository.dart';
import '../datasources/camera_local_datasource.dart';

class CameraRepositoryImpl implements CameraRepository {
  CameraRepositoryImpl(this._local);

  final CameraLocalDataSource _local;
  final List<MonitoredCamera> _cameras = [];
  bool _loaded = false;

  @override
  List<MonitoredCamera> get cameras => List.unmodifiable(_cameras);

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> load() async {
    if (_loaded) return;
    final stored = await _local.readCameras();
    _cameras
      ..clear()
      ..addAll(stored);
    _loaded = true;
  }

  @override
  Future<void> refresh() async {
    _loaded = false;
    await load();
  }

  @override
  Future<void> add(MonitoredCamera camera) async {
    await load();
    _cameras.removeWhere((c) => c.id == camera.id);
    _cameras.add(camera);
    await _local.writeCameras(_cameras);
  }

  @override
  Future<void> remove(String id) async {
    await load();
    _cameras.removeWhere((c) => c.id == id);
    await _local.writeCameras(_cameras);
  }
}
