// add_quiz_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import 'package:logger/logger.dart';
import '../widgets/subject_dropdown_with_add_button.dart';
import '../widgets/quiz_type_dropdown_with_add_button.dart';

class AddQuizPage extends StatefulWidget {
  const AddQuizPage({Key? key}) : super(key: key);

  @override
  _AddQuizPageState createState() => _AddQuizPageState();
}

class _AddQuizPageState extends State<AddQuizPage> {
  final _formKey = GlobalKey<FormState>();
  late final Logger _logger;
  late final QuizService _quizService;

  String? _selectedSubjectId;
  String? _selectedTypeId;
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers =
      List.generate(5, (_) => TextEditingController());
  int _correctOptionIndex = 0;
  final TextEditingController _explanationController = TextEditingController();

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
    _logger.i('AddQuizPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _logger.i('Building AddQuizPage');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Quiz'),
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
              _buildQuestionField(),
              const SizedBox(height: 16),
              ..._buildOptionFields(),
              const SizedBox(height: 16),
              _buildExplanationField(),
              const SizedBox(height: 20),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddDialog({required bool isSubject}) async {
    final TextEditingController controller = TextEditingController();
    final String itemType = isSubject ? 'Subject' : 'Quiz Type';

    _logger.i('Showing add $itemType dialog');

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
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
                Navigator.of(context).pop();
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
                  Navigator.of(context).pop();
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

  Widget _buildQuestionField() {
    return TextFormField(
      controller: _questionController,
      decoration: const InputDecoration(
        labelText: 'Question',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
      validator: (value) => value!.isEmpty ? 'Please enter a question' : null,
    );
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

  Widget _buildExplanationField() {
    return TextFormField(
      controller: _explanationController,
      decoration: const InputDecoration(
        labelText: 'Explanation',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
      validator: (value) =>
          value!.isEmpty ? 'Please enter an explanation' : null,
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submitQuiz,
      child: const Text('Add Quiz'),
    );
  }

  Future<void> _submitQuiz() async {
    _logger.i('Attempting to submit quiz');
    if (_formKey.currentState!.validate()) {
      try {
        final newQuiz = Quiz(
          id: '',
          question: _questionController.text,
          options: _optionControllers.map((c) => c.text).toList(),
          correctOptionIndex: _correctOptionIndex,
          explanation: _explanationController.text,
          typeId: _selectedTypeId!,
        );
        await _quizService.addQuiz(newQuiz);
        _logger.i('New quiz added successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz added successfully')),
        );
        _resetForm();
      } catch (e) {
        _logger.e('Error adding quiz: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to add quiz. Please try again.')),
        );
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
    setState(() {
      _selectedSubjectId = null;
      _selectedTypeId = null;
      _correctOptionIndex = 0;
    });
  }
}
