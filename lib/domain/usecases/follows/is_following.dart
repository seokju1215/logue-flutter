import 'package:logue/data/repositories/follow_repository.dart';

class IsFollowing {
  final FollowRepository repo;

  IsFollowing(this.repo);

  Future<bool> call(String userId) => repo.isFollowing(userId);
}