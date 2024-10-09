import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'subject_page.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _checkEmailVerification();
  }

  Future<void> _checkEmailVerification() async {
    setState(() {
      _isVerifying = true;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    bool isVerified = await userProvider.isEmailVerified();

    if (isVerified) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SubjectPage()),
      );
    } else {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('이메일 인증'),
        elevation: 0,
      ),
      body: Center(
        child: _isVerifying
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 80,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '이메일 인증이 필요합니다',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '이메일 주소를 확인해주세요. \nURL을 클릭하면 자동으로 인증이 완료됩니다.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 110),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('재전송'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          minimumSize:
                              const Size(200, 48), // 두 버튼의 최소 크기를 동일하게 설정
                        ),
                        onPressed: () async {
                          final userProvider =
                              Provider.of<UserProvider>(context, listen: false);
                          await userProvider.sendEmailVerification();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('인증 이메일이 재전송되었습니다.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('인증 완료'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          minimumSize:
                              const Size(200, 48), // 두 버튼의 최소 크기를 동일하게 설정
                        ),
                        onPressed: _checkEmailVerification,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
