import 'package:equatable/equatable.dart';

import '../../../domain/entities/detected_vehicle.dart';

class DetectionsState extends Equatable {
  const DetectionsState({
    this.detections = const [],
    this.detectionAvailable = false,
    this.unavailableMessage =
        'Vehicle number detection is not available on this platform.',
  });

  final List<DetectedVehicle> detections;
  final bool detectionAvailable;
  final String unavailableMessage;

  DetectionsState copyWith({
    List<DetectedVehicle>? detections,
    bool? detectionAvailable,
    String? unavailableMessage,
  }) {
    return DetectionsState(
      detections: detections ?? this.detections,
      detectionAvailable: detectionAvailable ?? this.detectionAvailable,
      unavailableMessage: unavailableMessage ?? this.unavailableMessage,
    );
  }

  @override
  List<Object?> get props =>
      [detections, detectionAvailable, unavailableMessage];
}
