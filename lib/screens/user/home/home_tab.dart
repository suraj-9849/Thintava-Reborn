// lib/screens/user/home/home_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:canteen_app/presentation/widgets/layout/enhanced_header.dart';
import 'package:canteen_app/presentation/widgets/order/active_order_banner.dart';
import 'package:canteen_app/presentation/widgets/menu/search_filter_bar.dart';
import 'package:canteen_app/presentation/widgets/layout/menu_section_header.dart';
import 'widgets/menu_grid.dart';

class HomeTab extends StatefulWidget {
  final Animation<double> fadeAnimation;
  final ValueChanged<int> onNavigateToTab;
  
  const HomeTab({
    Key? key,
    required this.fadeAnimation,
    required this.onNavigateToTab,
  }) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Veg', 'Non-Veg'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          opacity: widget.fadeAnimation,
          child: Column(
            children: [
              const EnhancedHeader(),
              ActiveOrderBanner(
                onTap: () => widget.onNavigateToTab(1),
              ),
              SearchFilterBar(
                searchController: _searchController,
                searchQuery: _searchQuery,
                selectedFilter: _selectedFilter,
                filterOptions: _filterOptions,
                onSearchChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                onFilterChanged: (value) {
                  setState(() {
                    _selectedFilter = value;
                  });
                },
                onClearSearch: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              ),
              Expanded(
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
                      const MenuSectionHeader(),
                      Expanded(
                        child: MenuGrid(
                          searchQuery: _searchQuery,
                          selectedFilter: _selectedFilter,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}