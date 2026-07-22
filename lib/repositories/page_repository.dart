import 'package:supabase_flutter/supabase_flutter.dart';

import 'story_repository.dart';

/// Handles page management for the editor/reader screens. Page rows (in
/// `story_pages`) are plain, RLS-protected table access.
///
/// NOTE: this table doesn't exist yet in the schema you shared — create
/// it (with RLS mirroring `stories`: readable if the parent story is
/// public or the caller is its creator, writable only by the creator)
/// with roughly:
///   id          uuid primary key default gen_random_uuid()
///   story_id    uuid references stories(id) on delete cascade
///   page_index  int not null
///   content     text not null default ''
///   image_url   text
///   created_at  timestamptz default now()
///   unique (story_id, page_index)
class PageRepository {
  PageRepository({SupabaseClient? client, StoryRepository? storyRepository})
      : _client = client ?? Supabase.instance.client,
        _storyRepository = storyRepository ?? StoryRepository(client: client);

  final SupabaseClient _client;
  final StoryRepository _storyRepository;

  static const String _pagesTable = 'story_pages';

  /// Fetches a single page by its position within the story, for the
  /// edit-page screen.
  Future<Map<String, dynamic>> fetchPage(String storyId, int pageIndex) async {
    final data = await _client
        .from(_pagesTable)
        .select()
        .eq('story_id', storyId)
        .eq('page_index', pageIndex)
        .single();
    return Map<String, dynamic>.from(data);
  }

  /// Appends a new page after the story's current last page, then bumps
  /// `stories.page_count` to match. Not wrapped in a DB transaction (the
  /// supabase-flutter client doesn't expose one) — if you see partial
  /// failures under concurrent edits, move this pair into an Edge
  /// Function like `create-story`.
  Future<void> addPage(
      String storyId, {
        required String content,
        String? imageUrl,
      }) async {
    final story = await _storyRepository.fetchStoryById(storyId);
    final nextIndex = (story['page_count'] as num?)?.toInt() ?? 0;

    await _client.from(_pagesTable).insert({
      'story_id': storyId,
      'page_index': nextIndex,
      'content': content,
      'image_url': imageUrl,
    });

    await _client
        .from('stories')
        .update({'page_count': nextIndex + 1})
        .eq('id', storyId);
  }

  /// Overwrites an existing page's content/image.
  Future<void> updatePage(
      String storyId,
      int pageIndex, {
        required String content,
        String? imageUrl,
      }) async {
    await _client
        .from(_pagesTable)
        .update({
      'content': content,
      'image_url': imageUrl,
    })
        .eq('story_id', storyId)
        .eq('page_index', pageIndex);
  }

  /// Deletes a page and shifts every later page's `page_index` down by one
  /// so indices stay contiguous, then decrements `stories.page_count`.
  Future<void> deletePage(String storyId, int pageIndex) async {
    await _client
        .from(_pagesTable)
        .delete()
        .eq('story_id', storyId)
        .eq('page_index', pageIndex);

    final laterPages = await _client
        .from(_pagesTable)
        .select('id, page_index')
        .eq('story_id', storyId)
        .gt('page_index', pageIndex)
        .order('page_index', ascending: true);

    for (final row in (laterPages as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      await _client
          .from(_pagesTable)
          .update({'page_index': (map['page_index'] as num).toInt() - 1})
          .eq('id', map['id']);
    }

    final story = await _storyRepository.fetchStoryById(storyId);
    final currentCount = (story['page_count'] as num?)?.toInt() ?? 1;
    await _client
        .from('stories')
        .update({'page_count': currentCount > 0 ? currentCount - 1 : 0})
        .eq('id', storyId);
  }
}