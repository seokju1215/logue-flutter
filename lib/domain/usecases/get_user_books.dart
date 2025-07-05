import 'package:logue/data/datasources/user_book_api.dart';

class GetUserBooks {
  final UserBookApi api;

  GetUserBooks(this.api);

  Future<List<Map<String, dynamic>>> call(String userId) {
    return api.fetchBooks(userId);
  }
}