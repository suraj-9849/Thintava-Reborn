import 'package:canteen_app/screens/admin/admin_home.dart';
import 'package:canteen_app/screens/admin/menu_management_screen.dart';
import 'package:canteen_app/screens/kitchen/kitchen_dashboard.dart';
import 'package:canteen_app/screens/user/order_history_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/user/menu_screen.dart';
import 'screens/user/cart_screen.dart';
import 'screens/user/order_tracking_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Platform-specific Firebase initialization
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCPsu2kuSKa9KezLhZNJWUF4B_n5kMqo4g",
        authDomain: "thintava-ee4f4.firebaseapp.com",
        projectId: "thintava-ee4f4",
        storageBucket: "thintava-ee4f4.firebasestorage.app",
        messagingSenderId: "626390741302",
        appId: "1:626390741302:ios:0579424d3bba31c12ec397",

        measurementId: "", // Optional
      ),
    );
  } else {
    await Firebase.initializeApp(); // Uses GoogleService-Info.plist (iOS) or google-services.json (Android)
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Canteen App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const AuthMenu(),
      routes: {
        '/menu': (_) => const MenuScreen(),
        '/cart': (context) {
          final cart =
              ModalRoute.of(context)!.settings.arguments as Map<String, int>;
          return CartScreen(cart: cart);
        },
        '/track': (_) => const OrderTrackingScreen(),
        '/kitchen': (_) => const KitchenDashboard(),
        '/admin/menu': (_) => const MenuManagementScreen(),
        '/admin/home': (_) => const AdminHome(),
        '/history': (_) => const OrderHistoryScreen(),
      },
    );
  }
}

class AuthMenu extends StatelessWidget {
  const AuthMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Canteen App Auth")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text("Login"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              child: const Text("Register"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
