// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:canteen_app/services/session_manager.dart'; // Import the SessionManager

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SessionManager _sessionManager = SessionManager(); // Add SessionManager

  // Register User
  Future<User?> register(String email, String password, String role) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;

      // Save role in Firestore
      await _db.collection('users').doc(user!.uid).set({
        'email': email,
        'role': role,
      });

      // Register session for this device
      await _sessionManager.registerSession(user);

      return user;
    } catch (e) {
      rethrow;
    }
  }

  // Login User
  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      
      if (user != null) {
        // Register session for this device (will terminate other sessions)
        await _sessionManager.registerSession(user);
        
        // Update FCM token
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _db.collection('users').doc(user.uid).update({
            'fcmToken': token,
          });
        }
      }
      
      return user;
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      // Clear session before signing out
      await _sessionManager.clearSession();
      
      // Remove FCM token before signing out
      User? user = _auth.currentUser;
      if (user != null) {
        await _db.collection('users').doc(user.uid).update({
          'fcmToken': null, // Remove the FCM token
        });
        
        // Delete the FCM token from Firebase Messaging
        await FirebaseMessaging.instance.deleteToken();
      }
      
      // Then sign out
      await _auth.signOut();
    } catch (e) {
      print('Error during logout: $e');
      // Still attempt to sign out even if token removal fails
      await _auth.signOut();
    }
  }

  // Check if this device is still the active session
  Future<bool> checkActiveSession() {
    return _sessionManager.isActiveSession();
  }
  
  // Start listening for session changes
  void startSessionListener(VoidCallback onForcedLogout) {
    _sessionManager.startSessionListener(onForcedLogout);
  }
  
  // Stop listening for session changes
  void stopSessionListener() {
    _sessionManager.stopSessionListener();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get user role from Firestore
  Future<String?> getUserRole(String uid) async {
    DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
    return doc['role'];
  }
}