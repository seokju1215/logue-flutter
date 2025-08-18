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
    
    if (contactNumber != null && contactNumber!.isNotEmpty) {
      // 이미 등록된 연락처가 있으면 바로 친구 검색 시작
      debugPrint('📱 이미 등록된 연락처로 바로 친구 검색 시작: $contactNumber');
      setState(() {
        hasContactPermission = true; // 권한이 있다고 설정
      });
      _searchFriendsFromContacts();
    } else if (widget.contactPhoneNumbers != null && widget.contactPhoneNumbers!.isNotEmpty) {
      // 전달받은 연락처 목록이 있으면 권한이 있다고 간주하고 바로 친구 검색 시작
      debugPrint('📱 전달받은 연락처 목록으로 바로 친구 검색 시작');
      setState(() {
        hasContactPermission = true; // 권한이 있다고 설정
      });
      _searchFriendsFromContacts();
    } else {
      // 전달받은 연락처 목록이 없어서 권한 확인 필요
      debugPrint('📱 전달받은 연락처 목록이 없어서 권한 확인 필요');
      _checkContactPermissionAndSearchFriends();
    }
  }

  Future<void> _checkContactPermission() async {
    try {
      debugPrint('🔐 연락처 권한 확인 시작');
      
      // 연락처 권한 상태 확인
      final permission = await FlutterContacts.requestPermission();
      debugPrint('🔐 연락처 권한 상태: $permission');
      
      setState(() {
        hasContactPermission = permission;
      });
      
      if (permission) {
        debugPrint('✅ 권한 승인됨, 친구 검색 시작');
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
      debugPrint('🔐 연락처 권한 확인 및 친구 찾기 시작');
      
      // 연락처 권한 상태 확인
      final permission = await FlutterContacts.requestPermission();
      debugPrint('🔐 연락처 권한 상태: $permission');
      
      setState(() {
        hasContactPermission = permission;
      });
      
      if (permission) {
        debugPrint('✅ 권한 승인됨, 친구 검색 시작');
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
      debugPrint('🔍 _searchFriendsFromContacts 시작');
      setState(() {
        isSearchingFriends = true;
      });

      // 전화번호 목록 준비
      List<String> phoneNumbers;
      
      if (contactNumber != null && contactNumber!.isNotEmpty) {
        // 이미 등록된 contact_number가 있으면 이를 사용
        debugPrint('📱 이미 등록된 연락처 사용: $contactNumber');
        phoneNumbers = [contactNumber!];
      } else if (widget.contactPhoneNumbers != null && widget.contactPhoneNumbers!.isNotEmpty) {
        debugPrint('📱 전달받은 연락처 전화번호 목록 사용');
        phoneNumbers = widget.contactPhoneNumbers!;
        debugPrint('📱 전달받은 전화번호 개수: ${phoneNumbers.length}개');
        debugPrint('📱 전화번호 목록: $phoneNumbers');
      } else {
        debugPrint('📱 주소록에서 전화번호 가져오기 시작');
        phoneNumbers = await _getPhoneNumbersFromContacts();
        debugPrint('📱 가져온 전화번호 개수: ${phoneNumbers.length}개');
      }
      
      if (phoneNumbers.isEmpty) {
        debugPrint('❌ 전화번호 목록이 비어있습니다.');
        setState(() {
          isSearchingFriends = false;
        });
        return;
      }

      // 전화번호 샘플 출력 (처음 5개)
      final sampleNumbers = phoneNumbers.take(5).toList();
      debugPrint('📱 전화번호 샘플 (처음 5개): $sampleNumbers');

      // RPC 함수 match_contacts를 사용하여 친구 찾기
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;
      debugPrint('🔍 현재 사용자 ID: $currentUserId');
      
      if (currentUserId == null) {
        debugPrint('❌ 현재 사용자 ID를 가져올 수 없습니다.');
        setState(() {
          isSearchingFriends = false;
        });
        return;
      }

      try {
        debugPrint('🚀 match_contacts RPC 함수 호출 시작');
        debugPrint('📤 전달할 전화번호 개수: ${phoneNumbers.length}개');
        
        // match_contacts RPC 함수 호출
        final response = await supabase.rpc(
          'match_contacts',
          params: {'contact_list': phoneNumbers},
        );

        debugPrint('📥 RPC 응답: $response');
        debugPrint('📥 RPC 응답 타입: ${response.runtimeType}');

        if (response != null) {
          final List<Map<String, dynamic>> friends = List<Map<String, dynamic>>.from(response);
          debugPrint('👥 파싱된 친구 목록: $friends');
          debugPrint('👥 친구 목록 타입: ${friends.runtimeType}');
          debugPrint('👥 친구 목록 길이: ${friends.length}');
          
          // 자기 자신 제외
          final filteredFriends = friends.where((friend) => friend['user_id'] != currentUserId).toList();
          debugPrint('👥 자기 자신 제외 후 친구 수: ${filteredFriends.length}명');
          
          if (mounted) {
            setState(() {
              foundFriends = filteredFriends;
              isSearchingFriends = false;
            });
          }
          
          debugPrint('✅ 친구 검색 완료: ${foundFriends.length}명의 친구를 찾았습니다.');
        } else {
          debugPrint('⚠️ RPC 응답이 null입니다.');
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
      debugPrint('🔍 주소록 접근 시작...');
      
      // 주소록 권한 요청 및 확인
      final hasPermission = await FlutterContacts.requestPermission(readonly: true);
      debugPrint('🔍 주소록 권한 상태: $hasPermission');
      
      if (!hasPermission) {
        debugPrint('❌ 주소록 접근 권한이 거부되었습니다.');
        return [];
      }

      debugPrint('🔍 주소록 가져오기 시작...');
      
      // 주소록 가져오기
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      
      debugPrint('🔍 가져온 연락처 수: ${contacts.length}');
      
      final phoneNumbers = <String>[];
      
      for (int i = 0; i < contacts.length; i++) {
        final contact = contacts[i];
        debugPrint('🔍 연락처 ${i + 1}: ${contact.displayName}');
        
        final phones = contact.phones;
        debugPrint('🔍 전화번호 개수: ${phones.length}');
        
        if (phones.isNotEmpty) {
          for (int j = 0; j < phones.length; j++) {
            final phone = phones[j];
            debugPrint('🔍 전화번호 ${j + 1}: ${phone.number}');
            
            // 전화번호에서 특수문자 제거하고 숫자만 추출
            final cleanNumber = phone.number.replaceAll(RegExp(r'[^\d]'), '');
            debugPrint('🔍 정리된 전화번호: $cleanNumber');
            
            if (cleanNumber.isNotEmpty) {
              phoneNumbers.add(cleanNumber);
              debugPrint('✅ 전화번호 추가됨: $cleanNumber');
            } else {
              debugPrint('❌ 빈 전화번호 제외됨');
            }
          }
        } else {
          debugPrint('❌ 이 연락처에는 전화번호가 없음');
        }
      }
      
      debugPrint('✅ 주소록에서 ${phoneNumbers.length}개의 전화번호를 가져왔습니다.');
      debugPrint('🔍 최종 전화번호 목록: $phoneNumbers');
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
        builder: (context) => InputPhoneNumberScreen(),
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
                          '프로필 공유',
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