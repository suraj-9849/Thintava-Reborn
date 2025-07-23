// lib/screens/user/profile_screen.dart - OPTIMIZED VERSION
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:canteen_app/presentation/widgets/profile/profile_header.dart';
import 'package:canteen_app/presentation/widgets/profile/stats_card.dart';
import 'package:canteen_app/presentation/widgets/profile/menu_section.dart';
import 'package:canteen_app/presentation/widgets/profile/profile_dialogs.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _authService = AuthService();
  
  int totalOrders = 0;
  double totalSpent = 0.0;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            ProfileHeader(
              onEditPressed: () => ProfileDialogs.showEditProfileDialog(
                context, 
                _showComingSoonSnackBar,
              ),
            ),
            
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatsCard(
                      totalOrders: totalOrders,
                      totalSpent: totalSpent,
                      isLoading: isLoading,
                    ),
                    
                    const SizedBox(height: 25),
                    
                    MenuSection(
                      title: "Account Settings",
                      items: [
                        MenuItemData(
                          icon: Icons.person_outline,
                          title: "Personal Information",
                          subtitle: "Update your profile details",
                          onTap: () => ProfileDialogs.showEditProfileDialog(
                            context, 
                            _showComingSoonSnackBar,
                          ),
                        ),
                        MenuItemData(
                          icon: Icons.favorite_border,
                          title: "Favorite Items",
                          subtitle: "View and manage your favorites",
                          onTap: () => _showComingSoonSnackBar("Favorites"),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 25),
                    
                    MenuSection(
                      title: "Orders",
                      items: [
                        MenuItemData(
                          icon: Icons.track_changes,
                          title: "Track Current Order",
                          subtitle: "View status of active orders",
                          onTap: () => Navigator.pushNamed(context, '/track'),
                        ),
                        MenuItemData(
                          icon: Icons.history,
                          title: "Order History",
                          subtitle: "View all your past orders",
                          onTap: () => Navigator.pushNamed(context, '/history'),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 25),
                    
                    MenuSection(
                      title: "Support & Legal",
                      items: [
                        MenuItemData(
                          icon: Icons.help_outline,
                          title: "Help & Support",
                          subtitle: "Get help with your account or orders",
                          onTap: () => ProfileDialogs.showHelpDialog(context),
                        ),
                        MenuItemData(
                          icon: Icons.feedback_outlined,
                          title: "Send Feedback",
                          subtitle: "Help us improve our service",
                          onTap: () => ProfileDialogs.showFeedbackDialog(
                            context, 
                            _showComingSoonSnackBar,
                          ),
                        ),
                        MenuItemData(
                          icon: Icons.info_outline,
                          title: "About App",
                          subtitle: "Learn more about our app",
                          onTap: () => ProfileDialogs.showAboutDialog(context),
                        ),
                        MenuItemData(
                          icon: Icons.privacy_tip_outlined,
                          title: "Privacy Policy",
                          subtitle: "Read our privacy policy",
                          onTap: () => _showComingSoonSnackBar("Privacy Policy"),
                        ),
                        MenuItemData(
                          icon: Icons.description_outlined,
                          title: "Terms of Service",
                          subtitle: "Read our terms and conditions",
                          onTap: () => _showComingSoonSnackBar("Terms of Service"),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 25),
                    
                    MenuSection(
                      title: "",
                      items: [
                        MenuItemData(
                          icon: Icons.logout,
                          title: "Logout",
                          subtitle: "Sign out of your account",
                          onTap: () => logout(context),
                          isDestructive: true,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 30),
                    
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
}