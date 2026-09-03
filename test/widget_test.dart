import 'package:android_ip_camera/models/stream_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StreamInfo parses native map', () {
    final info = StreamInfo.fromMap({
      'ip': '192.168.1.105',
      'port': 8554,
      'path': '/live',
      'rtspUrl': 'rtsp://192.168.1.105:8554/live',
      'streaming': true,
      'clientCount': 1,
      'camera': 'Rear',
    });

    expect(info.ip, '192.168.1.105');
    expect(info.rtspUrl, 'rtsp://192.168.1.105:8554/live');
    expect(info.streaming, isTrue);
    expect(info.clientCount, 1);
  });
}
