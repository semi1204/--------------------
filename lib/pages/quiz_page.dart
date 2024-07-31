import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import 'package:logger/logger.dart';
import 'edit_quiz_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class QuizPage extends StatefulWidget {
  final String subjectId;
  final String quizTypeId;

  const QuizPage({
    super.key,
    required this.subjectId,
    required this.quizTypeId,
  });

  @override
  _QuizPageState createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late final QuizService _quizService;
  late final UserProvider _userProvider;
  late final Logger _logger;
  List<Quiz> _quizzes = [];
  int _currentPage = 0;
  static const int _quizzesPerPage = 10;
  Map<String, int?> _userAnswers = {};

  @override
  void initState() {
    super.initState();
    _quizService = Provider.of<QuizService>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _logger = Provider.of<Logger>(context, listen: false);
    _loadQuizzes();
    _loadUserAnswers();
  }

  Future<void> _loadQuizzes() async {
    _logger.i(
        'Loading quizzes for subject: ${widget.subjectId}, quizType: ${widget.quizTypeId}');
    final quizzes = await _quizService
        .getQuizzes(widget.subjectId, widget.quizTypeId)
        .first;
    setState(() {
      _quizzes = quizzes;
    });
  }

  Future<void> _loadUserAnswers() async {
    if (_userProvider.user != null) {
      final prefs = await SharedPreferences.getInstance();
      final userAnswersJson =
          prefs.getString('user_answers_${_userProvider.user!.uid}');
      if (userAnswersJson != null) {
        final userAnswers = json.decode(userAnswersJson);
        setState(() {
          _userAnswers = Map<String, int?>.from(userAnswers);
        });
      }
    }
  }

  Future<void> _saveUserAnswer(String quizId, int answerIndex) async {
    _logger.i('Saving user answer for quiz: $quizId, answer: $answerIndex');
    setState(() {
      _userAnswers[quizId] = answerIndex;
    });
    if (_userProvider.user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'user_answers_${_userProvider.user!.uid}', json.encode(_userAnswers));
    }
  }

  Future<void> _resetUserAnswers() async {
    _logger.i('Resetting all user answers');
    setState(() {
      _userAnswers.clear();
    });
    if (_userProvider.user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_answers_${_userProvider.user!.uid}');
    }
  }

  Future<void> _resetQuiz(String quizId) async {
    _logger.i('Resetting quiz: $quizId');
    setState(() {
      _userAnswers.remove(quizId);
    });
    if (_userProvider.user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'user_answers_${_userProvider.user!.uid}', json.encode(_userAnswers));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetUserAnswers,
          ),
        ],
      ),
      body: _quizzes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _getPageItemCount(),
              itemBuilder: (context, index) {
                final quizIndex = _currentPage * _quizzesPerPage + index;
                final quiz = _quizzes[quizIndex];
                return QuizCard(
                  key: ValueKey(quiz.id),
                  quiz: quiz,
                  questionNumber: quizIndex + 1,
                  isAdmin: _userProvider.isAdmin,
                  onEdit: () => _editQuiz(quiz),
                  onDelete: () => _deleteQuiz(quiz),
                  selectedOptionIndex: _userAnswers[quiz.id],
                  onAnswerSelected: (answerIndex) =>
                      _saveUserAnswer(quiz.id, answerIndex),
                  onResetQuiz: () => _resetQuiz(quiz.id),
                );
              },
            ),
      bottomNavigationBar: _buildPaginationControls(),
    );
  }

  Widget _buildPaginationControls() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _currentPage > 0 ? _previousPage : null,
          ),
          Text(
              '${_currentPage + 1} / ${(_quizzes.length / _quizzesPerPage).ceil()}'),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _hasNextPage() ? _nextPage : null,
          ),
        ],
      ),
    );
  }

  int _getPageItemCount() {
    final remainingItems = _quizzes.length - (_currentPage * _quizzesPerPage);
    return remainingItems < _quizzesPerPage ? remainingItems : _quizzesPerPage;
  }

  bool _hasNextPage() {
    return (_currentPage + 1) * _quizzesPerPage < _quizzes.length;
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _logger.i('Navigated to previous page: $_currentPage');
    }
  }

  void _nextPage() {
    if (_hasNextPage()) {
      setState(() {
        _currentPage++;
      });
      _logger.i('Navigated to next page: $_currentPage');
    }
  }

  void _editQuiz(Quiz quiz) {
    _logger.i('Editing quiz: ${quiz.id}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditQuizPage(
          quiz: quiz,
          subjectId: widget.subjectId,
          quizTypeId: widget.quizTypeId,
        ),
      ),
    );
  }

  void _deleteQuiz(Quiz quiz) {
    _logger.i('Deleting quiz: ${quiz.id}');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Quiz'),
          content: const Text('Are you sure you want to delete this quiz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                _quizService.deleteQuiz(
                    widget.subjectId, widget.quizTypeId, quiz.id);
                setState(() {
                  _quizzes.removeWhere((q) => q.id == quiz.id);
                });
                Navigator.of(context).pop();
                _logger.i('Quiz deleted: ${quiz.id}');
              },
            ),
          ],
        );
      },
    );
  }
}
