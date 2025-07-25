// lib/screens/user/home/home_tab.dart - FIXED VERSION WITH CORRECT UI COLORS
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:canteen_app/presentation/widgets/layout/enhanced_header.dart';
import 'package:canteen_app/presentation/widgets/layout/menu_section_header.dart';
import 'package:canteen_app/presentation/widgets/menu/search_filter_bar.dart';
import 'package:canteen_app/presentation/widgets/menu/menu_item_card.dart';
import 'package:canteen_app/presentation/widgets/order/active_order_banner.dart';
import 'package:canteen_app/presentation/widgets/common/loading_states.dart';
import 'package:canteen_app/presentation/widgets/common/empty_state.dart';

class HomeTab extends StatefulWidget {
  final Animation<double> fadeAnimation;
  final Function(int) onNavigateToTab;
  
  const HomeTab({
    Key? key,
    required this.fadeAnimation,
    required this.onNavigateToTab,
  }) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  
  final List<String> _filterOptions = ['All', 'Veg', 'Non-Veg', 'Available'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.toLowerCase();
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  void _onClearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  bool _passesFilters(Map<String, dynamic> data) {
    final name = (data['name'] ?? '').toString().toLowerCase();
    final isVeg = data['isVeg'] ?? false;
    final available = data['available'] ?? true;
    
    // Search filter
    if (_searchQuery.isNotEmpty && !name.contains(_searchQuery)) {
      return false;
    }
    
    // Category filter
    switch (_selectedFilter) {
      case 'Veg':
        return isVeg;
      case 'Non-Veg':
        return !isVeg;
      case 'Available':
        return available;
      case 'All':
      default:
        return true;
    }
  }

  void _showStockError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Stock availability has changed. Please check item availability.',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // FIXED: Changed to match your app's primary color scheme
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFB703), // Your primary yellow/orange color
              Color(0xFFFFC107), // Slightly lighter shade
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: widget.fadeAnimation,
            child: Column(
              children: [
                // Enhanced Header with correct colors
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Hello ${FirebaseAuth.instance.currentUser?.displayName?.split(' ')[0] ?? FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? 'Friend'}! 👋",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white, // White text on yellow background
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Menu Section Header
        Container(
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
        ),
        
        SearchFilterBar(
          searchController: _searchController,
          searchQuery: _searchQuery,
          selectedFilter: _selectedFilter,
          filterOptions: _filterOptions,
          onSearchChanged: _onSearchChanged,
          onFilterChanged: _onFilterChanged,
          onClearSearch: _onClearSearch,
        ),
        
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('menuItems')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingGrid();
              }

              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.error_outline,
                  title: 'Error Loading Menu',
                  subtitle: 'Unable to load menu items. Please try again.',
                  actionText: 'Retry',
                  onActionPressed: () {
                    setState(() {});
                  },
                  iconColor: Colors.red,
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EmptyState(
                  icon: Icons.restaurant_menu,
                  title: 'No Menu Items',
                  subtitle: 'Menu items will appear here when available.',
                  iconColor: Colors.grey,
                );
              }

              final allItems = snapshot.data!.docs;
              final filteredItems = allItems.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _passesFilters(data);
              }).toList();

              if (filteredItems.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off,
                  title: 'No Results Found',
                  subtitle: _searchQuery.isNotEmpty
                      ? 'No items match "$_searchQuery" with current filters'
                      : 'No items match the current filters',
                  actionText: 'Clear Filters',
                  onActionPressed: () {
                    _onClearSearch();
                    setState(() {
                      _selectedFilter = 'All';
                    });
                  },
                  iconColor: Colors.orange,
                );
              }

              return Consumer<CartProvider>(
                builder: (context, cartProvider, child) {
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final doc = filteredItems[index];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      return MenuItemCard(
                        id: doc.id,
                        data: data,
                        index: index,
                        hasActiveOrder: false, // Always false now
                        onStockError: _showStockError,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}