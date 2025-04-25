import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class KakaoBookApi {
  final String _baseUrl = 'https://dapi.kakao.com/v3/search/book';

  Future<List<Map<String, dynamic>>> searchBooks(String query) async {
    final restApiKey = dotenv.env['KAKAO_REST_API_KEY'];

    if (restApiKey == null || restApiKey.isEmpty) {
      throw Exception('Kakao REST API 키가 설정되지 않았습니다.');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl?query=$query'),
      headers: {
        'Authorization': 'KakaoAK $restApiKey',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List documents = decoded['documents'];

      return documents.map<Map<String, dynamic>>((doc) {
        return {
          'title': doc['title'],
          'author': (doc['authors'] as List).join(', '),
          'image': doc['thumbnail'],
          'publisher': doc['publisher'],
        };
      }).toList();
    } else {
      throw Exception('Kakao Book API 요청 실패: ${response.statusCode}');
    }
  }
}