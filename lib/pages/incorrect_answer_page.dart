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

class IncorrectAnswersPage extends StatefulWidget {
  const IncorrectAnswersPage({super.key});

  @override
  State<IncorrectAnswersPage> createState() => _IncorrectAnswersPageState();
}

class _IncorrectAnswersPageState extends State<IncorrectAnswersPage> {
  late final QuizService _quizService;
  late final UserProvider _userProvider;
  late final Logger _logger;
  String? _selectedSubjectId;
  List<Quiz> _incorrectQuizzes = [];
  bool _isOffline = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _quizService = Provider.of<QuizService>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _logger = Provider.of<Logger>(context, listen: false);
    _logger.i('IncorrectAnswersPage initialized');
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    setState(() {
      _isOffline = connectivityResult == ConnectivityResult.none;
    });
    _logger.i('Connectivity status: ${_isOffline ? 'Offline' : 'Online'}');
  }

  Future<void> _loadIncorrectQuizzes() async {
    if (_selectedSubjectId == null) {
      _logger.w('No subject selected, cannot load incorrect quizzes');
      return;
    }

    _logger.i('Loading incorrect quizzes for subject: $_selectedSubjectId');
    setState(() => _isLoading = true);

    try {
      final quizzes = await _quizService.getIncorrectQuizzes(
        _userProvider.user!.uid,
        _selectedSubjectId!,
      );

      _logger.d('Received ${quizzes.length} incorrect quizzes from service');

      if (mounted) {
        setState(() {
          _incorrectQuizzes = quizzes;
          _isLoading = false;
        });
      }

      _logger.i('Loaded ${_incorrectQuizzes.length} incorrect quizzes');

      // Log details of each quiz for debugging
      _incorrectQuizzes.forEach((quiz) {
        _logger.d(
            'Quiz ID: ${quiz.id}, Question: ${quiz.question.substring(0, min(20, quiz.question.length))}...');
      });
    } catch (e) {
      _logger.e('Error loading incorrect quizzes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _incorrectQuizzes = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Cards'),
      ),
      body: Column(
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
      ),
    );
  }

  Future<void> _refreshQuizzes() async {
    _logger.i('Manually refreshing quiz list');
    await _loadIncorrectQuizzes();
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
              _incorrectQuizzes = [];
            });
            _loadIncorrectQuizzes();
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
    if (_incorrectQuizzes.isEmpty) {
      return const Center(child: Text('No incorrect quizzes available'));
    }
    return ListView.builder(
      itemCount: _incorrectQuizzes.length,
      itemBuilder: (context, index) {
        final quiz = _incorrectQuizzes[index];
        return QuizCard(
          key: ValueKey(quiz.id),
          quiz: quiz,
          questionNumber: index + 1,
          isIncorrectAnswersMode: true,
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

// 수정시 주의 사항:
// deletereview 버튼의 역할 :=> incorrectquizpage에서 카드를 삭제함.
//기기내부와 서버에서 reviewlist에서 삭제됨.
//quizlist와는 무관하고,
//quizpage에서 사용자가 기존에 선택한 ui는 변하지 않음.
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
        _incorrectQuizzes.removeWhere((q) => q.id == quiz.id);
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
