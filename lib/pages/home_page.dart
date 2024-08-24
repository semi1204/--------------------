import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/widgets/drawer/app_drawer.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'package:logger/logger.dart';
import 'subject_page.dart';

class DraggablePage extends StatefulWidget {
  const DraggablePage({super.key});

  @override
  DraggablePageState createState() => DraggablePageState();
}

class DraggablePageState extends State<DraggablePage> {
  late final Logger _logger;

  @override
  void initState() {
    super.initState();
    _logger = Provider.of<Logger>(context, listen: false);
    _logger.i('DraggablePage 초기화');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logger.i('DraggablePage 빌드');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        _logger.i(
            'DraggablePage 빌드. 로그인 여부: ${userProvider.user != null}. 관리자 여부: ${userProvider.isAdmin}');

        return Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                expandedHeight: 200.0,
                floating: false,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text('Quiz App'),
                  background: Container(
                    color: const Color(0xFF424242),
                    child: const Center(
                      child: Text(
                        '공지사항: 새로운 기능이 추가되었습니다!',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '퀴즈 앱에 오신 것을 환영합니다!',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => const SubjectPage()),
                          );
                        },
                        child: const Text('시작하기'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          drawer: const AppDrawer(),
        );
      },
    );
  }

  @override
  void dispose() {
    _logger.i('DraggablePage disposed');
    super.dispose();
  }
}
