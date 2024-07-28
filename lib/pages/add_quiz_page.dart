import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import 'package:logger/logger.dart';
import '../widgets/subject_dropdown_with_add_button.dart';
import '../widgets/quiz_type_dropdown_with_add_button.dart';
import 'package:markdown/markdown.dart' as md;
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class AddQuizPage extends StatefulWidget {
  const AddQuizPage({super.key});

  @override
  State<AddQuizPage> createState() => _AddQuizPageState();
}

class _AddQuizPageState extends State<AddQuizPage> {
  final _formKey = GlobalKey<FormState>();
  late final Logger _logger;
  late final QuizService _quizService;
  File? _image;
  String? _imageUrl; // 이 부분을 다시 추가했습니다.

  String? _selectedSubjectId;
  String? _selectedTypeId;
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers =
      List.generate(5, (_) => TextEditingController());
  int _correctOptionIndex = 0;
  final TextEditingController _explanationController = TextEditingController();
  final List<TextEditingController> _keywordControllers = [
    TextEditingController()
  ];

  bool _isPreviewMode = false;

  @override
  void initState() {
    super.initState();
    _logger = Provider.of<Logger>(context, listen: false);
    _quizService = Provider.of<QuizService>(context, listen: false);
    _logger.i('AddQuizPage initialized');
    _requestPermissions();
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    _explanationController.dispose();
    for (var controller in _keywordControllers) {
      controller.dispose();
    }
    _logger.i('AddQuizPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _logger.i('Building AddQuizPage with Markdown support');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Quiz'),
        actions: [
          Switch(
            value: _isPreviewMode,
            onChanged: (value) {
              setState(() {
                _isPreviewMode = value;
              });
              _logger.i('Preview mode changed to: $_isPreviewMode');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SubjectDropdownWithAddButton(
                quizService: _quizService,
                logger: _logger,
                selectedSubjectId: _selectedSubjectId,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedSubjectId = newValue;
                    _selectedTypeId = null;
                  });
                  _logger.i('Selected subject changed to: $newValue');
                },
                onAddPressed: () => _showAddDialog(isSubject: true),
              ),
              ElevatedButton(
                onPressed: _pickImage,
                child: const Text('Pick Image'),
              ),
              if (_image != null)
                Image.file(_image!, height: 200)
              else if (_imageUrl != null)
                Image.network(_imageUrl!, height: 200),
              const SizedBox(height: 16),
              if (_selectedSubjectId != null)
                QuizTypeDropdownWithAddButton(
                  quizService: _quizService,
                  logger: _logger,
                  selectedSubjectId: _selectedSubjectId!,
                  selectedTypeId: _selectedTypeId,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedTypeId = newValue;
                    });
                    _logger.i('Selected quiz type changed to: $newValue');
                  },
                  onAddPressed: () => _showAddDialog(isSubject: false),
                ),
              const SizedBox(height: 16),
              _buildKeywordFields(),
              const SizedBox(height: 16),
              // 수정된 부분: Markdown 위젯 사용
              _buildMarkdownField(
                controller: _questionController,
                labelText: 'Question',
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a question' : null,
              ),
              const SizedBox(height: 16),
              ..._buildOptionFields(),
              const SizedBox(height: 16),
              // 수정된 부분: Markdown 위젯 사용
              _buildMarkdownField(
                controller: _explanationController,
                labelText: 'Explanation',
                validator: (value) =>
                    value!.isEmpty ? 'Please enter an explanation' : null,
              ),
              const SizedBox(height: 20),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    _logger.i('Picking image for quiz');

    // 권한 체크 추가
    PermissionStatus photoStatus = await Permission.photos.status;
    if (!photoStatus.isGranted) {
      _logger.w('Photo permission not granted');
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _logger.i('Image picked: ${pickedFile.path}');
    } else {
      _logger.w('No image selected');
    }
  }

  // Markdown 필드 빌드
  Widget _buildMarkdownField({
    required TextEditingController controller,
    required String labelText,
    required String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(labelText, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_isPreviewMode)
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Markdown(
              data: controller.text,
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
            controller: controller,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'Enter ${labelText.toLowerCase()}',
            ),
            maxLines: 10,
            validator: validator,
            onChanged: (value) {
              setState(() {});
              _logger.i('Text changed in $labelText field');
            },
          ),
      ],
    );
  }

  Future<void> _showAddDialog({required bool isSubject}) async {
    final TextEditingController controller = TextEditingController();
    final String itemType = isSubject ? 'Subject' : 'Quiz Type';

    _logger.i('Showing add $itemType dialog');

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Add $itemType'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter $itemType name'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                _logger.i('Add $itemType dialog cancelled');
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  if (isSubject) {
                    await _quizService.addSubject(controller.text);
                    _logger.i('New subject added: ${controller.text}');
                  } else {
                    if (_selectedSubjectId != null) {
                      await _quizService.addQuizTypeToSubject(
                          _selectedSubjectId!, controller.text);
                      _logger.i(
                          'New quiz type added: ${controller.text} to subject: $_selectedSubjectId');
                    } else {
                      _logger.w(
                          'Attempted to add quiz type without selecting subject');
                    }
                  }
                  if (!mounted) return;
                  Navigator.of(dialogContext).pop();
                  setState(() {}); // Refresh the dropdowns
                } else {
                  _logger.w('Attempted to add $itemType with empty name');
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestPermissions() async {
    _logger.i('Requesting permissions');
    Map<Permission, PermissionStatus> statuses = await [
      Permission.photos,
      Permission.camera,
    ].request();
    _logger.i('Permission statuses: $statuses');
  }

  Widget _buildKeywordFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Keywords (Optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._keywordControllers.map((controller) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Enter a keyword',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _removeKeywordField(controller),
                  ),
                ],
              ),
            )),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Keyword'),
          onPressed: _addKeywordField,
        ),
      ],
    );
  }

  void _removeKeywordField(TextEditingController controller) {
    setState(() {
      _keywordControllers.remove(controller);
      controller.dispose();
    });
    _logger.i('Removed keyword field');
  }

  void _addKeywordField() {
    setState(() {
      _keywordControllers.add(TextEditingController());
    });
    _logger.i('Added new keyword field');
  }

  List<Widget> _buildOptionFields() {
    _logger.i('Building option fields');
    return List.generate(5, (index) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: RadioListTile<int>(
          title: TextFormField(
            controller: _optionControllers[index],
            decoration: InputDecoration(
              labelText: 'Option ${index + 1}',
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                _logger.w('Option ${index + 1} is empty');
                return 'Please enter an option';
              }
              return null;
            },
          ),
          value: index,
          groupValue: _correctOptionIndex,
          onChanged: (int? value) {
            if (value != null && value != _correctOptionIndex) {
              setState(() {
                _correctOptionIndex = value;
              });
              _logger.i('Correct option changed to: ${value + 1}');
            }
          },
        ),
      );
    });
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submitQuiz,
      child: const Text('Add Quiz'),
    );
  }

  Future<void> _submitQuiz() async {
    _logger.i('Attempting to submit quiz with image');
    if (_formKey.currentState!.validate()) {
      try {
        String? imageUrl;
        if (_image != null) {
          imageUrl = await _uploadImage(_image!);
        }

        final newQuiz = Quiz(
          id: '',
          question: _questionController.text,
          options: _optionControllers.map((c) => c.text).toList(),
          correctOptionIndex: _correctOptionIndex,
          explanation: _explanationController.text,
          typeId: _selectedTypeId!,
          keywords: _keywordControllers
              .map((c) => c.text.trim())
              .where((keyword) => keyword.isNotEmpty)
              .toList(),
          imageUrl: imageUrl,
        );
        await _quizService.addQuiz(
            _selectedSubjectId!, _selectedTypeId!, newQuiz);
        _logger.i('New quiz added successfully with image: $imageUrl');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quiz added successfully')),
          );
          _resetForm();
        }
      } catch (e) {
        _logger.e('Error adding quiz with image: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to add quiz. Please try again.')),
          );
        }
      }
    } else {
      _logger.w('Form validation failed');
    }
  }

  Future<String> _uploadImage(File image) async {
    _logger.i('Uploading image to Firebase Storage');
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('quiz_images')
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
    final uploadTask = storageRef.putFile(image);
    final snapshot = await uploadTask.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();
    _logger.i('Image uploaded successfully: $downloadUrl');
    return downloadUrl;
  }

  void _resetForm() {
    _logger.i('Resetting form');
    _formKey.currentState!.reset();
    _questionController.clear();
    for (var controller in _optionControllers) {
      controller.clear();
    }
    _explanationController.clear();
    for (var controller in _keywordControllers) {
      controller.dispose();
    }
    _keywordControllers.clear();
    _keywordControllers.add(TextEditingController());
    setState(() {
      _selectedSubjectId = null;
      _selectedTypeId = null;
      _correctOptionIndex = 0;
      _image = null;
      _imageUrl = null;
    });
  }
}
