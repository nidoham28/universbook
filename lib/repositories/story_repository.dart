import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles thumbnail upload, story creation, and story fetching for the
/// "Create Stories" / reader screens. Story-row writes go through the
/// `create-story` Edge Function so that server-only fields (banned,
/// verified, counts, search_queue, ...) are never trusted from the client.
class StoryRepository {
  StoryRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Storage bucket that holds story thumbnails. Created (public, with
  /// per-user-folder write policies) by the storage section at the end of
  /// stories.sql — run that migration before calling [uploadThumbnail].
  static const String _thumbnailBucket = 'story-thumbnails';

  /// Uploads a picked image's raw bytes to Storage and returns its public
  /// URL, ready to hand to [createStory] or PageRepository.addPage/updatePage.
  Future<String> uploadThumbnail({
    required Uint8List bytes,
    required String fileExt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to upload a story.');
    }

    final safeExt = fileExt.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    final path = '$userId/$fileName';

    await _client.storage.from(_thumbnailBucket).uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );

    return _client.storage.from(_thumbnailBucket).getPublicUrl(path);
  }

  /// Calls the `create-story` Edge Function, which inserts the row into
  /// the `stories` table on the server (using the caller's identity for
  /// `creator`, and server-computed defaults for everything else).
  Future<Map<String, dynamic>> createStory({
    required String title,
    required String thumbnail,
    required String category,
    required bool isPaid,
    double? cost,
    List<String> tags = const [],
    String status = 'draft',
  }) async {
    final response = await _client.functions.invoke(
      'create-story',
      body: {
        'title': title,
        'thumbnail': thumbnail,
        'category': category,
        'isPaid': isPaid,
        if (isPaid && cost != null) 'cost': cost,
        'tags': tags,
        'status': status,
      },
    );

    final status_ = response.status;
    if (status_ < 200 || status_ >= 300) {
      final data = response.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'Unexpected error (status $status_)';
      throw Exception(message);
    }

    final data = response.data;
    if (data is Map && data['story'] is Map) {
      return Map<String, dynamic>.from(data['story'] as Map);
    }
    throw Exception('Unexpected response shape from create-story');
  }

  /// Fetches a single story row by id, for the reader/page-view screen.
  /// Relies on the table's RLS policies: the caller sees it if the story
  /// is public, or if the caller is the story's own creator.
  Future<Map<String, dynamic>> fetchStoryById(String storyId) async {
    final data = await _client
        .from('stories')
        .select()
        .eq('id', storyId)
        .single();
    return Map<String, dynamic>.from(data);
  }

  /// Fetches every story the signed-in user has created — draft, private,
  /// and public — newest first, for the "My Stories" screen.
  Future<List<Map<String, dynamic>>> fetchMyStories() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to view your stories.');
    }

    final data = await _client
        .from('stories')
        .select()
        .eq('creator', userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }
}