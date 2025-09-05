// lib/screens/user/user_home.dart - FIXED VERSION (PREVENTS DIALOG ON INTENTIONAL LOGOUT)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:canteen_app/screens/user/order_tracking_screen.dart';
import 'package:canteen_app/screens/user/order_history_screen.dart';
import 'package:canteen_app/screens/user/profile_screen.dart';
import 'package:canteen_app/presentation/widgets/navigation/bottom_nav_bar.dart';
import 'package:canteen_app/presentation/widgets/navigation/cart_fab.dart';
import 'home/home_tab.dart';

class UserHome extends StatefulWidget {
  final int initialIndex;
  
  const UserHome({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final _authService = AuthService();
  late int _currentIndex;
  final PageController _pageController = PageController();
  
  // ADDED: Flag to track if we're in intentional logout process
  bool _isLoggingOut = false;
  
  // ADDED: Flag to control when page changes are programmatic vs manual
  bool _isAnimatingProgrammatically = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    
    _initializeAnimations();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialIndex != 0) {
        _pageController.animateToPage(
          widget.initialIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
    
    // FIXED: Enhanced session listener with intentional logout check
    _authService.startSessionListener(() {
      // Only show dialog if we're not in an intentional logout process
      if (!_isLoggingOut && mounted) {
        logout(context, forceLogout: true);
      } else {
        print('🚪 Skipping forced logout - intentional logout in progress or widget disposed');
      }
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
  }

  // FIXED: Enhanced logout method with intentional logout flag
  void logout(BuildContext context, {bool forceLogout = false}) async {
    // Prevent multiple logout attempts
    if (_isLoggingOut) {
      print('🚪 Logout already in progress, skipping');
      return;
    }
    
    if (!forceLogout) {
      // Set the flag BEFORE starting logout process
      setState(() {
        _isLoggingOut = true;
      });
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          backgroundColor: Colors.white,
          elevation: 20,
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB703).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFFFB703),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Logging Out',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                'Thank you for visiting!',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
      
      await Future.delayed(const Duration(seconds: 2));
    } else {
      // For forced logout, also set the flag
      setState(() {
        _isLoggingOut = true;
      });
      print('🚫 Forced logout initiated');
    }
    
    try {
      // Clean up cart first
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.cleanup();
      print('✅ Cart cleaned up during logout');
      
      // Perform the actual logout
      await _authService.logout();
      print('✅ AuthService logout completed');
      
    } catch (e) {
      print('❌ Error during logout: $e');
    }
    
    // Navigate to auth screen
    if (!forceLogout && context.mounted) {
      Navigator.of(context).pop(); // Close the dialog
    }
    
    if (context.mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
      Navigator.of(context).pushReplacementNamed('/auth');
    }
    
    // Reset the logout flag
    if (mounted) {
      setState(() {
        _isLoggingOut = false;
      });
    }
  }

  @override
  void dispose() {
    // Stop session listener and cleanup
    _authService.stopSessionListener();
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void navigateToTab(int index) {
    if (_isLoggingOut) {
      print('🚪 Ignoring navigation - logout in progress');
      return;
    }
    
    // Set flag to indicate programmatic navigation
    _isAnimatingProgrammatically = true;
    
    setState(() {
      _currentIndex = index;
    });
    
    // Use jumpToPage for instant navigation, but keep animateToPage for smooth transition
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200), // Reduced duration for snappier feel
      curve: Curves.fastOutSlowIn, // Changed to a more direct curve
    ).then((_) {
      // Reset flag after animation completes
      _isAnimatingProgrammatically = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading if logout is in progress
    if (_isLoggingOut) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                'Logging out...',
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
    
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          // Only update index if this is a manual swipe (not programmatic navigation)
          if (!_isLoggingOut && !_isAnimatingProgrammatically) {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        children: [
          HomeTab(
            fadeAnimation: _fadeAnimation,
            onNavigateToTab: navigateToTab,
          ),
          const OrderTrackingScreen(),
          const OrderHistoryScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: navigateToTab,
      ),
      floatingActionButton: (_currentIndex == 0 && !_isLoggingOut)
          ? CartFloatingActionButton(
              onPressed: () {
                if (!_isLoggingOut) {
                  Navigator.pushNamed(context, '/cart');
                }
              },
            )
          : null,
    );
  }
}