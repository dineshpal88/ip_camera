import 'package:android_ip_camera/features/camera_host/domain/entities/stream_info.dart';
import 'package:android_ip_camera/features/vehicle_monitoring/data/repositories/detection_repository_impl.dart';
import 'package:android_ip_camera/features/vehicle_monitoring/domain/entities/app_destination.dart';
import 'package:android_ip_camera/features/vehicle_monitoring/domain/entities/detected_vehicle.dart';
import 'package:android_ip_camera/core/platform/stream_url_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StreamInfo parses native map', () {
    final info = StreamInfo.fromMap({
      'ip': '192.168.1.105',
      'port': 8554,
      'path': '/live',
      'rtspUrl': 'rtsp://192.168.1.105:8554/live',
      'mjpegUrl': 'http://192.168.1.105:8080/stream.mjpg',
      'streaming': true,
      'clientCount': 1,
      'camera': 'Rear',
    });

    expect(info.ip, '192.168.1.105');
    expect(info.rtspUrl, 'rtsp://192.168.1.105:8554/live');
    expect(info.mjpegUrl, 'http://192.168.1.105:8080/stream.mjpg');
    expect(info.streaming, isTrue);
    expect(info.clientCount, 1);
  });

  test('MJPEG URL is derived from RTSP', () {
    expect(
      mjpegUrlFromRtsp('rtsp://192.168.1.7:8554/live'),
      'http://192.168.1.7:8080/stream.mjpg',
    );
  });

  test('DetectedVehicle model round-trip', () {
    final vehicle = DetectedVehicle(
      vehicleNumber: 'DL01AB1234',
      cameraId: '1',
      cameraName: 'Entrance',
      detectedAt: DateTime.utc(2026, 9, 4, 10),
      confidence: 0.91,
    );
    final copy = DetectedVehicle.fromJson(vehicle.toJson());
    expect(copy.vehicleNumber, 'DL01AB1234');
    expect(copy.cameraName, 'Entrance');
    expect(copy.confidence, 0.91);
  });

  test('Duplicate detection is suppressed during cooldown', () {
    final repo = DetectionRepositoryImpl();
    repo.cooldown = const Duration(seconds: 30);

    final first = DetectedVehicle(
      vehicleNumber: 'MH12AB1234',
      detectedAt: DateTime(2026, 9, 4, 12, 0),
      cameraName: 'Gate',
    );
    final duplicate = DetectedVehicle(
      vehicleNumber: 'mh12ab1234',
      detectedAt: DateTime(2026, 9, 4, 12, 0, 10),
      cameraName: 'Gate',
    );
    final later = DetectedVehicle(
      vehicleNumber: 'MH12AB1234',
      detectedAt: DateTime(2026, 9, 4, 12, 1),
      cameraName: 'Gate',
    );

    expect(repo.addIfNotDuplicate(first), isTrue);
    expect(repo.addIfNotDuplicate(duplicate), isFalse);
    expect(repo.addIfNotDuplicate(later), isTrue);
    expect(repo.detections.length, 2);
  });

  test('App destinations include Add Camera', () {
    expect(AppDestination.addCamera.label, 'Add Camera');
    expect(AppDestination.scanVehicle.routeName, '/scan-vehicle');
    expect(AppDestination.values.length, 5);
  });

  testWidgets('Blank home content builds', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(),
        ),
      ),
    );
    expect(find.byType(SizedBox), findsWidgets);
  });
}
