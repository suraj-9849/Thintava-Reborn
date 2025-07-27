// lib/presentation/widgets/user/simple_canteen_closed_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SimpleCanteenClosedWidget extends StatefulWidget {
  const SimpleCanteenClosedWidget({Key? key}) : super(key: key);

  @override
  State<SimpleCanteenClosedWidget> createState() => _SimpleCanteenClosedWidgetState();
}

class _SimpleCanteenClosedWidgetState extends State<SimpleCanteenClosedWidget> 
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _fadeController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _bounceController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: -10.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
    _bounceController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAnimatedIcon(),
              const SizedBox(height: 32),
              _buildMainMessage(),
              const SizedBox(height: 24),
              _buildInfoCard(),
              const SizedBox(height: 24),
              _buildRefreshButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon() {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.orange[600],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainMessage() {
    return Column(
      children: [
        Text(
          "Canteen is Currently Closed",
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "No menus are currently enabled. Please check back later when the canteen is operational.",
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.grey[600],
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue[700],
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What to do?',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The canteen admin will enable menus when food is available. Check back periodically or tap refresh below.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return ElevatedButton.icon(
      onPressed: () {
        // This will trigger the parent to rebuild and check canteen status again
        if (mounted) {
          // Find the parent widget and trigger a refresh
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          } else {
            // If we can't pop, just rebuild the current widget
            setState(() {});
          }
        }
      },
      icon: const Icon(Icons.refresh),
      label: Text(
        'Check Again',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFB703),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        shadowColor: const Color(0xFFFFB703).withOpacity(0.5),
      ),
    );
  }
}