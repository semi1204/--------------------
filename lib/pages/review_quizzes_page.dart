import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_card.dart';
import 'package:logger/logger.dart';
import '../models/subject.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:math' show min;

class ReviewQuizzesPage extends StatefulWidget {
  const ReviewQuizzesPage({super.key});

  @override
  State<ReviewQuizzesPage> createState() => _ReviewQuizzesPageState();
}

class _ReviewQuizzesPageState extends State<ReviewQuizzesPage> {
  late final QuizService _quizService;
  late final UserProvider _userProvider;
  late final Logger _logger;
  String? _selectedSubjectId;
  List<Quiz> _quizzesForReview = [];
  bool _isOffline = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedQuizTypeId;
  @override
  void initState() {
    super.initState();
    _quizService = Provider.of<QuizService>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _logger = Provider.of<Logger>(context, listen: false);
    _logger.i('ReviewQuizzesPage initialized');
  }

  Future<void> _loadQuizzesForReview() async {
    if (_selectedSubjectId == null || _selectedQuizTypeId == null) {
      _logger.w(
          'Subject or quiz type not selected, cannot load quizzes for review');
      return;
    }

    _logger.i('Loading quizzes for review: subject: $_selectedSubjectId');
    setState(() => _isLoading = true);

    try {
      final quizzesForReview = await _quizService.getQuizzesForReview(
        _userProvider.user!.uid,
        _selectedSubjectId!,
        _selectedQuizTypeId!,
      );

      if (mounted) {
        setState(() {
          _quizzesForReview = quizzesForReview;
          _isLoading = false;
        });
      }

      _logger.i('Loaded ${_quizzesForReview.length} quizzes for review');
    } catch (e) {
      _logger.e('Error loading quizzes for review: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSubjectDropdown(),
        Expanded(
          child: _selectedSubjectId == null
              ? const Center(child: Text('Please select a subject'))
              : RefreshIndicator(
                  onRefresh: _refreshQuizzes,
                  child: _buildQuizList(),
                ),
        ),
      ],
    );
  }

  Future<void> _refreshQuizzes() async {
    _logger.i('Manually refreshing quiz list');
    await _loadQuizzesForReview();
  }

  Widget _buildSubjectDropdown() {
    return FutureBuilder<List<Subject>>(
      future: _quizService.getSubjects(),
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
            _logger.i('Subject selected: $newValue');
            setState(() {
              _selectedSubjectId = newValue;
              _quizzesForReview = [];
            });
            _loadQuizzesForReview();
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
    );
  }

  Widget _buildQuizList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_quizzesForReview.isEmpty) {
      return const Center(child: Text('No quizzes for review available'));
    }
    return ListView.builder(
      itemCount: _quizzesForReview.length,
      itemBuilder: (context, index) {
        final quiz = _quizzesForReview[index];
        return QuizCard(
          key: ValueKey(quiz.id),
          quiz: quiz,
          questionNumber: index + 1,
          isIncorrectAnswersMode: false,
          onAnswerSelected: (answerIndex) {
            _logger.i(
                'Answer selected for quiz: ${quiz.id}, answer: $answerIndex');
            setState(() {}); // Refresh UI when answer is selected
          },
          onDeleteReview: () => _deleteReview(quiz),
          subjectId: _selectedSubjectId!,
          quizTypeId: quiz.typeId,
        );
      },
    );
  }

  Future<void> _deleteReview(Quiz quiz) async {
    _logger.i('Deleting review for quiz: ${quiz.id}');
    try {
      await _userProvider.deleteUserQuizData(
        _userProvider.user!.uid,
        _selectedSubjectId!,
        quiz.typeId,
        quiz.id,
      );
      setState(() {
        _quizzesForReview.removeWhere((q) => q.id == quiz.id);
      });
      _logger.i('Review deleted successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review deleted successfully')),
        );
      }
    } catch (e) {
      _logger.e('Error deleting review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to delete review. Please try again.')),
        );
      }
    }
  }
}
