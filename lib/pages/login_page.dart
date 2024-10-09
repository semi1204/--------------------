import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/pages/signup_page.dart';
import 'package:nursing_quiz_app_6/pages/subject_page.dart';
import 'package:nursing_quiz_app_6/providers/user_provider.dart';
import 'package:nursing_quiz_app_6/services/auth_service.dart';
import 'package:nursing_quiz_app_6/widgets/%08login_button_state.dart';
import 'package:nursing_quiz_app_6/widgets/custom_login_button.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show Platform;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ionicons/ionicons.dart';
import 'email_verification_page.dart';

class LoginPage extends StatefulWidget {
  final bool isFromDrawer;

  const LoginPage({super.key, this.isFromDrawer = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final LoginButtonBloc _loginButtonBloc = LoginButtonBloc();
  bool _isObscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _loginButtonBloc.close();
    super.dispose();
  }

  void _navigateAfterLogin() {
    final logger = Provider.of<Logger>(context, listen: false);
    if (widget.isFromDrawer) {
      logger.i('Login successful from Drawer, popping context');
      Navigator.of(context).pop();
    } else {
      logger.i('Login successful, navigating to DraggablePage');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const SubjectPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _handleEmailSignIn() async {
    if (_formKey.currentState!.validate()) {
      _loginButtonBloc.add(TriggerLoginButtonEvent(true));
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final logger = Provider.of<Logger>(context, listen: false);

        final user = await authService.signInWithEmailAndPassword(
          _emailController.text,
          _passwordController.text,
        );

        if (!mounted) return;

        if (user != null) {
          final userProvider =
              Provider.of<UserProvider>(context, listen: false);
          userProvider.setUser(user);
          logger.i('User ${user.email} signed in with email');

          bool isVerified = await userProvider.isEmailVerified();
          if (isVerified) {
            _navigateAfterLogin();
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => EmailVerificationPage()),
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        _handleFirebaseAuthError(e);
      } catch (e) {
        _handleGenericError(e);
      } finally {
        _loginButtonBloc.add(TriggerLoginButtonEvent(false));
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    _loginButtonBloc.add(TriggerLoginButtonEvent(true));
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final logger = Provider.of<Logger>(context, listen: false);

      final user = await authService.signInWithGoogle();

      if (!mounted) return;

      if (user != null) {
        Provider.of<UserProvider>(context, listen: false).setUser(user);
        logger.i('User ${user.email} signed in with Google');
        _navigateAfterLogin();
      }
    } catch (e) {
      _handleGenericError(e);
    } finally {
      _loginButtonBloc.add(TriggerLoginButtonEvent(false));
    }
  }

  Future<void> _handleAppleSignIn() async {
    _loginButtonBloc.add(TriggerLoginButtonEvent(true));
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final logger = Provider.of<Logger>(context, listen: false);

      final user = await userProvider.signInWithApple();

      if (!mounted) return;

      if (user != null) {
        logger.i('User ${user.email} signed in with Apple');
        _navigateAfterLogin();
      }
    } catch (e) {
      _handleGenericError(e);
    } finally {
      _loginButtonBloc.add(TriggerLoginButtonEvent(false));
    }
  }

  void _handleFirebaseAuthError(FirebaseAuthException e) {
    final logger = Provider.of<Logger>(context, listen: false);
    logger.e('Firebase Auth Error during sign in: ${e.code} - ${e.message}');
    String errorMessage = '해당 계정이 존재하지 않습니다. 이메일 또는 비밀번호를 확인해주세요.';
    switch (e.code) {
      case 'user-not-found':
        errorMessage = '해당 계정이 존재하지 않습니다. 이메일 또는 비밀번호를 확인해주세요.';
        break;
      case 'wrong-password':
        errorMessage = '비밀번호가 틀렸습니다. 다시 시도해주세요.';
        break;
    }
    _showErrorSnackBar(errorMessage);
  }

  void _handleGenericError(dynamic e) {
    final logger = Provider.of<Logger>(context, listen: false);
    logger.e('Error during sign in: $e');
    _showErrorSnackBar('예기치 못한 오류가 발생했습니다. 다시 시도해주세요.');
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('로그인'),
      ),
      body: BlocProvider(
        create: (context) => _loginButtonBloc,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildEmailField(),
                  const SizedBox(height: 16),
                  _buildPasswordField(),
                  const SizedBox(height: 24),
                  _buildEmailLoginButton(),
                  const SizedBox(height: 16),
                  _buildGoogleLoginButton(),
                  if (Platform.isIOS) ...[
                    const SizedBox(height: 16),
                    _buildAppleLoginButton(),
                  ],
                  const SizedBox(height: 16),
                  _buildSignUpButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: InputDecoration(
        labelText: '이메일',
        prefixIcon: const Icon(Icons.email),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '이메일을 입력해주세요.';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: InputDecoration(
        labelText: '비밀번호',
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off),
          onPressed: () {
            setState(() {
              _isObscure = !_isObscure;
            });
          },
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      obscureText: _isObscure,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '비밀번호를 입력해주세요.';
        }
        return null;
      },
    );
  }

  Widget _buildEmailLoginButton() {
    return _buildAnimatedButton(
      onTap: _handleEmailSignIn,
      icon: Icons.email,
      label: '이메일 로그인',
    );
  }

  Widget _buildGoogleLoginButton() {
    return _buildAnimatedButton(
      onTap: _handleGoogleSignIn,
      icon: Ionicons.logo_google,
      label: '구글 로그인',
    );
  }

  Widget _buildAppleLoginButton() {
    return _buildAnimatedButton(
      onTap: _handleAppleSignIn,
      icon: Ionicons.logo_apple,
      label: '애플 로그인',
    );
  }

  Widget _buildSignUpButton() {
    return TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SignUpPage()),
        );
      },
      child: const Text('계정이 없으신가요? 회원가입'),
    );
  }

  Widget _buildAnimatedButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    return BlocBuilder<LoginButtonBloc, LoginButtonState>(
      builder: (context, state) {
        return CustomLoginButton(
          onTap: state == LoginButtonState.loading ? () {} : onTap,
          isLoading: state == LoginButtonState.loading,
          icon: icon,
          label: label,
        );
      },
    );
  }
}
