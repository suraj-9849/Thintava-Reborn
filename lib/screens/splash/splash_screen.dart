import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:canteen_app/constants/food_quotes.dart';
import 'package:canteen_app/services/auth_service.dart';

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
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupFirebaseMessaging();
    _startListeningToAuth();
    
    // TEMPORARILY DISABLE SESSION LISTENER
    // _authService.startSessionListener(() {
    //   _handleForcedLogout();
    // });
    print('🎬 Splash screen initialized');
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
    print('🎭 Animations set up');
  }

  void _setupFirebaseMessaging() {
    try {
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
      print('📱 Firebase messaging set up');
    } catch (e) {
      print('❗ Error setting up Firebase messaging: $e');
    }
  }

  void _startListeningToAuth() {
    print("👂 Listening to authStateChanges...");
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (!mounted) return;

      if (user == null) {
        print("🔴 No user. Navigating to /auth...");
        // Add a delay for splash screen effect
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/auth');
        return;
      }

      print("🟢 User signed in: ${user.uid}");
      print("📧 User email: ${user.email}");
      
      // TEMPORARILY DISABLE SESSION CHECK - PROCEED DIRECTLY TO ROLE CHECK
      // bool isActiveSession = await _authService.checkActiveSession();
      // if (!isActiveSession) {
      //   print("❌ This device is not the active session for this user");
      //   await _authService.logout();
      //   
      //   if (!mounted) return;
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //       content: Text(
      //         'You have been logged out because your account was logged in on another device',
      //         style: GoogleFonts.poppins(),
      //       ),
      //       duration: const Duration(seconds: 5),
      //     ),
      //   );
      //   
      //   Navigator.pushReplacementNamed(context, '/auth');
      //   return;
      // }

      // START FCM Token Fetching
      await _fetchAndSaveFcmToken(user.uid);

      // Now fetch the user role
      final role = await _fetchUserRole(user.uid);

      if (!mounted) return;
      
      // Add a delay for splash screen effect
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      print("🎯 User role: $role");

      // Navigate based on role
      if (role == 'admin') {
        print("🏠 Navigating to admin home");
        Navigator.pushReplacementNamed(context, '/admin/home');
      } else if (role == 'kitchen') {
        print("👨‍🍳 Navigating to kitchen home");
        Navigator.pushReplacementNamed(context, '/kitchen-menu');
      } else {
        print("👤 Navigating to user home");
        Navigator.pushReplacementNamed(context, '/user/user-home');
      }
    }, onError: (error) {
      print("❗ Auth state change error: $error");
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/auth');
      }
    });
  }

  Future<void> _fetchAndSaveFcmToken(String userId) async {
    try {
      print("🚀 Fetching FCM token for user: $userId");
      String? token;
      int retries = 0;

      while (token == null && retries < 5) {
        try {
          token = await FirebaseMessaging.instance.getToken();
          if (token == null) {
            print("⏳ FCM token not ready, retrying... attempt ${retries + 1}");
            await Future.delayed(const Duration(seconds: 1));
            retries++;
          }
        } catch (e) {
          print("❗ Error getting FCM token on attempt ${retries + 1}: $e");
          retries++;
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (token != null) {
        print("✅ Got FCM token: ${token.substring(0, 20)}...");
        try {
          await FirebaseFirestore.instance.collection('users').doc(userId).set(
            {
              'fcmToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          print("💾 FCM token saved to Firestore");
        } catch (e) {
          print("❗ Error saving FCM token to Firestore: $e");
        }

        // Also listen for future token refreshes
        _tokenRefreshSubscription?.cancel();
        _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          print("🔄 FCM token refreshed: ${newToken.substring(0, 20)}...");
          try {
            await FirebaseFirestore.instance.collection('users').doc(userId).set(
              {
                'fcmToken': newToken,
                'lastTokenUpdate': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
            print("💾 Refreshed FCM token saved to Firestore");
          } catch (e) {
            print("❗ Error saving refreshed FCM token: $e");
          }
        });
      } else {
        print("❗ Could not get FCM token after $retries attempts");
      }
    } catch (e) {
      print("❗ Error in _fetchAndSaveFcmToken: $e");
    }
  }

  Future<String> _fetchUserRole(String userId) async {
    try {
      print("🔍 Fetching user role for: $userId");
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final role = data['role'] ?? 'user';
        print("📋 User role found: $role");
        print("📋 User data: ${data.keys.toList()}");
        return role;
      } else {
        print("📋 No user document found, defaulting to 'user'");
        // Create user document with default role
        try {
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'role': 'user',
            'email': FirebaseAuth.instance.currentUser?.email,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print("📋 Created default user document");
        } catch (e) {
          print("❗ Error creating user document: $e");
        }
        return 'user';
      }
    } catch (e) {
      print("❗ Error fetching role: $e");
      return 'user';
    }
  }

  @override
  void dispose() {
    print("🗑️ Disposing splash screen");
    _authSubscription.cancel();
    _tokenRefreshSubscription?.cancel();
    _animationController.dispose();
    // TEMPORARILY DISABLE SESSION LISTENER
    // _authService.stopSessionListener();
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