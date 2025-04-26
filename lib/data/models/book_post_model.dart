class BookPostModel {
  final String id;
  final String userId;
  final String? title;
  final String? author;
  final String? image;
  final String? reviewTitle;
  final String? reviewContent;
  final String? userName;
  final int? orderIndex; // ✅ 추가

  BookPostModel({
    required this.id,
    required this.userId,
    this.title,
    this.author,
    this.image,
    this.reviewTitle,
    this.reviewContent,
    this.userName,
    this.orderIndex, // ✅ 추가
  });

  factory BookPostModel.fromMap(Map<String, dynamic> map) {
    return BookPostModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String?,
      author: map['author'] as String?,
      image: map['image'] as String?,
      reviewTitle: map['review_title'] as String?,
      reviewContent: map['review_content'] as String?,
      userName: map['profiles'] != null ? map['profiles']['username'] as String? : null,
      orderIndex: map['order_index'] as int?, // ✅ 여기
    );
  }
}