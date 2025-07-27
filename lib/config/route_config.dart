// lib/config/route_config.dart - UPDATED ROUTES (REMOVED LIVE ORDERS, ADDED ANALYTICS)
import 'package:flutter/material.dart';
import 'package:canteen_app/screens/auth/auth_menu.dart';
import 'package:canteen_app/screens/auth/username_setup_screen.dart';
import 'package:canteen_app/screens/user/menu_screen.dart';
import 'package:canteen_app/screens/user/cart_screen.dart';
import 'package:canteen_app/screens/user/order_tracking_screen.dart';
import 'package:canteen_app/screens/user/order_history_screen.dart';
import 'package:canteen_app/screens/user/user_home.dart';
import 'package:canteen_app/screens/admin/admin_home.dart';
import 'package:canteen_app/screens/admin/menu_management_screen.dart';
import 'package:canteen_app/screens/admin/admin_order_history_screen.dart';
import 'package:canteen_app/screens/admin/admin_kitchen_view_screen.dart';
import 'package:canteen_app/screens/admin/admin_analytics_screen.dart'; // NEW
import 'package:canteen_app/screens/kitchen/kitchen_home.dart';
import 'package:canteen_app/screens/splash/splash_screen.dart';

class RouteConfig {
  static Map<String, WidgetBuilder> get routes {
    return {
      // Authentication routes
      '/auth': (_) => const AuthMenu(),
      '/username-setup': (_) => const UsernameSetupScreen(),
      
      // User routes - UPDATED FOR PROPER NAVIGATION
      '/user/user-home': (_) => const UserHome(), // Default home
      '/user/home': (_) => const UserHome(initialIndex: 0), // Home tab
      '/user/track': (_) => const UserHome(initialIndex: 1), // Track tab
      '/user/history': (_) => const UserHome(initialIndex: 2), // History tab
      '/user/profile': (_) => const UserHome(initialIndex: 3), // Profile tab
      
      // Legacy routes for backward compatibility - redirect to UserHome tabs
      '/menu': (_) => const UserHome(initialIndex: 0), // Redirect to home tab
      '/track': (_) => const UserHome(initialIndex: 1), // Redirect to track tab
      '/history': (_) => const UserHome(initialIndex: 2), // Redirect to history tab
      
      // Cart route (standalone is fine)
      '/cart': (_) => const CartScreen(),
      
      // Admin routes - UPDATED: REMOVED LIVE ORDERS, ADDED ANALYTICS
      '/admin/home': (_) => const AdminHome(),
      '/admin/menu': (_) => const MenuManagementScreen(),
      '/admin/admin-history': (_) => const AdminOrderHistoryScreen(),
      '/admin/admin-kitchen-view': (_) => const AdminKitchenViewScreen(),
      '/admin/analytics': (_) => const AdminAnalyticsScreen(), // NEW ANALYTICS ROUTE
      
      // Kitchen routes - SIMPLIFIED TO JUST ONE MAIN ROUTE
      '/kitchen': (_) => const KitchenHome(), // Now serves as the main dashboard
      '/kitchen-menu': (_) => const KitchenHome(), // Redirect to main kitchen dashboard
      '/kitchen-home': (_) => const KitchenHome(), // Redirect to main kitchen dashboard
      
      // App routes
      '/splash': (context) => const SplashScreen(),
    };
  }
  
  // Helper methods for navigation
  static void navigateToUserHome(BuildContext context, {int initialIndex = 0}) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => UserHome(initialIndex: initialIndex),
      ),
      (route) => false,
    );
  }
  
  static void navigateToTrackOrder(BuildContext context) {
    navigateToUserHome(context, initialIndex: 1);
  }
  
  static void navigateToOrderHistory(BuildContext context) {
    navigateToUserHome(context, initialIndex: 2);
  }
  
  static void navigateToProfile(BuildContext context) {
    navigateToUserHome(context, initialIndex: 3);
  }

  // Kitchen navigation helper
  static void navigateToKitchenDashboard(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const KitchenHome(),
      ),
      (route) => false,
    );
  }

  // NEW: Admin analytics navigation helper
  static void navigateToAdminAnalytics(BuildContext context) {
    Navigator.pushNamed(context, '/admin/analytics');
  }
}