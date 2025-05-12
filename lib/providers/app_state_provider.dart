import 'package:flutter/foundation.dart';

class AppStateProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  String _currentLocale = 'en';
  
  bool get isDarkMode => _isDarkMode;
  String get currentLocale => _currentLocale;
  
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
  
  void setLocale(String locale) {
    _currentLocale = locale;
    notifyListeners();
  }
}