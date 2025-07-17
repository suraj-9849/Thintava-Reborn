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
import 'package:canteen_app/screens/admin/admin_live_orders.dart';
import 'package:canteen_app/screens/kitchen/kitchen_dashboard.dart';
import 'package:canteen_app/screens/kitchen/kitchen_home.dart';
import 'package:canteen_app/screens/splash/splash_screen.dart';

class RouteConfig {
  static Map<String, WidgetBuilder> get routes {
    return {
      // Authentication routes
      '/auth': (_) => const AuthMenu(),
      '/username-setup': (_) => const UsernameSetupScreen(),
      
      // User routes
      '/menu': (_) => const MenuScreen(),
      '/cart': (_) => const CartScreen(),
      '/track': (_) => const OrderTrackingScreen(),
      '/history': (_) => const OrderHistoryScreen(),
      '/user/user-home': (_) => const UserHome(),
      
      // Admin routes
      '/admin/home': (_) => const AdminHome(),
      '/admin/menu': (_) => const MenuManagementScreen(),
      '/admin/live-orders': (_) => const AdminLiveOrdersScreen(),
      '/admin/admin-history': (_) => const AdminOrderHistoryScreen(),
      '/admin/admin-kitchen-view': (_) => const AdminKitchenViewScreen(),
      
      // Kitchen routes
      '/kitchen': (_) => const KitchenDashboard(),
      '/kitchen-menu': (_) => const KitchenHome(),
      '/kitchen-dashboard': (_) => const KitchenDashboard(),
      
      // App routes
      '/splash': (context) => const SplashScreen(),
    };
  }
}