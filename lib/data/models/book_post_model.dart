import 'package:flutter/foundation.dart';

class BookPostModel {
  final String id;
  final String userId;
  final String? title;
  final String? author;
  final String? image;
  final String? isbn;
  final String? reviewTitle;
  final String? reviewContent;
  final String? userName;
  final String? avatarUrl;
  final int? orderIndex;

  BookPostModel({
    required this.id,
    required this.userId,
    this.title,
    this.author,
    this.image,
    this.isbn,
    this.reviewTitle,
    this.reviewContent,
    this.userName,
    this.avatarUrl,
    this.orderIndex,
  });

  factory BookPostModel.fromMap(Map<String, dynamic> map) {
    debugPrint('🧪 map keys: ${map.keys}');
    final books = map['books'] as Map<String, dynamic>?;
    final profiles = map['profiles'] as Map<String, dynamic>?;

    if (books == null) {
      debugPrint('❌ books 변환 실패: ${map['books']}');
    }

    final isbn = books?['isbn'] ?? map['isbn'];
    final image = books?['image'] ?? map['image'];

    debugPrint('📚 PostItem에서 넘기는 ISBN: $isbn');

    return BookPostModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: books?['title'] as String? ?? map['title'] as String?,
      author: books?['author'] as String? ?? map['author'] as String?,
      image: image as String?,
      isbn: isbn as String?,
      reviewTitle: map['review_title'] as String?,
      reviewContent: map['review_content'] as String?,
      userName: profiles?['username'] as String? ?? map['username'] as String?,
      avatarUrl: profiles?['avatar_url'] as String? ?? map['avatar_url'] as String?,
      orderIndex: map['order_index'] as int?,
    );
  }
}