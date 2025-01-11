import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/providers/user_provider.dart';
import 'package:nursing_quiz_app_6/services/quiz_service.dart';
import 'package:provider/provider.dart';
import '../providers/subject_provider.dart';
import '../providers/theme_provider.dart';
import 'quiz_type_page.dart';
import 'review_quizzes_page.dart';
import 'add_quiz_page.dart';
import 'date_review_page.dart';
import '../widgets/drawer/app_drawer.dart';
import '../widgets/linked_title.dart';
import 'package:fl_chart/fl_chart.dart';

// 진행률 섹션 위젯
class ProgressSection extends StatelessWidget {
  final double progress;
  final int answeredCount;
  final int totalCount;
  final ThemeProvider themeProvider;

  const ProgressSection({
    Key? key,
    required this.progress,
    required this.answeredCount,
    required this.totalCount,
    required this.themeProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '진행률',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: themeProvider.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$answeredCount / $totalCount 문제',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: themeProvider.textColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: ProgressBar(
              progress: progress,
              themeProvider: themeProvider,
            ),
          ),
        ],
      ),
    );
  }
}

// 정답률 섹션 위젯
class AccuracySection extends StatelessWidget {
  final int accuracy;
  final ThemeProvider themeProvider;

  const AccuracySection({
    Key? key,
    required this.accuracy,
    required this.themeProvider,
  }) : super(key: key);

  Color _getAccuracyColor(int accuracy) {
    // 정답률에 따라 빨간색(0%)에서 초록색(100%)까지 선형 보간
    final hue = (accuracy / 100) * 120; // 0(빨간색)에서 120(초록색)까지의 HSL 색상값
    return HSLColor.fromAHSL(
      1.0, // alpha
      hue, // hue
      0.7, // saturation
      0.5, // lightness
    ).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '정답률',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.textColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${accuracy.toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  color: _getAccuracyColor(accuracy),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AccuracyChart(
            accuracy: accuracy,
            accuracyColor: _getAccuracyColor(accuracy),
            themeProvider: themeProvider,
          ),
        ],
      ),
    );
  }
}

// 진행바 위젯
class ProgressBar extends StatelessWidget {
  final double progress;
  final ThemeProvider themeProvider;

  const ProgressBar({
    Key? key,
    required this.progress,
    required this.themeProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 진행률 텍스트 계산
    final progressText = '${(progress * 100).toInt()}%';

    return Container(
      height: 80,
      width: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 배경 원
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: themeProvider.isDarkMode
                  ? Colors.grey[800]
                  : Colors.grey[200],
            ),
          ),
          // 진행도 원
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
            builder: (context, double value, child) {
              return Container(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 8,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Color.fromARGB(255, 64, 169, 255)),
                ),
              );
            },
          ),
          // 퍼센트 텍스트
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                progressText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 정답률 차트 위젯
class AccuracyChart extends StatelessWidget {
  final int accuracy;
  final Color accuracyColor;
  final ThemeProvider themeProvider;

  const AccuracyChart({
    Key? key,
    required this.accuracy,
    required this.accuracyColor,
    required this.themeProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.center,
          maxY: 100,
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchCallback: (event, response) {},
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${accuracy.toInt()}%',
                  TextStyle(
                    color: accuracyColor,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: accuracy.toDouble(),
                  color: accuracyColor,
                  width: 40,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: themeProvider.isDarkMode
                        ? Colors.grey[800]
                        : Colors.grey[200],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SubjectPage extends StatefulWidget {
  const SubjectPage({super.key});

  @override
  State<SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolling = false;
  Map<String, Map<String, dynamic>> _subjectProgressCache = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    await userProvider.initializeUser();

    if (!mounted) return;

    final subjectProvider =
        Provider.of<SubjectProvider>(context, listen: false);
    await subjectProvider.loadSubjects();

    // Only preload subject progress if user data is available
    if (userProvider.user != null &&
        userProvider.getUserQuizData().isNotEmpty) {
      await _preloadSubjectProgress();
    }
  }

  Future<void> _preloadSubjectProgress() async {
    final subjectProvider =
        Provider.of<SubjectProvider>(context, listen: false);
    final quizService = Provider.of<QuizService>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    for (var subject in subjectProvider.subjects) {
      if (!_subjectProgressCache.containsKey(subject.id)) {
        final progress = await _calculateQuizSubjectProgress(
            quizService, userProvider, subject.id, 'default');
        _subjectProgressCache[subject.id] = progress;
      }
    }
    if (mounted) setState(() {});
  }

  void _scrollListener() {
    if (!_isScrolling) {
      setState(() => _isScrolling = true);
      Future.delayed(const Duration(milliseconds: 150), () {
        setState(() => _isScrolling = false);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SubjectProvider, ThemeProvider>(
      builder: (context, subjectProvider, themeProvider, child) {
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight / 1.6),
            child: AppBar(
              title: LinkedTitle(
                titles: ['과목'],
                onTap: (_) {},
              ),
              centerTitle: true,
              elevation: 0,
            ),
          ),
          drawer: const AppDrawer(),
          body: IndexedStack(
            index: subjectProvider.selectedIndex,
            children: [
              _buildSubjectList(subjectProvider, themeProvider),
              const ReviewQuizzesPage(),
              const DateReviewPage(),
              if (Provider.of<UserProvider>(context, listen: false).isAdmin)
                const AddQuizPage(),
            ],
          ),
          bottomNavigationBar:
              _buildBottomNavigationBar(subjectProvider, themeProvider),
        );
      },
    );
  }

  Widget _buildSubjectList(
      SubjectProvider subjectProvider, ThemeProvider themeProvider) {
    if (subjectProvider.subjects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final quizService = Provider.of<QuizService>(context, listen: false);
    final userId = userProvider.user?.uid;

    return ListView.builder(
      key: const PageStorageKey('subject_list'),
      physics: const AlwaysScrollableScrollPhysics(),
      cacheExtent: 1000.0,
      itemCount: subjectProvider.subjects.length,
      itemBuilder: (context, index) {
        final subject = subjectProvider.subjects[index];

        // 캐시된 데이터 사용
        if (_subjectProgressCache.containsKey(subject.id)) {
          final progressData = _subjectProgressCache[subject.id]!;
          return SubjectCard(
            subject: subject,
            progress: progressData['progress'] as double,
            answeredCount: progressData['answeredCount'] as int,
            totalCount: progressData['totalCount'] as int,
            accuracy: progressData['accuracy'] as int,
            userId: userId,
            themeProvider: themeProvider,
          );
        }

        return FutureBuilder<Map<String, dynamic>>(
          future: _calculateQuizSubjectProgress(
              quizService, userProvider, subject.id, 'default'),
          builder: (context, progressSnapshot) {
            if (progressSnapshot.connectionState == ConnectionState.waiting) {
              return const ListTile(title: Text('Loading...'));
            }

            final progressData = progressSnapshot.data ??
                {
                  'progress': 0.0,
                  'answeredCount': 0,
                  'totalCount': 0,
                  'accuracy': 0
                };

            // 데이터 캐싱
            _subjectProgressCache[subject.id] = progressData;

            return SubjectCard(
              subject: subject,
              progress: progressData['progress'] as double,
              answeredCount: progressData['answeredCount'] as int,
              totalCount: progressData['totalCount'] as int,
              accuracy: progressData['accuracy'] as int,
              userId: userId,
              themeProvider: themeProvider,
            );
          },
        );
      },
    );
  }

  Widget _buildBottomNavigationBar(
      SubjectProvider subjectProvider, ThemeProvider themeProvider) {
    return BottomNavigationBar(
      currentIndex: subjectProvider.selectedIndex,
      onTap: subjectProvider.setSelectedIndex,
      iconSize: 20,
      selectedFontSize: 12,
      unselectedFontSize: 10,
      selectedItemColor: themeProvider.isDarkMode
          ? Colors.white
          : Color.fromARGB(255, 50, 90, 135),
      unselectedItemColor: themeProvider.isDarkMode
          ? Color.fromARGB(255, 153, 151, 151)
          : Color.fromARGB(255, 119, 117, 117),
      backgroundColor: themeProvider.isDarkMode
          ? ThemeProvider.darkModeSurface
          : Colors.white,
      type: BottomNavigationBarType.fixed,
      items: [
        const BottomNavigationBarItem(
            icon: Icon(Icons.local_library), label: '과목별 기출'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.refresh), label: 'AI 복습'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today), label: '날짜별 복습'),
        if (Provider.of<UserProvider>(context, listen: false).isAdmin)
          const BottomNavigationBarItem(icon: Icon(Icons.add), label: '퀴즈 추가'),
      ],
    );
  }

  Future<Map<String, dynamic>> _calculateQuizSubjectProgress(
      QuizService quizService,
      UserProvider userProvider,
      String subjectId,
      String quizTypeId) async {
    if (!userProvider.isInitialized) {
      return {
        'progress': 0.0,
        'answeredCount': 0,
        'totalCount': 0,
        'accuracy': 0
      };
    }

    final quizData = userProvider.getUserQuizData();
    final subjectData = quizData[subjectId] as Map<String, dynamic>?;
    final userId = userProvider.user?.uid;

    // 캐시된 데이터가 있으면 사용
    if (_subjectProgressCache.containsKey(subjectId)) {
      return _subjectProgressCache[subjectId]!;
    }

    int totalAnsweredQuizzes = 0;
    int totalQuizCount = 0;
    int totalAccuracy = 0;
    int totalTypes = 0;

    final quizTypes = await quizService.getQuizTypes(subjectId);

    for (var quizType in quizTypes) {
      final quizTypeData = subjectData?[quizType.id] as Map<String, dynamic>?;

      int typeQuizCount =
          await quizService.getTotalQuizCount(subjectId, quizType.id);
      totalQuizCount += typeQuizCount;

      int answeredCount = quizTypeData?.values
              .where((quiz) => (quiz as Map<String, dynamic>)['total'] > 0)
              .length ??
          0;
      totalAnsweredQuizzes += answeredCount;

      if (userId != null) {
        int typeAccuracy = await quizService.getWeightedAverageAccuracy(
            userId, subjectId, quizType.id);
        totalAccuracy += typeAccuracy;
        totalTypes++;
      }
    }

    double progress =
        totalQuizCount > 0 ? totalAnsweredQuizzes / totalQuizCount : 0.0;
    int averageAccuracy =
        totalTypes > 0 ? (totalAccuracy / totalTypes).round() : 0;

    final result = {
      'progress': progress,
      'answeredCount': totalAnsweredQuizzes,
      'totalCount': totalQuizCount,
      'accuracy': averageAccuracy
    };

    // 결과 캐싱
    _subjectProgressCache[subjectId] = result;

    return result;
  }
}

// 과목 카드 위젯
class SubjectCard extends StatelessWidget {
  final dynamic subject;
  final double progress;
  final int answeredCount;
  final int totalCount;
  final int accuracy;
  final String? userId;
  final ThemeProvider themeProvider;

  const SubjectCard({
    Key? key,
    required this.subject,
    required this.progress,
    required this.answeredCount,
    required this.totalCount,
    required this.accuracy,
    required this.userId,
    required this.themeProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode
              ? ThemeProvider.darkModeSurface
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuizTypePage(subject: subject),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          subject.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: ThemeProvider.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: ThemeProvider.primaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: ThemeProvider.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ProgressSection(
                          progress: progress,
                          answeredCount: answeredCount,
                          totalCount: totalCount,
                          themeProvider: themeProvider,
                        ),
                      ),
                      if (userId != null) ...[
                        const SizedBox(width: 32),
                        Expanded(
                          child: AccuracySection(
                            accuracy: accuracy,
                            themeProvider: themeProvider,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
