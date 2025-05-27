import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/domain/entities/follow_list_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FollowListTab extends StatelessWidget {
  final FollowListType type;
  final String userId;
  const FollowListTab({super.key, required this.type, required this.userId});

  @override
  Widget build(BuildContext context) {
    final future = _fetchFollowList(type);

    return FutureBuilder<List<Map<String, dynamic>>>(
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
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/other_profile', arguments: user['id']);
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: user['avatar_url'] == 'basic'
                          ? null
                          : NetworkImage(user['avatar_url']),
                      child: user['avatar_url'] == 'basic'
                          ? Image.asset('assets/basic_avatar.png')
                          : null,
                    ),
                    const SizedBox(width: 22), // ✅ 여기서 간격 조절
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${user['username']}',
                            style: const TextStyle(fontSize: 14, color: AppColors.black900),
                          ),
                          Text(
                            user['name'] ?? '사용자',
                            style: const TextStyle(fontSize: 12, color: AppColors.black500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchFollowList(FollowListType type) async {
    final client = Supabase.instance.client;

    try {
      if (type == FollowListType.followers) {
        final res = await client
            .from('followers_with_profiles')
            .select('*')
            .eq('following_id', userId);
        return List<Map<String, dynamic>>.from(res);
      } else {
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