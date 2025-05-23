// lib/services/session_manager.dart
// This class manages user sessions to prevent multiple device logins
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
      final String? fcmToken = await FirebaseMessaging.instance.getToken();
      
      // First, check if we need to terminate other sessions
      await _terminateOtherSessions(user.uid, deviceId);
      
      // Then register the current session
      await _db.collection(_sessionCollection).doc(user.uid).set({
        'activeDeviceId': deviceId,
        'activeDeviceFcmToken': fcmToken,
        'lastLoginTime': FieldValue.serverTimestamp(),
        'email': user.email,
      });
      
      print('Session registered successfully for device: $deviceId');
    } catch (e) {
      print('Error registering session: $e');
    }
  }
  
  // Terminate other sessions for this user
  Future<void> _terminateOtherSessions(String userId, String currentDeviceId) async {
    try {
      // Get the user's current session document
      DocumentSnapshot sessionDoc = await _db.collection(_sessionCollection).doc(userId).get();
      
      if (sessionDoc.exists) {
        // If there's an existing session and it's not for this device
        final data = sessionDoc.data() as Map<String, dynamic>;
        final String? existingDeviceId = data['activeDeviceId'];
        
        if (existingDeviceId != null && existingDeviceId != currentDeviceId) {
          final String? existingFcmToken = data['activeDeviceFcmToken'];
          
          // Store the terminated session in history
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
          
          // Send notification to the other device if possible
          if (existingFcmToken != null) {
            // This would require a Cloud Function to send the notification
            // Here we just log it - you'll need to implement a notification sender
            print('Should notify device with token: $existingFcmToken');
          }
        }
      }
    } catch (e) {
      print('Error terminating other sessions: $e');
    }
  }
  
  // Check if this device is still the active session
  Future<bool> isActiveSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      final String deviceId = await _getDeviceId();
      DocumentSnapshot sessionDoc = await _db.collection(_sessionCollection).doc(user.uid).get();
      
      if (!sessionDoc.exists) return false;
      
      final data = sessionDoc.data() as Map<String, dynamic>;
      final String? activeDeviceId = data['activeDeviceId'];
      
      return activeDeviceId == deviceId;
    } catch (e) {
      print('Error checking session status: $e');
      return false;
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
      
      if (sessionDoc.exists) {
        final data = sessionDoc.data() as Map<String, dynamic>;
        final String? activeDeviceId = data['activeDeviceId'];
        
        // Only clear if this is the active device
        if (activeDeviceId == deviceId) {
          // Add to history before clearing
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
          
          // Clear the active session
          await _db.collection(_sessionCollection).doc(user.uid).delete();
        }
      }
    } catch (e) {
      print('Error clearing session: $e');
    }
  }
  
  // Set up a listener for session changes
  StreamSubscription<DocumentSnapshot>? _sessionListener;
  
  void startSessionListener(VoidCallback onForcedLogout) {
    final user = _auth.currentUser;
    if (user == null) return;
    
    _sessionListener = _db.collection(_sessionCollection)
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) {
        // Session document was deleted
        print('Session document no longer exists');
        onForcedLogout();
        return;
      }
      
      final data = snapshot.data() as Map<String, dynamic>;
      final activeDeviceId = data['activeDeviceId'];
      final deviceId = await _getDeviceId();
      
      if (activeDeviceId != deviceId) {
        // Another device is now active
        print('Another device is now the active session');
        onForcedLogout();
      }
    }, onError: (error) {
      print('Error in session listener: $error');
    });
  }
  
  void stopSessionListener() {
    _sessionListener?.cancel();
    _sessionListener = null;
  }
}