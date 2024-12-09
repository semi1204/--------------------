import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheManager {
  static final Map<String, dynamic> _memoryCache = {};
  static final Map<String, DateTime> _expiryTimes = {};

  static const Duration defaultTTL = Duration(hours: 1);
  static SharedPreferences? _prefs;

  static const String _userDataPrefix = 'user_data_';
  static const String _quizDataPrefix = 'quiz_data_';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<T?> getUserData<T>(String userId, String key) async {
    return await _getData('$_userDataPrefix${userId}_$key');
  }

  static Future<void> setUserData<T>(
    String userId,
    String key,
    T value, {
    Duration? ttl,
  }) async {
    await _setData('$_userDataPrefix${userId}_$key', value, ttl: ttl);
  }

  static Future<T?> _getData<T>(String key) async {
    // Memory cache check
    if (_memoryCache.containsKey(key)) {
      if (_expiryTimes[key]!.isAfter(DateTime.now())) {
        return _memoryCache[key] as T?;
      }
      _memoryCache.remove(key);
      _expiryTimes.remove(key);
    }

    // SharedPreferences check
    final data = _prefs?.getString(key);
    if (data != null) {
      final decoded = json.decode(data);
      return decoded as T?;
    }
    return null;
  }

  static Future<void> _setData<T>(String key, T value, {Duration? ttl}) async {
    _memoryCache[key] = value;
    _expiryTimes[key] = DateTime.now().add(ttl ?? defaultTTL);
    await _prefs?.setString(key, json.encode(value));
  }
}
