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
  final List<String>? contactPhoneNumbers; // 연락처 전화번호 목록 추가
  
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
    // widget.contactNumber가 있으면 사용, 없으면 null
    contactNumber = widget.contactNumber;
    
    if (widget.contactPhoneNumbers != null && widget.contactPhoneNumbers!.isNotEmpty) {
      // 주소록에서 가져온 전화번호 목록이 있으면 권한이 있다고 간주하고 바로 친구 검색 시작
      setState(() {
        hasContactPermission = true; // 권한이 있다고 설정
      });
      _searchFriendsFromContacts();
    } else {
      // 전달받은 전화번호 목록이 없어서 권한 확인 필요
      _checkContactPermissionAndSearchFriends();
    }
  }

  Future<void> _checkContactPermission() async {
    try {
      
      // 연락처 권한 상태 확인
      final permission = await FlutterContacts.requestPermission();
      
      setState(() {
        hasContactPermission = permission;
      });
      
      if (permission) {
        // 권한이 있으면 친구 검색 시작
        _searchFriendsFromContacts();
      } else {
        debugPrint('❌ 권한 거부됨');
      }
    } catch (e) {
      debugPrint('❌ 연락처 권한 확인 실패: $e');
      debugPrint('❌ 에러 스택: ${StackTrace.current}');
    }
  }

  Future<void> _checkContactPermissionAndSearchFriends() async {
    try {
      
      // 연락처 권한 상태 확인
      final permission = await FlutterContacts.requestPermission();
      
      setState(() {
        hasContactPermission = permission;
      });
      
      if (permission) {
        // 권한이 있으면 바로 친구 검색 시작
        _searchFriendsFromContacts();
      } else {
        debugPrint('❌ 권한 거부됨');
      }
    } catch (e) {
      debugPrint('❌ 연락처 권한 확인 실패: $e');
      debugPrint('❌ 에러 스택: ${StackTrace.current}');
    }
  }

  Future<void> _searchFriendsFromContacts() async {
    try {
      setState(() {
        isSearchingFriends = true;
      });

      // 전화번호 목록 준비 - 주소록에서 가져온 전화번호들만 사용
      List<String> phoneNumbers;
      
      if (widget.contactPhoneNumbers != null && widget.contactPhoneNumbers!.isNotEmpty) {
        // 주소록에서 가져온 전화번호 목록 사용
        phoneNumbers = widget.contactPhoneNumbers!;
      } else {
        // 주소록에서 전화번호 가져오기
        phoneNumbers = await _getPhoneNumbersFromContacts();
      }
      
      if (phoneNumbers.isEmpty) {
        setState(() {
          isSearchingFriends = false;
        });
        return;
      }

      // 전화번호 샘플 출력 (처음 5개)
      final sampleNumbers = phoneNumbers.take(5).toList();

      // RPC 함수 match_contacts를 사용하여 친구 찾기
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;
      
      if (currentUserId == null) {
        setState(() {
          isSearchingFriends = false;
        });
        return;
      }

      try {
        
        // match_contacts RPC 함수 호출
        final response = await supabase.rpc(
          'match_contacts',
          params: {'contact_list': phoneNumbers},
        );


        if (response != null) {
          final List<Map<String, dynamic>> friends = List<Map<String, dynamic>>.from(response);
          
          // 자기 자신 제외
          final filteredFriends = friends.where((friend) => friend['user_id'] != currentUserId).toList();
          
          if (mounted) {
            setState(() {
              foundFriends = filteredFriends;
              isSearchingFriends = false;
            });
          }

        } else {
          if (mounted) {
            setState(() {
              foundFriends = [];
              isSearchingFriends = false;
            });
          }
          print('✅ 친구 검색 완료: 친구를 찾지 못했습니다.');
        }
      } catch (e) {
        debugPrint('❌ RPC 함수 호출 중 오류: $e');
        debugPrint('❌ 에러 스택: ${StackTrace.current}');
        if (mounted) {
          setState(() {
            isSearchingFriends = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ 친구 검색 중 오류 발생: $e');
      debugPrint('❌ 에러 스택: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          isSearchingFriends = false;
        });
      }
    }
  }

  /// 주소록에서 전화번호 목록을 가져옴
  Future<List<String>> _getPhoneNumbersFromContacts() async {
    try {
      // 주소록 권한 요청 및 확인
      final hasPermission = await FlutterContacts.requestPermission(readonly: true);
      
      if (!hasPermission) {
        debugPrint('❌ 주소록 접근 권한이 거부되었습니다.');
        return [];
      }

      
      // 주소록 가져오기
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      
      final phoneNumbers = <String>[];
      
      for (int i = 0; i < contacts.length; i++) {
        final contact = contacts[i];
        
        final phones = contact.phones;
        
        if (phones.isNotEmpty) {
          for (int j = 0; j < phones.length; j++) {
            final phone = phones[j];
            
            // 전화번호에서 특수문자 제거하고 숫자만 추출
            final cleanNumber = phone.number.replaceAll(RegExp(r'[^\d]'), '');
            
            if (cleanNumber.isNotEmpty) {
              phoneNumbers.add(cleanNumber);
            } else {
              debugPrint('❌ 빈 전화번호 제외됨');
            }
          }
        } else {
          debugPrint('❌ 이 연락처에는 전화번호가 없음');
        }
      }

      return phoneNumbers;
    } catch (e) {
      debugPrint('❌ 주소록에서 전화번호 가져오기 실패: $e');
      debugPrint('❌ 에러 상세: ${e.toString()}');
      debugPrint('❌ 에러 스택: ${StackTrace.current}');
      return [];
    }
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
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text("친구 찾기", style: TextStyle(fontSize: 16, color: AppColors.black900, fontWeight: FontWeight.w500,)),
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity, // Row가 가로 전체 쓰도록 보장
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 19), // 버튼과 19px 간격
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppColors.black200,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            isLoading
                                ? '로딩 중...'
                                : (contactNumber ?? '전화번호를 입력해주세요'),
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
                          padding: EdgeInsets.zero, // 시각적으로 더 오른쪽에 '착' 붙게
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '편집',
                          style: TextStyle(
                            color: AppColors.blue500,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
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

                // 연락처 권한이 없을 때 권한 요청 버튼


                            // 프로필 공유 버튼
                Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                          if (currentUserId != null) {
                            // 현재 사용자의 프로필 정보 가져오기
                            try {
                              final response = await Supabase.instance.client
                                  .from('profiles')
                                  .select('username')
                                  .eq('id', currentUserId)
                                  .single();

                              if (response != null && response['username'] != null) {
                                final profileLink = 'https://www.logue.it.kr/u/${response['username']}';
                                Share.share(profileLink);
                              }
                            } catch (e) {
                              print('❌ 프로필 정보 가져오기 실패: $e');
                            }
                          }
                        },
                        style: _outlinedStyle(context),
                        child: const Text(
                          '친구 초대',
                          style: TextStyle(fontSize: 13, color: AppColors.black900, height: 1.25),
                        ),
                      ),
                    ),
                  ],
                ),

              ],
            ),
          ),
          if (hasContactPermission && foundFriends.isNotEmpty) ...[
            Column(
              children: [
                SizedBox(height: 23,),
                StrokeTextStyle.createStrokeText(
                  text: '친구 찾기 결과',
                  fontSize: 16,
                  color: AppColors.black900,
                  fontWeight: FontWeight.w400,
                  height: 1.187,
                ),
                SizedBox(height: 6,),
                Expanded(
                  child: ListView.builder(
                    itemCount: foundFriends.length,
                    itemBuilder: (context, index) {
                      final friend = foundFriends[index];
                      final isFollowing = ref.watch(followStateProvider(friend['user_id']));

                      return FollowUserTile(
                        currentUserId: currentUserId ?? '',
                        userId: friend['user_id'],
                        username: friend['username'] ?? '',
                        name: friend['username'] ?? '', // name 필드가 없으므로 username 사용
                        avatarUrl: friend['avatar_url'] ?? 'basic',
                        isMyProfile: false,
                        onTapFollow: () async {
                          final followNotifier = ref.read(followStateProvider(friend['user_id']).notifier);
                          followNotifier.optimisticFollow();
                          try {
                            await followNotifier.follow();
                          } catch (e) {
                            followNotifier.optimisticUnfollow();
                          }
                        },
                        onTapUnfollow: () async {
                          final followNotifier = ref.read(followStateProvider(friend['user_id']).notifier);
                          followNotifier.optimisticUnfollow();
                          try {
                            await followNotifier.unfollow();
                          } catch (e) {
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
                        isFollowing: isFollowing,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],

          // 친구를 찾지 못했을 때 메시지
          if (hasContactPermission && !isSearchingFriends && foundFriends.isEmpty && contactNumber != null)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                SizedBox(height: 180,),
                Text(
                  "아직 LOGUE를 이용중인 친구가 없어요.\n친구를 초대해 인생 책을 공유해보세요!",
                  style:
                  TextStyle(fontSize: 13, color: AppColors.black500, ),
                ),
                SizedBox(height: 140,)
              ],
            )
        ],
      ),
    );
  }
} 