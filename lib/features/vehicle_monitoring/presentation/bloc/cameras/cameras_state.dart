import 'package:equatable/equatable.dart';

import '../../../domain/entities/monitored_camera.dart';

enum CamerasStatus { initial, loading, ready, failure }

class CamerasState extends Equatable {
  const CamerasState({
    this.status = CamerasStatus.initial,
    this.cameras = const [],
    this.message,
  });

  final CamerasStatus status;
  final List<MonitoredCamera> cameras;
  final String? message;

  bool get isLoading =>
      status == CamerasStatus.loading || status == CamerasStatus.initial;

  CamerasState copyWith({
    CamerasStatus? status,
    List<MonitoredCamera>? cameras,
    String? message,
  }) {
    return CamerasState(
      status: status ?? this.status,
      cameras: cameras ?? this.cameras,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, cameras, message];
}
