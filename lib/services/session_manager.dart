// lib/services/session_manager.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class SessionManager {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  // Collection name for session management
  static const String _sessionCollection = 'user_sessions';
  
  // Get current device identifier
  Future<String> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios_device';
      }
      return 'unknown_device';
    } catch (e) {
      print('Error getting device info: $e');
      return 'error_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
  
  // Register a new session for the current device
  Future<void> registerSession(User user) async {
    try {
      final String deviceId = await _getDeviceId();
      String? fcmToken;
      
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        print('Error getting FCM token: $e');
        // Continue without FCM token
      }
      
      // First, check if we need to terminate other sessions
      await _terminateOtherSessions(user.uid, deviceId);
      
      // Then register the current session with retry logic
      int retries = 3;
      while (retries > 0) {
        try {
          await _db.collection(_sessionCollection).doc(user.uid).set({
            'activeDeviceId': deviceId,
            'activeDeviceFcmToken': fcmToken,
            'lastLoginTime': FieldValue.serverTimestamp(),
            'email': user.email,
            'userId': user.uid,
          });
          
          print('✅ Session registered successfully for device: $deviceId');
          break;
        } catch (e) {
          retries--;
          print('Error registering session (retries left: $retries): $e');
          if (retries == 0) {
            print('Failed to register session after 3 attempts');
          } else {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }
    } catch (e) {
      print('Error in registerSession: $e');
      // Don't throw error - session management shouldn't break login
    }
  }
  
  // Terminate other sessions for this user
  Future<void> _terminateOtherSessions(String userId, String currentDeviceId) async {
    try {
      // Get the user's current session document
      DocumentSnapshot sessionDoc = await _db.collection(_sessionCollection).doc(userId).get();
      
      if (sessionDoc.exists && sessionDoc.data() != null) {
        // If there's an existing session and it's not for this device
        final data = sessionDoc.data() as Map<String, dynamic>;
        final String? existingDeviceId = data['activeDeviceId'];
        
        if (existingDeviceId != null && existingDeviceId != currentDeviceId) {
          final String? existingFcmToken = data['activeDeviceFcmToken'];
          
          // Store the terminated session in history
          try {
            await _db.collection(_sessionCollection)
                .doc(userId)
                .collection('history')
                .add({
                  'deviceId': existingDeviceId,
                  'fcmToken': existingFcmToken,
                  'loginTime': data['lastLoginTime'],
                  'logoutTime': FieldValue.serverTimestamp(),
                  'logoutReason': 'Logged in on another device',
                });
          } catch (e) {
            print('Error storing session history: $e');
          }
          
          print('🔄 Terminated session for device: $existingDeviceId');
        } else {
          print('🔄 Same device login or no existing device ID');
        }
      } else {
        print('🔄 No existing session found for user');
      }
    } catch (e) {
      print('Error terminating other sessions: $e');
    }
  }
  
  // Check if this device is still the active session
  Future<bool> isActiveSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No current user for session check');
        return false;
      }
      
      final String deviceId = await _getDeviceId();
      print('🔍 Checking session for device: $deviceId');
      
      DocumentSnapshot sessionDoc = await _db.collection(_sessionCollection).doc(user.uid).get();
      
      if (!sessionDoc.exists || sessionDoc.data() == null) {
        print('❌ No session document exists');
        return false;
      }
      
      final data = sessionDoc.data() as Map<String, dynamic>;
      final String? activeDeviceId = data['activeDeviceId'];
      
      final isActive = activeDeviceId == deviceId;
      print('🔍 Session check: activeDeviceId=$activeDeviceId, currentDeviceId=$deviceId, isActive=$isActive');
      
      return isActive;
    } catch (e) {
      print('Error checking session status: $e');
      return true; // Default to true to avoid blocking user
    }
  }
  
  // Clear the current session on logout
  Future<void> clearSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final String deviceId = await _getDeviceId();
      
      // Get current session
      DocumentSnapshot sessionDoc = await _db.collection(_sessionCollection).doc(user.uid).get();
      
      if (sessionDoc.exists && sessionDoc.data() != null) {
        final data = sessionDoc.data() as Map<String, dynamic>;
        final String? activeDeviceId = data['activeDeviceId'];
        
        // Only clear if this is the active device
        if (activeDeviceId == deviceId) {
          // Add to history before clearing
          try {
            await _db.collection(_sessionCollection)
                .doc(user.uid)
                .collection('history')
                .add({
                  'deviceId': deviceId,
                  'fcmToken': data['activeDeviceFcmToken'],
                  'loginTime': data['lastLoginTime'],
                  'logoutTime': FieldValue.serverTimestamp(),
                  'logoutReason': 'Manual logout',
                });
          } catch (e) {
            print('Error storing logout history: $e');
          }
          
          // Clear the active session
          await _db.collection(_sessionCollection).doc(user.uid).delete();
          print('🗑️ Session cleared for device: $deviceId');
        }
      }
    } catch (e) {
      print('Error clearing session: $e');
    }
  }
  
  // Set up a listener for session changes
  StreamSubscription<DocumentSnapshot>? _sessionListener;
  
  void startSessionListener(VoidCallback onForcedLogout) {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      print('👂 Starting session listener for user: ${user.uid}');
      
      _sessionListener = _db.collection(_sessionCollection)
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) async {
        try {
          if (!snapshot.exists || snapshot.data() == null) {
            // Session document was deleted
            print('❌ Session document no longer exists - forced logout');
            onForcedLogout();
            return;
          }
          
          final data = snapshot.data() as Map<String, dynamic>;
          final activeDeviceId = data['activeDeviceId'];
          final deviceId = await _getDeviceId();
          
          print('📱 Session listener: activeDeviceId=$activeDeviceId, currentDeviceId=$deviceId');
          
          if (activeDeviceId != deviceId) {
            // Another device is now active
            print('❌ Another device is now the active session - forced logout');
            onForcedLogout();
          }
        } catch (e) {
          print('Error in session listener callback: $e');
        }
      }, onError: (error) {
        print('Error in session listener: $error');
      });
    } catch (e) {
      print('Error starting session listener: $e');
    }
  }
  
  void stopSessionListener() {
    _sessionListener?.cancel();
    _sessionListener = null;
    print('🛑 Session listener stopped');
  }
}