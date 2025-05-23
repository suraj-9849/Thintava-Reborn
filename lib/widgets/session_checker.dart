// lib/widgets/session_checker.dart
import 'package:flutter/material.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';

class SessionChecker extends StatefulWidget {
  final Widget child;
  final AuthService authService;

  const SessionChecker({
    Key? key,
    required this.child,
    required this.authService,
  }) : super(key: key);

  @override
  State<SessionChecker> createState() => _SessionCheckerState();
}

class _SessionCheckerState extends State<SessionChecker> {
  bool _checking = true;
  bool _isValidSession = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final isActive = await widget.authService.checkActiveSession();
      if (mounted) {
        setState(() {
          _checking = false;
          _isValidSession = isActive;
        });
      }

      // If not a valid session, logout and show message
      if (!isActive && mounted) {
        await widget.authService.logout();
        _showSessionExpiredDialog();
      }
    } catch (e) {
      print('Error checking session: $e');
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Session Expired',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Your account has been logged in on another device. For security reasons, you have been logged out.',
          style: GoogleFonts.poppins(
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/auth', 
                (route) => false,
              );
            },
            child: Text(
              'OK', 
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFFB703),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If still checking or if the session is valid, show the child widget
    if (_checking || _isValidSession) {
      return widget.child;
    }

    // Otherwise, show a loading indicator while we handle the logout
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
            ),
            const SizedBox(height: 16),
            Text(
              'Checking session...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}