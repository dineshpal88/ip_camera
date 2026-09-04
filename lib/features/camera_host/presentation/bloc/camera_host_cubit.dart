import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/platform/camera_platform_datasource.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/stream_settings.dart';

enum CameraHostStatus { initial, ready, loading, streaming, failure }

class CameraHostState extends Equatable {
  const CameraHostState({
    this.status = CameraHostStatus.initial,
    this.info = const StreamInfo(),
    this.settings = const StreamSettings(),
    this.message,
  });

  final CameraHostStatus status;
  final StreamInfo info;
  final StreamSettings settings;
  final String? message;

  bool get isBusy => status == CameraHostStatus.loading;
  bool get isStreaming => info.streaming;

  CameraHostState copyWith({
    CameraHostStatus? status,
    StreamInfo? info,
    StreamSettings? settings,
    String? message,
  }) {
    return CameraHostState(
      status: status ?? this.status,
      info: info ?? this.info,
      settings: settings ?? this.settings,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, info, settings, message];
}

class CameraHostCubit extends Cubit<CameraHostState> {
  CameraHostCubit(this._platform) : super(const CameraHostState());

  final CameraPlatformDataSource _platform;
  StreamSubscription<Map<String, dynamic>>? _eventsSub;

  Future<void> initialize() async {
    emit(state.copyWith(status: CameraHostStatus.loading));
    try {
      await _platform.initialize();
      _eventsSub ??= _platform.events.listen(_onNativeEvent);
      final info = await _platform.getStreamInfo();
      emit(
        state.copyWith(
          status: info.streaming
              ? CameraHostStatus.streaming
              : CameraHostStatus.ready,
          info: info,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: CameraHostStatus.failure,
          message: 'Failed to initialize camera: $e',
        ),
      );
    }
  }

  void _onNativeEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    switch (type) {
      case 'streamingStarted':
      case 'streamingStopped':
      case 'clientConnected':
      case 'clientDisconnected':
      case 'stateChanged':
      case 'ipChanged':
        refreshInfo();
      case 'error':
      case 'encoderError':
      case 'cameraError':
        emit(
          state.copyWith(
            message: event['message']?.toString() ?? 'Unknown error',
          ),
        );
        refreshInfo();
    }
  }

  Future<void> refreshInfo() async {
    try {
      final info = await _platform.getStreamInfo();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: info.streaming
              ? CameraHostStatus.streaming
              : CameraHostStatus.ready,
          info: info,
        ),
      );
    } catch (_) {}
  }

  Future<void> startStream() async {
    emit(state.copyWith(status: CameraHostStatus.loading, message: null));
    try {
      final info = await _platform.startStream();
      emit(
        state.copyWith(
          status: CameraHostStatus.streaming,
          info: info,
          message: info.rtspUrl.isNotEmpty
              ? 'Streaming on ${info.rtspUrl}'
              : null,
        ),
      );
    } on PlatformException catch (e) {
      emit(
        state.copyWith(
          status: CameraHostStatus.failure,
          message: e.message ?? 'Failed to start stream',
        ),
      );
      await refreshInfo();
    } catch (e) {
      emit(
        state.copyWith(
          status: CameraHostStatus.failure,
          message: '$e',
        ),
      );
      await refreshInfo();
    }
  }

  Future<void> stopStream() async {
    emit(state.copyWith(status: CameraHostStatus.loading));
    await _platform.stopStream();
    await refreshInfo();
  }

  Future<void> switchCamera() async {
    if (state.isStreaming) return;
    final info = await _platform.switchCamera();
    emit(state.copyWith(info: info, status: CameraHostStatus.ready));
  }

  Future<void> updateResolution(int width, int height) async {
    if (state.isStreaming) return;
    final next = state.settings.copyWith(width: width, height: height);
    emit(state.copyWith(settings: next));
    await _platform.setResolution(width, height);
  }

  Future<void> updateFps(int fps) async {
    if (state.isStreaming) return;
    emit(state.copyWith(settings: state.settings.copyWith(fps: fps)));
    await _platform.setFps(fps);
  }

  Future<void> updateBitrate(int bitrate) async {
    if (state.isStreaming) return;
    emit(state.copyWith(settings: state.settings.copyWith(bitrate: bitrate)));
    await _platform.setBitrate(bitrate);
  }

  Future<void> updateLanOnly(bool enabled) async {
    if (state.isStreaming) return;
    emit(state.copyWith(settings: state.settings.copyWith(lanOnly: enabled)));
    await _platform.setLanOnly(enabled);
  }

  Future<void> disposeHost() async {
    await _eventsSub?.cancel();
    _eventsSub = null;
    if (!state.isStreaming) {
      await _platform.dispose();
    }
  }

  @override
  Future<void> close() async {
    await _eventsSub?.cancel();
    return super.close();
  }
}
