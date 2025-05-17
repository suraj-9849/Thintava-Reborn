// lib/utils/firebase_utils.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> saveInitialFCMToken() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      // Only update token if user is still logged in
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': newToken,
        }, SetOptions(merge: true));
      }
    });
  }
}

Future<void> clearFCMToken() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    try {
      // Remove token from Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fcmToken': null,
      });
      
      // Delete the FCM token
      await FirebaseMessaging.instance.deleteToken();
      
      print('FCM token cleared successfully');
    } catch (e) {
      print('Error clearing FCM token: $e');
    }
  }
}