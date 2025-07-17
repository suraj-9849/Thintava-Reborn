// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:canteen_app/services/session_manager.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final SessionManager _sessionManager = SessionManager();

  // Sign in with Google
  Future<UserAuthResult> signInWithGoogle() async {
    try {
      print('🔑 Starting Google Sign-In process...');
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        throw Exception('Sign-in was canceled');
      }
      
      print('✅ Google account selected: ${googleUser.email}');
      
      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Sign in to Firebase with the Google credential
      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;
      
      if (user != null) {
        print('✅ Firebase Auth successful for: ${user.email}');
        
        // Check if this is a new user or existing user
        bool isNewUser = await _checkIfNewUser(user.uid);
        
        if (isNewUser) {
          print('🆕 New user detected, needs username setup');
          
          // Create basic user document with Google info
          await _db.collection('users').doc(user.uid).set({
            'email': user.email,
            'displayName': user.displayName,
            'photoURL': user.photoURL,
            'role': 'user', // Default role
            'createdAt': FieldValue.serverTimestamp(),
            'provider': 'google',
            'needsUsernameSetup': true,
          });
          
          return UserAuthResult(
            user: user,
            isNewUser: true,
            needsUsernameSetup: true,
          );
        } else {
          print('👤 Existing user, checking username setup status');
          
          // Get user document to check username setup status
          final userDoc = await _db.collection('users').doc(user.uid).get();
          final userData = userDoc.data();
          final needsUsernameSetup = userData?['needsUsernameSetup'] ?? false;
          
          if (needsUsernameSetup) {
            return UserAuthResult(
              user: user,
              isNewUser: false,
              needsUsernameSetup: true,
            );
          } else {
            // Update FCM token for returning user
            await _updateFCMTokenSafely(user.uid, isLogin: true);
            
            return UserAuthResult(
              user: user,
              isNewUser: false,
              needsUsernameSetup: false,
            );
          }
        }
      } else {
        throw Exception('Google sign-in failed - no user returned');
      }
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = 'An account already exists with a different sign-in method.';
          break;
        case 'invalid-credential':
          errorMessage = 'The credential is invalid or expired.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Google sign-in is not enabled.';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled.';
          break;
        case 'user-not-found':
          errorMessage = 'No user found.';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password provided.';
          break;
        default:
          errorMessage = e.message ?? 'Google sign-in failed';
      }
      throw Exception(errorMessage);
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      throw Exception('Google sign-in failed: ${e.toString()}');
    }
  }

  // Set up username for new users
  Future<bool> setupUsername(String username) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }
      
      print('📝 Setting up username: $username for user: ${user.uid}');
      
      // Check if username is already taken
      final usernameExists = await _checkUsernameExists(username);
      if (usernameExists) {
        throw Exception('Username is already taken');
      }
      
      // Update user document with username
      await _db.collection('users').doc(user.uid).update({
        'username': username,
        'needsUsernameSetup': false,
        'usernameSetupAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update FCM token
      await _updateFCMTokenSafely(user.uid, isLogin: true);
      
      print('✅ Username setup completed successfully');
      return true;
    } catch (e) {
      print('❌ Error setting up username: $e');
      throw Exception('Failed to setup username: ${e.toString()}');
    }
  }

  // Check if username already exists
  Future<bool> _checkUsernameExists(String username) async {
    try {
      final query = await _db
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      
      return query.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking username existence: $e');
      return false; // Default to false to allow the attempt
    }
  }

  // Check if user is new (doesn't exist in Firestore)
  Future<bool> _checkIfNewUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return !doc.exists;
    } catch (e) {
      print('❌ Error checking if new user: $e');
      return true; // Default to true to be safe
    }
  }

  // Safe FCM Token update method
  Future<void> _updateFCMTokenSafely(String uid, {bool isRegistration = false, bool isLogin = false}) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      
      String? token = await FirebaseMessaging.instance.getToken();
      print('📱 FCM Token retrieved: ${token != null ? 'Success' : 'Failed'}');
      
      if (token != null && token.isNotEmpty) {
        Map<String, dynamic> updateData = {
          'fcmToken': token,
        };
        
        if (isRegistration) {
          updateData['registrationTime'] = FieldValue.serverTimestamp();
        }
        if (isLogin) {
          updateData['lastLoginTime'] = FieldValue.serverTimestamp();
        }
        
        await _db.collection('users').doc(uid).update(updateData);
        print('✅ FCM token updated successfully');
      } else {
        print('⚠️ FCM token is null or empty, skipping update');
      }
    } catch (e) {
      print('❌ Error updating FCM token: $e');
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _clearFCMTokenSafely(user.uid);
      }
      
      // Sign out from Google
      await _googleSignIn.signOut();
      
      // Sign out from Firebase Auth
      await _auth.signOut();
      print('✅ User logged out successfully');
    } catch (e) {
      print('❌ Error during logout: $e');
      try {
        await _auth.signOut();
        print('✅ Force sign out successful');
      } catch (signOutError) {
        print('❌ Error signing out: $signOutError');
        rethrow;
      }
    }
  }

  // Safe FCM Token clearing method
  Future<void> _clearFCMTokenSafely(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': null,
        'lastLogoutTime': FieldValue.serverTimestamp(),
      });
      
      await FirebaseMessaging.instance.deleteToken();
      print('✅ FCM token cleared successfully');
    } catch (e) {
      print('❌ Error clearing FCM token: $e');
    }
  }

  // Check if this device is still the active session
  Future<bool> checkActiveSession() async {
    return true; // Temporarily disabled
  }
  
  // Start listening for session changes
  void startSessionListener(VoidCallback onForcedLogout) {
    print('📱 Session listener temporarily disabled');
  }
  
  // Stop listening for session changes
  void stopSessionListener() {
    print('🛑 Session listener stop temporarily disabled');
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get user role from Firestore
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return data['role'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  // Get current user's role
  Future<String> getCurrentUserRole() async {
    final user = currentUser;
    if (user != null) {
      final role = await getUserRole(user.uid);
      return role ?? 'user';
    }
    return 'user';
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  // Get current user's email
  String? get currentUserEmail => _auth.currentUser?.email;

  // Get current user's UID
  String? get currentUserUid => _auth.currentUser?.uid;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Update user profile
  Future<void> updateUserProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.updatePhotoURL(photoURL);
        
        await _db.collection('users').doc(user.uid).update({
          'displayName': displayName,
          'photoURL': photoURL,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating user profile: $e');
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  // Reload user data
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      print('Error reloading user: $e');
    }
  }

  // Delete user account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Delete user data from Firestore
        await _db.collection('users').doc(user.uid).delete();
        
        // Sign out from Google
        await _googleSignIn.signOut();
        
        // Delete the user account
        await user.delete();
        
        print('✅ User account deleted successfully');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'requires-recent-login':
          errorMessage = 'Please log in again before deleting your account.';
          break;
        default:
          errorMessage = e.message ?? 'Failed to delete account';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }
}

// Result class for authentication
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