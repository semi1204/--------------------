import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import 'package:logger/logger.dart';
import '../widgets/quiz_card/markdown_field.dart';
import '../widgets/quiz_card/keyword_fields.dart';
import '../widgets/quiz_card/option_fields.dart';

class EditQuizPage extends StatefulWidget {
  final Quiz quiz;
  final String subjectId;
  final String quizTypeId;

  const EditQuizPage({
    Key? key,
    required this.quiz,
    required this.subjectId,
    required this.quizTypeId,
  }) : super(key: key);

  @override
  _EditQuizPageState createState() => _EditQuizPageState();
}

class _EditQuizPageState extends State<EditQuizPage> {
  final _formKey = GlobalKey<FormState>();
  late final Logger _logger;
  late final QuizService _quizService;

  late final TextEditingController _questionController;
  late final List<TextEditingController> _optionControllers;
  late int _correctOptionIndex;
  late final TextEditingController _explanationController;
  late final List<TextEditingController> _keywordControllers;

  bool _isPreviewMode = false;

  @override
  void initState() {
    super.initState();
    _logger = Provider.of<Logger>(context, listen: false);
    _quizService = Provider.of<QuizService>(context, listen: false);
    _logger.i('EditQuizPage initialized');

    _questionController = TextEditingController(text: widget.quiz.question);
    _optionControllers = widget.quiz.options
        .map((option) => TextEditingController(text: option))
        .toList();
    _correctOptionIndex = widget.quiz.correctOptionIndex;
    _explanationController =
        TextEditingController(text: widget.quiz.explanation);
    _keywordControllers = widget.quiz.keywords
        .map((keyword) => TextEditingController(text: keyword))
        .toList();
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
    _logger.i('EditQuizPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Quiz'),
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
                onPressed: _updateQuiz,
                child: const Text('Update Quiz'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateQuiz() async {
    _logger.i('Attempting to update quiz');
    if (_formKey.currentState!.validate()) {
      try {
        final updatedQuiz = Quiz(
          id: widget.quiz.id,
          question: _questionController.text,
          options: _optionControllers.map((c) => c.text).toList(),
          correctOptionIndex: _correctOptionIndex,
          explanation: _explanationController.text,
          typeId: widget.quiz.typeId,
          keywords: _keywordControllers
              .map((c) => c.text.trim())
              .where((keyword) => keyword.isNotEmpty)
              .toList(),
          imageUrl: widget.quiz.imageUrl,
        );
        await _quizService.updateQuiz(
            widget.subjectId, widget.quizTypeId, updatedQuiz);
        _logger.i('Quiz updated successfully');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quiz updated successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        _logger.e('Error updating quiz: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to update quiz. Please try again.')),
          );
        }
      }
    } else {
      _logger.w('Form validation failed');
    }
  }
}
