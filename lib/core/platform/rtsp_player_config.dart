import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Applies RTSP-friendly libmpv options on native platforms only.
/// Web stubs do not expose [NativePlayer.setProperty], so this is a no-op on Web.
Future<void> configureRtspNativePlayer(Player player) async {
  if (kIsWeb) return;
  final platform = player.platform;
  try {
    // Avoid static NativePlayer.setProperty — unavailable in web stubs.
    final dynamic native = platform;
    await native.setProperty('demuxer', 'lavf');
    await native.setProperty('demuxer-lavf-format', 'rtsp');
    await native.setProperty(
      'demuxer-lavf-o',
      'rtsp_transport=tcp,stimeout=5000000',
    );
    await native.setProperty('rtsp-transport', 'tcp');
    await native.setProperty('network-timeout', '10');
    await native.setProperty('aid', 'no');
    await native.setProperty('audio', 'no');
    await native.setProperty('cache', 'no');
    await native.setProperty('demuxer-readahead-secs', '1');
  } catch (_) {
    // Player backends without setProperty are left unchanged.
  }
}
