import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/user_profile.dart';

class SearchUsers {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<UserProfile>> call(String keyword) async {
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) return [];

    // username 검색 (자기 자신 제외)
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
        .inFilter('following_id', userIds);

    final followedIds = (followResult as List)
        .map((e) => e['following_id'] as String)
        .toSet();

    final users = rawUsers.map((e) {
      final userId = e['id'] as String;
      return UserProfile.fromMap(
        e,
        isFollowing: followedIds.contains(userId),
      );
    }).toList();

    // 정렬: 팔로우한 계정 위로, 나머지는 일반 순서
    users.sort((a, b) {
      // 팔로우 상태에 따라 정렬
      if (a.isFollowing && !b.isFollowing) return -1;
      if (!a.isFollowing && b.isFollowing) return 1;
      
      // 이름 순으로 정렬
      return a.name.compareTo(b.name);
    });

    return users;
  }
}