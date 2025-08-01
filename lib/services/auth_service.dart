// lib/services/auth_service.dart - FIXED VERSION (PREVENTS DIALOG ON INTENTIONAL LOGOUT)
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
  final SessionManager _sessionManager = SessionManager();

  // Flag to prevent session check during login process
  bool _isLoggingIn = false;
  
  // ADDED: Flag to prevent forced logout dialog during intentional logout
  bool _isIntentionalLogout = false;

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
      
      // Step 6: Handle user data (no username setup needed)
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

  // Handle user data after successful authentication - SIMPLIFIED
  Future<UserAuthResult> _handleUserData(User user) async {
    try {
      print('📝 Processing user data for: ${user.uid}');
      
      // Check if user document exists
      final userDoc = await _db.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        // New user - create document with all necessary info
        print('🆕 Creating new user document');
        
        await _db.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'provider': 'google',
          'isActive': true,
          // Remove username setup requirement
          'profileComplete': true,
        });
        
        // Update FCM token
        _updateFCMTokenAsync(user.uid);
        
        return UserAuthResult(
          user: user,
          isNewUser: true,
          needsUsernameSetup: false, // Changed to false
        );
      } else {
        // Existing user
        print('👤 Existing user found');
        
        final userData = userDoc.data() as Map<String, dynamic>;
        
        // Update user profile to ensure it's complete
        await _db.collection('users').doc(user.uid).update({
          'lastLoginTime': FieldValue.serverTimestamp(),
          'isActive': true,
          'profileComplete': true,
          // Update display name and photo if they changed
          'displayName': user.displayName,
          'photoURL': user.photoURL,
        });
        
        // Update FCM token
        _updateFCMTokenAsync(user.uid);
        
        return UserAuthResult(
          user: user,
          isNewUser: false,
          needsUsernameSetup: false, // Always false now
        );
      }
    } catch (e) {
      print('❌ Error handling user data: $e');
      // Return success anyway if Firebase auth worked
      return UserAuthResult(
        user: user,
        isNewUser: false,
        needsUsernameSetup: false, // Always false
      );
    }
  }

  // REMOVE OR KEEP AS LEGACY - setupUsername method
  @Deprecated('Username setup no longer required - using Gmail display names')
  Future<bool> setupUsername(String username) async {
    // Keep for backward compatibility but make it a no-op
    print('⚠️ setupUsername called but no longer required');
    return true;
  }

  // FIXED: Logout with session cleanup and intentional logout flag
  Future<void> logout() async {
    try {
      // IMPORTANT: Set intentional logout flag FIRST
      _isIntentionalLogout = true;
      print('🚪 Starting intentional logout - flag set to prevent forced logout dialog');
      
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
      
      // IMPORTANT: Reset the flag after logout is complete
      _isIntentionalLogout = false;
      
    } catch (e) {
      print('❌ Logout error: $e');
      // Reset flag on error too
      _isIntentionalLogout = false;
      
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

      // ADDED: Skip session check during intentional logout
      if (_isIntentionalLogout) {
        print('⏳ Skipping session check - intentional logout in progress');
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
  
  // FIXED: Start listening for session changes with intentional logout check
  void startSessionListener(VoidCallback onForcedLogout) {
    _sessionManager.startSessionListener(() {
      // ADDED: Check if this is an intentional logout before showing dialog
      if (_isIntentionalLogout) {
        print('🚪 Skipping forced logout callback - intentional logout in progress');
        return;
      }
      
      print('🚫 Forced logout triggered by session manager');
      onForcedLogout();
    });
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
  String? get currentUserDisplayName => _auth.currentUser?.displayName;
  String? get currentUserPhotoURL => _auth.currentUser?.photoURL;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ADDED: Getter to check if intentional logout is in progress (for debugging)
  bool get isIntentionalLogout => _isIntentionalLogout;

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

  // Helper method to get user display name
  String getUserDisplayName() {
    final user = currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!;
    } else if (user?.email != null) {
      // Extract name from email if display name is not available
      return user!.email!.split('@')[0];
    }
    return 'User';
  }
}

// Updated result class
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