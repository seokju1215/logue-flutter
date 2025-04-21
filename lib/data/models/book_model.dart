class BookModel {
  final String title;
  final String author;
  final String image;
  final String publisher;

  BookModel({
    required this.title,
    required this.author,
    required this.image,
    required this.publisher,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      image: json['image'] ?? '',
      publisher: json['publisher'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is BookModel && image == other.image;

  @override
  int get hashCode => image.hashCode;
}