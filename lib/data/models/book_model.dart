class BookModel {
  final String image;

  BookModel({required this.image});

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      image: json['image'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is BookModel && runtimeType == other.runtimeType && image == other.image;

  @override
  int get hashCode => image.hashCode;
}