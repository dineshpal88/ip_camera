import 'package:flutter/material.dart';

/// Non-web stub — MJPEG HTML view is web-only.
class MjpegView extends StatelessWidget {
  const MjpegView({
    super.key,
    required this.url,
    this.onError,
    this.onLoaded,
  });

  final String url;
  final ValueChanged<String>? onError;
  final VoidCallback? onLoaded;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onError?.call('MJPEG view is only available on Web');
    });
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Text(
          'MJPEG preview is web-only',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
