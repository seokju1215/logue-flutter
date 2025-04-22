import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final client = Supabase.instance.client;
  Map<String, dynamic>? profile;
  late final RealtimeChannel _channel;
  bool _showFullBio = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _subscribeToProfileUpdates();
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final data = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    setState(() {
      profile = data;
    });
  }

  void _subscribeToProfileUpdates() {
    final user = client.auth.currentUser;
    if (user == null) return;

    _channel = client.channel('public:profiles')
      ..on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(
          event: 'UPDATE',
          schema: 'public',
          table: 'profiles',
          filter: 'id=eq.${user.id}',
        ),
            (payload, [ref]) {
          final newProfile = payload['new'];
          if (mounted && newProfile != null) {
            setState(() {
              profile = newProfile as Map<String, dynamic>;
            });
          }
        },
      )
      ..subscribe();
  }

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: SvgPicture.asset('assets/bell_icon.svg'),
          onPressed: () {
            Navigator.pushNamed(context, '/notification');
          },
        ),
        title: Text(
          profile?['username'] ?? '사용자',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: SvgPicture.asset('assets/edit_icon.svg'),
            onPressed: () {
              Navigator.pushNamed(context, '/profile_edit');
            },
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile?['name'] ?? '',
                style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              profile?['job'] ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final bio = profile?['bio'] ?? '';
                final showMore = !_showFullBio && bio.length > 40;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final textSpan = TextSpan(
                      text: bio,
                      style: const TextStyle(fontSize: 12, color: AppColors.black900),
                    );

                    final tp = TextPainter(
                      text: textSpan,
                      textDirection: TextDirection.ltr,
                      maxLines: _showFullBio ? null : 2,
                      ellipsis: showMore ? '...' : null,
                    )..layout(maxWidth: constraints.maxWidth);

                    final isOverflowing = tp.didExceedMaxLines;

                    return RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _showFullBio || !isOverflowing
                                ? bio
                                : bio.substring(
                                    0,
                                    tp.getPositionForOffset(
                                      Offset(constraints.maxWidth, 28 * 2),
                                    ).offset,
                                  ) + '...',
                            style: const TextStyle(fontSize: 12, color: AppColors.black900),
                          ),
                          if (showMore)
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showFullBio = true;
                                  });
                                },
                                child: const Text(
                                  ' 더보기',
                                  style: TextStyle(fontSize: 12, color: AppColors.black900),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildCount("팔로워", profile?['followers'] ?? 0),
                const SizedBox(width: 24),
                _buildCount("팔로잉", profile?['followings'] ?? 0),
                const SizedBox(width: 24),
                _buildCount("방문자", profile?['visitors'] ?? 0),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // 책 추가 기능
                    },
                    child: const Text("책 추가 +"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // 프로필 공유 기능
                    },
                    child: const Text("프로필 공유"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCount(String label, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count.toString(),
            style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}