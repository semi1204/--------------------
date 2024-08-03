// add_quiz_page.dart
import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/widgets/add_quiz/add_dialog.dart';
import 'package:nursing_quiz_app_6/widgets/add_quiz/image_picker.dart';
import 'package:nursing_quiz_app_6/widgets/add_quiz/image_upload.dart';
import 'package:nursing_quiz_app_6/widgets/add_quiz/quiz_type_dropdown_with_add_button.dart';
import 'package:nursing_quiz_app_6/widgets/add_quiz/subject_dropdown_with_add_button.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/keyword_fields.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/markdown_field.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import 'package:logger/logger.dart';
import '../widgets/quiz_card/option_fields.dart';

class AddQuizPage extends StatefulWidget {
  const AddQuizPage({super.key});

  @override
  State<AddQuizPage> createState() => _AddQuizPageState();
}

class _AddQuizPageState extends State<AddQuizPage> {
  final _formKey = GlobalKey<FormState>();
  late final Logger _logger;
  late final QuizService _quizService;
  String? _imageFile;

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
              ImagePickerWidget(
                imageFile: _imageFile,
                onImagePicked: (file) {
                  setState(() {
                    _imageFile = file;
                  });
                },
                logger: _logger,
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

  Future<void> _showAddDialog({required bool isSubject}) async {
    final String itemType = isSubject ? 'Subject' : 'Quiz Type';
    _logger.i('Showing add $itemType dialog');

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AddDialog(itemType: itemType),
    );

    if (result != null && result.isNotEmpty) {
      if (isSubject) {
        await _quizService.addSubject(result);
        _logger.i('New subject added: $result');
      } else if (_selectedSubjectId != null) {
        await _quizService.addQuizTypeToSubject(_selectedSubjectId!, result);
        _logger
            .i('New quiz type added: $result to subject: $_selectedSubjectId');
      } else {
        _logger.w('Attempted to add quiz type without selecting subject');
      }
      setState(() {}); // Refresh the dropdowns
    } else {
      _logger.w('Attempted to add $itemType with empty name');
    }
  }

  Future<void> _submitQuiz() async {
    _logger.i('Attempting to submit quiz with image');
    if (_formKey.currentState!.validate()) {
      try {
        String? imageUrl;
        if (_imageFile != null) {
          imageUrl = await uploadImage(_imageFile!);
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
      _imageFile = null;
    });
    _logger.i('Form reset completed');
  }
}
