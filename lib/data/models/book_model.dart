class BookModel {
  final String image; // 책 표지 URL

  BookModel({required this.image});

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      image: json['image'] ?? '',
    );
  }
}