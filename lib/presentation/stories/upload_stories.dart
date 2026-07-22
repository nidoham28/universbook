import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../repositories/story_repository.dart'; // ← was stories_service.dart
import '../routes/app_routes.dart';

/// Screen for creating/uploading a new story.
///
/// Layout:
/// - Topbar: "Create Stories" title + a trailing check ("Done") icon that
///   validates and submits, and a leading close ("Remove") icon that pops
///   the screen.
/// - Thumbnail: tappable preview box. Tapping it opens the image picker
///   (gallery or camera); the resulting image is uploaded to Storage on
///   submit and its public URL is used as the thumbnail.
/// - Title: text input for the story title.
/// - Category: single-select chips (Horror, Romantic, Comedy, ...).
/// - Free / Paid: a switch; when Paid is on, a cost input appears.
///
/// On submit, the picked image is uploaded to Supabase Storage first, then
/// the story is created via the `create-story` Edge Function, which writes
/// the row into the `stories` table server-side.
class UploadStories extends StatefulWidget {
  const UploadStories({
    super.key,
    this.onSubmit,
    StoryRepository? storyRepository, // ← was StoriesService? storiesService
  }) : _storyRepository = storyRepository;

  /// Called with the story record returned by the server when submission
  /// succeeds.
  final void Function(Map<String, dynamic> storyData)? onSubmit;

  final StoryRepository? _storyRepository; // ← was StoriesService?

  @override
  State<UploadStories> createState() => _UploadStoriesState();
}

class _UploadStoriesState extends State<UploadStories> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _costController = TextEditingController();
  final _picker = ImagePicker();

  // ↓ was: widget._storiesService ?? StoriesService()
  late final StoryRepository _storyRepository =
      widget._storyRepository ?? StoryRepository();

  static const List<String> _categories = <String>[
    'Horror',
    'Romantic',
    'Comedy',
    'Drama',
    'Thriller',
    'Fantasy',
    'Mystery',
    'Adventure',
  ];

  String? _selectedCategory;
  bool _isPaid = false;
  bool _isSubmitting = false;

  Uint8List? _pickedImageBytes;
  String? _pickedImageExt;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardColor => _isDark ? AppColors.cardDark : AppColors.cardLight;
  Color get _borderColor =>
      _isDark ? AppColors.borderDark : AppColors.borderLight;
  Color get _textPrimary =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get _textSecondary =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  @override
  void dispose() {
    _titleController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (xfile == null) return; // user cancelled the picker — not an error

      final bytes = await xfile.readAsBytes();
      if (bytes.isEmpty) {
        _showError('That image appears to be empty. Please pick another.');
        return;
      }
      final ext = _extensionFromPath(xfile.path, xfile.mimeType);

      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageExt = ext;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      debugPrint('image_picker PlatformException: ${e.code} ${e.message}');
      _showError(_messageForPlatformException(e));
    } catch (e) {
      if (!mounted) return;
      debugPrint('image_picker error: $e');
      // Surface the real error instead of a generic message — this is
      // almost always missing platform permission entries (see the
      // AndroidManifest.xml / Info.plist notes shipped with this screen),
      // a file that isn't actually an image, or a web/CORS restriction.
      _showError('Could not load that image: $e');
    }
  }

  String _messageForPlatformException(PlatformException e) {
    switch (e.code) {
      case 'photo_access_denied':
      case 'camera_access_denied':
        return 'Permission denied. Enable photo/camera access for this '
            'app in Settings and try again.';
      case 'invalid_image':
        return 'That file could not be read as an image.';
      case 'no_available_camera':
        return 'No camera is available on this device.';
      default:
        return 'Could not load that image (${e.code}). Please try again.';
    }
  }

  String _extensionFromPath(String path, String? mimeType) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < path.length - 1) {
      return path.substring(dotIndex + 1).toLowerCase();
    }
    if (mimeType != null && mimeType.contains('/')) {
      return mimeType.split('/').last;
    }
    return 'jpg';
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary),
                title: Text('Choose from gallery',
                    style: TextStyle(color: _textPrimary)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: AppColors.primary),
                title:
                Text('Take a photo', style: TextStyle(color: _textPrimary)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_pickedImageBytes != null)
                ListTile(
                  leading:
                  const Icon(Icons.delete_outline, color: AppColors.error),
                  title: const Text('Remove image',
                      style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    setState(() {
                      _pickedImageBytes = null;
                      _pickedImageExt = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.error,
        content: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Future<void> _onDonePressed() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (_selectedCategory == null) {
      _showError('Please select a category');
      return;
    }

    if (_pickedImageBytes == null) {
      _showError('Please add a thumbnail image');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // ↓ was: _storiesService.uploadThumbnail(...)
      final thumbnailUrl = await _storyRepository.uploadThumbnail(
        bytes: _pickedImageBytes!,
        fileExt: _pickedImageExt ?? 'jpg',
      );

      final cost =
      _isPaid ? double.tryParse(_costController.text.trim()) : null;

      // ↓ was: _storiesService.createStory(...)
      final story = await _storyRepository.createStory(
        title: _titleController.text.trim(),
        thumbnail: thumbnailUrl,
        category: _selectedCategory!,
        isPaid: _isPaid,
        cost: cost,
      );

      if (!mounted) return;
      widget.onSubmit?.call(story);

      final storyId = story['id']?.toString();
      if (storyId != null) {
        // Switch straight into the reader for the story just published.
        context.pushReplacement(AppRoutes.pageViewPath(storyId));
      } else {
        Navigator.of(context).maybePop(story);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to publish story: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _onRemovePressed() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Remove',
          onPressed: _isSubmitting ? null : _onRemovePressed,
        ),
        title: const Text('Create Stories'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isSubmitting
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
                : const Icon(Icons.check),
            tooltip: 'Done',
            onPressed: _isSubmitting ? null : _onDonePressed,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildThumbnailPreview(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              style: TextStyle(color: _textPrimary),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: _textSecondary),
                prefixIcon:
                const Icon(Icons.title, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Category',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _buildCategoryChips(),
            const SizedBox(height: 24),
            _buildFreePaidSwitch(),
            if (_isPaid) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _costController,
                style: TextStyle(color: _textPrimary),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Cost',
                  labelStyle: TextStyle(color: _textSecondary),
                  prefixIcon: const Icon(Icons.attach_money,
                      color: AppColors.accent),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    const BorderSide(color: AppColors.accent, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.error),
                  ),
                ),
                validator: (value) {
                  if (!_isPaid) return null;
                  if (value == null || value.trim().isEmpty) {
                    return 'Cost is required for paid stories';
                  }
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid cost';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailPreview() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _isSubmitting ? null : _showImageSourceSheet,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _cardColor,
                  border: Border.all(color: _borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: _pickedImageBytes != null
                    ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover)
                    : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 48, color: _textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add a thumbnail',
                        style: TextStyle(color: _textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isSubmitting ? null : _showImageSourceSheet,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.camera_alt_outlined,
                      size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((category) {
        final isSelected = _selectedCategory == category;
        return ChoiceChip(
          label: Text(
            category,
            style: TextStyle(
              color: isSelected ? Colors.white : _textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          selected: isSelected,
          selectedColor: AppColors.primary,
          backgroundColor: _cardColor,
          side:
          BorderSide(color: isSelected ? AppColors.primary : _borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onSelected: (selected) {
            setState(() {
              _selectedCategory = selected ? category : null;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildFreePaidSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _isPaid ? 'Paid' : 'Free',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: _isPaid ? AppColors.warning : AppColors.success,
            ),
          ),
          Switch(
            value: _isPaid,
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
            inactiveThumbColor: AppColors.success,
            inactiveTrackColor: AppColors.success.withValues(alpha: 0.3),
            onChanged: _isSubmitting
                ? null
                : (value) {
              setState(() {
                _isPaid = value;
                if (!value) _costController.clear();
              });
            },
          ),
        ],
      ),
    );
  }
}