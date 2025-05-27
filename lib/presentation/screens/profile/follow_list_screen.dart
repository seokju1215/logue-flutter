import 'package:flutter/material.dart';
import 'package:logue/domain/entities/follow_list_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FollowListScreen extends StatelessWidget {
  final FollowListType type;
  final String userId;
  const FollowListScreen({super.key, required this.type, required this.userId});

  @override
  Widget build(BuildContext context) {
    final future = _fetchFollowList(type);
    final title = type == FollowListType.followers ? '팔로워' : '팔로잉';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: const BackButton(),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('사용자가 없습니다.'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: user['avatar_url'] == 'basic'
                      ? null
                      : NetworkImage(user['avatar_url']),
                  child: user['avatar_url'] == 'basic'
                      ? Image.asset('assets/basic_avatar.png')
                      : null,
                ),
                title: Text('${user['username']}'),
                subtitle: Text(user['name'] ?? '사용자'),
                onTap: () {
                  Navigator.pushNamed(context, '/other_profile', arguments: user['id']);
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchFollowList(FollowListType type) async {
    final client = Supabase.instance.client;

    try {
      if (type == FollowListType.followers) {
        // 팔로워 = 나를 팔로우한 사람 = followers_with_profiles 에서 following_id == 나
        final res = await client
            .from('followers_with_profiles')
            .select('*')
            .eq('following_id', userId);
        return List<Map<String, dynamic>>.from(res);
      } else {
        // 팔로잉 = 내가 팔로우한 사람 = followings_with_profiles 에서 follower_id == 나
        final res = await client
            .from('followings_with_profiles')
            .select('*')
            .eq('follower_id', userId);
        return List<Map<String, dynamic>>.from(res);
      }
    } catch (e, st) {
      print('❌ 오류 발생: $e');
      print('📍 Stacktrace: $st');
      return [];
    }
  }
}