import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:logger/logger.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 추가: 캐시된 이미지 로딩을 위해

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
  static const platform =
      MethodChannel('com.example.nursing_quiz_app_6/clipboard');
  final logger = Logger(); // 추가: 로거 인스턴스 생성

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
      child: Markdown(
        data: widget.controller.text,
        selectable: true,
        imageBuilder: (uri, title, alt) => _buildImageWidget(uri.toString()),
        extensionSet: md.ExtensionSet([
          const md.TableSyntax(),
        ], md.ExtensionSet.gitHubFlavored.inlineSyntaxes),
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(fontSize: 16),
          tableBody: const TextStyle(fontSize: 14),
          tableBorder: TableBorder.all(color: Colors.grey),
          tableColumnWidth: const FixedColumnWidth(120),
          tableCellsPadding: const EdgeInsets.all(4),
        ),
      ),
    );
  }

  Widget _buildMarkdownEditor() {
    return TextFormField(
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
    );
  }

  Future<void> _pasteImage() async {
    logger.i('Attempting to paste image');
    try {
      final Uint8List? imageData =
          await platform.invokeMethod('getClipboardImage');
      if (imageData != null) {
        String imageName =
            'pasted_image_${DateTime.now().millisecondsSinceEpoch}.png';
        String imageUrl = await _uploadImage(imageData, imageName);
        _insertImageMarkdown(imageUrl);
        logger.i('Image pasted successfully');
      } else {
        logger.w('No image data found in clipboard');
      }
    } on PlatformException catch (e) {
      logger.e('Platform error: ${e.message}');
    } catch (e) {
      logger.e('Error pasting image: $e');
    }
  }

  Future<String> _uploadImage(Uint8List imageData, String imageName) async {
    logger.i('Uploading image to Firebase Storage: $imageName');
    try {
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.ref().child('images/$imageName');

      // 수정: 메타데이터 추가
      final metadata = SettableMetadata(
        contentType: 'image/png',
        customMetadata: {'picked-file-path': imageName},
      );

      UploadTask uploadTask = ref.putData(imageData, metadata);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // 수정: URL 인코딩 제거 (Firebase는 이미 적절히 인코딩된 URL을 제공함)
      logger.i('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      logger.e('Error uploading image: $e');
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

  Widget _buildImageWidget(String src) {
    return CachedNetworkImage(
      imageUrl: src,
      placeholder: (context, url) => const CircularProgressIndicator(),
      errorWidget: (context, url, error) {
        logger.e('Error loading image: $error');
        return const Icon(Icons.error);
      },
    );
  }
}
