// lib/services/update_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

class UpdateService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Check if app needs update
  static Future<UpdateCheckResult> checkForUpdate() async {
    try {
      print('🔄 UpdateService: Starting version check...');
      print('🔄 UpdateService: Checking Firebase connectivity...');
      
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.parse(packageInfo.buildNumber);
      
      print('📱 Current version: $currentVersion (Build: $currentBuildNumber)');
      
      // Get minimum required version from Firebase
      print('🔄 UpdateService: Fetching version_control document from Firebase...');
      final doc = await _firestore.collection('app_config').doc('version_control').get();
      
      if (!doc.exists) {
        print('⚠️ No version control document found - allowing app to continue');
        return UpdateCheckResult(
          needsUpdate: false,
          currentVersion: currentVersion,
          requiredVersion: currentVersion,
          updateUrl: '',
          message: '',
        );
      }
      
      final data = doc.data()!;
      final platform = Platform.isAndroid ? 'android' : 'ios';
      final platformData = data[platform] as Map<String, dynamic>?;
      
      if (platformData == null) {
        print('⚠️ No platform data found for $platform - allowing app to continue');
        return UpdateCheckResult(
          needsUpdate: false,
          currentVersion: currentVersion,
          requiredVersion: currentVersion,
          updateUrl: '',
          message: '',
        );
      }
      
      final requiredVersion = platformData['required_version'] as String? ?? '1.0.0';
      final requiredBuildNumber = platformData['required_build_number'] as int? ?? 1;
      final updateUrl = platformData['update_url'] as String? ?? '';
      final message = platformData['message'] as String? ?? 'Please update your app to continue.';
      final isForceUpdate = platformData['force_update'] as bool? ?? false;
      
      print('🏪 Required version: $requiredVersion (Build: $requiredBuildNumber)');
      print('🔒 Force update: $isForceUpdate');
      
      // Compare versions - we use build number for precise comparison
      print('🔍 Version Comparison Details:');
      print('   ════════════════════════════════');
      print('   Current App Version: $currentVersion');
      print('   Current Build Number: $currentBuildNumber');
      print('   Required App Version: $requiredVersion');
      print('   Required Build Number: $requiredBuildNumber');
      print('   Force Update Enabled: $isForceUpdate');
      print('   ════════════════════════════════');
      print('   Build Comparison: $currentBuildNumber < $requiredBuildNumber = ${currentBuildNumber < requiredBuildNumber}');
      
      // The app needs update if:
      // 1. Force update is enabled AND
      // 2. Current build number is less than required build number
      final needsUpdate = isForceUpdate && currentBuildNumber < requiredBuildNumber;
      
      print('   ════════════════════════════════');
      print('   🎯 FINAL DECISION: needsUpdate = $needsUpdate');
      print('   Logic: ($isForceUpdate && $currentBuildNumber < $requiredBuildNumber) = $needsUpdate');
      print('   ════════════════════════════════');
      
      if (needsUpdate) {
        print('❌ UPDATE REQUIRED: App is outdated and needs update');
        print('   User will be blocked from using the app');
      } else {
        print('✅ NO UPDATE NEEDED: App can continue normally');
      }
      
      return UpdateCheckResult(
        needsUpdate: needsUpdate,
        currentVersion: currentVersion,
        requiredVersion: requiredVersion,
        updateUrl: updateUrl,
        message: message,
        isForceUpdate: isForceUpdate,
      );
    } catch (e) {
      print('❌ Error checking for updates: $e');
      // On error, allow app to continue (graceful degradation)
      return UpdateCheckResult(
        needsUpdate: false,
        currentVersion: '1.0.0',
        requiredVersion: '1.0.0',
        updateUrl: '',
        message: '',
        error: e.toString(),
      );
    }
  }
  
  /// Get app info for display
  static Future<Map<String, String>> getAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'appName': packageInfo.appName,
        'packageName': packageInfo.packageName,
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'platform': Platform.isAndroid ? 'Android' : 'iOS',
      };
    } catch (e) {
      print('Error getting app info: $e');
      return {
        'appName': 'Thintava',
        'packageName': 'com.example.canteen_app',
        'version': '1.0.0',
        'buildNumber': '1',
        'platform': Platform.isAndroid ? 'Android' : 'iOS',
      };
    }
  }
}

class UpdateCheckResult {
  final bool needsUpdate;
  final String currentVersion;
  final String requiredVersion;
  final String updateUrl;
  final String message;
  final bool isForceUpdate;
  final String? error;

  UpdateCheckResult({
    required this.needsUpdate,
    required this.currentVersion,
    required this.requiredVersion,
    required this.updateUrl,
    required this.message,
    this.isForceUpdate = false,
    this.error,
  });

  bool get hasError => error != null;
}