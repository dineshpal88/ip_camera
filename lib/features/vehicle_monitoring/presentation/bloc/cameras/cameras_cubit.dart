import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/monitored_camera.dart';
import '../../../domain/repositories/camera_repository.dart';
import 'cameras_state.dart';

class CamerasCubit extends Cubit<CamerasState> {
  CamerasCubit(this._repository) : super(const CamerasState());

  final CameraRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: CamerasStatus.loading));
    try {
      await _repository.load();
      emit(
        state.copyWith(
          status: CamerasStatus.ready,
          cameras: _repository.cameras,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: CamerasStatus.failure,
          message: e.toString(),
        ),
      );
    }
  }

  Future<void> refresh() async {
    emit(state.copyWith(status: CamerasStatus.loading));
    try {
      await _repository.refresh();
      emit(
        state.copyWith(
          status: CamerasStatus.ready,
          cameras: _repository.cameras,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: CamerasStatus.failure,
          message: e.toString(),
        ),
      );
    }
  }

  Future<void> addCamera(MonitoredCamera camera) async {
    try {
      await _repository.add(camera);
      emit(
        state.copyWith(
          status: CamerasStatus.ready,
          cameras: _repository.cameras,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: CamerasStatus.failure,
          message: e.toString(),
          cameras: _repository.cameras,
        ),
      );
    }
  }

  Future<void> removeCamera(String id) async {
    try {
      await _repository.remove(id);
      emit(
        state.copyWith(
          status: CamerasStatus.ready,
          cameras: _repository.cameras,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: CamerasStatus.failure,
          message: e.toString(),
          cameras: _repository.cameras,
        ),
      );
    }
  }
}
