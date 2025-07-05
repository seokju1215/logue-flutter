import 'package:supabase_flutter/supabase_flutter.dart';

final client = Supabase.instance.client;

Future<Map<String, dynamic>?> fetchCurrentUserProfile() async {
  final user = client.auth.currentUser;
  if (user == null) return null;

  final profileRes = await client
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  // 🔥 실시간 팔로워 수
  final followerRes = await client
      .from('follows')
      .select('id')
      .eq('following_id', user.id);
  final followerCount = followerRes.length;

  // 🔥 실시간 팔로잉 수
  final followingRes = await client
      .from('follows')
      .select('id')
      .eq('follower_id', user.id);
  final followingCount = followingRes.length;

  return {
    ...?profileRes,
    'followers': followerCount,
    'following': followingCount,
  };
}