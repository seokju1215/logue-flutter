import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/utils/amplitude_util.dart';

final followStateProvider = StateNotifierProvider.family<FollowStateNotifier, bool, String>(
      (ref, userId) => FollowStateNotifier(userId),
);

class FollowStateNotifier extends StateNotifier<bool> {
  final String targetUserId;
  final supabase = Supabase.instance.client;

  FollowStateNotifier(this.targetUserId) : super(false) {
    _init();
  }

  Future<void> _init() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == targetUserId) {
      state = false;
      return;
    }

    try {
      final res = await supabase
          .from('follows')
          .select('id')
          .eq('follower_id', currentUserId)
          .eq('following_id', targetUserId)
          .maybeSingle();

      state = res != null;
    } catch (e) {
      debugPrint('🔴 FollowState fetch error: $e');
    }
  }

  void optimisticFollow() => state = true;
  void optimisticUnfollow() => state = false;

  //// 실제 follow 요청
  Future<void> follow() async {
    optimisticFollow();

    final response = await supabase.rpc('follow_user', params: {
      'target_user_id': targetUserId,
    });

    if (response.error != null) {
      debugPrint('🔴 follow_user RPC 실패: ${response.error!.message}');
      optimisticUnfollow(); // 롤백
    } else{
      AmplitudeUtil.log('follow_user', props: {
        'target_user_id': targetUserId,
      });
    }
  }

  /// 실제 unfollow 요청
  Future<void> unfollow() async {
    optimisticUnfollow();
    debugPrint('📤 unfollow_user RPC 호출 시작 (target: $targetUserId)');

    final response = await supabase.rpc('unfollow_user', params: {
      'target_user_id': targetUserId,
    });

    if (response.error != null) {
      debugPrint('🔴 unfollow_user RPC 실패: ${response.error!.message}');
      optimisticFollow(); // 롤백
    } else {
      AmplitudeUtil.log('unfollow_user', props: {
        'target_user_id': targetUserId,
      });
      debugPrint('✅ unfollow_user RPC 성공');
    }
  }
}