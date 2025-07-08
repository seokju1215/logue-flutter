import 'package:my_logue/data/repositories/follow_repository.dart';

class FollowUser {
  final FollowRepository repo;

  FollowUser(this.repo);

  Future<void> call(String userId) => repo.follow(userId);
}