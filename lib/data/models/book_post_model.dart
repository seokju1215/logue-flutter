import 'package:flutter/foundation.dart';

class BookPostModel {
  final String id;
  final String userId;
  final String? title;
  final String? author;
  final String? image;
  final String? isbn;        // 유지
  final String? bookId;       // ✅ 새 PK 기반 필드 추가
  final String? reviewTitle;
  final String? reviewContent;
  final String? userName;
  final String? avatarUrl;
  final int? orderIndex;
  final bool? is_archived;

  BookPostModel({
    required this.id,
    required this.userId,
    this.bookId, // ✅ required
    this.title,
    this.author,
    this.image,
    this.isbn,
    this.reviewTitle,
    this.reviewContent,
    this.userName,
    this.avatarUrl,
    this.orderIndex,
    this.is_archived
  });

  factory BookPostModel.fromMap(Map<String, dynamic> map) {
    debugPrint('🧪 map keys: ${map.keys}');
    final books = map['books'] as Map<String, dynamic>?;
    final profiles = map['profiles'] as Map<String, dynamic>?;

    final bookId = books?['id'] ?? map['book_id'];
    if (bookId == null) {
      debugPrint('❌ bookId 누락: books: $books | map[book_id]: ${map['book_id']}');
      throw Exception('Book ID is required');
    }

    final isbn = books?['isbn'] ?? map['isbn'];
    final image = map['image'] ?? books?['image'];

    return BookPostModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      bookId: bookId,
      title: books?['title'] ?? map['title'],
      author: books?['author'] ?? map['author'],
      image: image,
      isbn: isbn,
      reviewTitle: map['review_title'],
      reviewContent: map['review_content'],
      userName: profiles?['username'] ?? map['username'],
      avatarUrl: profiles?['avatar_url'] ?? map['avatar_url'],
      orderIndex: map['order_index'] as int?,
      is_archived: map['is_archived'] as bool?,
    );
  }
}