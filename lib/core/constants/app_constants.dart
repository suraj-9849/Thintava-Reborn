// lib/core/constants/app_constants.dart
class AppConstants {
  // Navigation
  static const Duration navigationAnimationDuration = Duration(milliseconds: 400);
  static const Duration fadeAnimationDuration = Duration(milliseconds: 800);
  static const Duration shimmerAnimationDuration = Duration(milliseconds: 1500);
  
  // Cart & Orders
  static const Duration reservationDuration = Duration(minutes: 10);
  static const Duration orderExpiryDuration = Duration(minutes: 5);
  static const int lowStockThreshold = 5;
  static const int maxCartQuantity = 10;
  
  // UI
  static const double defaultPadding = 16.0;
  static const double defaultMargin = 20.0;
  static const double defaultBorderRadius = 16.0;
  static const double cardElevation = 4.0;
  
  // Status Colors
  static const String primaryColor = '#FFB703';
  static const String secondaryColor = '#004D40';
  static const String backgroundColor = '#F5F5F5';
}