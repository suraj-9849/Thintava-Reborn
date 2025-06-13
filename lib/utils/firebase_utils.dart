// lib/utils/firebase_utils.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';

// Global token refresh listener to avoid multiple listeners
StreamSubscription<String>? _tokenRefreshSubscription;

Future<void> saveInitialFCMToken() async {
  try {
    // Add delay to ensure Firebase is fully initialized
    await Future.delayed(const Duration(milliseconds: 500));
    
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Check if FCM is available
        String? token = await FirebaseMessaging.instance.getToken();
        
        if (token != null && token.isNotEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'fcmToken': token,
            'tokenUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          
          print('✅ Initial FCM token saved successfully');
          
          // Set up token refresh listener (only once)
          _setupTokenRefreshListener(user.uid);
        } else {
          print('⚠️ FCM token is null or empty');
        }
      } catch (tokenError) {
        print('❌ Error getting/saving FCM token: $tokenError');
        // Don't throw - continue without FCM if it fails
      }
    } else {
      print('⚠️ No authenticated user found for FCM token save');
    }
  } catch (e) {
    print('❌ Error in saveInitialFCMToken: $e');
    // Don't throw - this is not critical for app functionality
  }
}

// Set up token refresh listener (private method)
void _setupTokenRefreshListener(String uid) {
  try {
    // Cancel existing listener if any
    _tokenRefreshSubscription?.cancel();
    
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) async {
        try {
          // Only update token if user is still logged in and is the same user
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null && currentUser.uid == uid) {
            await FirebaseFirestore.instance.collection('users').doc(uid).set({
              'fcmToken': newToken,
              'tokenRefreshedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            
            print('✅ FCM token refreshed successfully');
          } else {
            print('⚠️ User changed or logged out, canceling token refresh');
            _tokenRefreshSubscription?.cancel();
          }
        } catch (e) {
          print('❌ Error updating refreshed FCM token: $e');
        }
      },
      onError: (error) {
        print('❌ FCM token refresh listener error: $error');
      },
    );
    
    print('📱 FCM token refresh listener set up');
  } catch (e) {
    print('❌ Error setting up token refresh listener: $e');
  }
}

Future<void> clearFCMToken() async {
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Cancel token refresh listener
        _tokenRefreshSubscription?.cancel();
        _tokenRefreshSubscription = null;
        
        // Remove token from Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmToken': null,
          'tokenClearedAt': FieldValue.serverTimestamp(),
        });
        
        // Delete the FCM token from Firebase Messaging
        await FirebaseMessaging.instance.deleteToken();
        
        print('✅ FCM token cleared successfully');
      } catch (firestoreError) {
        print('❌ Error clearing FCM token from Firestore: $firestoreError');
        
        // Still try to delete the local token even if Firestore update fails
        try {
          await FirebaseMessaging.instance.deleteToken();
          print('✅ Local FCM token deleted despite Firestore error');
        } catch (deleteError) {
          print('❌ Error deleting local FCM token: $deleteError');
        }
      }
    } else {
      print('⚠️ No authenticated user found for FCM token clear');
    }
  } catch (e) {
    print('❌ Error in clearFCMToken: $e');
    // Don't throw - continue with logout even if token clearing fails
  }
}

// Helper to check if FCM is available
Future<bool> isFCMAvailable() async {
  try {
    await FirebaseMessaging.instance.getToken();
    return true;
  } catch (e) {
    print('⚠️ FCM not available: $e');
    return false;
  }
}

// Safe FCM token refresh for manual calls
Future<void> refreshFCMToken(String uid) async {
  try {
    if (await isFCMAvailable()) {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': token,
          'manualRefreshAt': FieldValue.serverTimestamp(),
        });
        print('✅ FCM token manually refreshed');
      } else {
        print('⚠️ Failed to get token during manual refresh');
      }
    } else {
      print('⚠️ FCM not available for manual refresh');
    }
  } catch (e) {
    print('❌ Error manually refreshing FCM token: $e');
  }
}

// Cleanup method to call on app dispose
void disposeFCMListeners() {
  try {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    print('🛑 FCM listeners disposed');
  } catch (e) {
    print('❌ Error disposing FCM listeners: $e');
  }
}

// Get current FCM token (for debugging/testing)
Future<String?> getCurrentFCMToken() async {
  try {
    if (await isFCMAvailable()) {
      return await FirebaseMessaging.instance.getToken();
    }
    return null;
  } catch (e) {
    print('❌ Error getting current FCM token: $e');
    return null;
  }
}