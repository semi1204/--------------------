// widgets/image_picker_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';

class ImagePickerWidget extends StatelessWidget {
  final String? imageFile;
  final Function(String) onImagePicked;
  final Logger logger;

  const ImagePickerWidget({
    super.key,
    required this.imageFile,
    required this.onImagePicked,
    required this.logger,
  });

  Future<void> _pickImage() async {
    logger.i('Attempting to pick image for quiz');

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        onImagePicked(pickedFile.path);
        logger.i('Image picked: ${pickedFile.path}');
      } else {
        logger.w('No image selected');
      }
    } catch (e) {
      logger.e('Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return imageFile == null
        ? ElevatedButton.icon(
            icon: const Icon(Icons.image),
            label: const Text('Pick Image'),
            onPressed: _pickImage,
          )
        : Column(
            children: [
              Image.file(File(imageFile!)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Change Image'),
                onPressed: _pickImage,
              ),
            ],
          );
  }
}
