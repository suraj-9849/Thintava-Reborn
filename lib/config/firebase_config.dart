// lib/config/firebase_config.dart - DYNAMIC FIREBASE CONFIGURATION
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  // Currently selected project
  static String _currentProject = 'thintava-ee4f4'; // Default project
  
  // Define all your Firebase projects here
  static const Map<String, FirebaseOptions> _firebaseConfigs = {
    'thintava-ee4f4': FirebaseOptions(
      apiKey: kIsWeb ? "AIzaSyCPsu2kuSKa9KezLhZNJWUF4B_n5kMqo4g" : "AIzaSyCjCCnzeERfNzxA28wz0dVdbC6Cs6b8R_U",
      appId: kIsWeb ? "1:626390741302:web:0579424d3bba31c12ec397" : "1:626390741302:android:1c149a60f3ac2f952ec397",
      messagingSenderId: "626390741302",
      projectId: "thintava-ee4f4",
      storageBucket: "thintava-ee4f4.firebasestorage.app",
      // Add authDomain for web
      authDomain: kIsWeb ? "thintava-ee4f4.firebaseapp.com" : null,
    ),
    
    // Add more projects as needed:
    // 'canteen-branch-2': FirebaseOptions(
    //   apiKey: "your-second-canteen-api-key",
    //   appId: "your-second-canteen-app-id",
    //   messagingSenderId: "your-sender-id",
    //   projectId: "canteen-branch-2",
    //   storageBucket: "canteen-branch-2.firebasestorage.app",
    //   authDomain: kIsWeb ? "canteen-branch-2.firebaseapp.com" : null,
    // ),
    
    // 'canteen-branch-3': FirebaseOptions(
    //   apiKey: "your-third-canteen-api-key", 
    //   appId: "your-third-canteen-app-id",
    //   messagingSenderId: "your-sender-id",
    //   projectId: "canteen-branch-3",
    //   storageBucket: "canteen-branch-3.firebasestorage.app",
    //   authDomain: kIsWeb ? "canteen-branch-3.firebaseapp.com" : null,
    // ),
  };

  // Get current Firebase configuration
  static FirebaseOptions getCurrentConfig() {
    final config = _firebaseConfigs[_currentProject];
    if (config == null) {
      throw Exception('Firebase config not found for project: $_currentProject');
    }
    return config;
  }
  
  // Switch to different Firebase project (for multi-canteen support)
  static void switchProject(String projectId) {
    if (!_firebaseConfigs.containsKey(projectId)) {
      throw Exception('Firebase config not found for project: $projectId');
    }
    _currentProject = projectId;
    print('🔄 Switched to Firebase project: $projectId');
  }
  
  // Get current project ID
  static String getCurrentProjectId() {
    return _currentProject;
  }
  
  // Get all available projects
  static List<String> getAvailableProjects() {
    return _firebaseConfigs.keys.toList();
  }
  
  // Check if project exists
  static bool hasProject(String projectId) {
    return _firebaseConfigs.containsKey(projectId);
  }
  
  // Get project display name (you can customize this)
  static String getProjectDisplayName(String projectId) {
    switch (projectId) {
      case 'thintava-ee4f4':
        return 'Main Canteen';
      // case 'canteen-branch-2':
      //   return 'Branch 2 Canteen';  
      // case 'canteen-branch-3':
      //   return 'Branch 3 Canteen';
      default:
        return projectId;
    }
  }
  
  // Add new project configuration dynamically
  static void addProject(String projectId, FirebaseOptions options) {
    // In a production app, you might want to validate the options first
    _firebaseConfigs[projectId] = options;
    print('➕ Added new Firebase project: $projectId');
  }
  
  // Remove project configuration
  static void removeProject(String projectId) {
    if (projectId == _currentProject) {
      throw Exception('Cannot remove currently active project: $projectId');
    }
    _firebaseConfigs.remove(projectId);
    print('➖ Removed Firebase project: $projectId');
  }
  
  // Debug: Print current configuration (without sensitive data)
  static void debugPrintCurrentConfig() {
    final config = getCurrentConfig();
    print('🔧 Current Firebase Config:');
    print('   Project ID: ${config.projectId}');
    print('   App ID: ${config.appId}');
    print('   Sender ID: ${config.messagingSenderId}');
    print('   Storage Bucket: ${config.storageBucket}');
    print('   API Key: ${config.apiKey.substring(0, 10)}...');
  }
}