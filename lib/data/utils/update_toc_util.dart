import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/aladin_book_api.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UpdateTocUtil {
  static final AladinBookApi _aladinApi = AladinBookApi();

  /// 기존 DB의 책들 목차를 일괄 업데이트
  static Future<void> updateAllBooksToc() async {
    final client = Supabase.instance.client;
    
    try {
      print('🔄 목차 업데이트 시작...');
      await _aladinApi.updateExistingBooksToc(client);
      print('✅ 목차 업데이트 완료!');
    } catch (e) {
      print('❌ 목차 업데이트 실패: $e');
      rethrow;
    }
  }

  /// 특정 책의 목차만 업데이트
  static Future<void> updateSingleBookToc(String bookId) async {
    final client = Supabase.instance.client;
    
    try {
      // 책 정보 가져오기
      final book = await client
          .from('books')
          .select('id, isbn, title, author')
          .eq('id', bookId)
          .single();

      if (book != null) {
        await _updateBookToc(client, book);
        print('📖 개별 책 목차 업데이트 완료: ${book['title']}');
      }
    } catch (e) {
      print('❌ 개별 책 목차 업데이트 실패: $e');
      rethrow;
    }
  }

  /// 개별 책 목차 업데이트 (내부 메서드)
  static Future<void> _updateBookToc(SupabaseClient client, Map<String, dynamic> book) async {
    try {
      final isbn = book['isbn']?.toString();
      if (isbn == null || isbn.isEmpty) return;

      final ttbKey = dotenv.env['ALADIN_TTB_KEY'];
      if (ttbKey == null || ttbKey.isEmpty) return;

      // ItemLookUp API로 상세 정보 가져오기
      final lookupUrl = Uri.parse(
        'https://www.aladin.co.kr/ttb/api/ItemLookUp.aspx?ttbkey=$ttbKey&itemIdType=ISBN13&ItemId=$isbn&output=js&Version=20131101&OptResult=toc,fulldescription',
      );

      final response = await http.get(lookupUrl);
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List items = decoded['item'] ?? [];
        
        if (items.isNotEmpty) {
          final item = items.first;
          final subInfo = item['subInfo'] ?? {};
          final rawToc = subInfo['toc']?.toString() ?? '';
          
          if (rawToc.isNotEmpty) {
            // HTML 태그 제거하고 깔끔한 목차로 변환
            final cleanToc = rawToc
                .replaceAll(RegExp(r'<[^>]*>'), '') // HTML 태그 제거
                .replaceAll('&nbsp;', ' ') // 공백 문자 처리
                .trim();

            // DB 업데이트
            await client
                .from('books')
                .update({'toc': cleanToc})
                .eq('id', book['id']);

            print('📖 목차 업데이트 성공: ${book['title']}');
          }
        }
      }
    } catch (e) {
      print('❌ 개별 책 목차 업데이트 실패: ${book['title']} - $e');
    }
  }

  /// 목차가 없는 책들의 개수 확인
  static Future<int> getBooksWithoutTocCount() async {
    final client = Supabase.instance.client;
    
    try {
      final result = await client
          .from('books')
          .select('id')
          .or('toc.is.null,toc.eq.');

      return result.length;
    } catch (e) {
      print('❌ 목차 없는 책 개수 조회 실패: $e');
      return 0;
    }
  }
} 