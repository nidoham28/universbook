/// Public-facing profile from `public.profiles`.
///
/// RLS: SELECT allowed for all public accounts + own private account.
class ProfileModel {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? coverUrl;
  final String bio;
  final DateTime? birthday;
  final DateTime joinedAt;
  final int followerCount;
  final int followingCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProfileModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.coverUrl,
    this.bio = '',
    this.birthday,
    required this.joinedAt,
    this.followerCount = 0,
    this.followingCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String? ?? 'New user',
      avatarUrl: json['avatar_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      bio: json['bio'] as String? ?? '',
      birthday: json['birthday'] != null
          ? DateTime.parse(json['birthday'] as String)
          : null,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      followerCount: json['follower_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'cover_url': coverUrl,
    'bio': bio,
    'birthday': birthday?.toIso8601String(),
    'joined_at': joinedAt.toIso8601String(),
    'follower_count': followerCount,
    'following_count': followingCount,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  /// Immutable copy with overrides.
  ProfileModel copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? coverUrl,
    String? bio,
    DateTime? birthday,
    DateTime? joinedAt,
    int? followerCount,
    int? followingCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      bio: bio ?? this.bio,
      birthday: birthday ?? this.birthday,
      joinedAt: joinedAt ?? this.joinedAt,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}