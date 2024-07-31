import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import 'package:logger/logger.dart';
import '../widgets/subject_dropdown_with_add_button.dart';
import '../widgets/quiz_type_dropdown_with_add_button.dart';
import '../widgets/markdown_field.dart';
import '../widgets/keyword_fields.dart';
import '../widgets/option_fields.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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
              KeywordFields(
                controllers: _keywordControllers,
                logger: _logger,
              ),
              const SizedBox(height: 16),
              MarkdownField(
                controller: _questionController,
                labelText: 'Question',
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a question' : null,
                isPreviewMode: _isPreviewMode,
                logger: _logger,
              ),
              const SizedBox(height: 16),
              if (_image == null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.image),
                  label: const Text('Pick Image'),
                  onPressed: _pickImage,
                )
              else
                Column(
                  children: [
                    Image.file(_image!),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Change Image'),
                      onPressed: _pickImage,
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              OptionFields(
                controllers: _optionControllers,
                correctOptionIndex: _correctOptionIndex,
                onOptionChanged: (value) {
                  setState(() {
                    _correctOptionIndex = value!;
                  });
                },
                logger: _logger,
              ),
              const SizedBox(height: 16),
              MarkdownField(
                controller: _explanationController,
                labelText: 'Explanation',
                validator: (value) =>
                    value!.isEmpty ? 'Please enter an explanation' : null,
                isPreviewMode: _isPreviewMode,
                logger: _logger,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitQuiz,
                child: const Text('Add Quiz'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    _logger.i('Attempting to pick image for quiz');

    try {
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
    } catch (e) {
      _logger.e('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to pick image. Please try again.')),
        );
      }
    }
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
    });
    _logger.i('Form reset completed');
  }
}
