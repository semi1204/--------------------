import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/pages/signup_page.dart';
import 'package:nursing_quiz_app_6/providers/user_provider.dart';
import 'package:nursing_quiz_app_6/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nursing_quiz_app_6/pages/home_page.dart' show DraggablePage;

class LoginPage extends StatefulWidget {
  final bool isFromDrawer;
  // Drawer에서 로그인 => 로그인 후 Drawer 닫기
  // auth_wrapper 에서 로그인 => 로그인 후 HomePage로 이동
  // 이 두 경우를 구분하기 위한 isFromDrawer 변수 추가
  const LoginPage({super.key, this.isFromDrawer = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateAfterLogin() {
    final logger = Provider.of<Logger>(context, listen: false);
    if (widget.isFromDrawer) {
      logger.i('Login successful from Drawer, popping context');
      Navigator.of(context).pop(); // Close the login page (and drawer)
    } else {
      logger.i('Login successful, navigating to DraggablePage');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const DraggablePage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _handleEmailSignIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final logger = Provider.of<Logger>(context, listen: false);

        final user = await authService.signInWithEmailAndPassword(
          _emailController.text,
          _passwordController.text,
        );

        if (!mounted) return;

        if (user != null) {
          Provider.of<UserProvider>(context, listen: false).setUser(user);
          logger.i('User ${user.email} signed in with email');
          _navigateAfterLogin();
        }
      } on FirebaseAuthException catch (e) {
        final logger = Provider.of<Logger>(context, listen: false);
        logger
            .e('Firebase Auth Error during sign in: ${e.code} - ${e.message}');
        String errorMessage;
        switch (e.code) {
          case 'user-not-found':
            errorMessage =
                'No user found for that email. Please check your email or sign up.';
            break;
          case 'wrong-password':
            errorMessage = 'Wrong password provided. Please try again.';
            break;
          default:
            errorMessage =
                'An error occurred during sign in. Please try again later.';
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } catch (e) {
        final logger = Provider.of<Logger>(context, listen: false);
        logger.e('Error signing in with email: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'An unexpected error occurred. Please try again later.')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final logger = Provider.of<Logger>(context, listen: false);

      final user = await authService.signInWithGoogle();

      if (!mounted) return;

      if (user != null) {
        Provider.of<UserProvider>(context, listen: false).setUser(user);
        logger.i('User ${user.email} signed in with Google');
        _navigateAfterLogin(); // 수정: Navigator.pop(context) 대신 _navigateAfterLogin() 호출
      }
    } catch (e) {
      final logger = Provider.of<Logger>(context, listen: false);
      logger.e('Error signing in with Google: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign in: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleEmailSignIn,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Sign in with Email'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Sign in with Google'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SignUpPage()),
                        );
                      },
                child: const Text('Don\'t have an account? Sign up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
