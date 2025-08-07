import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/themes/stroke_text_style.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/core/widgets/post/post_item.dart';
import 'package:my_logue/core/widgets/follow/follow_user_tile.dart';
import '../../../data/models/book_post_model.dart';
import '../../../data/repositories/user_repository.dart';

class HomeRecommendTab extends StatefulWidget {
  const HomeRecommendTab({super.key});

  @override
  State<HomeRecommendTab> createState() => _HomeRecommendTabState();
}

class _HomeRecommendTabState extends State<HomeRecommendTab> {
  final client = Supabase.instance.client;
  List<Map<String, dynamic>> usersWithSameBooks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsersWithSameBooks();
  }

  Future<void> _fetchUsersWithSameBooks() async {
    try {
      final userRepository = UserRepository(client);
      final users = await userRepository.getUsersWithSameBooks();
      
      if (mounted) {
        setState(() {
          usersWithSameBooks = users;
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 인생책이 겹치는 사람 조회 실패: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  ButtonStyle _outlinedStyle(BuildContext context) {
    return ButtonStyle(
      foregroundColor: MaterialStateProperty.all(AppColors.black900),
      backgroundColor: MaterialStateProperty.all(Colors.white),
      overlayColor: MaterialStateProperty.resolveWith<Color?>(
            (states) {
          if (states.contains(MaterialState.pressed)) {
            return AppColors.black100;
          }
          return null;
        },
      ),
      side: MaterialStateProperty.all(
        const BorderSide(color: AppColors.black500, width: 1),
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      padding: MaterialStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 9),
      ),
      minimumSize: MaterialStateProperty.all(
        const Size(0, 34),
      ),
      textStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(0, 27, 0, 27),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: StrokeTextStyle.createStrokeText(text: '내 지인 중에서 LOGUE 유저 찾아보기', fontSize: 16 , color: AppColors.black900, fontWeight: FontWeight.w400, height: 1.187)
          ),
          const SizedBox(height: 13),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {

                    },
                    style: _outlinedStyle(context),
                    child: const Text(
                      '친구 찾기',
                      style: TextStyle(fontSize: 13, color: AppColors.black900, height: 1.25),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // 인생책이 겹치는 사람 섹션
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: StrokeTextStyle.createStrokeText(
              text: '나와 인생책이 겹치는 사람',
              fontSize: 16,
              color: AppColors.black900,
              fontWeight: FontWeight.w400,
              height: 1.187,
            ),
          ),
          const SizedBox(height: 13),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (usersWithSameBooks.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 22),
              child: Text(
                '아직 인생책이 겹치는 사람이 없어요.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.black500,
                ),
              ),
            )
          else
            Container(
              height: 90,
              margin: const EdgeInsets.symmetric(horizontal: 22),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: usersWithSameBooks.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final user = usersWithSameBooks[index];
                  return SizedBox(
                    width: 280,
                    child: FollowUserTile(
                      userId: user['user_id'],
                      username: user['username'] ?? '',
                      name: '${user['overlap_count']}권의 책이 겹쳐요',
                      avatarUrl: user['avatar_url'] ?? 'basic',
                      isMyProfile: false,
                      currentUserId: client.auth.currentUser?.id ?? '',
                      onTapFollow: _fetchUsersWithSameBooks,
                      onTapUnfollow: _fetchUsersWithSameBooks,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}