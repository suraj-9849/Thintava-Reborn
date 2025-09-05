// lib/screens/kitchen/kitchen_home.dart - UPDATED WITH LIVE ORDERS PER ITEM TAB
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:canteen_app/widgets/session_checker.dart';
import 'package:canteen_app/presentation/widgets/kitchen/qr_scanner_widget.dart';

// Capitalize helper
String capitalize(String s) =>
    s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';

class KitchenHome extends StatefulWidget {
  const KitchenHome({Key? key}) : super(key: key);

  @override
  State<KitchenHome> createState() => _KitchenHomeState();
}

class _KitchenHomeState extends State<KitchenHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _statusFilters = [
    'All',
    'Items', // MOVED NEXT TO ALL
    'Order History',
    'Placed',
    'Pick Up'
  ];
  String _currentFilter = 'All';
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // Updated length to 5
    _tabController.addListener(() {
      setState(() {
        _currentFilter = _statusFilters[_tabController.index];
      });
    });

    // Start session listener
    _authService.startSessionListener(() {
      _handleForcedLogout();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _authService.stopSessionListener();
    super.dispose();
  }

  void _handleForcedLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/auth');
    }
  }

  // SINGLE STREAM FOR ALL ORDERS - NO COMPLEX QUERIES
  Stream<QuerySnapshot> getAllOrdersStream() {
    // Get ALL orders and filter client-side
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp',
            descending: false) // Simple order by timestamp only
        .snapshots();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final db = FirebaseFirestore.instance;
      final orderRef = db.collection('orders').doc(orderId);

      final updates = <String, Object>{'status': newStatus};

      await orderRef.update(updates);

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Order ${orderId.substring(0, 8)} updated to $newStatus'),
            backgroundColor: const Color(0xFFFFB703),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error updating order status: $e');
    }
  }


  // CLIENT-SIDE FILTERING FOR ORDERS BASED ON CURRENT TAB
  List<QueryDocumentSnapshot> _filterOrdersForCurrentTab(
      List<QueryDocumentSnapshot> allDocs) {
    if (_currentFilter == 'Items') {
      // Return only orders that are placed and need to be cooked
      return allDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        final timestamp = data['timestamp'] as Timestamp?;
        
        // Only include orders that are placed (not yet being cooked or picked up)
        if (status != 'Placed') return false;
        
        // Check if order is older than 24 hours (expired)
        if (timestamp != null) {
          final orderDate = timestamp.toDate();
          final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
          if (orderDate.isBefore(twentyFourHoursAgo)) return false;
        }
        
        return true;
      }).toList();
    } else if (_currentFilter == 'Order History') {
      // Return all orders including completed ones for history
      return allDocs.toList();
    } else {
      // For all other tabs, exclude completed orders
      final activeDocs = allDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        final timestamp = data['timestamp'] as Timestamp?;
        
        // Filter out picked up orders and expired orders (older than 24 hours)
        if (status == 'PickedUp') return false;
        
        // Check if order is older than 24 hours
        if (timestamp != null) {
          final orderDate = timestamp.toDate();
          final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
          if (orderDate.isBefore(twentyFourHoursAgo)) return false;
        }
        
        return true;
      }).toList();

      if (_currentFilter == 'All') {
        return activeDocs;
      } else {
        // Filter by specific status
        return activeDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = capitalize(data['status'] as String? ?? '');
          return status == _currentFilter;
        }).toList();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionChecker(
      authService: _authService,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFB703),
          foregroundColor: Colors.black87,
          title: const Text("Kitchen Dashboard",
              style: TextStyle(color: Colors.black87)),
          centerTitle: true,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.black87),
              tooltip: 'Scan QR Code',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QRScannerWidget(
                      onOrderCompleted: () {
                        // Refresh the kitchen dashboard when an order is completed
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black87),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB703),
                        ),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await _authService.logout();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/auth');
                  }
                }
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(0xFF004D40),
            indicatorWeight: 3,
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.black54,
            tabs: _statusFilters.map((status) => Tab(
              text: status
            )).toList(),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFFFFB703),
          foregroundColor: Colors.black87,
          onPressed: () {
            setState(() {});
          },
          child: const Icon(Icons.refresh),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: getAllOrdersStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              print('Stream error: ${snapshot.error}');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 60, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      "Error loading orders",
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please check your connection and try again",
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text("Try Again"),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
                ),
              );
            }

            // ALL CLIENT-SIDE FILTERING HERE
            final allDocs = snapshot.data!.docs;

            // NEW: Handle Items tab - Show live item counts
            if (_currentFilter == 'Items') {
              final activeOrders = _filterOrdersForCurrentTab(allDocs);
              return LiveItemCountView(activeOrders: activeOrders);
            }

            // NEW: Handle Order History tab - Show history view with search
            if (_currentFilter == 'Order History') {
              final allOrders = _filterOrdersForCurrentTab(allDocs);
              return OrderHistoryView(orders: allOrders);
            }

            // Filter orders for current tab
            final filteredDocs = _filterOrdersForCurrentTab(allDocs);

            if (filteredDocs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        Icons.food_bank_outlined,
                        size: 80,
                        color: const Color(0xFFFFB703)),
                    const SizedBox(height: 24),
                    Text(
                      _getEmptyMessage(),
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getEmptySubMessage(),
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }


            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredDocs.length,
              itemBuilder: (ctx, i) {
                final doc = filteredDocs[i];
                final data = doc.data()! as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EnhancedOrderCard(
                    key: ValueKey(doc.id),
                    orderId: doc.id,
                    data: data,
                    onUpdate: updateOrderStatus,
                    isTerminated: false,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _getEmptyMessage() {
    switch (_currentFilter) {
      case 'All':
        return "No active orders";
      default:
        return "No orders with status: $_currentFilter";
    }
  }

  String _getEmptySubMessage() {
    switch (_currentFilter) {
      case 'All':
        return "All caught up! The kitchen is quiet for now.";
      default:
        return "Check other tabs for orders in different stages.";
    }
  }
}

// NEW: Live Item Count View - Shows current active orders per item
class LiveItemCountView extends StatelessWidget {
  final List<QueryDocumentSnapshot> activeOrders;

  const LiveItemCountView({
    Key? key,
    required this.activeOrders,
  }) : super(key: key);

  Map<String, ItemCount> _calculateLiveItemCounts() {
    Map<String, ItemCount> itemCounts = {};

    for (var orderDoc in activeOrders) {
      final orderData = orderDoc.data() as Map<String, dynamic>;
      final itemsData = orderData['items'];
      final orderId = orderDoc.id;

      if (itemsData != null) {
        List<Map<String, dynamic>> parsedItems = [];

        // Parse items based on data structure
        if (itemsData is List) {
          for (var item in itemsData) {
            if (item is Map<String, dynamic>) {
              parsedItems.add(item);
            }
          }
        } else if (itemsData is Map<String, dynamic>) {
          itemsData.forEach((itemId, itemData) {
            if (itemData is Map<String, dynamic>) {
              parsedItems.add(itemData);
            }
          });
        }

        // Process each item
        for (var item in parsedItems) {
          final itemName = item['name'] as String? ?? 'Unknown Item';
          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;

          if (!itemCounts.containsKey(itemName)) {
            itemCounts[itemName] = ItemCount(
              name: itemName,
              totalQuantity: 0,
              placedQuantity: 0,
              cookingQuantity: 0,
              orderIds: [],
            );
          }

          final itemCount = itemCounts[itemName]!;
          
          // Update quantities - just total quantity now, no state-specific counts
          itemCount.totalQuantity += quantity;
          itemCount.orderIds.add(orderId.substring(0, 6));
        }
      }
    }

    return itemCounts;
  }

  @override
  Widget build(BuildContext context) {
    final itemCounts = _calculateLiveItemCounts();
    
    // Sort items by total quantity (most to least)
    final sortedItems = itemCounts.values.toList()
      ..sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));

    if (sortedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              "No Items to Prepare",
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "Items from new orders will appear here",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Calculate total items across all orders
    final totalItems = sortedItems.fold<int>(0, (sum, item) => sum + item.totalQuantity);

    return Column(
      children: [
        // Fixed Header - Summary Stats
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFB703), Color(0xFFE69500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.kitchen,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Cooking Queue",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$totalItems items • ${activeOrders.length} orders",
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  "${sortedItems.length}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFB703),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Items List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sortedItems.length,
            itemBuilder: (context, index) {
              final item = sortedItems[index];
              return LiveItemCard(
                itemCount: item,
                priority: index + 1,
              );
            },
          ),
        ),
      ],
    );
  }
}

// NEW: Item Count Data Class
class ItemCount {
  final String name;
  int totalQuantity;
  int placedQuantity;
  int cookingQuantity;
  List<String> orderIds;

  ItemCount({
    required this.name,
    required this.totalQuantity,
    required this.placedQuantity,
    required this.cookingQuantity,
    required this.orderIds,
  });
}

// NEW: Live Item Card Widget
class LiveItemCard extends StatelessWidget {
  final ItemCount itemCount;
  final int priority;

  const LiveItemCard({
    Key? key,
    required this.itemCount,
    required this.priority,
  }) : super(key: key);

  Color _getPriorityColor() {
    if (itemCount.totalQuantity >= 5) {
      return Colors.red; // High priority
    } else if (itemCount.totalQuantity >= 3) {
      return Colors.orange; // Medium priority
    } else {
      return Colors.blue; // Normal priority
    }
  }

  String _getPriorityLabel() {
    if (itemCount.totalQuantity >= 5) {
      return 'HIGH';
    } else if (itemCount.totalQuantity >= 3) {
      return 'MEDIUM';
    } else {
      return ''; // REMOVED NORMAL LABEL
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor();
    final priorityLabel = _getPriorityLabel();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: priorityColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Left side - Item info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Priority badge and item name row
                  Row(
                    children: [
                      if (priorityLabel.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: priorityColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            priorityLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          itemCount.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Quantity info
                  Text(
                    "${itemCount.totalQuantity} ${itemCount.totalQuantity > 1 ? 'items' : 'item'} needed",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Right side - Quantity badge
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: priorityColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  '${itemCount.totalQuantity}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: priorityColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Keep the existing EnhancedOrderCard class unchanged...
class EnhancedOrderCard extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final Future<void> Function(String, String) onUpdate;
  final bool isTerminated;
  final bool isReadOnly;

  const EnhancedOrderCard({
    Key? key,
    required this.orderId,
    required this.data,
    required this.onUpdate,
    this.isTerminated = false,
    this.isReadOnly = false,
  }) : super(key: key);

  @override
  State<EnhancedOrderCard> createState() => _EnhancedOrderCardState();
}

class _EnhancedOrderCardState extends State<EnhancedOrderCard> {
  bool _isExpanded = false;

  // Get appropriate color for order status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Placed':
        return Colors.blue;
      case 'Pick Up':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Helper function to normalize status and handle legacy "Terminated" orders
  String _normalizeStatus(String rawStatus) {
    final capitalizedStatus = capitalize(rawStatus);
    
    // Convert legacy "Terminated" status to "Pick Up" since those orders
    // are still available for pickup
    if (capitalizedStatus == 'Terminated') {
      return 'Pick Up';
    }
    
    // Only allow valid statuses in the simplified 2-state system
    if (capitalizedStatus == 'Placed' || capitalizedStatus == 'Pick Up') {
      return capitalizedStatus;
    }
    
    // Default fallback for any other invalid statuses
    return 'Placed';
  }

  @override
  Widget build(BuildContext context) {
    // Normalize status to handle legacy "Terminated" orders
    final rawStatus = widget.data['status'] ?? '';
    final status = _normalizeStatus(rawStatus);
    final fullOrderId = widget.orderId;

    // Get order data
    final itemsData = widget.data['items'];
    final userEmail = widget.data['userEmail'] as String? ?? 'Unknown';
    final total = widget.data['total'] ?? 0.0;

    List<Map<String, dynamic>> parsedItems = [];
    int totalItems = 0;

    if (itemsData != null) {
      if (itemsData is List) {
        for (var item in itemsData) {
          if (item is Map<String, dynamic>) {
            parsedItems.add({
              'name': item['name'] ?? 'Unknown Item',
              'quantity': item['quantity'] ?? 1,
              'price': item['price'] ?? 0.0,
              'subtotal': item['subtotal'] ?? 0.0,
            });
            totalItems += (item['quantity'] as num?)?.toInt() ?? 1;
          }
        }
      } else if (itemsData is Map<String, dynamic>) {
        itemsData.forEach((itemId, itemData) {
          if (itemData is Map<String, dynamic>) {
            parsedItems.add({
              'name': itemData['name'] ?? 'Unknown Item',
              'quantity': itemData['quantity'] ?? 1,
              'price': itemData['price'] ?? 0.0,
              'subtotal': itemData['subtotal'] ?? 0.0,
            });
            totalItems += (itemData['quantity'] as num?)?.toInt() ?? 1;
          }
        });
      }
    }

    final timestamp = widget.data['timestamp'] as Timestamp?;
    final orderTime = timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch)
        : DateTime.now();

    // Format time
    final timeStr =
        '${orderTime.hour.toString().padLeft(2, '0')}:${orderTime.minute.toString().padLeft(2, '0')}';

    final pickedUpTime = widget.data['pickedUpTime'] as Timestamp?;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _getStatusColor(status).withOpacity(0.5),
          width: 1.5,
        ),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status,
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Placed: $timeStr",
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Order ID on its own line
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    "Order ID: $fullOrderId",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Items info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Items",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalItems > 0
                            ? "$totalItems item${totalItems > 1 ? 's' : ''}"
                            : "No items",
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // User email section
                Row(
                  children: [
                    Icon(Icons.person,
                        size: 16,
                        color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        userEmail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Total amount section
                Row(
                  children: [
                    Icon(Icons.currency_rupee,
                        size: 16,
                        color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Total: ₹${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFB703),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Status update section - conditional based on isReadOnly
                if (widget.isReadOnly)
                  // Read-only status display
                  Row(
                    children: [
                      const Text(
                        "Status: ",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  // Editable status dropdown
                  Row(
                    children: [
                      const Text(
                        "Status: ",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color:
                                    _getStatusColor(status).withOpacity(0.3)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: status,
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  size: 14),
                              isDense: true,
                              isExpanded: true,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black87),
                              onChanged: (newStatus) {
                                if (newStatus != null && mounted) {
                                  widget.onUpdate(widget.orderId, newStatus);
                                }
                              },
                              items: [
                                'Placed',
                                'Pick Up'
                              ]
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(
                                          s,
                                          style: const TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

              ],
            ),

            if (_isExpanded) ...[
              const Divider(height: 24),
              const Text(
                "Order Details",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (parsedItems.isNotEmpty)
                ...parsedItems.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Qty: ${item['quantity']} × ₹${item['price'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${item['subtotal'].toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFB703),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList()
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 32,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "No items in this order",
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
            ],

            // Expand/collapse indicator
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.black54,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// NEW: Order History View with Search
class OrderHistoryView extends StatefulWidget {
  final List<QueryDocumentSnapshot> orders;

  const OrderHistoryView({
    Key? key,
    required this.orders,
  }) : super(key: key);

  @override
  State<OrderHistoryView> createState() => _OrderHistoryViewState();
}

class _OrderHistoryViewState extends State<OrderHistoryView> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> get _filteredOrders {
    if (_searchQuery.isEmpty) {
      return widget.orders..sort((a, b) {
        final aTimestamp = a.data() as Map<String, dynamic>?;
        final bTimestamp = b.data() as Map<String, dynamic>?;
        final aTime = (aTimestamp?['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (bTimestamp?['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime); // Most recent first
      });
    }
    
    return widget.orders.where((doc) {
      final orderId = doc.id.toLowerCase();
      return orderId.contains(_searchQuery.toLowerCase());
    }).toList()..sort((a, b) {
      final aTimestamp = a.data() as Map<String, dynamic>?;
      final bTimestamp = b.data() as Map<String, dynamic>?;
      final aTime = (aTimestamp?['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final bTime = (bTimestamp?['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      return bTime.compareTo(aTime); // Most recent first
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _filteredOrders;

    return Column(
      children: [
        // Search bar
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by Order ID...',
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
          ),
        ),
        
        // Results header
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.history, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Text(
                _searchQuery.isEmpty 
                  ? "All Orders (${filteredOrders.length})"
                  : "Search Results (${filteredOrders.length})",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),

        // Orders list
        Expanded(
          child: filteredOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty ? Icons.history : Icons.search_off,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _searchQuery.isEmpty 
                          ? "No Order History" 
                          : "No orders found",
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty 
                          ? "Order history will appear here"
                          : "Try searching with a different Order ID",
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final doc = filteredOrders[index];
                    final data = doc.data()! as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: EnhancedOrderCard(
                        key: ValueKey(doc.id),
                        orderId: doc.id,
                        data: data,
                        onUpdate: (String orderId, String newStatus) async {
                          // Read-only for history view - no updates allowed
                          return;
                        },
                        isTerminated: false,
                        isReadOnly: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}