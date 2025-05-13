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
    final profiles = map['profiles'] as Map<String, dynamic>?;

    return BookPostModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String?,
      author: map['author'] as String?,
      image: map['image'] as String?,
      reviewTitle: map['review_title'] as String?,
      reviewContent: map['review_content'] as String?,
      userName: map['username'] as String?,    // ✅ profiles.username 가져와야 해
      avatarUrl: map['avatar_url'] as String?,// ✅ 추가
      orderIndex: map['order_index'] as int?,
    );
  }
}