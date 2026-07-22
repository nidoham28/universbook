// lib/screens/edit_page/edit_page_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/page_model.dart';
import '../../repositories/page_repository.dart';
import '../../services/image_picker.dart';

class EditPageScreen extends StatefulWidget {
  const EditPageScreen({
    super.key,
    required this.storyId,
    this.pageId,
    this.pageNo,
    PageRepository? pageRepository,
    ImagePickerService? imagePickerService,
  })  : _pageRepository = pageRepository,
        _imagePickerService = imagePickerService;

  /// The parent story UUID.
  final String storyId;

  /// If non-null we are editing an existing page.
  final String? pageId;

  /// Alternate lookup key for an existing page, used instead of [pageId]
  /// by callers that only have (storyId, page number) — e.g. deep links.
  /// Never sent when creating a page: page_no is always assigned
  /// server-side.
  final int? pageNo;

  final PageRepository? _pageRepository;
  final ImagePickerService? _imagePickerService;

  bool get isNewPage => pageId == null && pageNo == null;

  @override
  State<EditPageScreen> createState() => _EditPageScreenState();
}

class _EditPageScreenState extends State<EditPageScreen> {
  // ─── Dependencies ───────────────────────────────────────
  late final PageRepository _repo =
      widget._pageRepository ?? PageRepository();
  late final ImagePickerService _imagePicker =
      widget._imagePickerService ?? ImagePickerService();

  // ─── Form ───────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _relatedIdCtrl = TextEditingController();

  // ─── State ──────────────────────────────────────────────
  PageModel? _existingPage;
  String? _thumbnailUrl;
  Uint8List? _thumbnailPreviewBytes;
  PageStatus _status = PageStatus.draft;
  final List<String> _relatedPages = [];

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isPublishing = false;
  bool _isDeleting = false;
  bool _isUploading = false;
  String? _errorMessage;

  // Snapshot for dirty checking
  String _initTitle = '';
  String _initContent = '';
  String? _initThumbnail;
  PageStatus _initStatus = PageStatus.draft;
  List<String> _initRelated = const [];

  // ─── UUID regex ─────────────────────────────────────────
  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  // ─── Theme helpers ─────────────────────────────────────
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _card => _isDark ? AppColors.cardDark : AppColors.cardLight;

  Color get _border => _isDark ? AppColors.borderDark : AppColors.borderLight;

  Color get _fg1 =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

  Color get _fg2 =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  bool get _busy => _isSaving || _isPublishing || _isDeleting;

  bool get _hasUnsavedChanges =>
      _titleCtrl.text.trim() != _initTitle ||
          _contentCtrl.text.trim() != _initContent ||
          _thumbnailUrl != _initThumbnail ||
          _status != _initStatus ||
          !listEquals(_relatedPages, _initRelated);

  // ─── Lifecycle ──────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (!widget.isNewPage) _loadPage();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _relatedIdCtrl.dispose();
    super.dispose();
  }

  // ─── Load existing page ─────────────────────────────────

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final PageModel page;
      if (widget.pageId != null) {
        page = await _repo.fetchPageById(widget.pageId!);
      } else if (widget.pageNo != null) {
        page = await _repo.fetchPage(widget.storyId, widget.pageNo!);
      } else {
        setState(() => _isLoading = false);
        return;
      }

      if (!mounted) return;

      _existingPage = page;
      _titleCtrl.text = page.title;
      _contentCtrl.text = page.content;
      _thumbnailUrl = page.thumbnail;
      _status = page.status;
      _relatedPages
        ..clear()
        ..addAll(page.relatedPages);

      _initTitle = page.title;
      _initContent = page.content;
      _initThumbnail = page.thumbnail;
      _initStatus = page.status;
      _initRelated = List.of(page.relatedPages);

      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load page: $e';
        _isLoading = false;
      });
    }
  }

  // ─── Image pick + upload ────────────────────────────────

  Future<void> _pickAndUploadImage() async {
    final picked = await _imagePicker.pickImage();
    if (picked == null) return;

    setState(() {
      _isUploading = true;
      _thumbnailPreviewBytes = picked.bytes;
      _errorMessage = null;
    });

    try {
      // Delete old thumbnail if exists
      if (_thumbnailUrl != null && _thumbnailUrl!.isNotEmpty) {
        try {
          await _repo.deleteThumbnail(_thumbnailUrl!);
        } catch (_) {
          // Best-effort delete; ignore errors
        }
      }

      final url = await _repo.uploadThumbnailBytes(
        picked.bytes,
        fileExtension: picked.extension,
      );

      if (!mounted) return;
      setState(() {
        _thumbnailUrl = url;
        _isUploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Upload failed: $e';
        _isUploading = false;
        _thumbnailPreviewBytes = null;
      });
    }
  }

  void _removeThumbnail() {
    setState(() {
      _thumbnailUrl = null;
      _thumbnailPreviewBytes = null;
    });
  }

  // ─── Status enum <-> API string ─────────────────────────

  String _statusToApi(PageStatus s) {
    switch (s) {
      case PageStatus.draft:
        return 'draft';
      case PageStatus.private_:
        return 'private';
      case PageStatus.public_:
        return 'public';
    }
  }

  // ─── Save (draft/private, via RPC) ─────────────────────

  Future<void> _saveDraft() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final apiStatus = _statusToApi(_status);

      if (widget.isNewPage) {
        await _repo.addPage(
          storyId: widget.storyId,
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          thumbnail: _thumbnailUrl,
          relatedPages: _relatedPages,
          status: apiStatus,
        );
      } else {
        final id = widget.pageId ?? _existingPage?.id;
        if (id == null) throw Exception('Missing page ID for update');
        await _repo.updatePage(
          pageId: id,
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          thumbnail: _thumbnailUrl,
          relatedPages: _relatedPages,
          status: apiStatus,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not save: $e';
        _isSaving = false;
      });
    }
  }

  // ─── Publish via edge function ─────────────────────────

  Future<void> _publish() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isPublishing = true;
      _errorMessage = null;
    });

    try {
      if (widget.isNewPage) {
        await _repo.publishPage(
          storyId: widget.storyId,
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          thumbnail: _thumbnailUrl,
          relatedPages: _relatedPages,
        );
      } else {
        final id = widget.pageId ?? _existingPage?.id;
        if (id == null) throw Exception('Missing page ID');

        await _repo.updateAndPublishPage(
          pageId: id,
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          thumbnail: _thumbnailUrl,
          relatedPages: _relatedPages,
        );
      }

      if (!mounted) return;
      setState(() => _status = PageStatus.public_);
      _showSnack('Page published!');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Publish failed: $e';
        _isPublishing = false;
      });
    }
  }

  // ─── Delete ─────────────────────────────────────────────

  Future<void> _deletePage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete page?'),
        content: const Text('This action cannot be undone.'),
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
      if (_thumbnailUrl != null && _thumbnailUrl!.isNotEmpty) {
        await _repo.deleteThumbnail(_thumbnailUrl!);
      }
      final id = widget.pageId ?? _existingPage?.id;
      if (id != null) {
        await _repo.deletePage(id);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Delete failed: $e';
        _isDeleting = false;
      });
    }
  }

  // ─── Back / discard ─────────────────────────────────────

  Future<void> _onBackPressed() async {
    if (!_hasUnsavedChanges) {
      Navigator.of(context).maybePop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).maybePop();
  }

  // ─── Related pages chip list ────────────────────────────

  void _addRelatedId() {
    final value = _relatedIdCtrl.text.trim();
    if (value.isEmpty) {
      _showSnack('Enter a page UUID first.');
      return;
    }
    if (!_uuidRegex.hasMatch(value)) {
      _showSnack('Invalid UUID format.');
      return;
    }
    if (_relatedPages.contains(value)) {
      _showSnack('Already added.');
      return;
    }
    setState(() {
      _relatedPages.add(value);
      _relatedIdCtrl.clear();
    });
  }

  void _removeRelatedId(String v) => setState(() => _relatedPages.remove(v));

  // ─── Helpers ────────────────────────────────────────────

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  InputDecoration _deco({
    required String label,
    String? hint,
    Widget? prefixIcon,
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: _card,
      labelStyle: TextStyle(color: _fg2),
      hintStyle: TextStyle(color: _fg2.withValues(alpha: 0.8)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
      bottomNavigationBar: _isLoading ? null : _buildBottomBar(),
    );
  }

  // ─── App bar ────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        onPressed: _busy || _isLoading ? null : _onBackPressed,
        icon: const Icon(Icons.close),
        tooltip: 'Close',
      ),
      title: Text(widget.isNewPage ? 'New page' : 'Edit page'),
      centerTitle: true,
      actions: [
        if (!widget.isNewPage)
          IconButton(
            onPressed: _busy || _isLoading ? null : _deletePage,
            tooltip: 'Delete',
            icon: _isDeleting
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.delete_outline, color: AppColors.error),
          ),
      ],
    );
  }

  // ─── Bottom action bar ──────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          // ── Save ──
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _saveDraft,
              icon: _isSaving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: _border),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ── Publish ──
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _busy ? null : _publish,
              icon: _isPublishing
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.publish),
              label: const Text('Publish'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Form body ──────────────────────────────────────────

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // error banner
          if (_errorMessage != null) ...[
            _buildErrorBanner(),
            const SizedBox(height: 16),
          ],

          // identifiers
          _buildMetaCard(),
          const SizedBox(height: 20),

          // thumbnail
          _buildSectionLabel('Thumbnail'),
          const SizedBox(height: 8),
          _buildThumbnailSection(),
          const SizedBox(height: 20),

          // status
          _buildSectionLabel(
            'Status',
            sub: 'Save keeps this status as-is; Publish always makes '
                'the page public.',
          ),
          const SizedBox(height: 8),
          _buildStatusChips(),
          const SizedBox(height: 20),

          // title
          _buildSectionLabel('Title'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleCtrl,
            style: TextStyle(color: _fg1),
            decoration: _deco(
              label: 'Page title',
              hint: 'Enter a short title',
              prefixIcon:
              const Icon(Icons.title_outlined, color: AppColors.primary),
            ),
            validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Title is required' : null,
          ),
          const SizedBox(height: 20),

          // content
          _buildSectionLabel('Content'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _contentCtrl,
            minLines: 10,
            maxLines: 20,
            style: TextStyle(color: _fg1),
            decoration: _deco(
              label: 'Story text',
              hint: 'Write the page content here…',
            ).copyWith(alignLabelWithHint: true),
            validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Content is required' : null,
          ),
          const SizedBox(height: 20),

          // related pages
          _buildRelatedPagesSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Sub-widgets ────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title, {String? sub}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: _fg1, fontSize: 16, fontWeight: FontWeight.w700)),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: _fg2, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildMetaCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Identifiers',
                style:
                TextStyle(color: _fg1, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          _metaRow('Story UUID', widget.storyId),
          if (_existingPage?.id != null) ...[
            const SizedBox(height: 8),
            _metaRow('Page UUID', _existingPage!.id!),
          ],
          if (_existingPage != null) ...[
            const SizedBox(height: 8),
            _metaRow('Page #', _existingPage!.pageNo.toString()),
          ],
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: _fg2, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(value,
              style: TextStyle(
                  color: _fg1, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Thumbnail ──────────────────────────────────────────

  Widget _buildThumbnailSection() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // preview area
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(14)),
              child: _buildThumbnailPreview(),
            ),
          ),

          // actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickAndUploadImage,
                    icon: _isUploading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                      CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.upload_outlined),
                    label: Text(
                      _thumbnailUrl != null ? 'Replace image' : 'Upload image',
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (_thumbnailUrl != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _removeThumbnail,
                    icon: const Icon(Icons.close, color: AppColors.error),
                    tooltip: 'Remove thumbnail',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailPreview() {
    // Show local bytes while uploading
    if (_thumbnailPreviewBytes != null && _isUploading) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(_thumbnailPreviewBytes!, fit: BoxFit.cover),
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: Colors.white),
          ),
        ],
      );
    }

    // Show uploaded image
    if (_thumbnailUrl != null && _thumbnailUrl!.isNotEmpty) {
      return Image.network(
        _thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _thumbnailPlaceholder(
          icon: Icons.image_not_supported_outlined,
          text: 'Could not load thumbnail',
        ),
      );
    }

    // Empty placeholder
    return _thumbnailPlaceholder(
      icon: Icons.image_outlined,
      text: 'No thumbnail selected',
    );
  }

  Widget _thumbnailPlaceholder({
    required IconData icon,
    required String text,
  }) {
    return Container(
      color: _isDark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.black.withValues(alpha: 0.03),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: _fg2),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: _fg2)),
        ],
      ),
    );
  }

  // ── Status chips ───────────────────────────────────────

  Widget _buildStatusChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PageStatus.values.map((s) {
        final selected = _status == s;
        return ChoiceChip(
          label: Text(
            s.label,
            style: TextStyle(
              color: selected ? Colors.white : _fg1,
              fontWeight: FontWeight.w600,
            ),
          ),
          selected: selected,
          selectedColor: _statusColor(s),
          backgroundColor: _card,
          side: BorderSide(color: selected ? _statusColor(s) : _border),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onSelected: (_) => setState(() => _status = s),
        );
      }).toList(),
    );
  }

  Color _statusColor(PageStatus s) {
    switch (s) {
      case PageStatus.draft:
        return Colors.orange;
      case PageStatus.private_:
        return Colors.blueGrey;
      case PageStatus.public_:
        return AppColors.primary;
    }
  }

  // ── Related pages ──────────────────────────────────────

  Widget _buildRelatedPagesSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Related pages',
              sub: 'Add page UUIDs that relate to this page.'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _relatedIdCtrl,
                  style: TextStyle(color: _fg1),
                  decoration: _deco(
                    label: 'Page UUID',
                    hint: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                    prefixIcon:
                    const Icon(Icons.link, color: AppColors.primary),
                  ),
                  onFieldSubmitted: (_) => _addRelatedId(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _addRelatedId,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_relatedPages.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.02),
                border: Border.all(color: _border),
              ),
              child: Text('No related pages added.',
                  style: TextStyle(color: _fg2)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _relatedPages.map((id) {
                return InputChip(
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(id, overflow: TextOverflow.ellipsis),
                  ),
                  onDeleted: () => _removeRelatedId(id),
                  deleteIconColor: AppColors.error,
                  backgroundColor:
                  AppColors.primary.withValues(alpha: 0.10),
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.30),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}