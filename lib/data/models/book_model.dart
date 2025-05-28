class BookModel {
  final String isbn;
  final String title;
  final String? subtitle;
  final String author;
  final String publisher;
  final String? publishedDate;
  final int? pageCount;
  final String? description;
  final String? toc;
  final String image;

  BookModel({
    required this.isbn,
    required this.title,
    this.subtitle,
    required this.author,
    required this.publisher,
    this.publishedDate,
    this.pageCount,
    this.description,
    this.toc,
    required this.image,
  });
  factory BookModel.fromJson(Map<String, dynamic> json) {
    final imageUrl = (json['image'] ?? '') as String;

    return BookModel(
      isbn: json['isbn13'] ?? '',
      title: json['title'] ?? '',
      subtitle: null,
      author: json['author'] ?? '',
      publisher: json['publisher'] ?? '',
      publishedDate: json['pubDate'],
      pageCount: json['subInfo']?['itemPage'],
      description: json['description'] ?? '',
      toc: json['subInfo']?['toc'],
      image: imageUrl.startsWith('http://')
          ? imageUrl.replaceFirst('http://', 'https://')
          : imageUrl,
    );
  }

  Map<String, dynamic> toBookMap() => {
    'isbn': isbn,
    'title': title,
    'subtitle': subtitle,
    'author': author,
    'publisher': publisher,
    'published_date': publishedDate,
    'page_count': pageCount,
    'description': description,
    'toc': toc,
    'image': image,
  };
}