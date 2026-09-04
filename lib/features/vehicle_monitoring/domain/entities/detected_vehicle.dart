class DetectedVehicle {
  const DetectedVehicle({
    required this.vehicleNumber,
    required this.detectedAt,
    this.photoUrl,
    this.cameraId,
    this.cameraName,
    this.confidence,
  });

  final String vehicleNumber;
  final String? photoUrl;
  final String? cameraId;
  final String? cameraName;
  final DateTime detectedAt;
  final double? confidence;

  Map<String, dynamic> toJson() => {
        'vehicleNumber': vehicleNumber,
        'photoUrl': photoUrl,
        'cameraId': cameraId,
        'cameraName': cameraName,
        'detectedAt': detectedAt.toIso8601String(),
        'confidence': confidence,
      };

  factory DetectedVehicle.fromJson(Map<String, dynamic> json) {
    return DetectedVehicle(
      vehicleNumber: json['vehicleNumber']?.toString() ?? '',
      photoUrl: json['photoUrl']?.toString(),
      cameraId: json['cameraId']?.toString(),
      cameraName: json['cameraName']?.toString(),
      detectedAt:
          DateTime.tryParse(json['detectedAt']?.toString() ?? '') ??
          DateTime.now(),
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}
