import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AladinBookApi {
  final String _baseUrl = 'https://www.aladin.co.kr/ttb/api/ItemSearch.aspx';

  Future<List<Map<String, dynamic>>> searchBooks(String query) async {
    final ttbKey = dotenv.env['ALADIN_TTB_KEY'];

    if (ttbKey == null || ttbKey.isEmpty) {
      throw Exception('알라딘 TTB 키가 설정되지 않았습니다.');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl?ttbkey=$ttbKey&Query=$query&QueryType=Title&MaxResults=20&start=1&SearchTarget=Book&output=js&Version=20131101'),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final List items = decoded['item'] ?? [];


      return items.map<Map<String, dynamic>>((item) {
        final cover = item['cover'] ?? '';
        return {
          'title': item['title'] ?? '',
          'author': item['author'] ?? '',
          'image': (cover as String).replaceAll('_m.', '_l.'),
          'publisher': item['publisher'] ?? '',
        };
      }).toList();
    } else {
      throw Exception('알라딘 API 요청 실패: ${response.statusCode}');
    }
  }
}