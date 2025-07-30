// lib/screens/admin/admin_analytics_screen.dart - COMPLETE UPDATED VERSION
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'This Month';
  final List<String> _periods = ['Today', 'This Week', 'This Month', 'All Time'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getAnalyticsData() async {
    try {
      final now = DateTime.now();
      DateTime startDate;
      
      switch (_selectedPeriod) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'This Week':
          startDate = now.subtract(Duration(days: 7));
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        default: // All Time
          startDate = DateTime(2020, 1, 1);
      }

      // Fetch orders
      Query ordersQuery = FirebaseFirestore.instance.collection('orders');
      if (_selectedPeriod != 'All Time') {
        ordersQuery = ordersQuery.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      final ordersSnapshot = await ordersQuery.get();
      final orders = ordersSnapshot.docs;

      // Calculate metrics
      double totalRevenue = 0;
      int totalOrders = orders.length;
      Map<String, int> statusCounts = {};
      Map<String, double> dailyRevenue = {};
      Map<String, int> dailyOrders = {};
      Map<String, double> itemRevenue = {};
      Map<String, int> itemCounts = {};
      double averageOrderValue = 0;

      for (var doc in orders) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        final total = (data['total'] ?? 0.0) is double 
            ? data['total'] ?? 0.0 
            : double.tryParse((data['total'] ?? 0).toString()) ?? 0.0;
        final status = data['status'] as String? ?? 'Unknown';

        totalRevenue += total;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        if (timestamp != null) {
          // Daily breakdown
          final dayKey = '${timestamp.day}/${timestamp.month}';
          dailyRevenue[dayKey] = (dailyRevenue[dayKey] ?? 0) + total;
          dailyOrders[dayKey] = (dailyOrders[dayKey] ?? 0) + 1;

          // Item breakdown
          final items = data['items'];
          if (items is List) {
            for (var item in items) {
              if (item is Map<String, dynamic>) {
                final itemName = item['name'] ?? 'Unknown Item';
                final itemPrice = (item['price'] ?? 0.0) is double 
                    ? item['price'] ?? 0.0 
                    : double.tryParse((item['price'] ?? 0).toString()) ?? 0.0;
                final quantity = (item['quantity'] ?? 1) is int 
                    ? (item['quantity'] ?? 1) as int
                    : int.tryParse((item['quantity'] ?? 1).toString()) ?? 1;
                
                itemRevenue[itemName] = (itemRevenue[itemName] ?? 0) + (itemPrice * quantity);
                itemCounts[itemName] = (itemCounts[itemName] ?? 0) + quantity;
              }
            }
          }
        }
      }

      averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;

      // Fetch menu items for inventory analysis
      final menuSnapshot = await FirebaseFirestore.instance.collection('menuItems').get();
      final menuItems = menuSnapshot.docs;
      
      int totalMenuItems = menuItems.length;
      int availableItems = 0;
      int outOfStockItems = 0;
      int lowStockItems = 0;

      for (var doc in menuItems) {
        final data = doc.data() as Map<String, dynamic>;
        final available = data['available'] ?? true;
        final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
        final quantity = data['quantity'] ?? 0;

        if (!available || (!hasUnlimitedStock && quantity <= 0)) {
          outOfStockItems++;
        } else if (!hasUnlimitedStock && quantity <= 5) {
          lowStockItems++;
        } else {
          availableItems++;
        }
      }

      return {
        'totalRevenue': totalRevenue,
        'totalOrders': totalOrders,
        'averageOrderValue': averageOrderValue,
        'statusCounts': statusCounts,
        'dailyRevenue': dailyRevenue,
        'dailyOrders': dailyOrders,
        'itemRevenue': itemRevenue,
        'itemCounts': itemCounts,
        'totalMenuItems': totalMenuItems,
        'availableItems': availableItems,
        'outOfStockItems': outOfStockItems,
        'lowStockItems': lowStockItems,
        'period': _selectedPeriod,
      };
    } catch (e) {
      print('Error fetching analytics data: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analytics Dashboard',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFFFB703),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Revenue'),
            Tab(text: 'Orders'),
            Tab(text: 'Inventory'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Period Selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB703),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Period Selection:',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _periods.map((period) {
                      final isSelected = period == _selectedPeriod;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            period,
                            style: GoogleFonts.poppins(
                              color: isSelected ? const Color(0xFFFFB703) : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedPeriod = period;
                            });
                          },
                          backgroundColor: Colors.white.withOpacity(0.2),
                          selectedColor: Colors.white,
                          checkmarkColor: const Color(0xFFFFB703),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _getAnalyticsData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFB703)),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'Unable to load analytics data',
                          style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final data = snapshot.data!;

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(data),
                    _buildRevenueTab(data),
                    _buildOrdersTab(data),
                    _buildInventoryTab(data),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Metrics',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Key metrics grid
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
              double childAspectRatio = constraints.maxWidth > 600 ? 1.2 : 2.0;
              
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildMetricCard(
                    'Total Revenue',
                    '₹${(data['totalRevenue'] ?? 0).toStringAsFixed(2)}',
                    Icons.currency_rupee,
                    Colors.green,
                    data['period'] ?? '',
                  ),
                  _buildMetricCard(
                    'Total Orders',
                    '${data['totalOrders'] ?? 0}',
                    Icons.receipt_long,
                    Colors.blue,
                    data['period'] ?? '',
                  ),
                  _buildMetricCard(
                    'Average Order',
                    '₹${(data['averageOrderValue'] ?? 0).toStringAsFixed(2)}',
                    Icons.trending_up,
                    Colors.orange,
                    'Per order',
                  ),
                  _buildMetricCard(
                    'Menu Items',
                    '${data['totalMenuItems'] ?? 0}',
                    Icons.restaurant_menu,
                    Colors.purple,
                    '${data['availableItems'] ?? 0} available',
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // Order Status Breakdown
          Text(
            'Order Status Distribution',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildStatusBreakdown(data['statusCounts'] ?? {}),
        ],
      ),
    );
  }

  Widget _buildRevenueTab(Map<String, dynamic> data) {
    final dailyRevenue = data['dailyRevenue'] as Map<String, double>? ?? {};
    final itemRevenue = data['itemRevenue'] as Map<String, double>? ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue Analysis',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // REVENUE CHART WITH FIXED Y-AXIS
          if (dailyRevenue.isNotEmpty) ...[
            Text(
              'Daily Revenue',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildRevenueChart(dailyRevenue),
            const SizedBox(height: 24),
          ],
          
          // Top revenue items
          Text(
            'Top Revenue Items',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildTopItemsList(itemRevenue, 'revenue'),
        ],
      ),
    );
  }

  Widget _buildOrdersTab(Map<String, dynamic> data) {
    final dailyOrders = data['dailyOrders'] as Map<String, int>? ?? {};
    final itemCounts = data['itemCounts'] as Map<String, int>? ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Analysis',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // DAILY ORDERS CHART WITH FIXED Y-AXIS
          if (dailyOrders.isNotEmpty) ...[
            Text(
              'Daily Orders',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildOrdersChart(dailyOrders),
            const SizedBox(height: 24),
          ],
          
          // Most ordered items
          Text(
            'Most Ordered Items',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildTopItemsList(itemCounts, 'orders'),
        ],
      ),
    );
  }

  Widget _buildInventoryTab(Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inventory Status',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Inventory overview
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
              double childAspectRatio = constraints.maxWidth > 600 ? 1.8 : 3.0;
              
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildInventoryCard(
                    'Total Items',
                    '${data['totalMenuItems'] ?? 0}',
                    Icons.inventory,
                    Colors.blue,
                  ),
                  _buildInventoryCard(
                    'Available',
                    '${data['availableItems'] ?? 0}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildInventoryCard(
                    'Low Stock',
                    '${data['lowStockItems'] ?? 0}',
                    Icons.warning,
                    Colors.orange,
                  ),
                  _buildInventoryCard(
                    'Out of Stock',
                    '${data['outOfStockItems'] ?? 0}',
                    Icons.remove_circle,
                    Colors.red,
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // Stock status chart
          _buildStockStatusChart(data),
        ],
      ),
    );
  }

  // REVENUE CHART WITH FIXED Y-AXIS
  Widget _buildRevenueChart(Map<String, double> dailyRevenue) {
    final sortedEntries = dailyRevenue.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    if (sortedEntries.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No revenue data available',
            style: GoogleFonts.poppins(color: Colors.grey[600]),
          ),
        ),
      );
    }

    // Calculate Y-axis scale for revenue
    final maxRevenue = sortedEntries.map((e) => e.value).reduce(math.max);
    
    double yAxisMax;
    int yAxisSteps = 5;
    
    if (maxRevenue <= 100) {
      yAxisMax = ((maxRevenue / 20).ceil() * 20).toDouble();
    } else if (maxRevenue <= 500) {
      yAxisMax = ((maxRevenue / 100).ceil() * 100).toDouble();
    } else if (maxRevenue <= 1000) {
      yAxisMax = ((maxRevenue / 200).ceil() * 200).toDouble();
    } else if (maxRevenue <= 5000) {
      yAxisMax = ((maxRevenue / 1000).ceil() * 1000).toDouble();
    } else if (maxRevenue <= 10000) {
      yAxisMax = ((maxRevenue / 2000).ceil() * 2000).toDouble();
    } else {
      yAxisMax = ((maxRevenue / 5000).ceil() * 5000).toDouble();
    }

    final yAxisInterval = yAxisMax / yAxisSteps;
    
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 16), // Reduced left padding
        child: Column(
          mainAxisSize: MainAxisSize.min, // Prevent overflow
          children: [
            Text(
              'Revenue Trend',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12), // Reduced spacing
            
            Expanded(
              child: Row(
                children: [
                  // Fixed Y-axis - reduced width
                  SizedBox(
                    width: 50, // Reduced from 60
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(yAxisSteps + 1, (index) {
                        final value = yAxisMax - (index * yAxisInterval);
                        return SizedBox(
                          height: 18, // Reduced height
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _formatCurrency(value),
                              style: GoogleFonts.poppins(
                                fontSize: 9, // Slightly smaller font
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  
                  const SizedBox(width: 4), // Reduced spacing
                  
                  // Scrollable chart area
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: math.max(280, sortedEntries.length * 45.0), // Slightly reduced
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Chart bars
                            SizedBox(
                              height: 150, // Fixed height to prevent overflow
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: sortedEntries.map((entry) {
                                  final barHeight = ((entry.value / yAxisMax) * 120).clamp(4.0, 120.0);
                                  
                                  return SizedBox(
                                    width: 35,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Value label on top of bar
                                        if (barHeight > 18)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 2),
                                            child: Text(
                                              '₹${entry.value.toStringAsFixed(0)}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 7,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFFFFB703),
                                              ),
                                            ),
                                          ),
                                        
                                        // Bar
                                        Container(
                                          width: 24,
                                          height: barHeight,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [
                                                const Color(0xFFFFB703),
                                                const Color(0xFFFFB703).withOpacity(0.7),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(3),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFFFB703).withOpacity(0.3),
                                                blurRadius: 3,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            
                            const SizedBox(height: 6), // Reduced spacing
                            
                            // X-axis labels
                            SizedBox(
                              height: 16, // Reduced height
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: sortedEntries.map((entry) {
                                  return SizedBox(
                                    width: 35,
                                    child: Text(
                                      entry.key,
                                      style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ORDERS CHART WITH FIXED Y-AXIS
  Widget _buildOrdersChart(Map<String, int> dailyOrders) {
    final sortedEntries = dailyOrders.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    if (sortedEntries.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No orders data available',
            style: GoogleFonts.poppins(color: Colors.grey[600]),
          ),
        ),
      );
    }

    // Calculate Y-axis scale for orders
    final maxOrders = sortedEntries.map((e) => e.value).reduce(math.max);
    
    double yAxisMax;
    int yAxisSteps = 5;
    
    if (maxOrders <= 10) {
      yAxisMax = ((maxOrders / 2).ceil() * 2).toDouble();
    } else if (maxOrders <= 25) {
      yAxisMax = ((maxOrders / 5).ceil() * 5).toDouble();
    } else if (maxOrders <= 50) {
      yAxisMax = ((maxOrders / 10).ceil() * 10).toDouble();
    } else if (maxOrders <= 100) {
      yAxisMax = ((maxOrders / 20).ceil() * 20).toDouble();
    } else {
      yAxisMax = ((maxOrders / 50).ceil() * 50).toDouble();
    }

    final yAxisInterval = yAxisMax / yAxisSteps;
    
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 16), // Reduced left padding
        child: Column(
          mainAxisSize: MainAxisSize.min, // Prevent overflow
          children: [
            Text(
              'Daily Orders',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12), // Reduced spacing
            
            Expanded(
              child: Row(
                children: [
                  // Fixed Y-axis - reduced width
                  SizedBox(
                    width: 50, // Reduced from 60
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(yAxisSteps + 1, (index) {
                        final value = yAxisMax - (index * yAxisInterval);
                        return SizedBox(
                          height: 18, // Reduced height
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${value.toInt()}',
                              style: GoogleFonts.poppins(
                                fontSize: 9, // Slightly smaller font
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  
                  const SizedBox(width: 4), // Reduced spacing
                  
                  // Scrollable chart area
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: math.max(280, sortedEntries.length * 45.0), // Slightly reduced
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Chart bars
                            SizedBox(
                              height: 150, // Fixed height to prevent overflow
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: sortedEntries.map((entry) {
                                  final barHeight = ((entry.value / yAxisMax) * 120).clamp(4.0, 120.0);
                                  
                                  return SizedBox(
                                    width: 35,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Value label on top of bar
                                        if (barHeight > 18)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 2),
                                            child: Text(
                                              '${entry.value}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 7,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ),
                                        
                                        // Bar
                                        Container(
                                          width: 24,
                                          height: barHeight,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [
                                                Colors.blue,
                                                Colors.blue.withOpacity(0.7),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(3),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.blue.withOpacity(0.3),
                                                blurRadius: 3,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            
                            const SizedBox(height: 6), // Reduced spacing
                            
                            // X-axis labels
                            SizedBox(
                              height: 16, // Reduced height
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: sortedEntries.map((entry) {
                                  return SizedBox(
                                    width: 35,
                                    child: Text(
                                      entry.key,
                                      style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to format currency values for Y-axis
  String _formatCurrency(double value) {
    if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}k';
    } else {
      return '₹${value.toStringAsFixed(0)}';
    }
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[500],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBreakdown(Map<String, int> statusCounts) {
    if (statusCounts.isEmpty) {
      return const Center(child: Text('No order data available'));
    }

    return Column(
      children: statusCounts.entries.map((entry) {
        final total = statusCounts.values.fold(0, (sum, count) => sum + count);
        final percentage = total > 0 ? (entry.value / total * 100) : 0;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getStatusColor(entry.key),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.key,
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ),
              Text(
                '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopItemsList(Map<String, dynamic> items, String type) {
    final sortedItems = items.entries.toList()
      ..sort((a, b) {
        if (type == 'revenue') {
          final aValue = (a.value is num) ? (a.value as num).toDouble() : 0.0;
          final bValue = (b.value is num) ? (b.value as num).toDouble() : 0.0;
          return bValue.compareTo(aValue);
        } else {
          final aValue = (a.value is num) ? (a.value as num).toInt() : 0;
          final bValue = (b.value is num) ? (b.value as num).toInt() : 0;
          return bValue.compareTo(aValue);
        }
      });
    
    final topItems = sortedItems.take(5).toList();
    
    if (topItems.isEmpty) {
      return const Center(child: Text('No data available'));
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: topItems.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = topItems[index];
          final value = type == 'revenue' 
              ? '₹${((item.value is num) ? (item.value as num).toDouble() : 0.0).toStringAsFixed(2)}'
              : '${((item.value is num) ? (item.value as num).toInt() : 0)} orders';
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFFFB703).withOpacity(0.1),
              child: Text(
                '${index + 1}',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFFB703),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              item.key,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFFB703),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStockStatusChart(Map<String, dynamic> data) {
    final available = data['availableItems'] ?? 0;
    final lowStock = data['lowStockItems'] ?? 0;
    final outOfStock = data['outOfStockItems'] ?? 0;
    final total = available + lowStock + outOfStock;
    
    if (total == 0) {
      return const Center(child: Text('No inventory data available'));
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stock Distribution',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildStockBar('Available', available, total, Colors.green),
          const SizedBox(height: 8),
          _buildStockBar('Low Stock', lowStock, total, Colors.orange),
          const SizedBox(height: 8),
          _buildStockBar('Out of Stock', outOfStock, total, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStockBar(String label, int value, int total, Color color) {
    final percentage = total > 0 ? (value / total) : 0.0;
    
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$value',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Colors.blue;
      case 'cooking':
        return Colors.orange;
      case 'cooked':
        return Colors.green;
      case 'pick up':
        return Colors.purple;
      case 'pickedup':
        return Colors.teal;
      case 'terminated':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}