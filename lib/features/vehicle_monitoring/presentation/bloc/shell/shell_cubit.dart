import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/app_destination.dart';

class ShellCubit extends Cubit<AppDestination> {
  ShellCubit() : super(AppDestination.home);

  void select(AppDestination destination) => emit(destination);

  void openAddCamera() => emit(AppDestination.addCamera);

  void openScanVehicle() => emit(AppDestination.scanVehicle);
}
