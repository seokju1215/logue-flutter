class UserProfile {
  final String id;
  final String username;
  final String name; // ✅ 추가된 필드
  final String? avatarUrl;
  final bool isFollowing; // ✅ 현재 유저가 팔로우 중인지 여부

  UserProfile({
    required this.id,
    required this.username,
    required this.name,
    this.avatarUrl,
    this.isFollowing = false,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, {required bool isFollowing}) {
    return UserProfile(
      id: map['id'] as String,
      username: map['username'] as String,
      name: map['name'] as String? ?? '', // ✅ name 파싱 추가
      avatarUrl: map['avatar_url'] as String?,
      isFollowing: isFollowing,
    );
  }
}