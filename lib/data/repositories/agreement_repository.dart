import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // debugPrint를 위해 필요

class AgreementRepository {
  final _supabase = Supabase.instance.client;

  Future<bool> hasAgreedTerms(String userId) async {
    debugPrint('🔍 AgreementRepository.hasAgreedTerms() 시작 - userId: $userId');
    
    try {
      final response = await _supabase
          .from('user_agreements')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      debugPrint('🔍 user_agreements 조회 결과: $response');
      final hasAgreed = response != null;
      debugPrint('🔍 약관 동의 여부: $hasAgreed');
      
      return hasAgreed;
    } catch (e) {
      debugPrint('❌ hasAgreedTerms 오류: $e');
      return false;
    }
  }
}