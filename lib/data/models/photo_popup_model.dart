class PhotoPopupModel {
  final String id;
  final String platform;
  final bool enabled;
  final int displayOrder;
  final DateTime updatedAt;
  final String? title;
  final String? description;
  final String photoUrl;

  PhotoPopupModel({
    required this.id,
    required this.platform,
    required this.enabled,
    required this.displayOrder,
    required this.updatedAt,
    this.title,
    this.description,
    required this.photoUrl,
  });

  factory PhotoPopupModel.fromJson(Map<String, dynamic> json) {
    return PhotoPopupModel(
      id: json['id'] ?? '',
      platform: json['platform'] ?? '',
      enabled: json['enabled'] ?? false,
      displayOrder: json['display_order'] ?? 0,
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      title: json['title'],
      description: json['description'],
      photoUrl: json['photo_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'platform': platform,
      'enabled': enabled,
      'display_order': displayOrder,
      'updated_at': updatedAt.toIso8601String(),
      'title': title,
      'description': description,
      'photo_url': photoUrl,
    };
  }
}
