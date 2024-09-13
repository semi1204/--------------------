import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  static const Color primaryColor = Color.fromARGB(255, 152, 183, 219);
  static const Color secondaryColor = Color.fromARGB(255, 190, 236, 225);
  static const Color darkModeBackground = Color(0xFF303030);
  static const Color darkModeSurface = Color(0xFF424242);

  // buttonColor를 primaryColor로 변경
  Color get buttonColor => primaryColor;
  Color get textColor => _isDarkMode ? Colors.white : Colors.black;
  Color get iconColor => _isDarkMode ? Colors.white : Colors.black;

  ThemeData get currentTheme => _isDarkMode ? _darkTheme : _lightTheme;

  ThemeData get _darkTheme => ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: primaryColor,
          secondary: secondaryColor,
          surface: darkModeSurface,
        ),
        scaffoldBackgroundColor: darkModeBackground,
        cardColor: darkModeSurface,
        textTheme: GoogleFonts.notoSansTextTheme(ThemeData.dark().textTheme),
      );

  ThemeData get _lightTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ).copyWith(secondary: secondaryColor),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansTextTheme(ThemeData.light().textTheme),
      );

  double _textScaleFactor = 1.0;
  double get textScaleFactor => _textScaleFactor;

  void setTextScaleFactor(double factor) {
    _textScaleFactor = factor;
    notifyListeners();
    _saveTextScaleFactor();
  }

  void _loadTextScaleFactor() async {
    final prefs = await SharedPreferences.getInstance();
    _textScaleFactor = prefs.getDouble('textScaleFactor') ?? 1.0;
    notifyListeners();
  }

  void _saveTextScaleFactor() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('textScaleFactor', _textScaleFactor);
  }

  ThemeProvider() {
    _loadThemePreference();
    _loadTextScaleFactor();
  }

  void _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }
}
