// lib/screens/admin/admin_kitchen_view_screen.dart - EXACT COPY OF KITCHEN HOME BUT READ-ONLY
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:canteen_app/services/auth_service.dart';

// Capitalize helper
String capitalize(String s) =>
    s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';

class AdminKitchenViewScreen extends StatefulWidget {
  const AdminKitchenViewScreen({Key? key}) : super(key: key);

  @override
  State<AdminKitchenViewScreen> createState() => _AdminKitchenViewScreenState();
}

class _AdminKitchenViewScreenState extends State<AdminKitchenViewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _statusFilters = [
    'All',
    'Placed',
    'Pick Up'
  ];
  String _currentFilter = 'All';
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentFilter = _statusFilters[_tabController.index];
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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


  // CLIENT-SIDE FILTERING FOR ORDERS BASED ON CURRENT TAB
  List<QueryDocumentSnapshot> _filterOrdersForCurrentTab(
      List<QueryDocumentSnapshot> allDocs) {
    // Exclude completed orders
    final activeDocs = allDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String?;
      return status != 'PickedUp';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFB703),
        foregroundColor: Colors.black87,
        title: const Text("Kitchen Dashboard (Admin View)",
            style: TextStyle(color: Colors.black87)),
        centerTitle: true,
        elevation: 0,
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
                child: ReadOnlyOrderCard(
                  key: ValueKey(doc.id),
                  orderId: doc.id,
                  data: data,
                  isTerminated: false,
                ),
              );
            },
          );
        },
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

class ReadOnlyOrderCard extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final bool isTerminated;

  const ReadOnlyOrderCard({
    Key? key,
    required this.orderId,
    required this.data,
    this.isTerminated = false,
  }) : super(key: key);

  @override
  State<ReadOnlyOrderCard> createState() => _ReadOnlyOrderCardState();
}

class _ReadOnlyOrderCardState extends State<ReadOnlyOrderCard> {
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


  @override
  Widget build(BuildContext context) {
    final status = capitalize(widget.data['status'] ?? '');
    final fullOrderId = widget.orderId; // Show full order ID

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
                        style: TextStyle(
                          color: widget.isTerminated
                              ? Colors.black38
                              : Colors.black54,
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
                      style: TextStyle(
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
                          style: TextStyle(
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.isTerminated
                              ? Colors.black54
                              : const Color(0xFFFFB703),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // READ-ONLY Status display - NO EDITING DROPDOWN
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
            ]
          ),
        ),
      ),
    );
  }
}