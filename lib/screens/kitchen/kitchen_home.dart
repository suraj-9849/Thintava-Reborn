// lib/screens/kitchen/kitchen_home.dart - NOW SERVES AS THE MAIN DASHBOARD
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:canteen_app/widgets/order_expiry_timer.dart';
import 'package:canteen_app/widgets/session_checker.dart';

// Capitalize helper
String capitalize(String s) =>
    s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';

class KitchenHome extends StatefulWidget {
  const KitchenHome({Key? key}) : super(key: key);

  @override
  State<KitchenHome> createState() => _KitchenHomeState();
}

class _KitchenHomeState extends State<KitchenHome> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _statusFilters = ['All', 'Placed', 'Cooking', 'Cooked', 'Pick Up'];
  String _currentFilter = 'All';
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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

  Stream<QuerySnapshot> getOrdersStream() {
    // FIFO queue (oldest orders first)
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final db = FirebaseFirestore.instance;
      final orderRef = db.collection('orders').doc(orderId);

      final updates = <String, Object>{'status': newStatus};
      if (newStatus == 'Cooked') {
        updates['cookedTime'] = FieldValue.serverTimestamp();
      }
      if (newStatus == 'Pick Up') {
        updates['pickedUpTime'] = FieldValue.serverTimestamp();
      }

      await orderRef.update(updates);
      
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${orderId.substring(0, 6)} updated to $newStatus'),
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

  @override
  Widget build(BuildContext context) {
    return SessionChecker(
      authService: _authService,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFB703),
          foregroundColor: Colors.black87,
          title: const Text("Kitchen Dashboard", style: TextStyle(color: Colors.black87)),
          centerTitle: true,
          elevation: 0,
          // Remove the leading button since this is now the main screen
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black87),
              onPressed: () async {
                // Show confirmation dialog
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
            tabs: _statusFilters.map((status) => Tab(text: status)).toList(),
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
          stream: getOrdersStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      "Error loading orders",
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {}),
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

            // Filter orders based on selected tab - orders are already in FIFO order from query
            final allDocs = snapshot.data!.docs.where((d) {
              final s = d['status'];
              return s != 'Terminated' && s != 'PickedUp';
            }).toList();
            
            final docs = _currentFilter == 'All' 
                ? allDocs 
                : allDocs.where((d) => capitalize(d['status'] ?? '') == _currentFilter).toList();

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.food_bank_outlined, size: 80, color: Color(0xFFFFB703)),
                    const SizedBox(height: 24),
                    Text(
                      _currentFilter == 'All' 
                          ? "No active orders" 
                          : "No orders with status: $_currentFilter",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "All caught up! The kitchen is quiet for now.",
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final doc = docs[i];
                final data = doc.data()! as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EnhancedOrderCard(
                    key: ValueKey(doc.id),
                    orderId: doc.id,
                    data: data,
                    onUpdate: updateOrderStatus,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class EnhancedOrderCard extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final Future<void> Function(String, String) onUpdate;

  const EnhancedOrderCard({
    Key? key,
    required this.orderId,
    required this.data,
    required this.onUpdate,
  }) : super(key: key);

  @override
  State<EnhancedOrderCard> createState() => _EnhancedOrderCardState();
}

class _EnhancedOrderCardState extends State<EnhancedOrderCard> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant EnhancedOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Get appropriate color for order status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Placed':
        return Colors.blue;
      case 'Cooking':
        return Colors.orange;
      case 'Cooked':
        return const Color(0xFFFFB703);
      case 'Pick Up':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = capitalize(widget.data['status'] ?? '');
    final shortId = widget.orderId.substring(0, 6);
    
    // Get order data
    final itemsData = widget.data['items'];
    final userEmail = widget.data['userEmail'] as String? ?? 'Unknown';
    final total = widget.data['total'] ?? 0.0;

    List<Map<String, dynamic>> parsedItems = [];
    int totalItems = 0;

    if (itemsData != null) {
      if (itemsData is List) {
        // New format: List of items
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
        // Old format: Map of items
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
    final timeStr = '${orderTime.hour.toString().padLeft(2, '0')}:${orderTime.minute.toString().padLeft(2, '0')}';
    
    // Get pickup time for timer
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Order #$shortId",
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Fixed layout to prevent overflow completely
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items info on its own row
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
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // User email section
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
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
                      const Icon(Icons.currency_rupee, size: 16, color: Colors.grey),
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
                  
                  // Status update section - completely separate to avoid overflow
                  Row(
                    children: [
                      // Status text
                      const Text(
                        "Status: ",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      // Dropdown in container with fixed constraints
                      Expanded(
                        child: Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: status,
                              icon: const Icon(Icons.keyboard_arrow_down, size: 14),
                              isDense: true,
                              isExpanded: true,
                              style: const TextStyle(fontSize: 11, color: Colors.black87),
                              onChanged: (newStatus) {
                                if (newStatus != null && mounted) {
                                  widget.onUpdate(widget.orderId, newStatus);
                                }
                              },
                              items: ['Placed', 'Cooking', 'Cooked', 'Pick Up']
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
                  
                  // Timer widget - only show if status is "Pick Up" and we have pickup time
                  if (status == 'Pick Up' && pickedUpTime != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          "Timer: ",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                        SimpleCountdownTimer(
                          startTime: pickedUpTime.toDate(),
                          duration: const Duration(minutes: 5),
                        ),
                      ],
                    ),
                  ],
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
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.keyboard_arrow_up,
                    color: Colors.black54,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.black54,
                  ),
                ),
              ],
            ]
          ),
        ),
      ),
    );
  }
}