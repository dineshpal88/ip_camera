import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/monitored_camera.dart';

/// Persists CCTV / RTSP cameras added via the existing Add Camera flow.
class CameraRepository extends ChangeNotifier {
  CameraRepository._();

  static final CameraRepository instance = CameraRepository._();

  static const _storageKey = 'monitored_cameras_v1';

  final List<MonitoredCamera> _cameras = [];
  bool _loaded = false;

  List<MonitoredCamera> get cameras => List.unmodifiable(_cameras);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _cameras.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final camera = MonitoredCamera.fromJson(item);
            if (camera.id.isNotEmpty && camera.streamUrl.isNotEmpty) {
              _cameras.add(camera);
            }
          } else if (item is Map) {
            final camera = MonitoredCamera.fromJson(
              Map<String, dynamic>.from(item),
            );
            if (camera.id.isNotEmpty && camera.streamUrl.isNotEmpty) {
              _cameras.add(camera);
            }
          }
        }
      } catch (_) {
        // Keep empty list on corrupt storage.
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> add(MonitoredCamera camera) async {
    await load();
    _cameras.removeWhere((c) => c.id == camera.id);
    _cameras.add(camera);
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await load();
    _cameras.removeWhere((c) => c.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> refresh() async {
    _loaded = false;
    await load();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_cameras.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
