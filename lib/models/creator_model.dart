/// Creator stats from `public.creators`.
///
/// RLS: SELECT allowed for everyone (public data).
class CreatorModel {
  final String id;
  final String tagline;
  final bool isVerified;
  final String badge;
  final int creatorStorySum;
  final int creatorLikeSum;
  final int creatorReadingSum;
  final int creatorRatingSum;
  final int creatorRatingCount;
  final double? creatorRatingAverage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CreatorModel({
    required this.id,
    this.tagline = '',
    this.isVerified = false,
    this.badge = 'none',
    this.creatorStorySum = 0,
    this.creatorLikeSum = 0,
    this.creatorReadingSum = 0,
    this.creatorRatingSum = 0,
    this.creatorRatingCount = 0,
    this.creatorRatingAverage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CreatorModel.fromJson(Map<String, dynamic> json) {
    return CreatorModel(
      id: json['id'] as String,
      tagline: json['tagline'] as String? ?? '',
      isVerified: json['is_verified'] as bool? ?? false,
      badge: json['badge'] as String? ?? 'none',
      creatorStorySum: json['creator_story_sum'] as int? ?? 0,
      creatorLikeSum: json['creator_like_sum'] as int? ?? 0,
      creatorReadingSum: json['creator_reading_sum'] as int? ?? 0,
      creatorRatingSum: json['creator_rating_sum'] as int? ?? 0,
      creatorRatingCount: json['creator_rating_count'] as int? ?? 0,
      creatorRatingAverage: json['creator_rating_average'] != null
          ? (json['creator_rating_average'] as num).toDouble()
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tagline': tagline,
    'is_verified': isVerified,
    'badge': badge,
    'creator_story_sum': creatorStorySum,
    'creator_like_sum': creatorLikeSum,
    'creator_reading_sum': creatorReadingSum,
    'creator_rating_sum': creatorRatingSum,
    'creator_rating_count': creatorRatingCount,
    'creator_rating_average': creatorRatingAverage,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}