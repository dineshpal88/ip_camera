import 'dart:async';

import 'package:flutter/services.dart';

import '../models/stream_info.dart';

class CameraPlatformService {
  CameraPlatformService._();

  static const _methodChannel = MethodChannel('android_ip_camera/camera');
  static const _eventChannel = EventChannel('android_ip_camera/events');

  static Stream<Map<String, dynamic>>? _events;

  static Stream<Map<String, dynamic>> get events {
    _events ??= _eventChannel.receiveBroadcastStream().map(
          (event) => Map<String, dynamic>.from(event as Map),
        );
    return _events!;
  }

  static Future<void> initialize() async {
    await _methodChannel.invokeMethod<void>('initialize');
  }

  static Future<StreamInfo> getStreamInfo() async {
    final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'getStreamInfo',
    );
    return StreamInfo.fromMap(result ?? {});
  }

  static Future<String?> getDeviceIp() async {
    return _methodChannel.invokeMethod<String>('getDeviceIp');
  }

  static Future<bool> isStreaming() async {
    final result = await _methodChannel.invokeMethod<bool>('isStreaming');
    return result ?? false;
  }

  static Future<int> getClientCount() async {
    final result = await _methodChannel.invokeMethod<int>('getClientCount');
    return result ?? 0;
  }

  static Future<StreamInfo> startStream() async {
    final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'startStream',
    );
    return StreamInfo.fromMap(result ?? {});
  }

  static Future<void> stopStream() async {
    await _methodChannel.invokeMethod<void>('stopStream');
  }

  static Future<StreamInfo> switchCamera() async {
    final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'switchCamera',
    );
    return StreamInfo.fromMap(result ?? {});
  }

  static Future<void> setResolution(int width, int height) async {
    await _methodChannel.invokeMethod<void>('setResolution', {
      'width': width,
      'height': height,
    });
  }

  static Future<void> setFps(int fps) async {
    await _methodChannel.invokeMethod<void>('setFps', {'fps': fps});
  }

  static Future<void> setBitrate(int bitrate) async {
    await _methodChannel.invokeMethod<void>('setBitrate', {'bitrate': bitrate});
  }

  static Future<void> setLanOnly(bool enabled) async {
    await _methodChannel.invokeMethod<void>('setLanOnly', {'enabled': enabled});
  }

  static Future<void> requestKeyFrame() async {
    await _methodChannel.invokeMethod<void>('requestKeyFrame');
  }

  static Future<void> dispose() async {
    await _methodChannel.invokeMethod<void>('dispose');
  }
}
