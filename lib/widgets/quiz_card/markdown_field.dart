import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../utils/image_utils.dart';
import 'markdown_widgets.dart';

class MarkdownField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? Function(String?)? validator;
  final bool isPreviewMode;
  final Logger logger;

  const MarkdownField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.validator,
    required this.isPreviewMode,
    required this.logger,
  });

  @override
  State<MarkdownField> createState() => _MarkdownFieldState();
}

class _MarkdownFieldState extends State<MarkdownField> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.labelText, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (widget.isPreviewMode)
          _buildMarkdownPreview()
        else
          _buildMarkdownEditor(),
      ],
    );
  }

  Widget _buildMarkdownPreview() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        child: MarkdownRenderer(
          data: widget.controller.text,
          logger: widget.logger,
        ),
      ),
    );
  }

  Widget _buildMarkdownEditor() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300), // 최대 높이 설정
      child: SingleChildScrollView(
        child: TextFormField(
          controller: widget.controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'Enter ${widget.labelText.toLowerCase()}',
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste),
              onPressed: _pasteImage,
            ),
          ),
          maxLines: null, // 무제한 줄 허용 text에서 스크롤이 되지 않음
          keyboardType: TextInputType.multiline, // 여러 줄 입력 가능하도록 설정
          validator: widget.validator,
          onChanged: (value) {
            widget.logger.i('Text changed in ${widget.labelText} field');
          },
        ),
      ),
    );
  }

  Future<void> _pasteImage() async {
    widget.logger.i('Attempting to paste image');
    try {
      final Uint8List? imageData = await ImageUtils.getClipboardImage();
      if (imageData != null) {
        String imageName =
            'pasted_image_${DateTime.now().millisecondsSinceEpoch}.png';
        String imageUrl = await _uploadImage(imageData, imageName);
        _insertImageMarkdown(imageUrl);
        widget.logger.i('Image pasted successfully');
      } else {
        widget.logger.w('No image data found in clipboard');
      }
    } catch (e) {
      widget.logger.e('Error pasting image: $e');
    }
  }

  Future<String> _uploadImage(Uint8List imageData, String imageName) async {
    widget.logger.i('Uploading image to Firebase Storage: $imageName');
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

      widget.logger.i('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      widget.logger.e('Error uploading image: $e');
      rethrow;
    }
  }

  void _insertImageMarkdown(String imageUrl) {
    final currentText = widget.controller.text;
    final cursorPosition = widget.controller.selection.base.offset;
    final markdownImage = '![image]($imageUrl)';
    final newText = currentText.substring(0, cursorPosition) +
        markdownImage +
        currentText.substring(cursorPosition);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
          offset: cursorPosition + markdownImage.length),
    );
  }
}
