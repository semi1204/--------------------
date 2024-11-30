import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final Logger _logger = Logger();

  // Get current user's display name directly from Firebase
  String? getCurrentUserDisplayName() {
    return _auth.currentUser?.displayName;
  }

  // Reload and get latest user data
  Future<String?> getLatestUserDisplayName() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.displayName;
  }

  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _logger.i('User ${userCredential.user?.email} signed in with email');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      _logger.e('Firebase Auth Error during sign in: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      _logger.e('Error signing in with email: $e');
      rethrow;
    }
  }

  Future<User?> signUpWithEmailAndPassword(
      String email, String password, String displayName) async {
    try {
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 닉네임 설정 및 즉시 reload
      await userCredential.user?.updateProfile(displayName: displayName);
      await userCredential.user?.reload();

      await userCredential.user?.sendEmailVerification();
      _logger.i(
          'User ${userCredential.user?.email} signed up. Display name set to: ${userCredential.user?.displayName}');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      _logger.e('Firebase Auth Error during sign up: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      _logger.e('Error signing up with email: $e');
      rethrow;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleSignInAccount =
          await _googleSignIn.signIn();
      if (googleSignInAccount != null) {
        final GoogleSignInAuthentication googleSignInAuthentication =
            await googleSignInAccount.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleSignInAuthentication.accessToken,
          idToken: googleSignInAuthentication.idToken,
        );

        final UserCredential userCredential =
            await _auth.signInWithCredential(credential);

        // 닉네임이 없는 경우 이메일의 @ 앞부분을 닉네임으로 설정
        if (userCredential.user?.displayName == null ||
            userCredential.user!.displayName!.isEmpty) {
          final defaultNickname = userCredential.user?.email?.split('@')[0];
          await userCredential.user
              ?.updateProfile(displayName: defaultNickname);
          await userCredential.user?.reload();
        }

        _logger.i(
            'User ${userCredential.user?.email} signed in with Google. Display name: ${userCredential.user?.displayName}');
        return userCredential.user;
      }
    } on FirebaseAuthException catch (e) {
      _logger.e(
          'Firebase Auth Error during Google sign in: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      _logger.e('Error signing in with Google: $e');
      rethrow;
    }
    return null;
  }

  Future<User?> signInWithApple() async {
    try {
      final rawNonce = generateNonce();
      final nonce = sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Set Apple account name to Firebase user profile
      if (appleCredential.givenName != null) {
        final displayName =
            '${appleCredential.givenName} ${appleCredential.familyName}';
        await userCredential.user
            ?.updateProfile(displayName: displayName.trim());
      }

      _logger.i('User ${userCredential.user?.email} signed in with Apple');
      return userCredential.user;
    } catch (e) {
      _logger.e('Error signing in with Apple: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
    _logger.i('User signed out');
  }

  FirebaseAuth get auth => _auth;

  Future<bool> isEmailVerified() async {
    User? user = _auth.currentUser;
    await user?.reload();
    return user?.emailVerified ?? false;
  }

  Future<void> sendEmailVerification() async {
    User? user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> reauthenticateUser(String password) async {
    try {
      User? user = _auth.currentUser;
      if (user != null && user.email != null) {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        _logger.i('User reauthenticated successfully');
      } else {
        throw Exception('No user is currently signed in or user email is null');
      }
    } catch (e) {
      _logger.e('Error reauthenticating user: $e');
      rethrow;
    }
  }

  Future<void> deleteAccount(String password) async {
    try {
      await reauthenticateUser(password);
      User? user = _auth.currentUser;
      if (user != null) {
        await user.delete();
        _logger.i('User account deleted successfully');
      } else {
        throw Exception('No user is currently signed in');
      }
    } catch (e) {
      _logger.e('Error deleting user account: $e');
      rethrow;
    }
  }

  String generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // 닉네임 업데이트 메서드 추가
  Future<void> updateUserDisplayName(String newDisplayName) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.updateProfile(displayName: newDisplayName);
        await user.reload();
        _logger.i('Display name updated to: $newDisplayName');
      } else {
        throw Exception('No user is currently signed in');
      }
    } catch (e) {
      _logger.e('Error updating display name: $e');
      rethrow;
    }
  }

  // 닉네임 유효성 검사 메서드 추가
  bool isValidDisplayName(String displayName) {
    // 2-20자 제한, 특수문자 제한 등
    final RegExp validDisplayName = RegExp(r'^[a-zA-Z0-9가-힣]{2,20}$');
    return validDisplayName.hasMatch(displayName);
  }
}
