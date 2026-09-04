import 'package:flutter/foundation.dart';

/// Browsers cannot play RTSP the way VLC / Android (libmpv) can.
bool isRtspUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  return uri != null && uri.scheme.toLowerCase() == 'rtsp';
}

bool isWebCompatibleStreamUrl(String url) {
  final lower = url.trim().toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.contains('.m3u8') ||
      lower.contains('.mjpg') ||
      lower.contains('.mjpeg');
}

/// Companion MJPEG URL served by the Android host next to RTSP.
/// `rtsp://192.168.1.7:8554/live` → `http://192.168.1.7:8080/stream.mjpg`
String? mjpegUrlFromRtsp(String streamUrl) {
  final uri = Uri.tryParse(streamUrl.trim());
  if (uri == null || uri.scheme.toLowerCase() != 'rtsp') return null;
  if (uri.host.isEmpty) return null;
  return Uri(
    scheme: 'http',
    host: uri.host,
    port: 8080,
    path: '/stream.mjpg',
  ).toString();
}

/// URL the current platform should actually open for live preview.
String? playbackUrlForPlatform(String streamUrl) {
  final trimmed = streamUrl.trim();
  if (trimmed.isEmpty) return null;

  if (!kIsWeb) {
    return trimmed;
  }

  if (isWebCompatibleStreamUrl(trimmed)) {
    return trimmed;
  }

  // Prefer MJPEG companion stream for RTSP sources on Web.
  return mjpegUrlFromRtsp(trimmed);
}

bool isMjpegUrl(String url) {
  final lower = url.trim().toLowerCase();
  return lower.contains('.mjpg') ||
      lower.contains('.mjpeg') ||
      lower.contains('/stream.mjpg') ||
      lower.contains('multipart');
}

const String kWebRtspUnsupportedMessage =
    'RTSP is not directly supported by web browsers.\n\n'
    'This app maps RTSP to the camera phone MJPEG URL '
    '(http://IP:8080/stream.mjpg). Start streaming on the Android '
    'camera phone first, then retry.\n\n'
    'VLC can still open the original rtsp:// URL.';
