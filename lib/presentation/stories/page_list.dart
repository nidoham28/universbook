import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/page_model.dart';
import '../../repositories/page_repository.dart';
import '../../repositories/story_repository.dart';
import '../routes/app_routes.dart';

/// Reader/manager screen shown right after a story is published (and
/// reusable for opening any story later). Loads the story record and its
/// actual pages, shows a summary header, and lets the author tap into any
/// page to edit it or tap "Add page" to create a new one.
///
/// Route: GoRoute(path: '/pageView/:storyId', ...) — see AppRoutes.pageView.
class PageListScreen extends StatefulWidget {
  const PageListScreen({
    super.key,
    required this.storyId,
    this._storyRepository,
    this._pageRepository,
  });

  final String storyId;
  final StoryRepository? _storyRepository;
  final PageRepository? _pageRepository;

  @override
  State<PageListScreen> createState() => _PageViewScreenState();
}

class _PageViewScreenState extends State<PageListScreen> {
  late final StoryRepository _storyRepository =
      widget._storyRepository ?? StoryRepository();
  late final PageRepository _pageRepository =
      widget._pageRepository ?? PageRepository();

  Map<String, dynamic>? _story;
  List<PageModel> _pages = const [];
  bool _isLoading = true;
  String? _errorMessage;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _card => _isDark ? AppColors.cardDark : AppColors.cardLight;
  Color get _border => _isDark ? AppColors.borderDark : AppColors.borderLight;
  Color get _textPrimary =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get _textSecondary =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads the story record and its real pages together. Previously this
  /// screen only fetched the story and synthesized "Page 1", "Page 2"...
  /// tiles from page_count — no titles, no per-page thumbnails, no status.
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _storyRepository.fetchStoryById(widget.storyId),
        _pageRepository.fetchPages(widget.storyId),
      ]);
      if (!mounted) return;
      setState(() {
        _story = results[0] as Map<String, dynamic>;
        _pages = results[1] as List<PageModel>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load this story: $e';
        _isLoading = false;
      });
    }
  }

  /// Opens edit_page.dart for an existing page (page number provided) or
  /// for a brand-new page (omitted). Reloads on return so the list picks
  /// up any changes (new page, edited title/status, deletion, etc).
  Future<void> _openEditPage({int? pageNo}) async {
    await context.push(
      AppRoutes.editPagePath(widget.storyId, pageIndex: pageNo),
    );
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_story?['title'] as String? ?? 'Story'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
      floatingActionButton: _isLoading || _errorMessage != null
          ? null
          : FloatingActionButton.extended(
        onPressed: () => _openEditPage(),
        icon: const Icon(Icons.add),
        label: const Text('Add page'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      // A scrollable (not just Center) so the pull-to-refresh gesture
      // still works from the error state.
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40),
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _textSecondary),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ],
      );
    }

    final story = _story!;

    if (_pages.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildStoryHeader(story),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),
                Icon(Icons.menu_book_outlined,
                    size: 48, color: _textSecondary),
                const SizedBox(height: 12),
                Text(
                  'No pages yet. Tap "Add page" to create the first one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _textSecondary),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _pages.length + 1, // +1 for the story header
      separatorBuilder: (context, index) =>
          SizedBox(height: index == 0 ? 20 : 8),
      itemBuilder: (context, index) {
        if (index == 0) return _buildStoryHeader(story);
        final page = _pages[index - 1];
        return _PageListTile(
          page: page,
          card: _card,
          border: _border,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
          onTap: () => _openEditPage(pageNo: page.pageNo),
        );
      },
    );
  }

  Widget _buildStoryHeader(Map<String, dynamic> story) {
    final thumbnail = story['thumbnail'] as String?;
    final title = story['title'] as String? ?? 'Untitled story';
    final status = story['status'] as String? ?? 'draft';
    final views = (story['views_count'] as num?)?.toInt() ?? 0;
    final likes = (story['likes_count'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: thumbnail != null && thumbnail.isNotEmpty
                  ? Image.network(
                thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.image_not_supported_outlined,
                  color: _textSecondary,
                ),
              )
                  : Container(
                color: _isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                alignment: Alignment.center,
                child: Icon(Icons.menu_book_outlined,
                    color: _textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _statusBadge(status),
                    const SizedBox(width: 10),
                    Icon(Icons.visibility_outlined,
                        size: 14, color: _textSecondary),
                    const SizedBox(width: 3),
                    Text('$views',
                        style:
                        TextStyle(color: _textSecondary, fontSize: 12)),
                    const SizedBox(width: 10),
                    Icon(Icons.favorite_border,
                        size: 14, color: _textSecondary),
                    const SizedBox(width: 3),
                    Text('$likes',
                        style:
                        TextStyle(color: _textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_pages.length} page${_pages.length == 1 ? '' : 's'}',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final Color color;
    switch (status) {
      case 'public':
        color = AppColors.primary;
        break;
      case 'private':
        color = Colors.blueGrey;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.isEmpty ? status : status[0].toUpperCase() + status.substring(1),
        style:
        TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PageListTile extends StatelessWidget {
  const _PageListTile({
    required this.page,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  final PageModel page;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  Color get _statusColor {
    switch (page.status) {
      case PageStatus.draft:
        return Colors.orange;
      case PageStatus.private_:
        return Colors.blueGrey;
      case PageStatus.public_:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = page.content.trim();
    return Card(
      color: card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: SizedBox(
          width: 48,
          height: 48,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: page.thumbnail != null && page.thumbnail!.isNotEmpty
                ? Image.network(
              page.thumbnail!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.image_not_supported_outlined,
                color: textSecondary,
              ),
            )
                : Icon(Icons.description_outlined, color: textSecondary),
          ),
        ),
        title: Text(
          page.title.isNotEmpty ? page.title : 'Page ${page.pageNo + 1}',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: _statusColor,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                preview.isNotEmpty ? preview : page.status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: textSecondary),
      ),
    );
  }
}