import 'package:logue/data/repositories/follow_repository.dart';

class UnfollowUser {
  final FollowRepository repo;

  UnfollowUser(this.repo);

  Future<void> call(String userId) => repo.unfollow(userId);
}