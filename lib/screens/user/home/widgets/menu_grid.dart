// lib/screens/user/home/widgets/menu_grid.dart - UPDATED VERSION (REMOVED ACTIVE ORDER FEATURE)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:canteen_app/presentation/widgets/menu/menu_item_card.dart';
import 'package:canteen_app/presentation/widgets/common/loading_states.dart';
import 'package:canteen_app/presentation/widgets/common/empty_state.dart';

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
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingGrid();
        }

        if (snapshot.hasError) {
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
        final filteredItems = _filterItems(allItems);

        if (filteredItems.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_rounded,
            title: "No items found",
            subtitle: "Try adjusting your search or filter to find what you're looking for.",
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
                  hasActiveOrder: false, // Always false now
                );
              },
            );
          },
        );
      },
    );
  }

  List<DocumentSnapshot> _filterItems(List<DocumentSnapshot> allItems) {
    return allItems.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toLowerCase();
      final isVeg = data['isVeg'] ?? false;
      
      final matchesSearch = searchQuery.isEmpty || name.contains(searchQuery);
      final matchesFilter = selectedFilter == 'All' || 
                            (selectedFilter == 'Veg' && isVeg) ||
                            (selectedFilter == 'Non-Veg' && !isVeg);
      
      return matchesSearch && matchesFilter;
    }).toList();
  }
}