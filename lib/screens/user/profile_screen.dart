// lib/screens/user/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:canteen_app/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _authService = AuthService();
  
  // User stats
  int totalOrders = 0;
  double totalSpent = 0.0;
  double avgRating = 4.8;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    
    _animationController.forward();
    _loadUserStats();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Fetch user's order history
        final ordersSnapshot = await FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: user.uid)
            .get();
        
        double total = 0.0;
        for (var doc in ordersSnapshot.docs) {
          final data = doc.data();
          total += (data['total'] ?? 0.0);
        }
        
        setState(() {
          totalOrders = ordersSnapshot.docs.length;
          totalSpent = total;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user stats: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void logout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show logout loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Logging out...',
                          style: GoogleFonts.poppins(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              
              await _authService.logout();
              
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/auth');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Logout', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // Custom App Bar with Profile Header
            SliverAppBar(
              expandedHeight: 220,
              floating: false,
              pinned: true,
              backgroundColor: const Color(0xFFFFB703),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFB703), Color(0xFFFFC107)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          // Profile Avatar
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 35,
                              backgroundColor: Colors.white,
                              backgroundImage: user?.photoURL != null 
                                ? NetworkImage(user!.photoURL!) 
                                : null,
                              child: user?.photoURL == null 
                                ? Text(
                                    user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                                    style: GoogleFonts.poppins(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFFFB703),
                                    ),
                                  )
                                : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // User Info
                          Text(
                            user?.displayName ?? user?.email?.split('@')[0] ?? 'User',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? 'No email',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Text(
                              'Member',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                  onPressed: () => _showEditProfileDialog(),
                ),
              ],
            ),
            
            // Profile Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Stats Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: isLoading 
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFFB703),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  icon: Icons.shopping_bag_outlined,
                                  value: totalOrders.toString(),
                                  label: "Orders",
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 50,
                                color: Colors.grey[300],
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  icon: Icons.currency_rupee,
                                  value: "₹${totalSpent.toStringAsFixed(0)}",
                                  label: "Spent",
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 50,
                                color: Colors.grey[300],
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  icon: Icons.star_outline,
                                  value: "${avgRating}★",
                                  label: "Rating",
                                ),
                              ),
                            ],
                          ),
                    ),
                    
                    const SizedBox(height: 25),
                    
                    // Account Settings Section
                    _buildSectionHeader("Account Settings"),
                    const SizedBox(height: 12),
                    
                    _buildMenuOption(
                      icon: Icons.person_outline,
                      title: "Personal Information",
                      subtitle: "Update your profile details",
                      onTap: () => _showEditProfileDialog(),
                    ),
                    
                    _buildMenuOption(
                      icon: Icons.favorite_border,
                      title: "Favorite Items",
                      subtitle: "View and manage your favorites",
                      onTap: () => _showComingSoonSnackBar("Favorites"),
                    ),
                    
                    const SizedBox(height: 25),
                    
                    // Orders Section
                    _buildSectionHeader("Orders"),
                    const SizedBox(height: 12),
                    
                    _buildMenuOption(
                      icon: Icons.track_changes,
                      title: "Track Current Order",
                      subtitle: "View status of active orders",
                      onTap: () => Navigator.pushNamed(context, '/track'),
                    ),
                    
                    _buildMenuOption(
                      icon: Icons.history,
                      title: "Order History",
                      subtitle: "View all your past orders",
                      onTap: () => Navigator.pushNamed(context, '/history'),
                    ),
                    
                    const SizedBox(height: 25),
                    
                    // Support Section
                    _buildSectionHeader("Support & Legal"),
                    const SizedBox(height: 12),
                    
                    _buildMenuOption(
                      icon: Icons.help_outline,
                      title: "Help & Support",
                      subtitle: "Get help with your account or orders",
                      onTap: () => _showHelpDialog(),
                    ),
                    
                    _buildMenuOption(
                      icon: Icons.feedback_outlined,
                      title: "Send Feedback",
                      subtitle: "Help us improve our service",
                      onTap: () => _showFeedbackDialog(),
                    ),
                    
                    _buildMenuOption(
                      icon: Icons.info_outline,
                      title: "About App",
                      subtitle: "Learn more about our app",
                      onTap: () => _showAboutDialog(),
                    ),
                    
                    _buildMenuOption(
                      icon: Icons.privacy_tip_outlined,
                      title: "Privacy Policy",
                      subtitle: "Read our privacy policy",
                      onTap: () => _showComingSoonSnackBar("Privacy Policy"),
                    ),
                    
                    _buildMenuOption(
                      icon: Icons.description_outlined,
                      title: "Terms of Service",
                      subtitle: "Read our terms and conditions",
                      onTap: () => _showComingSoonSnackBar("Terms of Service"),
                    ),
                    
                    const SizedBox(height: 25),
                    
                    // Logout Section
                    _buildMenuOption(
                      icon: Icons.logout,
                      title: "Logout",
                      subtitle: "Sign out of your account",
                      onTap: () => logout(context),
                      isDestructive: true,
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // App Version
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          "v1.0.0",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB703).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFFB703),
            size: 18,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFFB703),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDestructive ? Colors.red.withOpacity(0.2) : Colors.grey[200]!,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDestructive 
                      ? Colors.red.withOpacity(0.1)
                      : const Color(0xFFFFB703).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isDestructive ? Colors.red : const Color(0xFFFFB703),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDestructive ? Colors.red : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final user = FirebaseAuth.instance.currentUser;
    final nameController = TextEditingController(text: user?.displayName ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.edit, color: const Color(0xFFFFB703)),
            const SizedBox(width: 8),
            Text(
              'Edit Profile',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Display Name',
                labelStyle: GoogleFonts.poppins(),
                prefixIcon: Icon(Icons.person, color: const Color(0xFFFFB703)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFFFFB703)),
                ),
              ),
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.email, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email Address',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          user?.email ?? 'No email',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Email cannot be changed for security reasons',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _showComingSoonSnackBar('Profile Update');
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB703),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Save Changes', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.help, color: const Color(0xFFFFB703)),
            const SizedBox(width: 8),
            Text(
              'Help & Support',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need help? We\'re here for you!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _buildHelpOption(Icons.email, 'Email Support', 'support@thintava.com'),
            _buildHelpOption(Icons.phone, 'Phone Support', '+91 98765 43210'),
            _buildHelpOption(Icons.chat, 'Live Chat', 'Available 9 AM - 9 PM'),
            _buildHelpOption(Icons.help_center, 'FAQ', 'Common questions & answers'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB703),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Close', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpOption(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFB703), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    final feedbackController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.feedback, color: const Color(0xFFFFB703)),
            const SizedBox(width: 8),
            Text(
              'Send Feedback',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'We value your feedback! Help us improve our service.',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Share your thoughts, suggestions, or report issues...',
                hintStyle: GoogleFonts.poppins(fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFFFFB703)),
                ),
              ),
              style: GoogleFonts.poppins(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              _showComingSoonSnackBar('Feedback Submission');
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB703),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Send Feedback', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.restaurant_menu, color: const Color(0xFFFFB703)),
            const SizedBox(width: 8),
            Text(
              'About App',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Ultimate Food Companion',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Easy ordering, real-time tracking, and delicious food delivered right to your doorstep.',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            Text(
              'Key Features:',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '• Browse extensive menu\n'
              '• Secure payment processing\n'
              '• Real-time order tracking\n'
              '• Order history and favorites\n'
              '• 24/7 customer support',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              'Version: 1.0.0\nMade with ❤️ in India',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB703),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Close', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showComingSoonSnackBar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature feature coming soon!',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: const Color(0xFFFFB703),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}