import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:logger/logger.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MarkdownField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? Function(String?)? validator;
  final bool isPreviewMode;
  final Logger logger;

  const MarkdownField({
    super.key, // 수정: super.key 사용
    required this.controller,
    required this.labelText,
    required this.validator,
    required this.isPreviewMode,
    required this.logger,
  });

  @override
  State<MarkdownField> createState() =>
      _MarkdownFieldState(); // 수정: State<MarkdownField> 사용
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
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Markdown(
              data: widget.controller.text,
              selectable: true,
              extensionSet: md.ExtensionSet([
                md.TableSyntax(),
              ], md.ExtensionSet.gitHubFlavored.inlineSyntaxes),
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 16),
                tableBody: const TextStyle(fontSize: 14),
                tableBorder: TableBorder.all(color: Colors.grey),
                tableColumnWidth: const FixedColumnWidth(120),
                tableCellsPadding: const EdgeInsets.all(4),
              ),
            ),
          )
        else
          TextFormField(
            controller: widget.controller,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'Enter ${widget.labelText.toLowerCase()}',
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste),
                onPressed: _pasteImage,
              ),
            ),
            maxLines: 10,
            validator: widget.validator,
            onChanged: (value) {
              widget.logger.i('Text changed in ${widget.labelText} field');
            },
          ),
      ],
    );
  }

  Future<void> _pasteImage() async {
    widget.logger.i('Attempting to paste image');
    try {
      ClipboardData? data = await Clipboard.getData(
          Clipboard.kTextPlain); // 수정: Clipboard.kTextPlain 사용
      if (data != null && data.text != null) {
        // 수정: data.text 사용
        String imageName =
            'pasted_image_${DateTime.now().millisecondsSinceEpoch}.png';
        String imageUrl =
            await _uploadImage(data.text!, imageName); // 수정: data.text! 사용
        _insertImageMarkdown(imageUrl);
        widget.logger.i('Image pasted successfully');
      } else {
        widget.logger.w('No image data found in clipboard');
      }
    } catch (e) {
      widget.logger.e('Error pasting image: $e');
    }
  }

  Future<String> _uploadImage(String imageData, String imageName) async {
    widget.logger.i('Uploading image to Firebase Storage: $imageName');
    try {
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.ref().child('images/$imageName');
      UploadTask uploadTask = ref.putString(imageData,
          format: PutStringFormat.dataUrl); // 수정: putString 메서드 사용
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
