import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class StorageService {
  final ImagePicker _picker = ImagePicker();

  /// Picks an image from gallery or camera.
  ///
  /// On Android 13+ the system photo picker is used and needs no permission,
  /// but on Android 12 and below (and on some OEM skins) the gallery read
  /// requires READ_EXTERNAL_STORAGE. Requesting it here keeps image upload from
  /// silently no-oping on those devices.
  Future<File?> pickImage(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final status = await Permission.photos.request();
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return null;
      }
      if (!status.isGranted && !status.isLimited) {
        // Fall through: the photo picker may still work without the legacy
        // permission on Android 13+, so don't hard-fail.
      }
    }

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
