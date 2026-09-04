import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/camera_host/presentation/bloc/camera_host_cubit.dart';
import '../features/vehicle_monitoring/data/datasources/camera_local_datasource.dart';
import '../features/vehicle_monitoring/data/repositories/camera_repository_impl.dart';
import '../features/vehicle_monitoring/data/repositories/detection_repository_impl.dart';
import '../features/vehicle_monitoring/domain/services/vehicle_number_detector.dart';
import '../features/vehicle_monitoring/presentation/bloc/cameras/cameras_cubit.dart';
import '../features/vehicle_monitoring/presentation/bloc/detections/detections_cubit.dart';
import '../features/vehicle_monitoring/presentation/bloc/shell/shell_cubit.dart';
import '../features/vehicle_monitoring/presentation/pages/vehicle_monitoring_root_page.dart';
import '../core/platform/camera_platform_datasource.dart';

class AppDependencies {
  AppDependencies._();

  static late final CameraLocalDataSource cameraLocalDataSource;
  static late final CameraRepositoryImpl cameraRepository;
  static late final DetectionRepositoryImpl detectionRepository;
  static late final VehicleNumberDetector vehicleNumberDetector;
  static late final CameraPlatformDataSource cameraPlatformDataSource;

  static void init() {
    cameraLocalDataSource = CameraLocalDataSource();
    cameraRepository = CameraRepositoryImpl(cameraLocalDataSource);
    detectionRepository = DetectionRepositoryImpl();
    vehicleNumberDetector = createVehicleNumberDetector();
    cameraPlatformDataSource = CameraPlatformDataSource();
  }
}

class IpCameraApp extends StatelessWidget {
  const IpCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ShellCubit()),
        BlocProvider(
          create: (_) => CamerasCubit(AppDependencies.cameraRepository)..load(),
        ),
        BlocProvider(
          create: (_) => DetectionsCubit(
            repository: AppDependencies.detectionRepository,
            detector: AppDependencies.vehicleNumberDetector,
          ),
        ),
        BlocProvider(
          create: (_) =>
              CameraHostCubit(AppDependencies.cameraPlatformDataSource),
        ),
      ],
      child: MaterialApp(
        title: 'Vehicle Monitoring',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.dark,
          ),
        ),
        home: const VehicleMonitoringRootPage(),
      ),
    );
  }
}
