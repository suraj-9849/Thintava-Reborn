// lib/widgets/version_guard.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:canteen_app/services/update_service.dart';
import 'package:canteen_app/screens/update_required_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
  bool _isOffline = false;
  String _statusMessage = "Checking for updates...";

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
      // First check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        print('🔍 VersionGuard: No internet connection');
        if (mounted) {
          setState(() {
            _isOffline = true;
            _statusMessage = "No internet connection";
          });
          
          // Show retry after delay
          Timer(const Duration(seconds: 2), () {
            if (mounted && _isOffline) {
              setState(() {
                _statusMessage = "Tap to retry";
              });
            }
          });
        }
        return;
      }
      
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

  Future<void> _retryVersionCheck() async {
    setState(() {
      _isOffline = false;
      _statusMessage = "Checking for updates...";
    });
    
    await Future.delayed(const Duration(milliseconds: 500));
    _checkVersion();
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
                  // Show offline icon or loading spinner
                  _isOffline 
                    ? GestureDetector(
                        onTap: _retryVersionCheck,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: const Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      )
                    : const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _isOffline ? _retryVersionCheck : null,
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: _isOffline ? FontWeight.w600 : FontWeight.w500,
                        color: Colors.white,
                        decoration: _isOffline ? TextDecoration.underline : TextDecoration.none,
                      ),
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