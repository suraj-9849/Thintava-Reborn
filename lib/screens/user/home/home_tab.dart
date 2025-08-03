// lib/screens/user/home/home_tab.dart - COMPLETELY FIXED VERSION
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
import 'dart:async';

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
  
  final List<String> _filterOptions = ['All', 'Veg', 'Non-Veg', 'Available'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onClearSearch() {
    _searchController.clear();
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
        
        Expanded(
          child: _buildMenuItemsWithSearch(),
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

  // ✅ COMPLETELY FIXED: No setState calls, no rebuilds, no overflow
  Widget _buildMenuItemsWithSearch() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildEnabledMenuItemsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingGrid();
        }

        if (snapshot.hasError) {
          print('Stream error: ${snapshot.error}');
          return _buildSafeEmptyState(
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
          return _buildSafeEmptyState(
            icon: Icons.restaurant_menu,
            title: 'No Menu Items Available',
            subtitle: 'Menu items will appear here when available.',
            iconColor: Colors.grey,
          );
        }

        final allItems = snapshot.data!.docs;

        return Column(
          children: [
            // ✅ FIXED: Search bar that doesn't cause rebuilds
            _buildStatelessSearchBar(),
            
            // ✅ FIXED: Filtered items list
            Expanded(
              child: _StatelessFilteredList(
                allItems: allItems,
                searchController: _searchController,
                filterOptions: _filterOptions,
                onStockError: _showStockError,
              ),
            ),
          ],
        );
      },
    );
  }

  // ✅ FIXED: Safe empty state that doesn't overflow
  Widget _buildSafeEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionText,
    VoidCallback? onActionPressed,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 64,
                color: iconColor ?? Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              if (actionText != null && onActionPressed != null) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onActionPressed,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    actionText,
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
            ],
          ),
        ),
      ),
    );
  }

  // ✅ FIXED: Search bar that doesn't trigger rebuilds
  Widget _buildStatelessSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      child: Row(
        children: [
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
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, child) {
                      return value.text.isNotEmpty
                          ? IconButton(
                              onPressed: _onClearSearch,
                              icon: Icon(
                                Icons.clear_rounded,
                                color: Colors.grey[500],
                              ),
                            )
                          : const SizedBox.shrink();
                    },
                  ),
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
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildEnabledMenuItemsStream() async* {
    final enabledMenuTypes = await MenuOperationsService.getEnabledMenuTypes();
    
    if (enabledMenuTypes.isEmpty) {
      yield* Stream.empty();
      return;
    }

    try {
      final enabledMenuValues = enabledMenuTypes.map((type) => type.value).toList();
      
      yield* FirebaseFirestore.instance
          .collection('menuItems')
          .orderBy('name')
          .snapshots()
          .map((snapshot) {
            final filteredDocs = snapshot.docs.where((doc) {
              final data = doc.data();
              final menuType = data['menuType'] ?? 'breakfast';
              final available = data['available'] ?? false;
              
              return enabledMenuValues.contains(menuType) && available;
            }).toList();
            
            return FilteredQuerySnapshot(filteredDocs);
          });
    } catch (e) {
      print('Error in menu items stream: $e');
      yield* Stream.empty();
    }
  }
}

// ✅ COMPLETELY NEW: Stateless filtered list that doesn't cause parent rebuilds
class _StatelessFilteredList extends StatefulWidget {
  final List<QueryDocumentSnapshot> allItems;
  final TextEditingController searchController;
  final List<String> filterOptions;
  final VoidCallback onStockError;

  const _StatelessFilteredList({
    required this.allItems,
    required this.searchController,
    required this.filterOptions,
    required this.onStockError,
  });

  @override
  State<_StatelessFilteredList> createState() => _StatelessFilteredListState();
}

class _StatelessFilteredListState extends State<_StatelessFilteredList> {
  String _searchQuery = '';
  String _selectedFilter = 'All';
  Timer? _debounceTimer;
  List<QueryDocumentSnapshot>? _cachedFilteredItems;

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = widget.searchController.text.toLowerCase();
          _cachedFilteredItems = null;
        });
      }
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _cachedFilteredItems = null;
    });
  }

  Future<bool> _passesFilters(Map<String, dynamic> data, String itemId) async {
    final name = (data['name'] ?? '').toString().toLowerCase();
    final isVeg = data['isVeg'] ?? false;
    final available = data['available'] ?? false;
    
    if (!available) return false;
    
    if (_searchQuery.isNotEmpty && !name.contains(_searchQuery)) {
      return false;
    }
    
    switch (_selectedFilter) {
      case 'Veg':
        return isVeg;
      case 'Non-Veg':
        return !isVeg;
      case 'Available':
        try {
          final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
          if (hasUnlimitedStock) return true;
          final availableStock = await UserUtils.getAvailableStock(data, itemId);
          return availableStock > 0;
        } catch (e) {
          return UserUtils.getAvailableStockSync(data) > 0;
        }
      case 'All':
      default:
        return true;
    }
  }

  Future<List<QueryDocumentSnapshot>> _getFilteredItems() async {
    if (_cachedFilteredItems != null) {
      return _cachedFilteredItems!;
    }

    List<QueryDocumentSnapshot> filteredItems = [];

    for (final doc in widget.allItems) {
      final data = doc.data() as Map<String, dynamic>;
      
      try {
        if (await _passesFilters(data, doc.id)) {
          filteredItems.add(doc);
        }
      } catch (e) {
        print('Error filtering item ${doc.id}: $e');
        filteredItems.add(doc);
      }
    }

    _cachedFilteredItems = filteredItems;
    return filteredItems;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Filter: ',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFFB703),
                    ),
                    isDense: true,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        _onFilterChanged(newValue);
                      }
                    },
                    items: widget.filterOptions.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 15),
        
        // Filtered items list
        Expanded(
          child: FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _getFilteredItems(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFB703)),
                );
              }

              if (snapshot.hasError) {
                return _buildCompactEmptyState(
                  Icons.error_outline,
                  'Error filtering items',
                  'Please try again',
                  Colors.red,
                );
              }

              final filteredItems = snapshot.data ?? [];

              if (filteredItems.isEmpty) {
                return _buildCompactEmptyState(
                  Icons.search_off,
                  'No results found',
                  _buildNoResultsMessage(),
                  Colors.orange,
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
                        onStockError: widget.onStockError,
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

  Widget _buildCompactEmptyState(IconData icon, String title, String subtitle, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _buildNoResultsMessage() {
    if (_searchQuery.isNotEmpty) {
      return 'No items match "$_searchQuery"';
    }
    
    switch (_selectedFilter) {
      case 'Available':
        return 'No items currently available';
      case 'Veg':
        return 'No vegetarian items found';
      case 'Non-Veg':
        return 'No non-vegetarian items found';
      default:
        return 'No items match current filters';
    }
  }
}

// Helper classes remain the same
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