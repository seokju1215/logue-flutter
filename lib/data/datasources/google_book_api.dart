import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleBookApi {
  final String _baseUrl = 'https://www.googleapis.com/books/v1/volumes';

  Future<List<Map<String, dynamic>>> searchBooks(String query) async {
    final response = await http.get(
      Uri.parse('$_baseUrl?q=$query'),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List items = decoded['items'] ?? [];

      return items.map<Map<String, dynamic>>((item) {
        final volumeInfo = item['volumeInfo'] ?? {};
        final imageLinks = volumeInfo['imageLinks'] ?? {};
        return {
          'title': volumeInfo['title'] ?? '',
          'author': (volumeInfo['authors'] as List?)?.join(', ') ?? '',
          'image': imageLinks['thumbnail'] ?? '',
          'publisher': volumeInfo['publisher'] ?? '',
        };
      }).toList();
    } else {
      throw Exception('Google Book API 요청 실패: ${response.statusCode}');
    }
  }
}