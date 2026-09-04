import 'dart:async';

import 'package:flutter/services.dart';

import '../../features/camera_host/domain/entities/stream_info.dart';

/// Platform bridge to Android MethodChannel / EventChannel.
/// Channel IDs must stay in sync with native Kotlin.
class CameraPlatformDataSource {
  CameraPlatformDataSource();

  static const _methodChannel = MethodChannel('android_ip_camera/camera');
  static const _eventChannel = EventChannel('android_ip_camera/events');

  Stream<Map<String, dynamic>>? _events;

  Stream<Map<String, dynamic>> get events {
    _events ??= _eventChannel.receiveBroadcastStream().map(
          (event) => Map<String, dynamic>.from(event as Map),
        );
    return _events!;
  }

  Future<void> initialize() async {
    await _methodChannel.invokeMethod<void>('initialize');
  }

  Future<StreamInfo> getStreamInfo() async {
    final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'getStreamInfo',
    );
    return StreamInfo.fromMap(result ?? {});
  }

  Future<String?> getDeviceIp() async {
    return _methodChannel.invokeMethod<String>('getDeviceIp');
  }

  Future<bool> isStreaming() async {
    final result = await _methodChannel.invokeMethod<bool>('isStreaming');
    return result ?? false;
  }

  Future<int> getClientCount() async {
    final result = await _methodChannel.invokeMethod<int>('getClientCount');
    return result ?? 0;
  }

  Future<StreamInfo> startStream() async {
    final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'startStream',
    );
    return StreamInfo.fromMap(result ?? {});
  }

  Future<void> stopStream() async {
    await _methodChannel.invokeMethod<void>('stopStream');
  }

  Future<StreamInfo> switchCamera() async {
    final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'switchCamera',
    );
    return StreamInfo.fromMap(result ?? {});
  }

  Future<void> setResolution(int width, int height) async {
    await _methodChannel.invokeMethod<void>('setResolution', {
      'width': width,
      'height': height,
    });
  }

  Future<void> setFps(int fps) async {
    await _methodChannel.invokeMethod<void>('setFps', {'fps': fps});
  }

  Future<void> setBitrate(int bitrate) async {
    await _methodChannel.invokeMethod<void>('setBitrate', {'bitrate': bitrate});
  }

  Future<void> setLanOnly(bool enabled) async {
    await _methodChannel.invokeMethod<void>('setLanOnly', {'enabled': enabled});
  }

  Future<void> requestKeyFrame() async {
    await _methodChannel.invokeMethod<void>('requestKeyFrame');
  }

  Future<void> dispose() async {
    await _methodChannel.invokeMethod<void>('dispose');
  }
}
