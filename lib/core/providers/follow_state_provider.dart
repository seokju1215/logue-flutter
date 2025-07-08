import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/data/repositories/follow_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final followStateProvider = StateNotifierProvider.family<FollowStateNotifier, bool, String>(
  (ref, userId) => FollowStateNotifier(userId, ref.read(followRepositoryProvider)),
);

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  final client = Supabase.instance.client;
  final functionBaseUrl = dotenv.env['FUNCTION_BASE_URL']!;
  return FollowRepository(client: client, functionBaseUrl: functionBaseUrl);
});

class FollowStateNotifier extends StateNotifier<bool> {
  final String targetUserId;
  final FollowRepository followRepository;
  bool _isDisposed = false;

  FollowStateNotifier(this.targetUserId, this.followRepository) : super(false) {
    _init();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void safeSet(bool value) {
    if (!_isDisposed) {
      state = value;
    } else {
      debugPrint('🔴 safeSet: 이미 dispose 상태라 state 갱신 무시');
    }
  }

  Future<void> _init() async {
    final currentUserId = followRepository.client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == targetUserId) {
      safeSet(false);
      return;
    }

    try {
      final res = await followRepository.client
          .from('follows')
          .select('id')
          .eq('follower_id', currentUserId)
          .eq('following_id', targetUserId)
          .maybeSingle();
      safeSet(res != null);
    } catch (e) {
      debugPrint('🔴 FollowState fetch error: $e');
      safeSet(false);
    }
  }

  void optimisticFollow() => safeSet(true);
  void optimisticUnfollow() => safeSet(false);

  Future<void> follow() async {
    try {
      await followRepository.follow(targetUserId);
    } catch (e) {
      debugPrint('🔴 follow-user Edge Function 실패: $e');
      rethrow;
    }
  }

  Future<void> unfollow() async {
    try {
      await followRepository.unfollow(targetUserId);
    } catch (e) {
      debugPrint('🔴 unfollow-user Edge Function 실패: $e');
      rethrow;
    }
  }

  Future<void> refresh() async {
    await _init();
  }
}