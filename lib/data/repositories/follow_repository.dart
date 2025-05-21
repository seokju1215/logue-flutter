import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class FollowRepository {
  final SupabaseClient client;
  final String functionBaseUrl;

  FollowRepository({required this.client, required this.functionBaseUrl});

  Future<void> follow(String targetUserId) => _callEdgeFunction('follow-user', targetUserId);

  Future<void> unfollow(String targetUserId) => _callEdgeFunction('unfollow-user', targetUserId);

  Future<bool> isFollowing(String targetUserId) async {
    final myId = client.auth.currentUser?.id;
    if (myId == null) return false;

    final result = await client
        .from('follows')
        .select('follower_id')
        .eq('follower_id', myId)
        .eq('following_id', targetUserId)
        .maybeSingle();

    return result != null;
  }

  Future<void> _callEdgeFunction(String functionName, String targetUserId) async {
    final accessToken = client.auth.currentSession?.accessToken;
    if (accessToken == null) throw Exception('로그인 필요');

    final response = await http.post(
      Uri.parse('$functionBaseUrl/$functionName'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'target_user_id': targetUserId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Edge Function 오류: ${response.body}');
    }
  }
}