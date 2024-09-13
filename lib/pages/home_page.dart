import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/widgets/drawer/app_drawer.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';
import 'package:logger/logger.dart';
import 'subject_page.dart';
import 'package:card_swiper/card_swiper.dart';

class DraggablePage extends StatefulWidget {
  const DraggablePage({super.key});

  @override
  DraggablePageState createState() => DraggablePageState();
}

class DraggablePageState extends State<DraggablePage> {
  late final Logger _logger;

  final List<NoticeCard> notices = [
    const NoticeCard(header: "오픈 이벤트 중!", content: "30% 할인 된 가격에 구독!"),
    const NoticeCard(header: "딸깍!복습", content: "복습버튼만 누르세요! \n 자동으로 복습해드릴게요!"),
    const NoticeCard(header: "업데이트", content: "버그 수정 및 성능 개선이 이루어졌습니다."),
  ];

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
    return Consumer2<UserProvider, ThemeProvider>(
      builder: (context, userProvider, themeProvider, child) {
        _logger.i(
            'DraggablePage 빌드. 로그인 여부: ${userProvider.user != null}. 관리자 여부: ${userProvider.isAdmin}');

        return Theme(
          data: themeProvider.currentTheme,
          child: Scaffold(
            drawer: const AppDrawer(),
            body: CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  expandedHeight: 200.0,
                  floating: false,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text(''),
                    background: Container(
                      color: themeProvider.isDarkMode
                          ? ThemeProvider.darkModeSurface
                          : ThemeProvider.primaryColor,
                      child: Swiper(
                        itemBuilder: (BuildContext context, int index) {
                          return Center(child: notices[index]);
                        },
                        itemCount: notices.length,
                        viewportFraction: 0.9,
                        scale: 0.95,
                        layout: SwiperLayout.DEFAULT,
                        pagination: const SwiperPagination(
                          builder: DotSwiperPaginationBuilder(
                            color: Colors.grey,
                            activeColor: Colors.white,
                            size: 8.0,
                            activeSize: 8.0,
                            space: 4.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverFillRemaining(
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '공부하러 가기',
                          style: getAppTextStyle(context,
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: Icon(Icons.arrow_forward,
                              color: themeProvider.iconColor),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const SubjectPage(),
                              ),
                            );
                          },
                          tooltip: '시작하기',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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

class NoticeCard extends StatelessWidget {
  final String header;
  final String content;

  const NoticeCard({super.key, required this.header, required this.content});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.85,
      child: Card(
        color: themeProvider.isDarkMode
            ? ThemeProvider.darkModeSurface.withOpacity(0.8)
            : Colors.white.withOpacity(0.8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                header,
                style: getAppTextStyle(context,
                    fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: getAppTextStyle(context, fontSize: 16),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
