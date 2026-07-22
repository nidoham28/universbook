import 'package:supabase_flutter/supabase_flutter.dart';

/// Columns the feed can be sorted by. Maps 1:1 to real column names
/// (or a computed expression) on `public.stories`.
enum StorySortField {
  createdAt('created_at'),
  updatedAt('updated_at'),
  title('title'),
  viewsCount('views_count'),
  likesCount('likes_count'),
  cost('cost'),
  pageNo('page_no');

  final String column;
  const StorySortField(this.column);
}

enum SortDirection { asc, desc }

/// Lightweight model for a row in `public.pages`.
/// Only exposes fields that are safe/relevant for the feed — server-only
/// columns like `search_queue` / `related_pages` aren't surfaced here.
class Story {
  final String id;
  final String creator;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String title;
  final String? thumbnail;
  final int pageNo;
  final String status;
  final int viewsCount;
  final int likesCount;
  // `category` is a Postgres array column (text[]), not a scalar string.
  final List<String> category;
  final List<String> tags;
  final bool verified;
  final num cost;
  final bool isPaid;

  final num ratingSum;
  final int ratingTime;

  Story({
    required this.id,
    required this.creator,
    required this.createdAt,
    required this.updatedAt,
    required this.title,
    required this.thumbnail,
    required this.pageNo,
    required this.status,
    required this.viewsCount,
    required this.likesCount,
    required this.category,
    required this.tags,
    required this.verified,
    required this.cost,
    required this.isPaid,
    required this.ratingSum,
    required this.ratingTime,
  });

  /// Average rating (0 when no ratings yet), for display convenience.
  double get averageRating => ratingTime > 0 ? ratingSum / ratingTime : 0.0;

  factory Story.fromMap(Map<String, dynamic> map) {
    return Story(
      id: map['id'] as String,
      creator: map['creator'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      title: map['title'] as String? ?? '',
      thumbnail: map['thumbnail'] as String?,
      pageNo: map['page_no'] as int? ?? 0,
      status: map['status'] as String,
      viewsCount: map['views_count'] as int? ?? 0,
      likesCount: map['likes_count'] as int? ?? 0,
      category: List<String>.from(map['category'] as List? ?? const []),
      tags: List<String>.from(map['tags'] as List? ?? const []),
      verified: map['verified'] as bool? ?? false,
      cost: map['cost'] as num? ?? 0,
      isPaid: map['is_paid'] as bool? ?? false,
      ratingSum: map['rating_sum'] as num? ?? 0,
      ratingTime: map['rating_time'] as int? ?? 0,
    );
  }
}

/// Repository for reading the public page feed.
///
/// This only ever SELECTs from `pages`. Creation/updates go through
/// the upsert-page edge function per the RLS policies in pages.sql,
/// so no write methods live here.
class FeedRepository {
  FeedRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _table = 'pages';

  /// Fetch a page of public stories.
  ///
  /// [sortBy] / [direction] control ordering (defaults to newest first).
  /// [category] filters to stories whose `category` array contains this
  /// value, if provided.
  /// [searchQuery] does a simple case-insensitive title match.
  /// [page] is 0-indexed; [pageSize] controls page length.
  Future<List<Story>> fetchStories({
    StorySortField sortBy = StorySortField.createdAt,
    SortDirection direction = SortDirection.desc,
    String? category,
    String? searchQuery,
    int page = 0,
    int pageSize = 20,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    var query = _client
        .from(_table)
        .select()
        .eq('status', 'public')
        .eq('banned', false);

    if (category != null && category.isNotEmpty && category != 'All') {
      // `category` is a Postgres array column, so membership is checked
      // with `contains` (renders to `@>`), not `eq`.
      query = query.contains('category', [category]);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.ilike('title', '%${searchQuery.trim()}%');
    }

    final response = await query
        .order(sortBy.column, ascending: direction == SortDirection.asc)
        .range(from, to);

    return (response as List)
        .map((row) => Story.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Rating is a derived value (rating_sum / rating_time), so it can't be
  /// sorted with a plain `.order()` — fetch a wider window ordered by a
  /// reasonable proxy, then sort client-side. Fine for feed-sized pages;
  /// swap for a DB view/generated column if you need this at scale.
  Future<List<Story>> fetchStoriesByRating({
    SortDirection direction = SortDirection.desc,
    String? category,
    int page = 0,
    int pageSize = 20,
  }) async {
    var query = _client
        .from(_table)
        .select()
        .eq('status', 'public')
        .eq('banned', false)
        .gt('rating_time', 0);

    if (category != null && category.isNotEmpty && category != 'All') {
      query = query.contains('category', [category]);
    }

    // Pull a generous window so the client-side sort stays accurate
    // across the requested page.
    final windowSize = (page + 1) * pageSize * 3;
    final response =
    await query.order('rating_time', ascending: false).limit(windowSize);

    final stories = (response as List)
        .map((row) => Story.fromMap(row as Map<String, dynamic>))
        .toList();

    stories.sort((a, b) => direction == SortDirection.asc
        ? a.averageRating.compareTo(b.averageRating)
        : b.averageRating.compareTo(a.averageRating));

    final from = page * pageSize;
    final to = (from + pageSize).clamp(0, stories.length);
    if (from >= stories.length) return [];
    return stories.sublist(from, to);
  }

  /// Fetch a single public story by id.
  Future<Story?> fetchStoryById(String id) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('id', id)
        .eq('status', 'public')
        .eq('banned', false)
        .maybeSingle();

    if (response == null) return null;
    return Story.fromMap(response);
  }

  /// Distinct list of categories currently in use, for building filter
  /// chips dynamically instead of hardcoding them. Since `category` is
  /// an array column, each row can contribute multiple categories, so
  /// results are flattened before de-duping.
  Future<List<String>> fetchCategories() async {
    final response = await _client
        .from(_table)
        .select('category')
        .eq('status', 'public')
        .eq('banned', false);

    final categories = (response as List)
        .expand((row) => List<String>.from(
        (row as Map<String, dynamic>)['category'] as List? ?? const []))
        .toSet()
        .toList()
      ..sort();

    return categories;
  }
}