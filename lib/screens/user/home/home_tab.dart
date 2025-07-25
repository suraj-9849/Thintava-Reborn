// lib/screens/user/home/home_tab.dart - IMMEDIATE ACTIVE ORDER CHECK
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
  bool _isCheckingActiveOrder = true;
  bool _hasActiveOrder = false;
  DocumentSnapshot? _activeOrderDoc;
  
  final List<String> _filterOptions = ['All', 'Veg', 'Non-Veg', 'Available'];

  @override
  void initState() {
    super.initState();
    _checkActiveOrderImmediately();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // FIXED: Immediate active order check on load
  Future<void> _checkActiveOrderImmediately() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isCheckingActiveOrder = false;
          _hasActiveOrder = false;
        });
        return;
      }
      
      print('🔍 Checking for active orders immediately...');
      
      final activeOrderQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['Placed', 'Cooking', 'Cooked', 'Pick Up'])
          .limit(1)
          .get();
      
      if (mounted) {
        setState(() {
          _isCheckingActiveOrder = false;
          _hasActiveOrder = activeOrderQuery.docs.isNotEmpty;
          _activeOrderDoc = activeOrderQuery.docs.isNotEmpty ? activeOrderQuery.docs.first : null;
        });
        
        if (_hasActiveOrder) {
          print('🚫 Active order found: ${_activeOrderDoc!.id}');
        } else {
          print('✅ No active order found');
        }
      }
    } catch (e) {
      print('❌ Error checking active order: $e');
      if (mounted) {
        setState(() {
          _isCheckingActiveOrder = false;
          _hasActiveOrder = false;
        });
      }
    }
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

  void _showActiveOrderError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You have an active order. Complete it before placing a new order.',
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
        action: SnackBarAction(
          label: 'Track Order',
          textColor: Colors.white,
          onPressed: () => widget.onNavigateToTab(1),
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
              Color(0xFF004D40),
              Color(0xFF00695C),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: widget.fadeAnimation,
            child: Column(
              children: [
                const EnhancedHeader(),
                
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
    // FIXED: Show loading first, then decide what screen to show
    if (_isCheckingActiveOrder) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
            ),
            const SizedBox(height: 16),
            Text(
              "Loading...",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // FIXED: If active order exists, show active order screen immediately
    if (_hasActiveOrder && _activeOrderDoc != null) {
      return _buildActiveOrderScreen(_activeOrderDoc!);
    }

    // FIXED: Only show normal menu if no active order
    return _buildNormalMenuScreen();
  }

  // FIXED: Dedicated screen for when there's an active order
  Widget _buildActiveOrderScreen(DocumentSnapshot orderDoc) {
    final orderData = orderDoc.data() as Map<String, dynamic>;
    final orderId = orderDoc.id;
    final status = orderData['status'] ?? 'Unknown';
    final shortOrderId = orderId.length > 6 ? orderId.substring(0, 6) : orderId;
    
    return Column(
      children: [
        const SizedBox(height: 40),
        Expanded(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.orange.withOpacity(0.2), width: 2),
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
                    child: const Icon(
                      Icons.restaurant_menu,
                      size: 48,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Active Order in Progress",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Order #$shortOrderId",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Text(
                      "Status: $status",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "You cannot place a new order while you have an active order in progress.",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Please complete your current order first.",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onNavigateToTab(1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.track_changes, size: 20),
                      label: Text(
                        "Track Your Order",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onNavigateToTab(2),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.history, size: 20),
                      label: Text(
                        "View Order History",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      // Force refresh the active order check
                      setState(() {
                        _isCheckingActiveOrder = true;
                      });
                      _checkActiveOrderImmediately();
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(
                      "Refresh",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // FIXED: Normal menu screen (only shown when no active order)
  Widget _buildNormalMenuScreen() {
    return Column(
      children: [
        const MenuSectionHeader(),
        
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
                        hasActiveOrder: false, // No active order in this screen
                        onStockError: () {
                          // FIXED: Re-check for active order when user tries to add item
                          _checkActiveOrderImmediately().then((_) {
                            if (_hasActiveOrder) {
                              // Active order was detected, the UI will update automatically
                              print('Active order detected after item click');
                            } else {
                              _showActiveOrderError();
                            }
                          });
                        },
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