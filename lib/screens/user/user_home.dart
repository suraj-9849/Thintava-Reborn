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
      drawer: Drawer(
        child: Container(
          color: const Color(0xFFFFF1D7),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFFFB703), const Color(0xFFFFB703).withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white70,
                      child: Icon(Icons.person, size: 40, color: Color(0xFF023047)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Welcome Back!",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF023047),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Color(0xFF023047)),
                title: Text('My Profile', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to profile page
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite, color: Color(0xFF023047)),
                title: Text('Favorites', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to favorites page
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_on, color: Color(0xFF023047)),
                title: Text('Delivery Address', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to address page
                },
              ),
              ListTile(
                leading: const Icon(Icons.payment, color: Color(0xFF023047)),
                title: Text('Payment Methods', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to payment page
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings, color: Color(0xFF023047)),
                title: Text('Settings', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to settings page
                },
              ),
              ListTile(
                leading: const Icon(Icons.help, color: Color(0xFF023047)),
                title: Text('Help & Support', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to help page
                },
              ),
            ],
          ),
        ),
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
                  const SizedBox(height: 20),
                  Text(
                    "What would you like today?",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF023047),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Explore our delicious menu options",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: const Color(0xFF023047).withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Food categories horizontal scrollable list
                  SizedBox(
                    height: 120,
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
                  
                  const SizedBox(height: 30),
                  Text(
                    "Quick Actions",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF023047),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // Main action cards in a responsive grid
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
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
                  
                  // Footer with current promotions
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFFFB703),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        unselectedLabelStyle: GoogleFonts.poppins(),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: 0,
        onTap: (index) {
          // Handle navigation
        },
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String label) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 15),
      child: Column(
        children: [
          Container(
            height: 70,
            width: 70,
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
              size: 35,
              color: const Color(0xFF023047),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF023047),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
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