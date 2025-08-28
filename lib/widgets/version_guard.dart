// lib/widgets/version_guard.dart
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
  }

  Future<void> _checkVersion() async {
    try {
      final result = await UpdateService.checkForUpdate();
      
      if (mounted) {
        setState(() {
          _updateResult = result;
          _isChecking = false;
        });
      }
    } catch (e) {
      print('Version check error: $e');
      
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking
    if (_isChecking) {
      
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Checking for updates...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show update screen if needed
    if (_updateResult?.needsUpdate == true) {
      return UpdateRequiredScreen(updateResult: _updateResult!);
    }

    // Show normal app if no update needed
    return widget.child;
  }
}