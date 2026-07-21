/// Private reader preferences from `public.consumers`.
///
/// RLS: SELECT allowed ONLY for own row. Attempting to fetch
/// another user's consumer data returns `null`.
class ConsumerModel {
  final String id;
  final String preferredLang;
  final bool matureContentEnabled;
  final List<int> favoriteCategories;
  final String defaultTheme;
  final int consumerStoryReadSum;
  final int consumerChapterReadSum;
  final int consumerReadingMinuteSum;
  final int readingStreakDays;
  final int longestStreakDays;
  final DateTime? lastReadDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConsumerModel({
    required this.id,
    this.preferredLang = 'bn',
    this.matureContentEnabled = false,
    this.favoriteCategories = const [],
    this.defaultTheme = 'light',
    this.consumerStoryReadSum = 0,
    this.consumerChapterReadSum = 0,
    this.consumerReadingMinuteSum = 0,
    this.readingStreakDays = 0,
    this.longestStreakDays = 0,
    this.lastReadDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConsumerModel.fromJson(Map<String, dynamic> json) {
    return ConsumerModel(
      id: json['id'] as String,
      preferredLang: json['preferred_lang'] as String? ?? 'bn',
      matureContentEnabled: json['mature_content_enabled'] as bool? ?? false,
      favoriteCategories: (json['favorite_categories'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList() ??
          const [],
      defaultTheme: json['default_theme'] as String? ?? 'light',
      consumerStoryReadSum: json['consumer_story_read_sum'] as int? ?? 0,
      consumerChapterReadSum: json['consumer_chapter_read_sum'] as int? ?? 0,
      consumerReadingMinuteSum: json['consumer_reading_minute_sum'] as int? ?? 0,
      readingStreakDays: json['reading_streak_days'] as int? ?? 0,
      longestStreakDays: json['longest_streak_days'] as int? ?? 0,
      lastReadDate: json['last_read_date'] != null
          ? DateTime.parse(json['last_read_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'preferred_lang': preferredLang,
    'mature_content_enabled': matureContentEnabled,
    'favorite_categories': favoriteCategories,
    'default_theme': defaultTheme,
    'consumer_story_read_sum': consumerStoryReadSum,
    'consumer_chapter_read_sum': consumerChapterReadSum,
    'consumer_reading_minute_sum': consumerReadingMinuteSum,
    'reading_streak_days': readingStreakDays,
    'longest_streak_days': longestStreakDays,
    'last_read_date': lastReadDate?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}