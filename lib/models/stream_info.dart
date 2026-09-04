class StreamInfo {
  const StreamInfo({
    this.ip = '',
    this.port = 8554,
    this.path = '/live',
    this.rtspUrl = '',
    this.streaming = false,
    this.clientCount = 0,
    this.camera = 'Rear',
    this.resolution = '720x1280',
    this.fps = 30,
    this.bitrate = 2000000,
    this.lanOnly = true,
  });

  final String ip;
  final int port;
  final String path;
  final String rtspUrl;
  final bool streaming;
  final int clientCount;
  final String camera;
  final String resolution;
  final int fps;
  final int bitrate;
  final bool lanOnly;

  bool get hasWifiIp => ip.isNotEmpty;

  factory StreamInfo.fromMap(Map<dynamic, dynamic> map) {
    return StreamInfo(
      ip: map['ip']?.toString() ?? '',
      port: (map['port'] as num?)?.toInt() ?? 8554,
      path: map['path']?.toString() ?? '/live',
      rtspUrl: map['rtspUrl']?.toString() ?? '',
      streaming: map['streaming'] == true,
      clientCount: (map['clientCount'] as num?)?.toInt() ?? 0,
      camera: map['camera']?.toString() ?? 'Rear',
      resolution: map['resolution']?.toString() ?? '720x1280',
      fps: (map['fps'] as num?)?.toInt() ?? 30,
      bitrate: (map['bitrate'] as num?)?.toInt() ?? 2000000,
      lanOnly: map['lanOnly'] != false,
    );
  }
}
