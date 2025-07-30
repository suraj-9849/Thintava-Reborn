// lib/screens/user/home/widgets/menu_grid.dart - FIXED WITHOUT COMPOSITE INDEX
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:canteen_app/presentation/widgets/menu/menu_item_card.dart';
import 'package:canteen_app/presentation/widgets/common/loading_states.dart';
import 'package:canteen_app/presentation/widgets/common/empty_state.dart';
import 'package:canteen_app/core/utils/user_utils.dart';

class MenuGrid extends StatelessWidget {
  final String searchQuery;
  final String selectedFilter;
  
  const MenuGrid({
    Key? key,
    required this.searchQuery,
    required this.selectedFilter,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('menuItems')
          .orderBy('name') // ✅ FIXED: Only order by name to avoid composite index
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingGrid();
        }

        if (snapshot.hasError) {
          print('MenuGrid stream error: ${snapshot.error}');
          return EmptyState(
            icon: Icons.wifi_off_rounded,
            title: "Oops! Something went wrong",
            subtitle: "Unable to load menu items.\nPlease check your connection and try again.",
            actionText: "Try Again",
            onActionPressed: () => {}, // Will trigger rebuild
            iconColor: Colors.red[400],
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyState(
            icon: Icons.restaurant_outlined,
            title: "Menu Coming Soon",
            subtitle: "Our chefs are preparing something amazing for you!",
            iconColor: Colors.orange,
          );
        }

        final allItems = snapshot.data!.docs;
        
        return FutureBuilder<List<DocumentSnapshot>>(
          future: _filterItemsAsync(allItems),
          builder: (context, filterSnapshot) {
            if (filterSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingGrid();
            }

            if (filterSnapshot.hasError) {
              print('MenuGrid filtering error: ${filterSnapshot.error}');
              return EmptyState(
                icon: Icons.error_outline,
                title: "Error Filtering Items",
                subtitle: "Unable to filter menu items. Please try again.",
                actionText: "Try Again",
                onActionPressed: () => {},
                iconColor: Colors.red[400],
              );
            }

            final filteredItems = filterSnapshot.data ?? [];

            if (filteredItems.isEmpty) {
              return EmptyState(
                icon: Icons.search_off_rounded,
                title: "No items found",
                subtitle: _getNoResultsMessage(),
                actionText: "Clear Filters",
                onActionPressed: () {
                  // This would need to be passed from parent to clear filters
                },
                iconColor: Colors.grey[400],
              );
            }

            return Consumer<CartProvider>(
              builder: (context, cartProvider, child) {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final doc = filteredItems[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final id = doc.id;
                    
                    return MenuItemCard(
                      id: id,
                      data: data,
                      index: index,
                      hasActiveOrder: false,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ✅ FIXED: Async filtering with proper stock checks
  Future<List<DocumentSnapshot>> _filterItemsAsync(List<DocumentSnapshot> allItems) async {
    List<DocumentSnapshot> filteredItems = [];

    for (final doc in allItems) {
      final data = doc.data() as Map<String, dynamic>;
      
      try {
        if (await _passesFiltersAsync(data, doc.id)) {
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

  // ✅ FIXED: Enhanced async filtering logic
  Future<bool> _passesFiltersAsync(Map<String, dynamic> data, String itemId) async {
    final name = (data['name'] ?? '').toLowerCase();
    final isVeg = data['isVeg'] ?? false;
    final available = data['available'] ?? false;
    
    // ✅ Items must be available (not hidden by admin) - filter this first
    if (!available) {
      return false;
    }
    
    // Search filter
    final matchesSearch = searchQuery.isEmpty || name.contains(searchQuery);
    if (!matchesSearch) {
      return false;
    }
    
    // Category filters
    switch (selectedFilter) {
      case 'Veg':
        return isVeg;
      case 'Non-Veg':
        return !isVeg;
      case 'Available':
        // ✅ FIXED: "Available" should only show items with actual stock
        return await _hasStock(data, itemId);
      case 'All':
      default:
        // ✅ FIXED: "All" shows all available items (not hidden ones)
        return true; // We already filtered for available=true above
    }
  }

  // ✅ NEW: Helper method to check if item has stock
  Future<bool> _hasStock(Map<String, dynamic> data, String itemId) async {
    try {
      final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
      
      if (hasUnlimitedStock) {
        return true; // Unlimited stock is always available
      }
      
      // Check available stock (considering reservations)
      final availableStock = await UserUtils.getAvailableStock(data, itemId);
      return availableStock > 0;
    } catch (e) {
      print('Error checking stock for $itemId: $e');
      // Fallback to sync check
      return UserUtils.getAvailableStockSync(data) > 0;
    }
  }

  String _getNoResultsMessage() {
    if (searchQuery.isNotEmpty) {
      return 'No items match "$searchQuery" with current filters';
    }
    
    switch (selectedFilter) {
      case 'Available':
        return 'No items are currently available with stock';
      case 'Veg':
        return 'No vegetarian items found';
      case 'Non-Veg':
        return 'No non-vegetarian items found';
      default:
        return 'No items match the current filters';
    }
  }
}