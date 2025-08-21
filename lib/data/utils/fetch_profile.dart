import 'package:flutter/foundation.dart';
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

  return profileRes;
}

// 팔로워/팔로잉 카운트를 별도로 가져오는 함수
Future<Map<String, int>> fetchFollowCounts([String? userId]) async {
  final targetUserId = userId ?? client.auth.currentUser?.id;
  if (targetUserId == null) return {'followers': 0, 'following': 0};

  try {
    final followerRes = await client
        .from('follows')
        .select('id')
        .eq('following_id', targetUserId);
    final followerCount = followerRes.length;

    final followingRes = await client
        .from('follows')
        .select('id')
        .eq('follower_id', targetUserId);
    final followingCount = followingRes.length;

    return {'followers': followerCount, 'following': followingCount};
  } catch (e) {
    debugPrint('❌ 팔로워/팔로잉 카운트 조회 실패: $e');
    return {'followers': 0, 'following': 0};
  }
}