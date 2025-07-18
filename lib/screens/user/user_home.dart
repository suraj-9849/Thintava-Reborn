// lib/screens/user/user_home.dart - Enhanced Modern UI
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:canteen_app/screens/user/order_tracking_screen.dart';
import 'package:canteen_app/screens/user/order_history_screen.dart';
import 'package:canteen_app/screens/user/profile_screen.dart';

class UserHome extends StatefulWidget {
  const UserHome({Key? key}) : super(key: key);

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _shimmerAnimation;
  final _authService = AuthService();
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  List<String> _filterOptions = ['All', 'Veg', 'Non-Veg'];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    
    // Start listening for session changes
    _authService.startSessionListener(() {
      logout(context, forceLogout: true);
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _shimmerAnimation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
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
    _shimmerController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    _authService.stopSessionListener();
    super.dispose();
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
          _buildHomePage(),
          const OrderTrackingScreen(),
          const OrderHistoryScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildModernBottomNav(),
      floatingActionButton: _buildCartFAB(),
    );
  }

  Widget _buildModernBottomNav() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
            );
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFFFB703),
          unselectedItemColor: Colors.grey[500],
          selectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.home_outlined, Icons.home, 0),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.track_changes_outlined, Icons.track_changes, 1),
              label: 'Track',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.history_outlined, Icons.history, 2),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.person_outline, Icons.person, 3),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData outlined, IconData filled, int index) {
    final isSelected = _currentIndex == index;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFB703).withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isSelected ? filled : outlined,
        size: 24,
      ),
    );
  }

  Widget? _buildCartFAB() {
    return _currentIndex == 0
        ? Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              if (cartProvider.isEmpty) return const SizedBox();

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB703).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.pushNamed(context, '/cart');
                  },
                  backgroundColor: const Color(0xFFFFB703),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.shopping_cart_rounded, size: 24),
                      if (cartProvider.itemCount > 0)
                        Positioned(
                          right: -8,
                          top: -8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              '${cartProvider.itemCount}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: Text(
                    "View Cart",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          )
        : null;
  }

  Widget _buildHomePage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFFB703),
            Color(0xFFFFC107),
            Color(0xFFFFD54F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildEnhancedHeader(),
              _buildSearchAndFilter(),
              _buildMenuSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedHeader() {
    final user = FirebaseAuth.instance.currentUser;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Hello ${user?.displayName?.split(' ')[0] ?? user?.email?.split('@')[0] ?? 'Friend'}! 👋",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      child: Row(
        children: [
          // Search Bar
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search for dishes...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey[500],
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: Icon(
                            Icons.clear_rounded,
                            color: Colors.grey[500],
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Filter Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                icon: Icon(
                  Icons.filter_list_rounded,
                  color: const Color(0xFFFFB703),
                  size: 16,
                ),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFFB703),
                ),
                isDense: true,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedFilter = newValue;
                    });
                  }
                },
                items: _filterOptions.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Expanded(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FA),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(35),
            topRight: Radius.circular(35),
          ),
        ),
        child: Column(
          children: [
            _buildMenuHeader(),
            _buildMenuGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB703).withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: Color(0xFFFFB703),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "Our Menu",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('menuItems')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingGrid();
          }

          if (snapshot.hasError) {
            return _buildErrorState();
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          // Filter items based on search query and veg/non-veg filter
          final allItems = snapshot.data!.docs;
          final filteredItems = allItems.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toLowerCase();
            final isVeg = data['isVeg'] ?? false;
            
            final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery);
            final matchesFilter = _selectedFilter == 'All' || 
                                  (_selectedFilter == 'Veg' && isVeg) ||
                                  (_selectedFilter == 'Non-Veg' && !isVeg);
            
            return matchesSearch && matchesFilter;
          }).toList();

          if (filteredItems.isEmpty) {
            return _buildNoResultsState();
          }

          return _buildMenuList(filteredItems);
        },
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "No items found",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try adjusting your search or filter to find what you're looking for.",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedFilter = 'All';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB703),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.clear_all_rounded),
              label: Text(
                "Clear Filters",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: _buildShimmerCard(),
        );
      },
    );
  }

  Widget _buildShimmerCard() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey[300]!,
                      Colors.grey[100]!,
                      Colors.grey[300]!,
                    ],
                    stops: [0.0, 0.5, 1.0],
                    begin: Alignment(-1.0 + _shimmerAnimation.value, 0.0),
                    end: Alignment(1.0 + _shimmerAnimation.value, 0.0),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey[300]!,
                            Colors.grey[100]!,
                            Colors.grey[300]!,
                          ],
                          stops: [0.0, 0.5, 1.0],
                          begin: Alignment(-1.0 + _shimmerAnimation.value, 0.0),
                          end: Alignment(1.0 + _shimmerAnimation.value, 0.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey[300]!,
                            Colors.grey[100]!,
                            Colors.grey[300]!,
                          ],
                          stops: [0.0, 0.5, 1.0],
                          begin: Alignment(-1.0 + _shimmerAnimation.value, 0.0),
                          end: Alignment(1.0 + _shimmerAnimation.value, 0.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Oops! Something went wrong",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Unable to load menu items.\nPlease check your connection and try again.",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB703),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                "Try Again",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_outlined,
                size: 48,
                color: Colors.orange[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Menu Coming Soon",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Our chefs are preparing something amazing for you!",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList(List<DocumentSnapshot> items) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final doc = items[index];
        final data = doc.data() as Map<String, dynamic>;
        final id = doc.id;
        
        return _buildEnhancedMenuCard(id, data, index);
      },
    );
  }

  Widget _buildEnhancedMenuCard(String id, Map<String, dynamic> data, int index) {
    final name = data['name'] ?? 'Unknown Item';
    final price = (data['price'] ?? 0.0) is double 
      ? (data['price'] ?? 0.0) 
      : double.parse((data['price'] ?? '0').toString());
    final description = data['description'] ?? '';
    final imageUrl = data['imageUrl'] as String?;
    final isVeg = data['isVeg'] ?? false;
    final quantity = data['quantity'] ?? 0;
    final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
    final available = data['available'] ?? true;
    
    final isOutOfStock = !hasUnlimitedStock && quantity <= 0;
    final isUnavailable = !available;

    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        int cartQuantity = cartProvider.getQuantity(id);
        
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 100)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFoodImage(imageUrl, isVeg, isOutOfStock, isUnavailable),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildFoodDetails(
                                name, price, description, quantity, 
                                hasUnlimitedStock, available, isOutOfStock, 
                                isUnavailable, cartProvider, id, cartQuantity
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOutOfStock && !hasUnlimitedStock)
                        _buildOutOfStockOverlay(),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFoodImage(String? imageUrl, bool isVeg, bool isOutOfStock, bool isUnavailable) {
    return Stack(
      children: [
        Container(
          width: 85,
          height: 85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageUrl != null && imageUrl.isNotEmpty
              ? ColorFiltered(
                  colorFilter: (isOutOfStock || isUnavailable)
                    ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                    : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                  ),
                )
              : _buildImagePlaceholder(),
          ),
        ),
        // Veg/Non-veg indicator
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 3,
                ),
              ],
            ),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isVeg ? Colors.green : Colors.red,
                shape: isVeg ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isVeg ? BorderRadius.circular(2) : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFoodDetails(String name, double price, String description, 
      int quantity, bool hasUnlimitedStock, bool available, bool isOutOfStock, 
      bool isUnavailable, CartProvider cartProvider, String id, int cartQuantity) {
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name and status
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: (isOutOfStock || isUnavailable) ? Colors.grey[600] : Colors.black87,
                  decoration: (isOutOfStock || isUnavailable) ? TextDecoration.lineThrough : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isUnavailable)
              _buildStatusBadge('Unavailable', Colors.grey)
            else if (isOutOfStock)
              _buildStatusBadge('Out of Stock', Colors.red)
            else if (!hasUnlimitedStock && quantity <= 5)
              _buildStatusBadge('Low Stock', Colors.orange)
            else if (hasUnlimitedStock)
              _buildStatusBadge('Available', Colors.green),
          ],
        ),
        
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: (isOutOfStock || isUnavailable) ? Colors.grey[500] : Colors.grey[600],
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        
        const SizedBox(height: 12),
        
        // Price
        Text(
          "₹${price.toStringAsFixed(2)}",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: (isOutOfStock || isUnavailable) ? Colors.grey[500] : const Color(0xFFFFB703),
            decoration: (isOutOfStock || isUnavailable) ? TextDecoration.lineThrough : null,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Add to cart controls
        if (!isOutOfStock && !isUnavailable)
          _buildCartControls(cartProvider, id, cartQuantity)
        else
          _buildUnavailableButton(isUnavailable),
      ],
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCartControls(CartProvider cartProvider, String id, int cartQuantity) {
    if (cartQuantity > 0) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFB703).withOpacity(0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0xFFFFB703).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCartButton(
              icon: Icons.remove_rounded,
              onTap: () => cartProvider.removeItem(id),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB703),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                cartQuantity.toString(),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            _buildCartButton(
              icon: Icons.add_rounded,
              onTap: () async {
                final success = await cartProvider.addItem(id);
                if (!success) {
                  _showStockError();
                }
              },
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            final success = await cartProvider.addItem(id);
            if (!success) {
              _showStockError();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB703),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 0,
          ),
          icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
          label: Text(
            "Add to Cart",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildCartButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: const Color(0xFFFFB703),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildUnavailableButton(bool isUnavailable) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isUnavailable ? Icons.block_rounded : Icons.hourglass_empty_rounded,
            color: Colors.grey[600],
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isUnavailable ? 'Currently Unavailable' : 'Out of Stock',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutOfStockOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'OUT OF STOCK',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 40,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  void _showStockError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cannot add more items - insufficient stock',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}