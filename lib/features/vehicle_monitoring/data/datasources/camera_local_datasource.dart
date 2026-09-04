import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/monitored_camera.dart';

class CameraLocalDataSource {
  static const storageKey = 'monitored_cameras_v1';

  Future<List<MonitoredCamera>> readCameras() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final cameras = <MonitoredCamera>[];
      for (final item in list) {
        final map = item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item as Map);
        final camera = MonitoredCamera.fromJson(map);
        if (camera.id.isNotEmpty && camera.streamUrl.isNotEmpty) {
          cameras.add(camera);
        }
      }
      return cameras;
    } catch (_) {
      return [];
    }
  }

  Future<void> writeCameras(List<MonitoredCamera> cameras) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(cameras.map((c) => c.toJson()).toList());
    await prefs.setString(storageKey, encoded);
  }
}
