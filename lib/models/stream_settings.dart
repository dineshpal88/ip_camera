class StreamSettings {
  const StreamSettings({
    this.width = 1280,
    this.height = 720,
    this.fps = 30,
    this.bitrate = 2000000,
    this.lanOnly = true,
  });

  final int width;
  final int height;
  final int fps;
  final int bitrate;
  final bool lanOnly;

  StreamSettings copyWith({
    int? width,
    int? height,
    int? fps,
    int? bitrate,
    bool? lanOnly,
  }) {
    return StreamSettings(
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
      bitrate: bitrate ?? this.bitrate,
      lanOnly: lanOnly ?? this.lanOnly,
    );
  }

  String get resolutionLabel => '${width}x$height';

  static const resolutions = <Map<String, int>>[
    {'width': 640, 'height': 480},
    {'width': 1280, 'height': 720},
    {'width': 1920, 'height': 1080},
  ];

  static const fpsOptions = [15, 24, 30];

  static const bitrateOptions = <Map<String, dynamic>>[
    {'label': '1 Mbps', 'value': 1000000},
    {'label': '2 Mbps', 'value': 2000000},
    {'label': '4 Mbps', 'value': 4000000},
    {'label': '6 Mbps', 'value': 6000000},
  ];

  static String bitrateLabel(int bitrate) {
    return switch (bitrate) {
      1000000 => '1 Mbps',
      2000000 => '2 Mbps',
      4000000 => '4 Mbps',
      6000000 => '6 Mbps',
      _ => '${bitrate ~/ 1000000} Mbps',
    };
  }
}
