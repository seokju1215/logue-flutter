import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/stroke_text_style.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'input_phone_number_screen.dart';
import '../../../../core/widgets/follow/follow_user_tile.dart';
import '../../../screens/profile/other_profile_screen.dart';
import '../../../../core/providers/follow_state_provider.dart';

class FindFriendsScreen extends ConsumerStatefulWidget {
  final String? contactNumber;
  final List<String>? contactPhoneNumbers;

  const FindFriendsScreen({
    super.key,
    this.contactNumber,
    this.contactPhoneNumbers,
  });

  @override
  ConsumerState<FindFriendsScreen> createState() => _FindFriendsScreenState();
}

class _FindFriendsScreenState extends ConsumerState<FindFriendsScreen> {
  String? contactNumber;
  bool isLoading = false;
  List<Map<String, dynamic>> foundFriends = [];
  bool isSearchingFriends = false;
  bool hasContactPermission = false;

  @override
  void initState() {
    super.initState();
    contactNumber = widget.contactNumber;

    if (widget.contactPhoneNumbers != null && widget.contactPhoneNumbers!.isNotEmpty) {
      setState(() {
        hasContactPermission = true;
      });
      _searchFriendsFromContacts();
    } else {
      _checkContactPermissionAndSearchFriends();
    }
  }

  Future<void> _checkContactPermissionAndSearchFriends() async {
    final permission = await FlutterContacts.requestPermission();
    setState(() {
      hasContactPermission = permission;
    });
    if (permission) _searchFriendsFromContacts();
  }

  Future<void> _searchFriendsFromContacts() async {
    final startedAt = DateTime.now();
    try {
      setState(() => isSearchingFriends = true);

      List<String> phoneNumbers = widget.contactPhoneNumbers ?? await _getPhoneNumbersFromContacts();

      if (phoneNumbers.isEmpty) return;

      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final response = await supabase.rpc('match_contacts', params: {'contact_list': phoneNumbers});
      final friends = List<Map<String, dynamic>>.from(response)
          .where((f) => f['user_id'] != currentUserId)
          .toList();

      await Future.delayed(Duration(milliseconds: 300));
      setState(() {
        foundFriends = friends;
        isSearchingFriends = false;
      });
    } catch (e) {
      setState(() => isSearchingFriends = false);
    }
  }

  Future<List<String>> _getPhoneNumbersFromContacts() async {
    final hasPermission = await FlutterContacts.requestPermission(readonly: true);
    if (!hasPermission) return [];

    final contacts = await FlutterContacts.getContacts(withProperties: true);
    return contacts
        .expand((contact) => contact.phones)
        .map((phone) => phone.number.replaceAll(RegExp(r'[^\d]'), ''))
        .where((clean) => clean.isNotEmpty)
        .toList();
  }

  Future<void> _editPhoneNumber() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InputPhoneNumberScreen(
          initialPhoneNumber: contactNumber,
          contactPhoneNumbers: widget.contactPhoneNumbers,
          fromScreen: 'find_friends_screen',
        ),
      ),
    );
  }

  ButtonStyle _outlinedStyle(BuildContext context) {
    return ButtonStyle(
      foregroundColor: MaterialStateProperty.all(AppColors.black900),
      backgroundColor: MaterialStateProperty.all(Colors.white),
      overlayColor: MaterialStateProperty.resolveWith<Color?>(
            (states) => states.contains(MaterialState.pressed) ? AppColors.black100 : null,
      ),
      side: MaterialStateProperty.all(const BorderSide(color: AppColors.black500, width: 1)),
      shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
      padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 9)),
      minimumSize: MaterialStateProperty.all(const Size(0, 34)),
      textStyle: MaterialStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text("친구 찾기", style: TextStyle(fontSize: 16, color: AppColors.black900, fontWeight: FontWeight.w500)),
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: kBottomNavigationBarHeight + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(right: 19),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: AppColors.black200,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              isLoading ? '로딩 중...' : (contactNumber ?? '전화번호를 입력해주세요'),
                              style: TextStyle(
                                fontSize: 14,
                                color: contactNumber != null ? AppColors.black500 : AppColors.black300,
                                height: 1.21,
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _editPhoneNumber,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('편집', style: TextStyle(color: AppColors.blue500, fontSize: 15)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 19),
                    StrokeTextStyle.createStrokeText(
                      text: '친구를 초대해 인생 책을 공유해보세요!',
                      fontSize: 16,
                      color: AppColors.black900,
                      fontWeight: FontWeight.w400,
                      height: 1.187,
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        const Expanded(child: SizedBox()),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final userId = Supabase.instance.client.auth.currentUser?.id;
                              if (userId != null) {
                                final response = await Supabase.instance.client
                                    .from('profiles')
                                    .select('username')
                                    .eq('id', userId)
                                    .single();
                                final username = response['username'];
                                final profileLink = 'https://www.logue.it.kr/u/$username';
                                Share.share(profileLink);
                              }
                            },
                            style: _outlinedStyle(context),
                            child: const Text('친구 초대', style: TextStyle(fontSize: 13, color: AppColors.black900)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isSearchingFriends)
                Padding(
                  padding: const EdgeInsets.only(top: 180),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.black900),
                    ),
                  ),
                ),
              if (hasContactPermission && foundFriends.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 23),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 22),
                        child: StrokeTextStyle.createStrokeText(
                          text: '친구 찾기 결과',
                          fontSize: 16,
                          color: AppColors.black900,
                          fontWeight: FontWeight.w400,
                          height: 1.187,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: foundFriends.length,
                        itemBuilder: (context, index) {
                          final friend = foundFriends[index];
                          final isFollowing = ref.watch(followStateProvider(friend['user_id']));
                          return FollowUserTile(
                            currentUserId: currentUserId ?? '',
                            userId: friend['user_id'],
                            username: friend['username'] ?? '',
                            name: friend['username'] ?? '',
                            avatarUrl: friend['avatar_url'] ?? 'basic',
                            isMyProfile: false,
                            isFollowing: isFollowing,
                            onTapFollow: () async {
                              final followNotifier = ref.read(followStateProvider(friend['user_id']).notifier);
                              followNotifier.optimisticFollow();
                              try {
                                await followNotifier.follow();
                              } catch (_) {
                                followNotifier.optimisticUnfollow();
                              }
                            },
                            onTapUnfollow: () async {
                              final followNotifier = ref.read(followStateProvider(friend['user_id']).notifier);
                              followNotifier.optimisticUnfollow();
                              try {
                                await followNotifier.unfollow();
                              } catch (_) {
                                followNotifier.optimisticFollow();
                              }
                            },
                            onTapProfile: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OtherProfileScreen(userId: friend['user_id']),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              if (hasContactPermission && !isSearchingFriends && foundFriends.isEmpty && contactNumber != null)
                Padding(
                  padding: const EdgeInsets.only(top: 180),
                  child: const Center(
                    child: Text(
                      "아직 LOGUE를 이용중인 친구가 없어요.\n친구를 초대해 인생 책을 공유해보세요!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.black500),
                    ),
                  ),
                ),
              const SizedBox(height: 0),
            ],
          ),
        ),
      ),
    );
  }
}