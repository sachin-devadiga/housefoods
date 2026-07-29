import 'dart:io';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final ImagePicker _picker = ImagePicker();

  /// Picks an image from gallery or camera
  Future<File?> pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1080,
    );
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }
}
