import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class UserHome extends StatefulWidget {
  const UserHome({Key? key}) : super(key: key);

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _cardAnimation1;
  late Animation<Offset> _cardAnimation2;
  late Animation<Offset> _cardAnimation3;
  late Animation<Offset> _cardAnimation4;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Overall fade-in animation for the content
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // Pulse animation for interactive elements
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Staggered slide animations for each card
    _cardAnimation1 = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.elasticOut)),
    );

    _cardAnimation2 = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.6, curve: Curves.elasticOut)),
    );

    _cardAnimation3 = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.8, curve: Curves.elasticOut)),
    );

    _cardAnimation4 = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0, curve: Curves.elasticOut)),
    );

    _controller.forward();
  }

  void logout(BuildContext context) async {
    // Show a cool animated dialog before logout
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logging Out'),
        content: SizedBox(
          height: 100,
          child: Center(
            child: Column(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
                ),
                const SizedBox(height: 20),
                Text('Thank you for visiting!', 
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    // Actual logout with a small delay for animation
    await Future.delayed(const Duration(seconds: 1));
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pop(); // Close dialog
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "Thintava", 
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: "Notifications",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('No new notifications!', 
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.black87,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: "Logout",
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFFB703), // The requested amber color
              const Color(0xFFFFB703).withOpacity(0.85),
              const Color(0xFFFDC85D),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16), // Reduced height
                  Text(
                    "What would you like today?",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF023047),
                    ),
                  ),
                  const SizedBox(height: 4), // Reduced height
                  Text(
                    "Explore our delicious menu options",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: const Color(0xFF023047).withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16), // Reduced height
                  
                  // Food categories horizontal scrollable list
                  SizedBox(
                    height: 100, // Reduced height from 120
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildCategoryItem(Icons.local_pizza, "Pizza"),
                        _buildCategoryItem(Icons.lunch_dining, "Burgers"),
                        _buildCategoryItem(Icons.ramen_dining, "Noodles"),
                        _buildCategoryItem(Icons.icecream, "Desserts"),
                        _buildCategoryItem(Icons.local_drink, "Drinks"),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16), // Reduced height
                  Text(
                    "Quick Actions",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF023047),
                    ),
                  ),
                  const SizedBox(height: 10), // Reduced height
                  
                  // Main action cards in a responsive grid
                  // Wrap with Flexible instead of Expanded to avoid overflow
                  Flexible(
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      shrinkWrap: true, // Add shrinkWrap
                      physics: const ScrollPhysics(), // Allow scrolling if needed
                      children: [
                        SlideTransition(
                          position: _cardAnimation1,
                          child: _buildActionCard(
                            context,
                            Icons.restaurant_menu,
                            "Browse Menu",
                            "Explore our delicious options",
                            () => Navigator.pushNamed(context, '/menu'),
                            Colors.orangeAccent,
                          ),
                        ),
                        SlideTransition(
                          position: _cardAnimation2,
                          child: _buildActionCard(
                            context,
                            Icons.track_changes,
                            "Track Order",
                            "Check your current order status",
                            () => Navigator.pushNamed(context, '/track'),
                            Colors.blueAccent,
                          ),
                        ),
                        SlideTransition(
                          position: _cardAnimation3,
                          child: _buildActionCard(
                            context,
                            Icons.history,
                            "Order History",
                            "View your past orders",
                            () => Navigator.pushNamed(context, '/history'),
                            Colors.purpleAccent,
                          ),
                        ),
                        SlideTransition(
                          position: _cardAnimation4,
                          child: _buildActionCard(
                            context,
                            Icons.local_offer,
                            "Special Deals",
                            "Check out today's offers",
                            () => Navigator.pushNamed(context, '/deals'),
                            Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Add padding at the bottom to ensure there's no overflow
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String label) {
    return Container(
      width: 90, // Reduced width
      margin: const EdgeInsets.only(right: 15),
      child: Column(
        children: [
          Container(
            height: 60, // Reduced height
            width: 60, // Reduced width
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 30, // Reduced size
              color: const Color(0xFF023047),
            ),
          ),
          const SizedBox(height: 6), // Reduced spacing
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13, // Reduced font size
              fontWeight: FontWeight.w500,
              color: const Color(0xFF023047),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
    Color accentColor,
  ) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0), // Reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8), // Reduced padding
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 28, // Reduced size
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 10), // Reduced spacing
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15, // Reduced font size
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF023047),
                  ),
                ),
                const SizedBox(height: 4), // Reduced spacing
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11, // Reduced font size
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}