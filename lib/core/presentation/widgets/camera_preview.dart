import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CameraPreview extends StatelessWidget {
  const CameraPreview({super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const Center(child: Text('Android only'));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: AndroidView(
          viewType: 'android_ip_camera/preview',
          layoutDirection: TextDirection.ltr,
          creationParamsCodec: const StandardMessageCodec(),
        ),
      ),
    );
  }
}
