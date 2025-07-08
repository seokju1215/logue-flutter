import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AladinBookApi {
  final String _baseUrl = 'https://www.aladin.co.kr/ttb/api/ItemSearch.aspx';
  final String _lookupUrl = 'https://www.aladin.co.kr/ttb/api/ItemLookUp.aspx';

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

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final List items = decoded['item'] ?? [];

      final RegExp excludePattern = RegExp(r'(세[\s\-]*트|\+|스[\s\-]*티[\s\-]*커)', caseSensitive: false);

      final filteredItems = items
          .where((item) {
        final cover = item['cover']?.toString().trim() ?? '';
        final rawTitle = item['title']?.toString().toLowerCase() ?? '';

        return cover.isNotEmpty && !excludePattern.hasMatch(rawTitle);
      })
          .toList();

      // 상세 정보를 병렬로 가져오기
      final detailedBooks = await Future.wait(
        filteredItems.map((item) => _enrichBookWithDetails(item, ttbKey)),
      );

      return detailedBooks.where((book) => book != null).cast<Map<String, dynamic>>().toList();
    } else {
      throw Exception('❌ 알라딘 API 요청 실패: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> _enrichBookWithDetails(Map<String, dynamic> item, String ttbKey) async {
    try {
      final isbn13 = item['isbn13']?.toString();
      if (isbn13 == null || isbn13.isEmpty) {
        return _processBookItem(item);
      }

      // ItemLookUp API로 상세 정보 가져오기
      final lookupUrl = Uri.parse(
        '$_lookupUrl?ttbkey=$ttbKey&itemIdType=ISBN13&ItemId=$isbn13&output=js&Version=20131101&OptResult=toc,fulldescription',
      );

      final lookupResponse = await http.get(lookupUrl);
      
      if (lookupResponse.statusCode == 200) {
        final lookupDecoded = jsonDecode(utf8.decode(lookupResponse.bodyBytes));
        final List lookupItems = lookupDecoded['item'] ?? [];
        
        if (lookupItems.isNotEmpty) {
          final detailedItem = lookupItems.first;
          // 상세 정보로 기존 아이템 업데이트
          item['subInfo'] = detailedItem['subInfo'] ?? item['subInfo'];
          item['description'] = detailedItem['description'] ?? item['description'];
        }
      }
    } catch (e) {
      // 상세 정보 가져오기 실패 시 기본 정보만 사용
      print('상세 정보 가져오기 실패: $e');
    }

    return _processBookItem(item);
  }

  Map<String, dynamic> _processBookItem(Map<String, dynamic> item) {
    final subInfo = item['subInfo'] ?? {};

    // 제목과 fallback용 부제 분리
    String rawTitle = item['title'] ?? '';
    String title = rawTitle;
    String? fallbackSubtitle;

    if (rawTitle.contains(' - ')) {
      final parts = rawTitle.split(' - ');
      title = parts.first.trim();
      fallbackSubtitle = parts.sublist(1).join(' - ').trim();
    }

    // subtitle 우선순위: 알라딘 subTitle > fallback > ''
    final rawSub = subInfo['subTitle']?.toString().trim();
    final subtitle = (rawSub != null && rawSub.isNotEmpty)
        ? rawSub
        : (fallbackSubtitle ?? '');

    // 이미지 처리
    String cover = item['cover'] ?? '';
    if (cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }
    cover = cover.replaceAllMapped(
      RegExp(r'(cover(sum|\d{2,3}))'),
          (_) => 'cover500',
    );

    // 목차 정보 처리
    String toc = subInfo['toc']?.toString() ?? '';
    if (toc.isNotEmpty) {
      // HTML 태그 제거하고 깔끔한 목차로 변환
      toc = toc
          .replaceAll(RegExp(r'<[^>]*>'), '') // HTML 태그 제거
          .replaceAll('&nbsp;', ' ') // 공백 문자 처리
          .trim();
    }

    return {
      'title': title,
      'subtitle': subtitle,
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
      'toc': toc, // 깔끔한 목차 정보
      'link': item['link'] ?? '',
    };
  }
}