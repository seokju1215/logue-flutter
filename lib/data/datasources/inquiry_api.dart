import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class InquiryApi {
  final SupabaseClient client;

  InquiryApi(this.client);

  Future<List<Map<String, dynamic>>> fetchInquiries(String userId) async {
    final response = await client
        .from('inquiries')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    if (response == null) return [];

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchAllInquiries() async {
    final response = await client
        .from('inquiries')
        .select()
        .order('created_at', ascending: false);

    if (response == null) return [];

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchCompletedInquiries() async {
    final response = await client
        .from('inquiries')
        .select()
        .eq('is_completed', true)
        .order('created_at', ascending: false);

    if (response == null) return [];

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchPendingInquiries() async {
    final response = await client
        .from('inquiries')
        .select()
        .eq('is_completed', false)
        .order('created_at', ascending: false);

    if (response == null) return [];

    return List<Map<String, dynamic>>.from(response);
  }
}