// utils/image_upload.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

Future<String> uploadImage(String imagePath) async {
  final File image = File(imagePath);
  final storageRef = FirebaseStorage.instance
      .ref()
      .child('quiz_images')
      .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
  final uploadTask = storageRef.putFile(image);
  final snapshot = await uploadTask.whenComplete(() {});
  return await snapshot.ref.getDownloadURL();
}
