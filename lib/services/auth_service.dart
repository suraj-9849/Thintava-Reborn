// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Add this import

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

      return user;
    } catch (e) {
      rethrow;
    }
  }

  // Login User
  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
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

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get user role from Firestore
  Future<String?> getUserRole(String uid) async {
    DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
    return doc['role'];
  }
}