// lib/config/route_config.dart - UPDATED ROUTES WITH MENU OPERATIONS
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
import 'package:canteen_app/screens/admin/admin_analytics_screen.dart';
import 'package:canteen_app/screens/admin/menu_operations_screen.dart'; // NEW
import 'package:canteen_app/screens/kitchen/kitchen_home.dart';
import 'package:canteen_app/screens/splash/splash_screen.dart';
import 'package:canteen_app/screens/legal/privacy_policy_screen.dart';
import 'package:canteen_app/screens/legal/terms_of_service_screen.dart';
import '../models/menu_type.dart';

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
      
      // Admin routes - UPDATED: ADDED MENU OPERATIONS
      '/admin/home': (_) => const AdminHome(),
      '/admin/menu': (context) {
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        final menuType = args?['menuType'] as MenuType?;
        return MenuManagementScreen(initialMenuType: menuType);
      },
      '/admin/menu-operations': (_) => const MenuOperationsScreen(), // NEW ROUTE
      '/admin/admin-history': (_) => const AdminOrderHistoryScreen(),
      '/admin/admin-kitchen-view': (_) => const AdminKitchenViewScreen(),
      '/admin/analytics': (_) => const AdminAnalyticsScreen(),
      
      // Kitchen routes - SIMPLIFIED TO JUST ONE MAIN ROUTE
      '/kitchen': (_) => const KitchenHome(), // Now serves as the main dashboard
      '/kitchen-menu': (_) => const KitchenHome(), // Redirect to main kitchen dashboard
      '/kitchen-home': (_) => const KitchenHome(), // Redirect to main kitchen dashboard
      
      // Legal routes
      '/privacy-policy': (_) => const PrivacyPolicyScreen(),
      '/terms-of-service': (_) => const TermsOfServiceScreen(),
      
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

  // Admin navigation helpers
  static void navigateToAdminAnalytics(BuildContext context) {
    Navigator.pushNamed(context, '/admin/analytics');
  }

  // NEW: Menu operations navigation helper
  static void navigateToMenuOperations(BuildContext context) {
    Navigator.pushNamed(context, '/admin/menu-operations');
  }

  // NEW: Navigate to menu management with specific menu type
  static void navigateToMenuManagementWithType(BuildContext context, MenuType menuType) {
    Navigator.pushNamed(
      context, 
      '/admin/menu',
      arguments: {'menuType': menuType},
    );
  }

  // NEW: Navigate to admin home
  static void navigateToAdminHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminHome(),
      ),
      (route) => false,
    );
  }

  // NEW: Helper method to handle menu-specific navigation
  static void navigateToMenuTypeManagement(BuildContext context, MenuType menuType) {
    Navigator.pushNamed(
      context,
      '/admin/menu',
      arguments: {'menuType': menuType},
    );
  }

  // NEW: Check if route exists
  static bool routeExists(String routeName) {
    return routes.containsKey(routeName);
  }

  // NEW: Get route builder for a specific route
  static WidgetBuilder? getRouteBuilder(String routeName) {
    return routes[routeName];
  }

  // NEW: Navigate with fade transition
  static void navigateWithFadeTransition(
    BuildContext context,
    Widget destination, {
    bool replace = false,
  }) {
    final route = PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => destination,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );

    if (replace) {
      Navigator.pushReplacement(context, route);
    } else {
      Navigator.push(context, route);
    }
  }

  // NEW: Navigate with slide transition
  static void navigateWithSlideTransition(
    BuildContext context,
    Widget destination, {
    bool replace = false,
    SlideDirection direction = SlideDirection.rightToLeft,
  }) {
    Offset begin;
    switch (direction) {
      case SlideDirection.rightToLeft:
        begin = const Offset(1.0, 0.0);
        break;
      case SlideDirection.leftToRight:
        begin = const Offset(-1.0, 0.0);
        break;
      case SlideDirection.topToBottom:
        begin = const Offset(0.0, -1.0);
        break;
      case SlideDirection.bottomToTop:
        begin = const Offset(0.0, 1.0);
        break;
    }

    final route = PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => destination,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: begin,
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );

    if (replace) {
      Navigator.pushReplacement(context, route);
    } else {
      Navigator.push(context, route);
    }
  }

  // NEW: Show modal bottom sheet with custom route
  static void showModalRoute(
    BuildContext context,
    Widget child, {
    bool isScrollControlled = true,
    bool isDismissible = true,
    Color? backgroundColor,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      backgroundColor: backgroundColor ?? Colors.transparent,
      builder: (context) => child,
    );
  }

  // NEW: Show full screen dialog
  static void showFullScreenDialog(
    BuildContext context,
    Widget child, {
    bool barrierDismissible = true,
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.8,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
        barrierDismissible: barrierDismissible,
        opaque: false,
        barrierColor: Colors.black54,
      ),
    );
  }
}

// NEW: Enum for slide directions
enum SlideDirection {
  rightToLeft,
  leftToRight,
  topToBottom,
  bottomToTop,
}