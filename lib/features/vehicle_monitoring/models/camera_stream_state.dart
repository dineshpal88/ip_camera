enum CameraStreamStatus {
  idle,
  connecting,
  live,
  offline,
  unsupported,
}

class CameraStreamState {
  const CameraStreamState({
    this.status = CameraStreamStatus.idle,
    this.message,
  });

  final CameraStreamStatus status;
  final String? message;

  CameraStreamState copyWith({
    CameraStreamStatus? status,
    String? message,
  }) {
    return CameraStreamState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }
}
