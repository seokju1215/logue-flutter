import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/data/repositories/follow_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final followStateProvider = StateNotifierProvider.family<FollowStateNotifier, bool, String>(
  (ref, userId) => FollowStateNotifier(userId, ref.read(followRepositoryProvider)),
);

// 로그아웃 시 모든 followStateProvider를 무효화하기 위한 프로바이더
final followStateInvalidatorProvider = Provider<FollowStateInvalidator>((ref) {
  return FollowStateInvalidator(ref);
});

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  final client = Supabase.instance.client;
  final functionBaseUrl = dotenv.env['FUNCTION_BASE_URL']!;
  return FollowRepository(client: client, functionBaseUrl: functionBaseUrl);
});

class FollowStateInvalidator {
  final Ref _ref;
  FollowStateInvalidator(this._ref);

  void invalidateAll() {
    // 모든 followStateProvider를 무효화
    _ref.invalidate(followStateProvider);
  }
}

class FollowStateNotifier extends StateNotifier<bool> {
  final String targetUserId;
  final FollowRepository followRepository;
  bool _isDisposed = false;
  bool _isRequestInProgress = false; // 요청 중복 방지
  bool _isInitialized = false; // 초기화 완료 여부

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
    if (_isDisposed) {
      debugPrint('🔴 _init: 이미 dispose 상태라 초기화 중단');
      return;
    }

    final currentUserId = followRepository.client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == targetUserId) {
      safeSet(false);
      _isInitialized = true;
      return;
    }

    try {
      final res = await followRepository.client
          .from('follows')
          .select('id')
          .eq('follower_id', currentUserId)
          .eq('following_id', targetUserId)
          .maybeSingle();
      
      if (!_isDisposed) {
        safeSet(res != null);
        _isInitialized = true;
        debugPrint('🔍 FollowState 초기화 완료: $targetUserId -> ${res != null}');
      }
    } catch (e) {
      debugPrint('🔴 FollowState fetch error: $e');
      if (!_isDisposed) {
        safeSet(false);
        _isInitialized = true;
      }
    }
  }

  void optimisticFollow() => safeSet(true);
  void optimisticUnfollow() => safeSet(false);

  Future<void> follow() async {
    if (_isDisposed) {
      debugPrint('🔴 follow: 이미 dispose 상태라 요청 중단');
      return;
    }
    
    if (_isRequestInProgress) {
      debugPrint('🔴 follow 요청 중복 방지: $targetUserId');
      return;
    }
    
    _isRequestInProgress = true;
    try {
      await followRepository.follow(targetUserId);
      if (!_isDisposed) {
        debugPrint('🔍 follow 완료: $targetUserId');
      }
    } catch (e) {
      debugPrint('🔴 follow-user Edge Function 실패: $e');
      rethrow;
    } finally {
      if (!_isDisposed) {
        _isRequestInProgress = false;
      }
    }
  }

  Future<void> unfollow() async {
    if (_isDisposed) {
      debugPrint('🔴 unfollow: 이미 dispose 상태라 요청 중단');
      return;
    }
    
    if (_isRequestInProgress) {
      debugPrint('🔴 unfollow 요청 중복 방지: $targetUserId');
      return;
    }
    
    _isRequestInProgress = true;
    try {
      await followRepository.unfollow(targetUserId);
      if (!_isDisposed) {
        debugPrint('🔍 unfollow 완료: $targetUserId');
      }
    } catch (e) {
      debugPrint('🔴 unfollow-user Edge Function 실패: $e');
      rethrow;
    } finally {
      if (!_isDisposed) {
        _isRequestInProgress = false;
      }
    }
  }

  Future<void> refresh() async {
    await _init();
  }

  // 강제 새로고침 (캐시 무시)
  Future<void> forceRefresh() async {
    _isDisposed = false; // dispose 상태 리셋
    await _init();
  }
}