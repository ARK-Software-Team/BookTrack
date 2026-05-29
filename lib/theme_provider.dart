// lib/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  final String id;
  final String name;
  final Color color;

  const AppTheme({required this.id, required this.name, required this.color});
}

class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'app_theme';

  static const List<AppTheme> themes = [
    AppTheme(id: 'purple',   name: 'Mor',     color: Color(0xFF6A1B9A)),
    AppTheme(id: 'indigo',   name: 'Mavi',    color: Color(0xFF283593)),
    AppTheme(id: 'teal',     name: 'Yeşil',   color: Color(0xFF00695C)),
    AppTheme(id: 'deepOrange', name: 'Turuncu', color: Color(0xFFBF360C)),
    AppTheme(id: 'navy',     name: 'Lacivert', color: Color(0xFF1A237E)),
    AppTheme(id: 'slate',    name: 'Antrasit', color: Color(0xFF37474F)),
  ];

  AppTheme _current = themes.first;
  AppTheme get current => _current;
  Color get primaryColor => _current.color;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefKey);
    if (id != null) {
      final found = themes.where((t) => t.id == id);
      if (found.isNotEmpty) {
        _current = found.first;
        notifyListeners();
      }
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    _current = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, theme.id);
  }

  ThemeData get themeData => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _current.color,
      primary: _current.color,
      secondary: _current.color,
    ),
    primaryColor: _current.color,
    useMaterial3: true,
  );
}