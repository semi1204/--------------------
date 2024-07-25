import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/constants.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  final Logger _logger = Logger();

  User? get user => _user;
  bool get isAdmin => _user?.email == ADMIN_EMAIL;

  void setUser(User? user) {
    if (_user?.uid != user?.uid) {
      _user = user;
      _logger.i('User state changed: ${user?.email ?? 'No user'}');
      notifyListeners();
    }
  }
}
