// lib/widgets/version_guard.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:canteen_app/services/update_service.dart';
import 'package:canteen_app/screens/update_required_screen.dart';

class VersionGuard extends StatefulWidget {
  final Widget child;
  
  const VersionGuard({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<VersionGuard> createState() => _VersionGuardState();
}

class _VersionGuardState extends State<VersionGuard> {
  bool _isChecking = true;
  UpdateCheckResult? _updateResult;

  @override
  void initState() {
    super.initState();
    _checkVersion();
    
    // Fallback timer - if version check takes too long, continue anyway
    Timer(const Duration(seconds: 15), () {
      if (mounted && _isChecking) {
        print('⏰ VersionGuard: Timeout reached, allowing app to continue');
        setState(() {
          _isChecking = false;
          _updateResult = UpdateCheckResult(
            needsUpdate: false,
            currentVersion: '1.0.0',
            requiredVersion: '1.0.0',
            updateUrl: '',
            message: 'Version check timeout',
            error: 'Timeout after 15 seconds',
          );
        });
      }
    });
  }

  Future<void> _checkVersion() async {
    print('🔍 VersionGuard: Starting version check...');
    
    try {
      // Add a timeout to prevent infinite loading
      final result = await UpdateService.checkForUpdate()
          .timeout(const Duration(seconds: 10));
      
      print('🔍 VersionGuard: Version check completed');
      print('   Result: needsUpdate = ${result.needsUpdate}');
      print('   Force Update: ${result.isForceUpdate}');
      print('   Current: ${result.currentVersion}');
      print('   Required: ${result.requiredVersion}');
      
      if (mounted) {
        setState(() {
          _updateResult = result;
          _isChecking = false;
        });
        
        print('🔍 VersionGuard: State updated, _isChecking = false');
      }
    } catch (e) {
      print('❌ VersionGuard: Version check error: $e');
      
      if (mounted) {
        setState(() {
          _isChecking = false;
          // On error, allow app to continue (graceful degradation)
          _updateResult = UpdateCheckResult(
            needsUpdate: false,
            currentVersion: '1.0.0',
            requiredVersion: '1.0.0',
            updateUrl: '',
            message: 'Version check failed',
            error: e.toString(),
          );
        });
        
        print('🔍 VersionGuard: Error state updated, allowing app to continue');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 VersionGuard: build() called');
    print('   _isChecking = $_isChecking');
    print('   _updateResult?.needsUpdate = ${_updateResult?.needsUpdate}');
    
    // Show loading while checking
    if (_isChecking) {
      print('🔍 VersionGuard: Showing loading screen');
      
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFB703), Color(0xFFFFB703)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Container with shadow effect
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 60,
                      height: 60,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Thintava',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Checking for updates...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Show update screen if needed
    if (_updateResult?.needsUpdate == true) {
      print('🔍 VersionGuard: Showing update required screen');
      return UpdateRequiredScreen(updateResult: _updateResult!);
    }

    // Show normal app if no update needed
    print('🔍 VersionGuard: Showing normal app');
    return widget.child;
  }
}