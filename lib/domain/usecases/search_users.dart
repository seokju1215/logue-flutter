import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/user_profile.dart';

class SearchUsers {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<UserProfile>> call(String keyword) async {
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) return [];

    // username 검색
    final response = await client
        .from('profiles')
        .select('id, username,name, avatar_url')
        .ilike('username', '%$keyword%')
        .neq('id', currentUserId) // 자기 자신 제외
        .limit(6);

    final List<dynamic> rawUsers = response;

    // 해당 유저들이 팔로우 중인지 여부 확인
    final userIds = rawUsers.map((e) => e['id'] as String).toList();

    final followResult = await client
        .from('follows')
        .select('following_id')
        .eq('follower_id', currentUserId)
        .in_('following_id', userIds);

    final followedIds = (followResult as List)
        .map((e) => e['following_id'] as String)
        .toSet();

    return rawUsers.map((e) {
      final userId = e['id'] as String;
      return UserProfile.fromMap(
        e,
        isFollowing: followedIds.contains(userId),
      );
    }).toList();
  }
}