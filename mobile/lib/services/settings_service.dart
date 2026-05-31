import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppFontSize { small, medium, large }

class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._();
  SettingsService._();

  ThemeMode _themeMode = ThemeMode.system;
  AppFontSize _fontSize = AppFontSize.medium;
  Locale _locale = const Locale('en');

  ThemeMode get themeMode => _themeMode;
  AppFontSize get fontSize => _fontSize;
  Locale get locale => _locale;

  double get fontScale => switch (_fontSize) {
        AppFontSize.small => 0.85,
        AppFontSize.medium => 1.0,
        AppFontSize.large => 1.15,
      };

  bool get isArabic => _locale.languageCode == 'ar';
  bool get isRtl =>
      _locale.languageCode == 'ar' || _locale.languageCode == 'he';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? 0];
    _fontSize = AppFontSize.values[prefs.getInt('fontSize') ?? 1];
    _locale = Locale(prefs.getString('locale') ?? 'en');
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }

  Future<void> setFontSize(AppFontSize size) async {
    if (_fontSize == size) return;
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fontSize', size.index);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
    notifyListeners();
  }
}
