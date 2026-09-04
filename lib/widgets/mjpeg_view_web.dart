// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Plays an MJPEG multipart stream via an HTML <img> element (browser-native).
class MjpegView extends StatefulWidget {
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
  State<MjpegView> createState() => _MjpegViewState();
}

class _MjpegViewState extends State<MjpegView> {
  late String _viewType;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _registerFactory();
  }

  @override
  void didUpdateWidget(covariant MjpegView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      setState(_registerFactory);
    }
  }

  void _registerFactory() {
    _generation++;
    _viewType =
        'mjpeg-view-${identityHashCode(this)}-$_generation';
    final url = widget.url;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final img = html.ImageElement()
        ..src = url
        ..alt = 'Live camera'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain'
        ..style.backgroundColor = '#000';

      img.onError.listen((_) {
        widget.onError?.call(
          'Failed to load MJPEG. Is the camera phone streaming? '
          'Open $url directly to verify.',
        );
      });
      img.onLoad.listen((_) {
        widget.onLoaded?.call();
      });
      return img;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
