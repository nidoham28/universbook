import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universbook/genarated/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../repositories/feed_repository.dart';
import '../../routes/app_routes.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _CategoryData {
  final String label;
  final IconData icon;
  const _CategoryData(this.label, this.icon);
}

class _SortOption {
  final String label;
  final StorySortField? field; // null => sort by rating (handled separately)
  final SortDirection direction;
  const _SortOption(this.label, this.field, this.direction);
}

class _FeedTabState extends State<FeedTab> {
  static const List<_CategoryData> _categories = [
    _CategoryData('All', Icons.apps_rounded),
    _CategoryData('Horror', Icons.dark_mode_rounded),
    _CategoryData('Romantic', Icons.favorite_rounded),
    _CategoryData('Sad', Icons.water_drop_rounded),
    _CategoryData('Comedy', Icons.sentiment_very_satisfied_rounded),
    _CategoryData('Adventure', Icons.terrain_rounded),
    _CategoryData('Mystery', Icons.search_rounded),
    _CategoryData('Fantasy', Icons.auto_awesome_rounded),
    _CategoryData('Thriller', Icons.bolt_rounded),
  ];

  static const List<_SortOption> _sortOptions = [
    _SortOption('Newest', StorySortField.createdAt, SortDirection.desc),
    _SortOption('Oldest', StorySortField.createdAt, SortDirection.asc),
    _SortOption('Title A–Z', StorySortField.title, SortDirection.asc),
    _SortOption('Title Z–A', StorySortField.title, SortDirection.desc),
    _SortOption('Most viewed', StorySortField.viewsCount, SortDirection.desc),
    _SortOption('Most liked', StorySortField.likesCount, SortDirection.desc),
    _SortOption('Top rated', null, SortDirection.desc),
  ];

  final FeedRepository _repository = FeedRepository();

  String _selectedCategory = 'All';
  _SortOption _selectedSort = _sortOptions.first;

  late Future<List<Story>> _storiesFuture;

  @override
  void initState() {
    super.initState();
    _storiesFuture = _loadStories();
  }

  Future<List<Story>> _loadStories() {
    if (_selectedSort.field == null) {
      return _repository.fetchStoriesByRating(
        direction: _selectedSort.direction,
        category: _selectedCategory,
      );
    }
    return _repository.fetchStories(
      sortBy: _selectedSort.field!,
      direction: _selectedSort.direction,
      category: _selectedCategory,
    );
  }

  void _onCategorySelected(String label) {
    setState(() {
      _selectedCategory = label;
      _storiesFuture = _loadStories();
    });
  }

  void _onSortSelected(_SortOption option) {
    setState(() {
      _selectedSort = option;
      _storiesFuture = _loadStories();
    });
  }

  Future<void> _onRefresh() async {
    final future = _loadStories();
    setState(() => _storiesFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16, right: 4, top: 6, bottom: 6),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = category.label == _selectedCategory;

                    final unselectedText = isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight;
                    final unselectedBg =
                    isDark ? AppColors.cardDark : AppColors.cardLight;
                    final unselectedBorder =
                    isDark ? AppColors.borderDark : AppColors.borderLight;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _onCategorySelected(category.label),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : unselectedBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : unselectedBorder,
                              width: 1,
                            ),
                            boxShadow: isSelected
                                ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.28),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                category.icon,
                                size: 16,
                                color: isSelected ? Colors.white : unselectedText,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                category.label,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.0,
                                  letterSpacing: 0.2,
                                  fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? Colors.white : unselectedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            PopupMenuButton<_SortOption>(
              icon: Icon(
                Icons.tune_rounded,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              onSelected: _onSortSelected,
              itemBuilder: (context) => _sortOptions
                  .map((option) => PopupMenuItem(
                value: option,
                child: Row(
                  children: [
                    if (option.label == _selectedSort.label)
                      Icon(Icons.check_rounded, size: 16, color: AppColors.primary)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(option.label),
                  ],
                ),
              ))
                  .toList(),
            ),
            const SizedBox(width: 8),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: FutureBuilder<List<Story>>(
              future: _storiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _ErrorState(
                    message: '${snapshot.error}',
                    onRetry: () => setState(() => _storiesFuture = _loadStories()),
                  );
                }

                final stories = snapshot.data ?? const [];

                if (stories.isEmpty) {
                  return _EmptyState(welcomeMessage: l10n.welcomeMessage);
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: stories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _StoryCard(story: stories[index]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryCard extends StatelessWidget {
  final Story story;
  const _StoryCard({required this.story});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final titleColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor =
    isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // `story.id` is the pages.id row id — PageViewScreen resolves it
          // to a page (and its parent story) via its own StoryRepository().
          context.push('${AppRoutes.pageView}/${story.id}');
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _Thumbnail(
                  url: story.thumbnail,
                  borderColor: borderColor,
                  iconColor: secondaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            story.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                        ),
                        if (story.verified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 16, color: AppColors.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // `category` is now a List<String> (array column), so
                    // join it for display instead of rendering the list directly.
                    if (story.category.isNotEmpty)
                      Text(
                        story.category.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: secondaryColor),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.remove_red_eye_outlined, size: 14, color: secondaryColor),
                        const SizedBox(width: 3),
                        Text('${story.viewsCount}',
                            style: TextStyle(fontSize: 12, color: secondaryColor)),
                        const SizedBox(width: 12),
                        Icon(Icons.favorite_border_rounded, size: 14, color: secondaryColor),
                        const SizedBox(width: 3),
                        Text('${story.likesCount}',
                            style: TextStyle(fontSize: 12, color: secondaryColor)),
                        const SizedBox(width: 12),
                        Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                        const SizedBox(width: 3),
                        Text(
                          story.ratingTime > 0
                              ? story.averageRating.toStringAsFixed(1)
                              : '—',
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        ),
                        const Spacer(),
                        if (story.isPaid)
                          Container(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              story.cost.toStringAsFixed(0),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders a story/page thumbnail, falling back to a placeholder icon
/// when [url] is null or empty (`pages.thumbnail` is nullable) or when
/// the image fails to load.
class _Thumbnail extends StatelessWidget {
  final String? url;
  final Color borderColor;
  final Color iconColor;

  const _Thumbnail({
    required this.url,
    required this.borderColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _placeholder();
    }

    return Image.network(
      url!,
      width: 72,
      height: 96,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: 72,
          height: 96,
          color: borderColor,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 72,
      height: 96,
      color: borderColor,
      child: Icon(Icons.menu_book_rounded, color: iconColor),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String welcomeMessage;
  const _EmptyState({required this.welcomeMessage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined,
                size: 40, color: theme.colorScheme.onSurface.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(
              welcomeMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}