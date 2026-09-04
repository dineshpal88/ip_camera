class MonitoredCamera {
  const MonitoredCamera({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.createdAt,
  });

  final String id;
  final String name;
  final String streamUrl;
  final DateTime? createdAt;

  bool get isRtsp => streamUrl.toLowerCase().startsWith('rtsp://');

  bool get isWebCompatible {
    final lower = streamUrl.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.contains('.m3u8');
  }

  MonitoredCamera copyWith({
    String? id,
    String? name,
    String? streamUrl,
    DateTime? createdAt,
  }) {
    return MonitoredCamera(
      id: id ?? this.id,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'streamUrl': streamUrl,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory MonitoredCamera.fromJson(Map<String, dynamic> json) {
    return MonitoredCamera(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Camera',
      streamUrl: json['streamUrl']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}
