import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../repositories/story_repository.dart'; // ← was stories_service.dart
import '../routes/app_routes.dart';

/// Reader/manager screen shown right after a story is published (and
/// reusable for opening any story later). Takes the story's id, loads its
/// record, and lists its pages. Tapping a page opens it for editing; the
/// floating "Add page" button creates a new one.
///
/// Route: GoRoute(path: '/pageView/:storyId', ...) — see AppRoutes.pageView.
class PageViewScreen extends StatefulWidget {
  const PageViewScreen({
    super.key,
    required this.storyId,
    StoryRepository? storyRepository, // ← was StoriesService? storiesService
  }) : _storyRepository = storyRepository;

  final String storyId;
  final StoryRepository? _storyRepository; // ← was StoriesService?

  @override
  State<PageViewScreen> createState() => _PageViewScreenState();
}

class _PageViewScreenState extends State<PageViewScreen> {
  // ↓ was: widget._storiesService ?? StoriesService()
  late final StoryRepository _storyRepository =
      widget._storyRepository ?? StoryRepository();

  Map<String, dynamic>? _story;
  bool _isLoading = true;
  String? _errorMessage;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textPrimary =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get _textSecondary =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  @override
  void initState() {
    super.initState();
    _loadStory();
  }

  Future<void> _loadStory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // ↓ was: _storiesService.fetchStoryById(...)
      final story = await _storyRepository.fetchStoryById(widget.storyId);
      if (!mounted) return;
      setState(() {
        _story = story;
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

  /// Opens edit_page.dart for an existing page (index provided) or for a
  /// brand-new page (index omitted). Reloads the story on return so the
  /// list picks up any changes (new page added, page_count changed, etc).
  Future<void> _openEditPage({int? pageIndex}) async {
    await context.push(
      AppRoutes.editPagePath(widget.storyId, pageIndex: pageIndex),
    );
    if (!mounted) return;
    _loadStory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_story?['title'] as String? ?? 'Story'),
        centerTitle: true,
      ),
      body: _buildBody(),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadStory,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final story = _story!;
    final thumbnail = story['thumbnail'] as String?;
    final pageCount = (story['page_count'] as num?)?.toInt() ?? 0;

    if (pageCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, size: 48, color: _textSecondary),
              const SizedBox(height: 12),
              Text(
                'No pages yet. Tap "Add page" to create the first one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: pageCount,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _PageListTile(
          index: index,
          thumbnail: index == 0 ? thumbnail : null,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
          onTap: () => _openEditPage(pageIndex: index),
        );
      },
    );
  }
}

class _PageListTile extends StatelessWidget {
  const _PageListTile({
    required this.index,
    required this.thumbnail,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  final int index;
  final String? thumbnail;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: SizedBox(
          width: 48,
          height: 48,
          child: thumbnail != null && thumbnail!.isNotEmpty
              ? Image.network(
            thumbnail!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.image_not_supported_outlined,
              color: textSecondary,
            ),
          )
              : Icon(Icons.description_outlined, color: textSecondary),
        ),
        title: Text(
          'Page ${index + 1}',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        ),
        trailing: Icon(Icons.chevron_right, color: textSecondary),
      ),
    );
  }
}