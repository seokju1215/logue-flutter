import 'package:flutter/foundation.dart';
class BookPostModel {
  final String id;
  final String userId;
  final String? title;
  final String? author;
  final String? image;
  final String? reviewTitle;
  final String? reviewContent;
  final String? userName;
  final String? avatarUrl; // ✅ 추가
  final int? orderIndex;

  BookPostModel({
    required this.id,
    required this.userId,
    this.title,
    this.author,
    this.image,
    this.reviewTitle,
    this.reviewContent,
    this.userName,
    this.avatarUrl, // ✅ 추가
    this.orderIndex,
  });

  factory BookPostModel.fromMap(Map<String, dynamic> map) {
    debugPrint('🧪 map keys: ${map.keys}');
    debugPrint('🧪 raw profiles value: ${map['profiles']}');

    // profiles 파싱 안전하게 처리
    final profilesRaw = map['profiles'];
    final profiles = (profilesRaw is Map)
        ? Map<String, dynamic>.from(profilesRaw as Map)
        : null;

    final model = BookPostModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String?,
      author: map['author'] as String?,
      image: map['image'] as String?,
      reviewTitle: map['review_title'] as String?,
      reviewContent: map['review_content'] as String?,
      userName: map['username'] as String?, // ✅ 수정된 부분
      avatarUrl: map['avatar_url'] as String?,
      orderIndex: map['order_index'] as int?,
    );

    return model;
  }
}