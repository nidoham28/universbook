import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../repositories/story_repository.dart'; // ← was stories_service.dart
import '../routes/app_routes.dart';

/// "My Stories" screen — lists every story the signed-in user has created,
/// including drafts and private stories, newest first.
///
/// Route: AppRoutes.myStories ('/myStories').
class StoriesPage extends StatefulWidget {
  const StoriesPage({super.key, StoryRepository? storyRepository})
      : _storyRepository = storyRepository;

  final StoryRepository? _storyRepository;

  @override
  State<StoriesPage> createState() => _StoriesPageState();
}

class _StoriesPageState extends State<StoriesPage> {
  late final StoryRepository _storyRepository =
      widget._storyRepository ?? StoryRepository();

  List<Map<String, dynamic>>? _stories;
  bool _isLoading = true;
  String? _errorMessage;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardColor => _isDark ? AppColors.cardDark : AppColors.cardLight;
  Color get _borderColor =>
      _isDark ? AppColors.borderDark : AppColors.borderLight;
  Color get _textPrimary =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get _textSecondary =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final stories = await _storyRepository.fetchMyStories();
      if (!mounted) return;
      setState(() {
        _stories = stories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load your stories: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stories'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStories,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _scrollableCenter(
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
                  onPressed: _loadStories, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final stories = _stories ?? const [];
    if (stories.isEmpty) {
      return _scrollableCenter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_stories_outlined,
                  size: 56, color: _textSecondary),
              const SizedBox(height: 12),
              Text(
                'You haven\'t published any stories yet',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap the + button to create your first one',
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
      itemCount: stories.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _StoryListTile(
        story: stories[index],
        cardColor: _cardColor,
        borderColor: _borderColor,
        textPrimary: _textPrimary,
        textSecondary: _textSecondary,
        onTap: () {
          final id = stories[index]['id']?.toString();
          if (id != null) context.push(AppRoutes.pageViewPath(id));
        },
      ),
    );
  }

  Widget _scrollableCenter({required Widget child}) {
    // Wrapped in a scroll view so RefreshIndicator's pull-to-refresh still
    // works from empty/error states, not just the populated list.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _StoryListTile extends StatelessWidget {
  const _StoryListTile({
    required this.story,
    required this.cardColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  final Map<String, dynamic> story;
  final Color cardColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = story['title'] as String? ?? 'Untitled';
    final thumbnail = story['thumbnail'] as String?;
    final category = story['category'] as String?;
    final status = story['status'] as String? ?? 'draft';
    final isPaid = story['is_paid'] == true;
    final cost = story['cost'];
    final viewsCount = (story['views_count'] as num?)?.toInt() ?? 0;
    final likesCount = (story['likes_count'] as num?)?.toInt() ?? 0;
    final banned = story['banned'] == true;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: thumbnail == null || thumbnail.isEmpty
                      ? Container(
                    color: borderColor.withValues(alpha: 0.3),
                    child: Icon(Icons.image_outlined,
                        color: textSecondary),
                  )
                      : Image.network(
                    thumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(
                          color: borderColor.withValues(alpha: 0.3),
                          child: Icon(Icons.broken_image_outlined,
                              color: textSecondary),
                        ),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _StatusChip(status: status),
                        if (banned)
                          const _Chip(label: 'Banned', color: AppColors.error),
                        if (category != null && category.isNotEmpty)
                          _Chip(label: category, color: AppColors.primary),
                        _Chip(
                          label: isPaid ? 'Paid • $cost' : 'Free',
                          color:
                          isPaid ? AppColors.warning : AppColors.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 14, color: textSecondary),
                        const SizedBox(width: 4),
                        Text('$viewsCount',
                            style:
                            TextStyle(color: textSecondary, fontSize: 12)),
                        const SizedBox(width: 12),
                        Icon(Icons.favorite_border,
                            size: 14, color: textSecondary),
                        const SizedBox(width: 4),
                        Text('$likesCount',
                            style:
                            TextStyle(color: textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'public' => AppColors.success,
      'private' => AppColors.warning,
      _ => AppColors.textSecondaryLight,
    };
    return _Chip(
        label: status[0].toUpperCase() + status.substring(1), color: color);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style:
        TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}