// lib/utils/image_utils.dart

import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class ImageUtils {
  static const platform =
      MethodChannel('com.example.nursing_quiz_app_6/clipboard');

  static Future<Uint8List?> getClipboardImage() async {
    logger.d('Attempting to get clipboard image');
    try {
      final Uint8List? imageData =
          await platform.invokeMethod('getClipboardImage');
      if (imageData != null) {
        logger.i('Clipboard image retrieved successfully');
      } else {
        logger.w('No image data found in clipboard');
      }
      return imageData;
    } on PlatformException catch (e) {
      logger.e('Platform error: ${e.message}');
      return null;
    }
  }

  static Future<String> uploadImage(
      Uint8List imageData, String imageName) async {
    logger.i('Uploading image to Firebase Storage: $imageName');
    try {
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.ref().child('images/$imageName');

      final metadata = SettableMetadata(
        contentType: 'image/png',
        customMetadata: {'picked-file-path': imageName},
      );

      UploadTask uploadTask = ref.putData(imageData, metadata);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      logger.i('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      logger.e('Error uploading image: $e');
      rethrow;
    }
  }
}
