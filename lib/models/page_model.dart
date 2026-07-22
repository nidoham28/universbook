// lib/models/page_model.dart

import 'package:equatable/equatable.dart';

enum PageStatus { draft, private_, public_ }

extension PageStatusX on PageStatus {
  String get value {
    switch (this) {
      case PageStatus.draft:
        return 'draft';
      case PageStatus.private_:
        return 'private';
      case PageStatus.public_:
        return 'public';
    }
  }

  String get label {
    switch (this) {
      case PageStatus.draft:
        return 'Draft';
      case PageStatus.private_:
        return 'Private';
      case PageStatus.public_:
        return 'Public';
    }
  }

  static PageStatus fromString(String value) {
    switch (value) {
      case 'private':
        return PageStatus.private_;
      case 'public':
        return PageStatus.public_;
      default:
        return PageStatus.draft;
    }
  }
}

class PageModel extends Equatable {
  const PageModel({
    this.id,
    required this.storyId,
    this.creator,
    this.createdAt,
    this.updatedAt,
    required this.title,
    this.thumbnail,
    required this.content,
    this.status = PageStatus.draft,
    this.banned = false,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.commentCount = 0,
    this.contentLength = 0,
    required this.pageNo,
    this.relatedPages = const [],
    this.searchQueue = const [],
  });

  final String? id;
  final String storyId;
  final String? creator;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String title;
  final String? thumbnail;
  final String content;
  final PageStatus status;
  final bool banned;
  final int viewsCount;
  final int likesCount;
  final int commentCount;
  final int contentLength;
  final int pageNo;
  final List<String> relatedPages;
  final List<String> searchQueue;

  factory PageModel.fromJson(Map<String, dynamic> json) {
    return PageModel(
      id: json['id'] as String?,
      storyId: (json['stories_id'] ?? json['story_id']) as String,
      creator: json['creator'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      title: (json['title'] as String?) ?? '',
      thumbnail: json['thumbnail'] as String?,
      content: (json['content'] as String?) ?? '',
      status: PageStatusX.fromString(
        (json['status'] as String?) ?? 'draft',
      ),
      banned: (json['banned'] as bool?) ?? false,
      viewsCount: (json['views_count'] as int?) ?? 0,
      likesCount: (json['likes_count'] as int?) ?? 0,
      commentCount: (json['comment_count'] as int?) ?? 0,
      contentLength: (json['content_length'] as int?) ?? 0,
      pageNo: json['page_no'] as int,
      relatedPages: (json['related_pages'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          const [],
      searchQueue: (json['search_queue'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'story_id': storyId,
      'creator': creator,
      'title': title,
      'thumbnail': thumbnail,
      'content': content,
      'status': status.value,
      'content_length': content.length,
      'page_no': pageNo,
      'related_pages': relatedPages,
      'search_queue': searchQueue,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      'thumbnail': thumbnail,
      'content': content,
      'status': status.value,
      'content_length': content.length,
      'related_pages': relatedPages,
      'search_queue': searchQueue,
    };
  }

  PageModel copyWith({
    String? id,
    String? storyId,
    String? creator,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? title,
    String? thumbnail,
    String? content,
    PageStatus? status,
    bool? banned,
    int? viewsCount,
    int? likesCount,
    int? commentCount,
    int? contentLength,
    int? pageNo,
    List<String>? relatedPages,
    List<String>? searchQueue,
  }) {
    return PageModel(
      id: id ?? this.id,
      storyId: storyId ?? this.storyId,
      creator: creator ?? this.creator,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      content: content ?? this.content,
      status: status ?? this.status,
      banned: banned ?? this.banned,
      viewsCount: viewsCount ?? this.viewsCount,
      likesCount: likesCount ?? this.likesCount,
      commentCount: commentCount ?? this.commentCount,
      contentLength: contentLength ?? this.contentLength,
      pageNo: pageNo ?? this.pageNo,
      relatedPages: relatedPages ?? this.relatedPages,
      searchQueue: searchQueue ?? this.searchQueue,
    );
  }

  @override
  List<Object?> get props => [
    id, storyId, creator, createdAt, updatedAt,
    title, thumbnail, content, status, banned,
    viewsCount, likesCount, commentCount,
    contentLength, pageNo, relatedPages, searchQueue,
  ];
}