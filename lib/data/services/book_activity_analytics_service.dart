import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/firebase_analytics_util.dart';

/// 책 활동 분석 서비스
/// 일일/주간/월간 책 추가 및 후기 작성 통계를 관리합니다.
class BookActivityAnalyticsService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  // SharedPreferences 키
  static const String _keyLastTrackedDate = 'last_tracked_date';
  static const String _keyDailyBooksAdded = 'daily_books_added';
  static const String _keyDailyReviewsWritten = 'daily_reviews_written';
  static const String _keyWeeklyBooksAdded = 'weekly_books_added';
  static const String _keyWeeklyReviewsWritten = 'weekly_reviews_written';
  static const String _keyMonthlyBooksAdded = 'monthly_books_added';
  static const String _keyMonthlyReviewsWritten = 'monthly_reviews_written';

  /// 책이 프로필에 추가될 때 호출 (write_review_screen, archive_bottom_sheet에서 사용)
  static Future<void> trackBookAdded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // 일일 카운트 증가
      final currentDaily = prefs.getInt('${_keyDailyBooksAdded}_$today') ?? 0;
      await prefs.setInt('${_keyDailyBooksAdded}_$today', currentDaily + 1);
      
      // 주간 카운트 증가
      final weekStart = _getWeekStartDate().toIso8601String().split('T')[0];
      final currentWeekly = prefs.getInt('${_keyWeeklyBooksAdded}_$weekStart') ?? 0;
      await prefs.setInt('${_keyWeeklyBooksAdded}_$weekStart', currentWeekly + 1);
      
      // 월간 카운트 증가
      final monthStart = _getMonthStartDate().toIso8601String().split('T')[0];
      final currentMonthly = prefs.getInt('${_keyMonthlyBooksAdded}_$monthStart') ?? 0;
      await prefs.setInt('${_keyMonthlyBooksAdded}_$monthStart', currentMonthly + 1);
      
      debugPrint('📊 책 추가 카운트 업데이트: 일일=${currentDaily + 1}, 주간=${currentWeekly + 1}, 월간=${currentMonthly + 1}');
    } catch (e) {
      debugPrint('❌ 책 추가 카운트 업데이트 실패: $e');
    }
  }

  /// 후기가 작성될 때 호출
  static Future<void> trackReviewWritten() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // 일일 카운트 증가
      final currentDaily = prefs.getInt('${_keyDailyReviewsWritten}_$today') ?? 0;
      await prefs.setInt('${_keyDailyReviewsWritten}_$today', currentDaily + 1);
      
      // 주간 카운트 증가
      final weekStart = _getWeekStartDate().toIso8601String().split('T')[0];
      final currentWeekly = prefs.getInt('${_keyWeeklyReviewsWritten}_$weekStart') ?? 0;
      await prefs.setInt('${_keyWeeklyReviewsWritten}_$weekStart', currentWeekly + 1);
      
      // 월간 카운트 증가
      final monthStart = _getMonthStartDate().toIso8601String().split('T')[0];
      final currentMonthly = prefs.getInt('${_keyMonthlyReviewsWritten}_$monthStart') ?? 0;
      await prefs.setInt('${_keyMonthlyReviewsWritten}_$monthStart', currentMonthly + 1);
      
      debugPrint('📊 후기 작성 카운트 업데이트: 일일=${currentDaily + 1}, 주간=${currentWeekly + 1}, 월간=${currentMonthly + 1}');
    } catch (e) {
      debugPrint('❌ 후기 작성 카운트 업데이트 실패: $e');
    }
  }

  /// 일일 통계를 GA로 전송 (앱 종료 시 또는 자정에 호출)
  static Future<void> sendDailyStatistics({DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateStr = targetDate.toIso8601String().split('T')[0];
      final prefs = await SharedPreferences.getInstance();
      
      final booksAdded = prefs.getInt('${_keyDailyBooksAdded}_$dateStr') ?? 0;
      final reviewsWritten = prefs.getInt('${_keyDailyReviewsWritten}_$dateStr') ?? 0;
      
      if (booksAdded > 0 || reviewsWritten > 0) {
        await FirebaseAnalyticsUtil.logDailyBookActivity(
          booksAdded: booksAdded,
          reviewsWritten: reviewsWritten,
          date: targetDate,
        );
        debugPrint('📊 일일 통계 전송 완료: 책 추가=$booksAdded, 후기 작성=$reviewsWritten');
      }
    } catch (e) {
      debugPrint('❌ 일일 통계 전송 실패: $e');
    }
  }

  /// 주간 통계를 GA로 전송 (주말에 호출)
  static Future<void> sendWeeklyStatistics({DateTime? weekStartDate}) async {
    try {
      final startDate = weekStartDate ?? _getWeekStartDate();
      final dateStr = startDate.toIso8601String().split('T')[0];
      final prefs = await SharedPreferences.getInstance();
      
      final booksAdded = prefs.getInt('${_keyWeeklyBooksAdded}_$dateStr') ?? 0;
      final reviewsWritten = prefs.getInt('${_keyWeeklyReviewsWritten}_$dateStr') ?? 0;
      
      if (booksAdded > 0 || reviewsWritten > 0) {
        await FirebaseAnalyticsUtil.logWeeklyBookSummary(
          weeklyBooksAdded: booksAdded,
          weeklyReviewsWritten: reviewsWritten,
          weekStartDate: startDate,
        );
        debugPrint('📊 주간 통계 전송 완료: 책 추가=$booksAdded, 후기 작성=$reviewsWritten');
      }
    } catch (e) {
      debugPrint('❌ 주간 통계 전송 실패: $e');
    }
  }

  /// 월간 통계를 GA로 전송 (월말에 호출)
  static Future<void> sendMonthlyStatistics({DateTime? monthDate}) async {
    try {
      final targetMonth = monthDate ?? DateTime.now();
      final monthStart = _getMonthStartDate();
      final dateStr = monthStart.toIso8601String().split('T')[0];
      final prefs = await SharedPreferences.getInstance();
      
      final booksAdded = prefs.getInt('${_keyMonthlyBooksAdded}_$dateStr') ?? 0;
      final reviewsWritten = prefs.getInt('${_keyMonthlyReviewsWritten}_$dateStr') ?? 0;
      
      if (booksAdded > 0 || reviewsWritten > 0) {
        await FirebaseAnalyticsUtil.logMonthlyBookSummary(
          monthlyBooksAdded: booksAdded,
          monthlyReviewsWritten: reviewsWritten,
          monthDate: targetMonth,
        );
        debugPrint('📊 월간 통계 전송 완료: 책 추가=$booksAdded, 후기 작성=$reviewsWritten');
      }
    } catch (e) {
      debugPrint('❌ 월간 통계 전송 실패: $e');
    }
  }

  /// 앱 시작 시 호출 - 이전 날짜의 통계 전송
  static Future<void> initializeAndSendPendingStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTrackedDate = prefs.getString(_keyLastTrackedDate);
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      if (lastTrackedDate != null && lastTrackedDate != today) {
        // 이전 날짜의 통계 전송
        final previousDate = DateTime.parse(lastTrackedDate);
        await sendDailyStatistics(date: previousDate);
        
        // 주말이면 주간 통계도 전송
        if (DateTime.now().weekday == DateTime.sunday) {
          await sendWeeklyStatistics();
        }
        
        // 월말이면 월간 통계도 전송
        if (DateTime.now().day == 1) {
          final lastMonth = DateTime(DateTime.now().year, DateTime.now().month - 1, 1);
          await sendMonthlyStatistics(monthDate: lastMonth);
        }
      }
      
      // 현재 날짜 업데이트
      await prefs.setString(_keyLastTrackedDate, today);
    } catch (e) {
      debugPrint('❌ 미처리 통계 전송 실패: $e');
    }
  }

  /// 주 시작 날짜 계산 (월요일)
  static DateTime _getWeekStartDate() {
    final now = DateTime.now();
    final daysFromMonday = now.weekday - 1;
    return now.subtract(Duration(days: daysFromMonday));
  }

  /// 월 시작 날짜 계산
  static DateTime _getMonthStartDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }
}