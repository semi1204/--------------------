// incorrect_answer_page.dart

import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/models/subject.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_card.dart';
import 'package:logger/logger.dart';

class IncorrectAnswersPage extends StatefulWidget {
  const IncorrectAnswersPage({Key? key}) : super(key: key);

  @override
  _IncorrectAnswersPageState createState() => _IncorrectAnswersPageState();
}

class _IncorrectAnswersPageState extends State<IncorrectAnswersPage> {
  late final QuizService _quizService;
  late final UserProvider _userProvider;
  late final Logger _logger;
  String? _selectedSubjectId;
  int _currentQuizIndex = 0;

  @override
  void initState() {
    super.initState();
    _quizService = Provider.of<QuizService>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _logger = Provider.of<Logger>(context, listen: false);
    _logger.i('IncorrectAnswersPage initialized');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incorrect Answers'),
      ),
      body: Column(
        children: [
          _buildSubjectDropdown(),
          Expanded(
            child: _selectedSubjectId == null
                ? const Center(child: Text('Please select a subject'))
                : _buildQuizContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectDropdown() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: StreamBuilder<List<Subject>>(
        stream: _quizService.getSubjects(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Text('No subjects available');
          }
          return DropdownButton<String>(
            value: _selectedSubjectId,
            hint: const Text('Select a subject'),
            onChanged: (String? newValue) {
              setState(() {
                _selectedSubjectId = newValue;
                _currentQuizIndex = 0; // Reset quiz index when subject changes
              });
              _logger.i('Selected subject: $newValue');
            },
            items:
                snapshot.data!.map<DropdownMenuItem<String>>((Subject subject) {
              return DropdownMenuItem<String>(
                value: subject.id,
                child: Text(subject.name),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildQuizContent() {
    return StreamBuilder<List<Quiz>>(
      stream: _userProvider.user != null
          ? _quizService.getIncorrectQuizzes(
              _userProvider.user!.uid, _selectedSubjectId!)
          : Stream.value([]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No incorrect quizzes available'));
        }
        _logger.i('Incorrect quizzes loaded. Count: ${snapshot.data!.length}');

        return Column(
          children: [
            Expanded(
              child: QuizCard(quiz: snapshot.data![_currentQuizIndex]),
            ),
            _buildNavigationButtons(snapshot.data!.length),
          ],
        );
      },
    );
  }

  Widget _buildNavigationButtons(int quizCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: _currentQuizIndex > 0
              ? () => setState(() => _currentQuizIndex--)
              : null,
          child: const Text('Previous'),
        ),
        Text('${_currentQuizIndex + 1} / $quizCount'),
        ElevatedButton(
          onPressed: _currentQuizIndex < quizCount - 1
              ? () => setState(() => _currentQuizIndex++)
              : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}
