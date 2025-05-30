import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AladinBookApi {
  final String _baseUrl = 'https://www.aladin.co.kr/ttb/api/ItemSearch.aspx';

  Future<List<Map<String, dynamic>>> searchBooks(String query) async {
    return _fetchBooks(query, queryType: 'Title');
  }

  Future<List<Map<String, dynamic>>> searchBooksByAuthor(String author) async {
    return _fetchBooks(author, queryType: 'Author');
  }

  Future<List<Map<String, dynamic>>> _fetchBooks(String query, {required String queryType}) async {
    final ttbKey = dotenv.env['ALADIN_TTB_KEY'];

    if (ttbKey == null || ttbKey.isEmpty) {
      throw Exception('알라딘 TTB 키가 설정되지 않았습니다.');
    }

    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse(
      '$_baseUrl?ttbkey=$ttbKey&Query=$encodedQuery&QueryType=$queryType&MaxResults=20&start=1&SearchTarget=Book&output=js&Version=20131101&OptResult=toc,fulldescription',
    );

    print('📡 Aladin API 호출: $url');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final List items = decoded['item'] ?? [];


      return items
          .where((item) {
        final cover = item['cover'] ?? '';
        return cover.trim().isNotEmpty;
      })
          .map<Map<String, dynamic>>((item) {
        String cover = item['cover'] ?? '';
        if (cover.startsWith('http://')) {
          cover = cover.replaceFirst('http://', 'https://');
        }

        cover = cover.replaceAllMapped(
          RegExp(r'(cover(sum|\d{2,3}))'),
              (_) => 'cover500',
        );

        final subInfo = item['subInfo'] ?? {};

        return {
          'title': item['title'] ?? '',
          'subtitle': item['subtitle'] ?? '',
          'author': item['author'] ?? '',
          'image': cover,
          'publisher': item['publisher'] ?? '',
          'isbn13': item['isbn13'] ?? '',
          'pubDate': item['pubDate'] ?? '',
          'description': item['description'] ?? '',
          'subInfo': subInfo,
          'pageCount': subInfo['itemPage'] is int
              ? subInfo['itemPage']
              : int.tryParse(subInfo['itemPage']?.toString() ?? ''),
          'toc': subInfo['toc']?.toString() ?? '',
        };
      }).toList();
    } else {
      throw Exception('❌ 알라딘 API 요청 실패: ${response.statusCode}');
    }
  }
}