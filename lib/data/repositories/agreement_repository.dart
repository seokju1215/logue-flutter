import 'package:supabase_flutter/supabase_flutter.dart';

class AgreementRepository {
  final _supabase = Supabase.instance.client;

  Future<bool> hasAgreedTerms(String userId) async {
    final response = await _supabase
        .from('user_agreements')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    return response != null;
  }
}