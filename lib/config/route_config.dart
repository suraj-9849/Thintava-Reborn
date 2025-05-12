import 'package:flutter/material.dart';
import 'package:canteen_app/screens/auth/auth_menu.dart';
import 'package:canteen_app/screens/auth/login_screen.dart';
import 'package:canteen_app/screens/auth/register_screen.dart';
import 'package:canteen_app/screens/user/menu_screen.dart';
import 'package:canteen_app/screens/user/cart_screen.dart';
import 'package:canteen_app/screens/user/order_tracking_screen.dart';
import 'package:canteen_app/screens/user/order_history_screen.dart';
import 'package:canteen_app/screens/user/user_home.dart';
import 'package:canteen_app/screens/admin/admin_home.dart';
import 'package:canteen_app/screens/admin/menu_management_screen.dart';
import 'package:canteen_app/screens/admin/admin_order_history_screen.dart';
import 'package:canteen_app/screens/admin/admin_kitchen_view_screen.dart';
import 'package:canteen_app/screens/kitchen/kitchen_dashboard.dart';
import 'package:canteen_app/screens/kitchen/kitchen_home.dart';
import 'package:canteen_app/screens/splash/splash_screen.dart';

class RouteConfig {
  static Map<String, WidgetBuilder> get routes {
    return {
      '/auth': (_) => const AuthMenu(),
      '/menu': (_) => const MenuScreen(),
      '/cart': (context) {
        final cart = ModalRoute.of(context)!.settings.arguments as Map<String, int>;
        return CartScreen(cart: cart);
      },
      '/splash': (context) => const SplashScreen(),
      '/track': (_) => const OrderTrackingScreen(),
      '/kitchen': (_) => const KitchenDashboard(),
      '/kitchen-menu': (_) => const KitchenHome(),
      '/admin/menu': (_) => const MenuManagementScreen(),
      '/admin/home': (_) => const AdminHome(),
      '/history': (_) => const OrderHistoryScreen(),
      '/admin/admin-history': (_) => const AdminOrderHistoryScreen(),
      '/admin/admin-kitchen-view': (_) => const AdminKitchenViewScreen(),
      '/user/user-home': (_) => const UserHome(),
    };
  }
}