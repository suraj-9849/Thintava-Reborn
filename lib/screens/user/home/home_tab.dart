// lib/screens/user/home/home_tab.dart - FIXED WITHOUT COMPOSITE INDEX
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:canteen_app/presentation/widgets/menu/search_filter_bar.dart';
import 'package:canteen_app/presentation/widgets/menu/menu_item_card.dart';
import 'package:canteen_app/presentation/widgets/common/loading_states.dart';
import 'package:canteen_app/presentation/widgets/common/empty_state.dart';
import 'package:canteen_app/core/utils/user_utils.dart';
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

  // ✅ FIXED: Enhanced filtering logic (client-side to avoid composite index)
  Future<bool> _passesFilters(Map<String, dynamic> data, String itemId) async {
    final name = (data['name'] ?? '').toString().toLowerCase();
    final isVeg = data['isVeg'] ?? false;
    final available = data['available'] ?? false; // Item must be available (not hidden)
    
    // ✅ FIRST CHECK: Item must be available (not hidden by admin)
    if (!available) {
      return false; // Hidden items should NEVER show in any filter
    }
    
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
        // ✅ FIXED: "Available" should only show items that are both available AND have stock
        return await _isActuallyAvailable(data, itemId);
      case 'All':
      default:
        // ✅ FIXED: "All" should show all available items (but not hidden ones)
        return true; // We already checked available=true above
    }
  }

  // ✅ NEW: Helper method to check if item is actually available (has stock)
  Future<bool> _isActuallyAvailable(Map<String, dynamic> data, String itemId) async {
    try {
      final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
      
      if (hasUnlimitedStock) {
        return true; // Unlimited stock is always available
      }
      
      // Check available stock (considering reservations)
      final availableStock = await UserUtils.getAvailableStock(data, itemId);
      return availableStock > 0;
    } catch (e) {
      print('Error checking availability for $itemId: $e');
      // Fallback to sync check
      return UserUtils.getAvailableStockSync(data) > 0;
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
          return _buildCanteenClosedWidget();
        }

        return _buildMenuContent();
      },
    );
  }

  Widget _buildCanteenClosedWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            Container(
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
            const SizedBox(height: 32),
            
            // Main message
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
              "Please check back later when it's operational",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            // Refresh button
            ElevatedButton.icon(
              onPressed: () {
                setState(() {});
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
            ),
          ],
        ),
      ),
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
                    _buildEnabledMenusIndicator(),
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
          child: _buildEnabledMenuItems(),
        ),
      ],
    );
  }

  Widget _buildEnabledMenusIndicator() {
    return FutureBuilder<List<MenuType>>(
      future: MenuOperationsService.getEnabledMenuTypes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text(
            "Loading menus...",
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

        final enabledMenus = snapshot.data!;
        
        if (enabledMenus.isEmpty) {
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
          children: enabledMenus.map((menuType) => Container(
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

  Widget _buildEnabledMenuItems() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildEnabledMenuItemsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingGrid();
        }

        if (snapshot.hasError) {
          print('Stream error: ${snapshot.error}');
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
            subtitle: 'Menu items will appear here when available.',
            iconColor: Colors.grey,
          );
        }

        return _buildFilteredItemsList(snapshot.data!.docs);
      },
    );
  }

  // ✅ NEW: Separate method to handle filtered items list
  Widget _buildFilteredItemsList(List<QueryDocumentSnapshot> allItems) {
    return FutureBuilder<List<QueryDocumentSnapshot>>(
      future: _getFilteredItems(allItems),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingGrid();
        }

        if (snapshot.hasError) {
          print('Filtering error: ${snapshot.error}');
          return EmptyState(
            icon: Icons.error_outline,
            title: 'Error Loading Items',
            subtitle: 'Unable to filter menu items. Please try again.',
            actionText: 'Retry',
            onActionPressed: () {
              setState(() {});
            },
            iconColor: Colors.red,
          );
        }

        final filteredItems = snapshot.data ?? [];

        if (filteredItems.isEmpty) {
          return EmptyState(
            icon: Icons.search_off,
            title: 'No Results Found',
            subtitle: _buildNoResultsMessage(),
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

  // ✅ NEW: Async method to filter items properly
  Future<List<QueryDocumentSnapshot>> _getFilteredItems(List<QueryDocumentSnapshot> allItems) async {
    List<QueryDocumentSnapshot> filteredItems = [];

    for (final doc in allItems) {
      final data = doc.data() as Map<String, dynamic>;
      
      // ✅ FIXED: Use async filtering method
      try {
        if (await _passesFilters(data, doc.id)) {
          filteredItems.add(doc);
        }
      } catch (e) {
        print('Error filtering item ${doc.id}: $e');
        // Include item if filtering fails (show rather than hide)
        filteredItems.add(doc);
      }
    }

    return filteredItems;
  }

  String _buildNoResultsMessage() {
    if (_searchQuery.isNotEmpty) {
      return 'No items match "$_searchQuery" with current filters';
    }
    
    switch (_selectedFilter) {
      case 'Available':
        return 'No items are currently available with stock';
      case 'Veg':
        return 'No vegetarian items match your search';
      case 'Non-Veg':
        return 'No non-vegetarian items match your search';
      default:
        return 'No items match the current filters';
    }
  }

  // ✅ FIXED: Use orderBy only, then filter client-side to avoid composite index
  Stream<QuerySnapshot> _buildEnabledMenuItemsStream() async* {
    final enabledMenuTypes = await MenuOperationsService.getEnabledMenuTypes();
    
    if (enabledMenuTypes.isEmpty) {
      yield* Stream.empty();
      return;
    }

    try {
      final enabledMenuValues = enabledMenuTypes.map((type) => type.value).toList();
      
      // ✅ FIXED: Use simple orderBy query, then filter client-side to avoid composite index
      yield* FirebaseFirestore.instance
          .collection('menuItems')
          .orderBy('name') // Only order by name to avoid composite index
          .snapshots()
          .map((snapshot) {
            // Client-side filtering for both enabled menu types AND available items
            final filteredDocs = snapshot.docs.where((doc) {
              final data = doc.data();
              final menuType = data['menuType'] ?? 'breakfast';
              final available = data['available'] ?? false;
              
              // Must be both enabled menu type AND available (not hidden)
              return enabledMenuValues.contains(menuType) && available;
            }).toList();
            
            // Create a new QuerySnapshot with filtered docs
            return FilteredQuerySnapshot(filteredDocs);
          });
    } catch (e) {
      print('Error in menu items stream: $e');
      yield* Stream.empty();
    }
  }
}

// Helper class to create filtered QuerySnapshot
class FilteredQuerySnapshot implements QuerySnapshot {
  final List<QueryDocumentSnapshot> _docs;

  FilteredQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot> get docs => _docs;
  
  @override
  List<DocumentChange> get docChanges => [];
  
  @override
  SnapshotMetadata get metadata => FilteredSnapshotMetadata();
  
  @override
  int get size => _docs.length;
  
  @override
  bool get isEmpty => _docs.isEmpty;
}

class FilteredSnapshotMetadata implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;
  
  @override
  bool get isFromCache => false;
}