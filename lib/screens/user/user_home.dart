// lib/screens/user/user_home.dart - OPTIMIZED VERSION
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
    
    _authService.startSessionListener(() {
      logout(context, forceLogout: true);
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

  void logout(BuildContext context, {bool forceLogout = false}) async {
    if (!forceLogout) {
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
    }
    
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    await cartProvider.cleanup();
    
    await _authService.logout();
    
    if (!forceLogout && context.mounted) {
      Navigator.of(context).pop();
    }
    
    if (context.mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();
    _authService.stopSessionListener();
    super.dispose();
  }

  void navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
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
      floatingActionButton: _currentIndex == 0
          ? CartFloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(context, '/cart');
              },
            )
          : null,
    );
  }
}