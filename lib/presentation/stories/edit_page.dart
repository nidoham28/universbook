import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../repositories/page_repository.dart'; // ← was stories_service.dart

/// Create/edit screen for a single page within a story.
///
/// Route: GoRoute(path: '/editPage/:storyId', ...) — see
/// AppRoutes.editPagePath. If [pageIndex] is null this is a brand-new page;
/// otherwise it's the index of the existing page being edited.
class EditPageScreen extends StatefulWidget {
  const EditPageScreen({
    super.key,
    required this.storyId,
    this.pageIndex,
    PageRepository? pageRepository, // ← was StoriesService? storiesService
  }) : _pageRepository = pageRepository;

  final String storyId;
  final int? pageIndex;
  final PageRepository? _pageRepository; // ← was StoriesService?

  bool get isNewPage => pageIndex == null;

  @override
  State<EditPageScreen> createState() => _EditPageScreenState();
}

class _EditPageScreenState extends State<EditPageScreen> {
  // ↓ was: widget._storiesService ?? StoriesService()
  late final PageRepository _pageRepository =
      widget._pageRepository ?? PageRepository();
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _imageUrlController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _errorMessage;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textPrimary =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get _textSecondary =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  @override
  void initState() {
    super.initState();
    if (!widget.isNewPage) {
      _loadExistingPage();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // PageRepository.fetchPage(storyId, pageIndex) returns the page row
      // with at least {'content': String, 'image_url': String?}.
      final page = await _pageRepository.fetchPage(
        widget.storyId,
        widget.pageIndex!,
      );
      if (!mounted) return;
      _textController.text = (page['content'] as String?) ?? '';
      _imageUrlController.text = (page['image_url'] as String?) ?? '';
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load this page: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _savePage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final content = _textController.text.trim();
      final imageUrl = _imageUrlController.text.trim();

      if (widget.isNewPage) {
        // Appends a new page and bumps the story's page_count.
        await _pageRepository.addPage(
          widget.storyId,
          content: content,
          imageUrl: imageUrl.isEmpty ? null : imageUrl,
        );
      } else {
        // Overwrites the given page's content.
        await _pageRepository.updatePage(
          widget.storyId,
          widget.pageIndex!,
          content: content,
          imageUrl: imageUrl.isEmpty ? null : imageUrl,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not save this page: $e';
        _isSaving = false;
      });
    }
  }

  Future<void> _deletePage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete page?'),
        content: Text(
          'Page ${widget.pageIndex! + 1} will be removed. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });
    try {
      // Deletes the page, re-indexes later pages, decrements page_count.
      await _pageRepository.deletePage(widget.storyId, widget.pageIndex!);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not delete this page: $e';
        _isDeleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isSaving || _isDeleting;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isNewPage
              ? 'Add page'
              : 'Edit page ${widget.pageIndex! + 1}',
        ),
        centerTitle: true,
        actions: [
          if (!widget.isNewPage)
            IconButton(
              onPressed: busy || _isLoading ? null : _deletePage,
              icon: _isDeleting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: 'Delete page',
            ),
          TextButton(
            onPressed: busy || _isLoading ? null : _savePage,
            child: _isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Save'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 12),
          ],
          if (_imageUrlController.text.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _imageUrlController.text,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180,
                  alignment: Alignment.center,
                  color: _textSecondary.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: _textSecondary,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _imageUrlController,
            decoration: const InputDecoration(
              labelText: 'Image URL (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _textController,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(
              labelText: 'Page text',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Page text can\'t be empty'
                : null,
          ),
        ],
      ),
    );
  }
}