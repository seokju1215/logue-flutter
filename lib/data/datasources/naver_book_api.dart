import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/book_model.dart';

class NaverBookApi {
  Future<List<BookModel>> searchBooks(String query) async {
    final url = Uri.parse('https://openapi.naver.com/v1/search/book.json?query=$query');

    final response = await http.get(
      url,
      headers: {
        'X-Naver-Client-Id': dotenv.env['NAVER_CLIENT_ID']!,
        'X-Naver-Client-Secret': dotenv.env['NAVER_CLIENT_SECRET']!,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data['items'] as List;
      return items.map((json) => BookModel.fromJson(json)).toList();
    } else {
      throw Exception('책 검색 실패: ${response.statusCode}');
    }
  }
}