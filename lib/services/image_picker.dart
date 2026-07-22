import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class PickedImageData {
  final Uint8List bytes;
  final String extension;

  PickedImageData({
    required this.bytes,
    required this.extension,
  });
}

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  Future<PickedImageData?> pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (file == null) return null;
      
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last.toLowerCase();
      
      return PickedImageData(
        bytes: bytes,
        extension: ext.isEmpty ? 'jpg' : ext,
      );
    } catch (e) {
      return null;
    }
  }
}
