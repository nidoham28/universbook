import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/page_model.dart';
import '../../repositories/page_repository.dart';
import '../routes/app_routes.dart';

/// Reader screen for a single page, opened from the feed. Shows a cover
/// banner (the page's own thumbnail + title), then the page's content and
/// its search_queue tags below. This is a single-page "story view" — it
/// does NOT list sibling pages from the same story; there is no
/// channel/playlist behavior here. Tapping "Edit" opens that same page
/// in the editor.
///
/// Route: GoRoute(path: '/pageView/:pageId', ...) — see AppRoutes.pageView.
/// `pageId` is a `pages.id` row id (see FeedTab's onTap), not a story id.
class PageViewScreen extends StatefulWidget {
  const PageViewScreen({
    super.key,
    required this.pageId,
    this._pageRepository,
  });

  final String pageId;
  final PageRepository? _pageRepository;

  @override
  State<PageViewScreen> createState() => _PageViewScreenState();
}

class _PageViewScreenState extends State<PageViewScreen> {
  late final PageRepository _pageRepository =
      widget._pageRepository ?? PageRepository();

  PageModel? _page;
  bool _isLoading = true;
  String? _errorMessage;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textPrimary =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get _textSecondary =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  static const List<Color> _tagPalette = [
    Color(0xFFFF6B9D),
    Color(0xFF4D96FF),
    Color(0xFF3DD9B3),
    Color(0xFFFFB84D),
    Color(0xFFB16CEA),
    Color(0xFF6BCB77),
  ];

  Color _tagColor(int i) => _tagPalette[i % _tagPalette.length];

  Color _darken(Color color, [double amount = 0.35]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // widget.pageId identifies a single page row — fetch that page only,
      // not the full set of pages belonging to its parent story.
      final page = await _pageRepository.fetchPageById(widget.pageId);
      if (!mounted) return;
      setState(() {
        _page = page;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load this page: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openEditPage() async {
    final page = _page;
    if (page == null) return;
    await context.push(
      AppRoutes.editPagePath(page.storyId, pageIndex: page.pageNo),
    );
    if (!mounted) return;
    _loadPage();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Scaffold(
      floatingActionButton: page == null
          ? null
          : FloatingActionButton.extended(
        onPressed: _openEditPage,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null || page == null
          ? _buildError()
          : RefreshIndicator(
        onRefresh: _loadPage,
        child: CustomScrollView(
          slivers: [
            _buildHeaderSliver(page),
            _buildContentSliver(page),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Page not found',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadPage, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSliver(PageModel page) {
    final thumbnail = page.thumbnail;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 220,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnail != null && thumbnail.isNotEmpty)
              Image.network(
                thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color:
                  _isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                ),
              )
            else
              Container(
                color: _isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                child: Icon(Icons.menu_book_outlined,
                    size: 56, color: _textSecondary),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.65),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'PAGE ${page.pageNo + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Text(
                    page.title.isNotEmpty ? page.title : 'Untitled page',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSliver(PageModel page) {
    final tags = page.searchQueue.take(6).toList();

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          if (page.content.trim().isNotEmpty)
            Text(
              page.content.trim(),
              style: TextStyle(
                color: _textPrimary,
                fontSize: 15.5,
                height: 1.55,
              ),
            )
          else
            Text(
              'This page has no content yet.',
              style: TextStyle(color: _textSecondary),
            ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < tags.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                      _tagColor(i).withOpacity(_isDark ? 0.22 : 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _tagColor(i).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      tags[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _isDark
                            ? _tagColor(i).withOpacity(0.95)
                            : _darken(_tagColor(i)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ]),
      ),
    );
  }
}