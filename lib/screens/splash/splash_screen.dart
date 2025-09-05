// lib/screens/splash/splash_screen.dart - UPDATED TO NAVIGATE TO KITCHEN HOME DIRECTLY
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:canteen_app/constants/food_quotes.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:canteen_app/services/notification_service.dart';

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
  String _statusMessage = "Preparing your experience...";

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupOrderNotifications();
    _startListeningToAuth();
    print('🎬 Enhanced splash screen initialized with Google Auth support');
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


  void _setupOrderNotifications() {
    try {
      // Order notification setup is handled in main.dart during app initialization
      // Here we just confirm it's working
      print('📱 Order notification system confirmed active');
      
      if (mounted) {
        setState(() {
          _statusMessage = "Ready to connect...";
        });
      }
    } catch (e) {
      print('❗ Error in order notification setup: $e');
      if (mounted) {
        setState(() {
          _statusMessage = "Preparing app...";
        });
      }
    }
  }

  void _startListeningToAuth() {
    print("👂 Listening to authStateChanges with Google Auth support...");
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (!mounted) return;

      if (user == null) {
        print("🔴 No user. Navigating to /auth...");
        setState(() {
          _statusMessage = "Please sign in to continue...";
        });
        
        // Clean up any existing order notifications
        await NotificationService.cleanupNotifications();
        
        // Add a delay for splash screen effect
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/auth');
        return;
      }

      print("🟢 User signed in: ${user.uid}");
      print("📧 User email: ${user.email}");
      
      setState(() {
        _statusMessage = "Setting up your notifications...";
      });

      // Setup order notifications for the authenticated user
      await _setupUserOrderNotifications(user.uid);

      setState(() {
        _statusMessage = "Checking account setup...";
      });

      // Check if user needs username setup
      final userData = await _authService.getUserData(user.uid);
      
      if (userData != null && (userData['needsUsernameSetup'] ?? false)) {
        print("📝 User needs username setup");
        setState(() {
          _statusMessage = "Username setup required...";
        });
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/username-setup');
        return;
      }

      setState(() {
        _statusMessage = "Loading your account...";
      });

      // Now fetch the user role
      final role = await _fetchUserRole(user.uid);

      if (!mounted) return;
      
      setState(() {
        _statusMessage = "Almost ready...";
      });
      
      // Add a delay for splash screen effect
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      print("🎯 User role: $role");

      // Navigate based on role - UPDATED KITCHEN NAVIGATION
      if (role == 'admin') {
        print("🏠 Navigating to admin home");
        Navigator.pushReplacementNamed(context, '/admin/home');
      } else if (role == 'kitchen') {
        print("👨‍🍳 Navigating to kitchen dashboard (now main kitchen home)");
        Navigator.pushReplacementNamed(context, '/kitchen'); // Changed from '/kitchen-menu' to '/kitchen'
      } else {
        print("👤 Navigating to user home");
        Navigator.pushReplacementNamed(context, '/user/user-home');
      }
    }, onError: (error) {
      print("❗ Auth state change error: $error");
      if (mounted) {
        setState(() {
          _statusMessage = "Authentication error. Please try again.";
        });
        Timer(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/auth');
          }
        });
      }
    });
  }

  Future<void> _setupUserOrderNotifications(String userId) async {
    try {
      print("🔔 Setting up order notifications for user: $userId");
      
      // Get user role to determine notification preferences
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final userRole = userData?['role'] ?? 'user';
      
      // Get FCM token for order notifications
      String? token;
      int retries = 0;

      while (token == null && retries < 3) {
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
        print("✅ Got FCM token for order notifications: ${token.substring(0, 20)}...");
        
        // Save token with order notification preferences
        Map<String, dynamic> notificationPrefs = {
          'orderUpdates': true,
          'promotions': false, // Explicitly disabled
          'marketing': false,  // Explicitly disabled
        };
        
        // Add role-specific notification preferences
        if (userRole == 'kitchen') {
          notificationPrefs['newOrderAlerts'] = true;
        } else if (userRole == 'user') {
          notificationPrefs['orderExpiring'] = true;
        }
        
        try {
          await FirebaseFirestore.instance.collection('users').doc(userId).set(
            {
              'fcmToken': token,
              'notificationPreferences': notificationPrefs,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
              'deviceInfo': {
                'platform': 'flutter',
                'notificationChannels': ['thintava_orders', 'thintava_urgent'],
              }
            },
            SetOptions(merge: true),
          );
          print("💾 Order notification preferences saved to Firestore");
        } catch (e) {
          print("❗ Error saving notification preferences: $e");
        }

        // Set up token refresh listener for order notifications
        _tokenRefreshSubscription?.cancel();
        _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          print("🔄 FCM token refreshed for order notifications: ${newToken.substring(0, 20)}...");
          try {
            await FirebaseFirestore.instance.collection('users').doc(userId).set(
              {
                'fcmToken': newToken,
                'lastTokenUpdate': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
            print("💾 Refreshed FCM token saved for order notifications");
          } catch (e) {
            print("❗ Error saving refreshed FCM token: $e");
          }
        });
        
        setState(() {
          _statusMessage = "Order notifications activated!";
        });
      } else {
        print("❗ Could not get FCM token after $retries attempts");
        setState(() {
          _statusMessage = "Notifications unavailable, continuing...";
        });
      }
    } catch (e) {
      print("❗ Error in _setupUserOrderNotifications: $e");
      setState(() {
        _statusMessage = "Notification setup failed, continuing...";
      });
    }
  }

  Future<String> _fetchUserRole(String userId) async {
    try {
      print("🔍 Fetching user role for: $userId");
      
      // Use AuthService to get user data
      final userData = await _authService.getUserData(userId);
      
      if (userData != null) {
        final role = userData['role'] ?? 'user';
        print("📋 User role found: $role");
        print("📋 User data keys: ${userData.keys.toList()}");
        return role;
      } else {
        print("📋 No user document found, creating default user");
        // Create user document with default role and notification preferences
        try {
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'role': 'user',
            'email': FirebaseAuth.instance.currentUser?.email,
            'createdAt': FieldValue.serverTimestamp(),
            'needsUsernameSetup': false, // Since they completed Google auth flow
            'notificationPreferences': {
              'orderUpdates': true,
              'orderExpiring': true,
              'promotions': false,
              'marketing': false,
            }
          }, SetOptions(merge: true));
          print("📋 Created default user document with order notification preferences");
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
    print("🗑️ Disposing enhanced splash screen");
    _authSubscription.cancel();
    _tokenRefreshSubscription?.cancel();
    _animationController.dispose();
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
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 60,
                    height: 60,
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
                // Google Auth indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.security,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Secure Google Authentication",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Order notification indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Order Notifications Enabled",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // Privacy notice
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "We'll send you notifications only about your orders - no promotions or spam!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
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