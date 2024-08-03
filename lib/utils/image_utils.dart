import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';

class ImageUtils {
  static const platform =
      MethodChannel('com.example.nursing_quiz_app_6/clipboard');
  static final Logger logger = Logger();

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
      Reference ref = storage.ref().child('quiz_images/$imageName');

      final metadata = SettableMetadata(
        contentType: 'image/png',
        customMetadata: {'picked-file-path': imageName},
      );

      UploadTask uploadTask = ref.putData(imageData, metadata);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      logger.i('Image uploaded successfully. Download URL: $downloadUrl');
      return 'quiz_images/$imageName';
    } catch (e) {
      logger.e('Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }
}
