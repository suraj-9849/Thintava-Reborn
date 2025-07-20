// lib/services/auth_service.dart - WITH DEVICE MANAGEMENT ENABLED
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'package:canteen_app/services/session_manager.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final SessionManager _sessionManager = SessionManager(); // ENABLED

  // Flag to prevent session check during login process
  bool _isLoggingIn = false;

  // Simple Google Sign-In with Device Management
  Future<UserAuthResult> signInWithGoogle() async {
    try {
      _isLoggingIn = true;
      print('🔑 Starting Google Sign-In process...');
      
      // Clear any previous sign-in state
      await _googleSignIn.signOut();
      
      // Step 1: Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Sign-in was canceled');
      }
      
      print('✅ Google account selected: ${googleUser.email}');
      
      // Step 2: Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Step 3: Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      print('🔑 Signing in to Firebase...');
      
      // Step 4: Firebase sign-in
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      
      if (user == null) {
        throw Exception('Firebase sign-in failed - no user returned');
      }
      
      print('✅ Firebase sign-in successful: ${user.email}');
      
      // Step 5: Register device session BEFORE handling user data
      await _sessionManager.registerSession(user);
      print('✅ Device session registered');
      
      // Step 6: Handle user data
      final result = await _handleUserData(user);
      
      _isLoggingIn = false;
      return result;
      
    } on PlatformException catch (e) {
      _isLoggingIn = false;
      print('❌ Platform error: ${e.code} - ${e.message}');
      throw Exception(_getPlatformErrorMessage(e));
    } on FirebaseAuthException catch (e) {
      _isLoggingIn = false;
      print('❌ Firebase error: ${e.code} - ${e.message}');
      throw Exception(_getFirebaseErrorMessage(e));
    } catch (e) {
      _isLoggingIn = false;
      print('❌ General error: $e');
      
      // Handle the specific type casting error
      String errorStr = e.toString();
      if (errorStr.contains('PigeonUserDetails') || 
          errorStr.contains('List<Object?>') ||
          errorStr.contains('type cast')) {
        // This is a known compatibility issue - try a different approach
        print('🔄 Attempting fallback authentication...');
        return await _fallbackSignIn();
      }
      
      throw Exception('Sign-in failed. Please try again.');
    }
  }

  // Fallback sign-in method for compatibility issues
  Future<UserAuthResult> _fallbackSignIn() async {
    try {
      // Check if user is already signed in to Firebase
      User? currentUser = _auth.currentUser;
      
      if (currentUser != null) {
        print('✅ Using existing Firebase session: ${currentUser.email}');
        
        // Register session for fallback too
        await _sessionManager.registerSession(currentUser);
        print('✅ Device session registered (fallback)');
        
        return await _handleUserData(currentUser);
      }
      
      throw Exception('Fallback authentication failed');
    } catch (e) {
      print('❌ Fallback error: $e');
      throw Exception('Authentication failed. Please restart the app and try again.');
    }
  }

  // Handle user data after successful authentication
  Future<UserAuthResult> _handleUserData(User user) async {
    try {
      print('📝 Processing user data for: ${user.uid}');
      
      // Check if user document exists
      final userDoc = await _db.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        // New user - create document
        print('🆕 Creating new user document');
        
        await _db.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'provider': 'google',
          'needsUsernameSetup': true,
          'isActive': true,
        });
        
        // Update FCM token
        _updateFCMTokenAsync(user.uid);
        
        return UserAuthResult(
          user: user,
          isNewUser: true,
          needsUsernameSetup: true,
        );
      } else {
        // Existing user
        print('👤 Existing user found');
        
        final userData = userDoc.data() as Map<String, dynamic>;
        final needsUsernameSetup = userData['needsUsernameSetup'] ?? false;
        
        // Update last login
        await _db.collection('users').doc(user.uid).update({
          'lastLoginTime': FieldValue.serverTimestamp(),
          'isActive': true,
        });
        
        // Update FCM token
        _updateFCMTokenAsync(user.uid);
        
        return UserAuthResult(
          user: user,
          isNewUser: false,
          needsUsernameSetup: needsUsernameSetup,
        );
      }
    } catch (e) {
      print('❌ Error handling user data: $e');
      // Return success anyway if Firebase auth worked
      return UserAuthResult(
        user: user,
        isNewUser: true,
        needsUsernameSetup: true,
      );
    }
  }

  // Setup username
  Future<bool> setupUsername(String username) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }
      
      final trimmedUsername = username.trim();
      
      // Validate username
      if (trimmedUsername.isEmpty) {
        throw Exception('Please enter a username');
      }
      
      if (trimmedUsername.length < 3) {
        throw Exception('Username must be at least 3 characters');
      }
      
      if (trimmedUsername.length > 20) {
        throw Exception('Username must be less than 20 characters');
      }
      
      // Check for valid characters
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmedUsername)) {
        throw Exception('Username can only contain letters, numbers, and underscores');
      }
      
      // Check if username exists
      final querySnapshot = await _db
          .collection('users')
          .where('username', isEqualTo: trimmedUsername)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        throw Exception('Username is already taken');
      }
      
      // Update user document
      await _db.collection('users').doc(user.uid).update({
        'username': trimmedUsername,
        'needsUsernameSetup': false,
        'usernameSetupAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Username setup completed: $trimmedUsername');
      return true;
    } catch (e) {
      print('❌ Username setup error: $e');
      rethrow;
    }
  }

  // Logout with session cleanup
  Future<void> logout() async {
    try {
      final user = _auth.currentUser;
      
      if (user != null) {
        // Clear device session FIRST
        await _sessionManager.clearSession();
        print('✅ Device session cleared');
        
        // Update user status (non-blocking)
        _db.collection('users').doc(user.uid).update({
          'isActive': false,
          'lastLogoutTime': FieldValue.serverTimestamp(),
          'fcmToken': null,
        }).catchError((error) {
          print('⚠️ User status update failed: $error');
        });
      }
      
      // Sign out from both services
      await _googleSignIn.signOut();
      await _auth.signOut();
      
      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout error: $e');
      // Force logout
      try {
        await _sessionManager.clearSession();
        await _googleSignIn.signOut();
        await _auth.signOut();
      } catch (forceError) {
        print('❌ Force logout error: $forceError');
      }
    }
  }

  // DEVICE MANAGEMENT METHODS - ENABLED

  // Check if this device is still the active session
  Future<bool> checkActiveSession() async {
    try {
      // SKIP session check during login process
      if (_isLoggingIn) {
        print('⏳ Skipping session check - login in progress');
        return true;
      }

      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No current user for session check');
        return false;
      }

      return await _sessionManager.isActiveSession();
    } catch (e) {
      print('Error checking active session: $e');
      return true; // Default to true to avoid blocking user during errors
    }
  }
  
  // Start listening for session changes
  void startSessionListener(VoidCallback onForcedLogout) {
    _sessionManager.startSessionListener(onForcedLogout);
  }
  
  // Stop listening for session changes
  void stopSessionListener() {
    _sessionManager.stopSessionListener();
  }

  // Async FCM token update (non-blocking)
  void _updateFCMTokenAsync(String uid) {
    FirebaseMessaging.instance.getToken().then((token) {
      if (token != null && token.isNotEmpty) {
        _db.collection('users').doc(uid).update({
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        }).then((_) {
          print('✅ FCM token updated');
        }).catchError((error) {
          print('⚠️ FCM token update failed: $error');
        });
      }
    }).catchError((error) {
      print('⚠️ FCM token retrieval failed: $error');
    });
  }

  // Error message helpers
  String _getPlatformErrorMessage(PlatformException e) {
    switch (e.code) {
      case 'sign_in_failed':
        return 'Google Sign-In failed. Please try again.';
      case 'sign_in_canceled':
        return 'Sign-in was canceled';
      case 'network_error':
        return 'Network error. Please check your connection.';
      default:
        return 'Authentication error. Please try again.';
    }
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'Account exists with different sign-in method';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  // Getters
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  String? get currentUserEmail => _auth.currentUser?.email;
  String? get currentUserUid => _auth.currentUser?.uid;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // User data methods
  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['role'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting user role: $e');
      return 'user';
    }
  }

  Future<String> getCurrentUserRole() async {
    final user = currentUser;
    if (user != null) {
      final role = await getUserRole(user.uid);
      return role ?? 'user';
    }
    return 'user';
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
}

// Result class
class UserAuthResult {
  final User user;
  final bool isNewUser;
  final bool needsUsernameSetup;

  UserAuthResult({
    required this.user,
    required this.isNewUser,
    required this.needsUsernameSetup,
  });
}