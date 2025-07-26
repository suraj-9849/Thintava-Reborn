// lib/screens/user/home/normal_menu_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:canteen_app/presentation/widgets/layout/menu_section_header.dart';
import 'package:canteen_app/presentation/widgets/menu/search_filter_bar.dart';
import 'package:canteen_app/presentation/widgets/menu/menu_item_card.dart';
import 'package:canteen_app/presentation/widgets/common/loading_states.dart';
import 'package:canteen_app/presentation/widgets/common/empty_state.dart';

class NormalMenuView extends StatefulWidget {
  const NormalMenuView({Key? key}) : super(key: key);

  @override
  State<NormalMenuView> createState() => _NormalMenuViewState();
}

class _NormalMenuViewState extends State<NormalMenuView> {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Menu Section Header
          const MenuSectionHeader(),
          
          // Search and Filter Bar
          SearchFilterBar(
            searchController: _searchController,
            searchQuery: _searchQuery,
            selectedFilter: _selectedFilter,
            filterOptions: _filterOptions,
            onSearchChanged: _onSearchChanged,
            onFilterChanged: _onFilterChanged,
            onClearSearch: _onClearSearch,
          ),
          
          // Menu Items List
          Expanded(
            child: _buildMenuItemsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemsList() {
    return StreamBuilder<QuerySnapshot>(
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
                  hasActiveOrder: false, // Always false in normal menu view
                  onStockError: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Unable to add item to cart. Please try again.',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.red,
                      ),
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
}