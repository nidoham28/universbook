import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/page_model.dart';
import 'story_repository.dart';

/// Handles page management for the editor/reader screens.
class PageRepository {
  PageRepository({SupabaseClient? client, StoryRepository? storyRepository})
      : _client = client ?? Supabase.instance.client,
        _storyRepository = storyRepository ?? StoryRepository(client: client);

  final SupabaseClient _client;
  final StoryRepository _storyRepository;

  static const String _pagesTable = 'pages';
  static const String _bucket = 'page-thumbnails';
  static const String _publishFn = 'create-page';
  static final Uuid _uuid = Uuid();

  String get _userId {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AuthException('Not signed in');
    return uid;
  }

  // ─────────────────────────────────────────────────────────
  // READ
  // ─────────────────────────────────────────────────────────

  Future<PageModel> fetchPageById(String id) async {
    final data = await _client
        .from(_pagesTable)
        .select()
        .eq('id', id)
        .single();
    return PageModel.fromJson(data);
  }

  Future<PageModel> fetchPage(String storyId, int pageIndex) async {
    final data = await _client
        .from(_pagesTable)
        .select()
        .eq('story_id', storyId)
        .eq('page_no', pageIndex)
        .single();
    return PageModel.fromJson(data);
  }

  Future<List<PageModel>> fetchPages(String storyId) async {
    final data = await _client
        .from(_pagesTable)
        .select()
        .eq('story_id', storyId)
        .order('page_no', ascending: true);
    return (data as List).map((e) => PageModel.fromJson(e)).toList();
  }

  /// Returns the next available page number (= current page_count), for
  /// display only (e.g. "Page 6"). Don't feed this into addPage/publishPage
  /// — both assign page_no server-side precisely to avoid the race this
  /// value is subject to.
  Future<int> nextPageNo(String storyId) async {
    final story = await _storyRepository.fetchStoryById(storyId);
    return (story['page_count'] as num?)?.toInt() ?? 0;
  }

  // ─────────────────────────────────────────────────────────
  // IMAGE UPLOAD
  // ─────────────────────────────────────────────────────────

  Future<String> uploadThumbnailBytes(
      Uint8List bytes, {
        String fileExtension = 'jpg',
      }) async {
    final path = '$_userId/${_uuid.v4()}.$fileExtension';

    await _client.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        cacheControl: '3600',
        upsert: false,
        contentType: 'image/$fileExtension',
      ),
    );

    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  Future<void> deleteThumbnail(String publicUrl) async {
    try {
      final segments = Uri.parse(publicUrl).pathSegments;
      final i = segments.indexOf(_bucket);
      if (i == -1 || i + 1 >= segments.length) return;
      await _client.storage
          .from(_bucket)
          .remove([segments.sublist(i + 1).join('/')]);
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────
  // WRITES (drafts / private pages — no Edge Function round trip)
  // ─────────────────────────────────────────────────────────

  /// Creates a draft/private page. `pages` has no client-writable INSERT
  /// policy — this goes through the `add_page` RPC instead, which locks
  /// the parent story row before assigning page_no (so it can't race a
  /// concurrent add_page/publishPage call) and checks story ownership
  /// itself. Use [publishPage] for a page that should be indexed for
  /// search immediately.
  Future<PageModel> addPage({
    required String storyId,
    required String title,
    required String content,
    String? thumbnail,
    List<String> relatedPages = const [],
    String status = 'draft',
  }) async {
    final data = await _client.rpc('add_page', params: {
      'p_story_id': storyId,
      'p_title': title.trim(),
      'p_content': content.trim(),
      'p_thumbnail': thumbnail,
      'p_related_pages': relatedPages,
      'p_status': status,
    });
    return PageModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Updates a draft/private page in place. `pages` has no client-writable
  /// UPDATE policy — this goes through the `update_page` RPC, which checks
  /// ownership itself. Pass [status] only when you want to change it;
  /// omitting it leaves the page's current status untouched.
  Future<PageModel> updatePage({
    required String pageId,
    required String title,
    required String content,
    String? thumbnail,
    List<String> relatedPages = const [],
    String? status,
  }) async {
    final data = await _client.rpc('update_page', params: {
      'p_page_id': pageId,
      'p_title': title.trim(),
      'p_content': content.trim(),
      'p_thumbnail': thumbnail,
      'p_related_pages': relatedPages,
      'p_status': status,
    });
    return PageModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ─────────────────────────────────────────────────────────
  // PUBLISH (via Edge Function)
  // ─────────────────────────────────────────────────────────

  /// Creates a new public page. page_no is always assigned server-side
  /// (never pass one in) — that's what makes concurrent publishes safe.
  Future<Map<String, dynamic>> publishPage({
    required String storyId,
    required String title,
    required String content,
    String? thumbnail,
    List<String> relatedPages = const [],
  }) async {
    final res = await _client.functions.invoke(
      _publishFn,
      body: {
        'story_id': storyId, // matches Edge Function + DB column
        'title': title.trim(),
        'content': content.trim(),
        if (thumbnail != null) 'thumbnail': thumbnail,
        'related_pages': relatedPages,
        'status': 'public',
      },
    );

    if (res.status != 200 && res.status != 201) {
      final err =
          (res.data is Map ? res.data['error'] : null) ?? res.data.toString();
      throw Exception('publishPage failed (${res.status}): $err');
    }

    final data = res.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return <String, dynamic>{};
  }

  /// Updates an existing public page identified by [pageId].
  /// Fetches the page first to resolve story_id + page_no, then delegates
  /// to the Edge Function (which owns the search-queue rebuild, etc.).
  Future<Map<String, dynamic>> updateAndPublishPage({
    required String pageId,
    required String title,
    required String content,
    String? thumbnail,
    List<String> relatedPages = const [],
  }) async {
    final page = await fetchPageById(pageId);

    final res = await _client.functions.invoke(
      _publishFn,
      body: {
        'story_id': page.storyId, // matches Edge Function + DB column
        'page_no': page.pageNo,
        'title': title.trim(),
        'content': content.trim(),
        if (thumbnail != null) 'thumbnail': thumbnail,
        'related_pages': relatedPages,
        'status': 'public',
      },
    );

    if (res.status != 200 && res.status != 201) {
      final err =
          (res.data is Map ? res.data['error'] : null) ?? res.data.toString();
      throw Exception('updateAndPublishPage failed (${res.status}): $err');
    }

    final data = res.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return <String, dynamic>{};
  }

  // ─────────────────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────────────────

  Future<void> deletePage(String pageId) async {
    final page = await fetchPageById(pageId);

    await _client.rpc('delete_page_and_reindex', params: {
      'p_story_id': page.storyId,
      'p_page_no': page.pageNo,
    });

    if (page.thumbnail != null && page.thumbnail!.isNotEmpty) {
      await deleteThumbnail(page.thumbnail!);
    }
  }
}