class FoodScanLog {
  const FoodScanLog({
    this.id,
    required this.userId,
    required this.predictedLabel,
    required this.confidence,
    this.imagePath,
    this.dedupeKey,
    this.createdAt,
  });

  final String? id;
  final String userId;
  final String predictedLabel;
  final double confidence;
  final String? imagePath;
  final String? dedupeKey;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'predicted_label': predictedLabel,
      'confidence': confidence,
      'image_path': imagePath,
    };

    if (dedupeKey != null) {
      json['dedupe_key'] = dedupeKey;
    }
    if (id != null) {
      json['id'] = id;
    }
    if (createdAt != null) {
      json['created_at'] = createdAt!.toIso8601String();
    }

    return json;
  }
}
