// lib/screens/user/home/home_tab.dart - FIXED WITH CORRECT IMPORTS
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
import 'package:canteen_app/presentation/widgets/user/canteen_closed_widget.dart';
import '../../../services/menu_operations_service.dart';
import '../../../models/menu_type.dart';

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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFB703),
              Color(0xFFFFC107),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: widget.fadeAnimation,
            child: Column(
              children: [
                // Enhanced Header
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
                            color: Colors.white,
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
    return FutureBuilder<bool>(
      future: MenuOperationsService.isCanteenOperational(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFFFFB703),
                ),
                const SizedBox(height: 16),
                Text(
                  'Checking canteen status...',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error checking canteen status',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[400],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    'Try Again',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB703),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final isOperational = snapshot.data ?? false;

        if (!isOperational) {
          return const CanteenClosedWidget();
        }

        return _buildMenuContent();
      },
    );
  }

  Widget _buildMenuContent() {
    return Column(
      children: [
        // Menu Section Header with operational status
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Our Menu",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    _buildActiveMenusIndicator(),
                  ],
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
          child: _buildActiveMenuItems(),
        ),
      ],
    );
  }

  Widget _buildActiveMenusIndicator() {
    return FutureBuilder<List<MenuType>>(
      future: MenuOperationsService.getActiveMenuTypes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text(
            "Loading active menus...",
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Text(
            "Error loading menu status",
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.red[400],
            ),
          );
        }

        final activeMenus = snapshot.data!;
        
        if (activeMenus.isEmpty) {
          return Text(
            "No active menus",
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.red[400],
            ),
          );
        }

        return Wrap(
          spacing: 6,
          children: activeMenus.map((menuType) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: menuType.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: menuType.color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  menuType.icon,
                  size: 12,
                  color: menuType.color,
                ),
                const SizedBox(width: 4),
                Text(
                  menuType.displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: menuType.color,
                  ),
                ),
              ],
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildActiveMenuItems() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildActiveMenuItemsStream(),
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
            title: 'No Menu Items Available',
            subtitle: 'Active menu items will appear here when available.',
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
                  hasActiveOrder: false,
                  onStockError: _showStockError,
                );
              },
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _buildActiveMenuItemsStream() async* {
    final activeMenuTypes = await MenuOperationsService.getActiveMenuTypes();
    
    if (activeMenuTypes.isEmpty) {
      yield EmptyQuerySnapshot();
      return;
    }

    final activeMenuValues = activeMenuTypes.map((type) => type.value).toList();
    
    yield* FirebaseFirestore.instance
        .collection('menuItems')
        .where('menuType', whereIn: activeMenuValues)
        .orderBy('name')
        .snapshots();
  }
}

// Helper class to create empty QuerySnapshot
class EmptyQuerySnapshot implements QuerySnapshot {
  @override
  List<QueryDocumentSnapshot> get docs => [];
  
  @override
  List<DocumentChange> get docChanges => [];
  
  @override
  SnapshotMetadata get metadata => EmptySnapshotMetadata();
  
  @override
  int get size => 0;
  
  @override
  bool get isEmpty => true;
}

class EmptySnapshotMetadata implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;
  
  @override
  bool get isFromCache => false;
}