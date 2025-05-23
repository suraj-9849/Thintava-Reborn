import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:canteen_app/constants/food_quotes.dart';
import 'package:canteen_app/services/auth_service.dart'; // Import AuthService

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  
  @override
  _SplashScreenState createState() => _SplashScreenState();
}
 
class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final StreamSubscription<User?> _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final AuthService _authService = AuthService(); // Create instance of AuthService

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupFirebaseMessaging();
    _startListeningToAuth();
    
    // Set up session listener for forced logout
    _authService.startSessionListener(() {
      // This will be called if this device is logged out remotely
      _handleForcedLogout();
    });
  }
  
  void _handleForcedLogout() {
    // Show dialog notifying user they've been logged out
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Logged Out', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(
            'You have been logged out because your account was logged in on another device.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/auth');
              },
              child: Text('OK', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _animationController.forward();
  }

  void _setupFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        FlutterLocalNotificationsPlugin().show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'thintava_channel',
              'Thintava Notifications',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  void _startListeningToAuth() {
    print("👂 Listening to authStateChanges...");
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (!mounted) return;

      if (user == null) {
        print("🔴 No user. Navigating to /auth...");
        // Add a delay for splash screen effect
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/auth');
        return;
      }

      print("🟢 User signed in: ${user.uid}");
      
      // Check if this is the active session for this user
      bool isActiveSession = await _authService.checkActiveSession();
      if (!isActiveSession) {
        print("❌ This device is not the active session for this user");
        // Force logout on this device
        await _authService.logout();
        
        if (!mounted) return;
        // Show message and redirect to login
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You have been logged out because your account was logged in on another device',
              style: GoogleFonts.poppins(),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        
        // Navigate to auth screen
        Navigator.pushReplacementNamed(context, '/auth');
        return;
      }

      // If this is the active session, continue with normal flow
      // Important: START FCM Token Fetching
      await _fetchAndSaveFcmToken(user.uid);

      // Now fetch the user role
      final role = await _fetchUserRole(user.uid);

      if (!mounted) return;
      
      // Add a delay for splash screen effect
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin/home');
      } else if (role == 'kitchen') {
        Navigator.pushReplacementNamed(context, '/kitchen-menu');
      } else {
        Navigator.pushReplacementNamed(context, '/user/user-home');
      }
    });
  }

  Future<void> _fetchAndSaveFcmToken(String userId) async {
    try {
      print("🚀 Fetching FCM token...");
      String? token;
      int retries = 0;

      while (token == null && retries < 10) {
        token = await FirebaseMessaging.instance.getToken();
        if (token == null) {
          print("⏳ FCM token not ready, retrying... attempt $retries");
          await Future.delayed(const Duration(seconds: 1));
          retries++;
        }
      }

      if (token != null) {
        print("✅ Got FCM token: $token");
        await FirebaseFirestore.instance.collection('users').doc(userId).set(
          {'fcmToken': token},
          SetOptions(merge: true),
        );

        // Also listen for future token refreshes
        _tokenRefreshSubscription?.cancel();
        _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          print("🔄 FCM token refreshed: $newToken");
          await FirebaseFirestore.instance.collection('users').doc(userId).set(
            {'fcmToken': newToken},
            SetOptions(merge: true),
          );
        });
      } else {
        print("❗ Error fetching FCM token after retries.");
      }
    } catch (e) {
      print("❗ Error fetching FCM token: $e");
    }
  }

  Future<String> _fetchUserRole(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['role'] ?? 'user';
      } else {
        return 'user';
      }
    } catch (e) {
      print("❗ Error fetching role: $e");
      return 'user';
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _tokenRefreshSubscription?.cancel();
    _animationController.dispose();
    _authService.stopSessionListener(); // Stop session listener
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFB703), Color(0xFFFFB703)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Container with shadow effect
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    size: 60,
                    color: Color(0xFFFFB703),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Thintava',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                // Random food quote from our list
                Text(
                  foodQuotes[DateTime.now().second % foodQuotes.length],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  "Preparing your experience...",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}