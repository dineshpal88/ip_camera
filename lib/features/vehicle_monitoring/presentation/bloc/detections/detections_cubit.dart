import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/detected_vehicle.dart';
import '../../../domain/repositories/detection_repository.dart';
import '../../../domain/services/vehicle_number_detector.dart';
import 'detections_state.dart';

class DetectionsCubit extends Cubit<DetectionsState> {
  DetectionsCubit({
    required DetectionRepository repository,
    required VehicleNumberDetector detector,
  })  : _repository = repository,
        _detector = detector,
        super(
          DetectionsState(
            detectionAvailable: detector.isAvailable,
            unavailableMessage: detector.unavailableMessage,
            detections: repository.detections,
          ),
        );

  final DetectionRepository _repository;
  final VehicleNumberDetector _detector;

  VehicleNumberDetector get detector => _detector;

  bool addDetection(DetectedVehicle vehicle) {
    final accepted = _repository.addIfNotDuplicate(vehicle);
    if (accepted) {
      emit(state.copyWith(detections: _repository.detections));
    }
    return accepted;
  }

  void clear() {
    _repository.clear();
    emit(state.copyWith(detections: const []));
  }
}
