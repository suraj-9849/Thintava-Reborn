// lib/screens/kitchen/kitchen_home.dart - FULLY CLIENT-SIDE FILTERING
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:canteen_app/widgets/order_expiry_timer.dart';
import 'package:canteen_app/screens/kitchen/kitchen_notification_test.dart';
import 'package:canteen_app/widgets/session_checker.dart';

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
    'Placed',
    'Cooking',
    'Cooked',
    'Pick Up',
    'Terminated'
  ];
  String _currentFilter = 'All';
  final _authService = AuthService();
  int _terminatedCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
      if (newStatus == 'Cooked') {
        updates['cookedTime'] = FieldValue.serverTimestamp();
      }
      if (newStatus == 'Pick Up') {
        updates['pickedUpTime'] = FieldValue.serverTimestamp();
      }
      if (newStatus == 'Terminated') {
        updates['terminatedTime'] = FieldValue.serverTimestamp();
      }

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

  // CLIENT-SIDE FILTERING FOR TODAY'S TERMINATED ORDERS
  int _getTerminatedCountFromDocs(List<QueryDocumentSnapshot> allDocs) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    int count = 0;
    for (var doc in allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String?;
      final timestamp = data['timestamp'] as Timestamp?;

      if (status == 'Terminated' && timestamp != null) {
        final orderDate = timestamp.toDate();
        if (orderDate.isAfter(startOfDay) && orderDate.isBefore(endOfDay)) {
          count++;
        }
      }
    }
    return count;
  }

  // CLIENT-SIDE FILTERING FOR ORDERS BASED ON CURRENT TAB
  List<QueryDocumentSnapshot> _filterOrdersForCurrentTab(
      List<QueryDocumentSnapshot> allDocs) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_currentFilter == 'Terminated') {
      // Return only today's terminated orders
      return allDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        final timestamp = data['timestamp'] as Timestamp?;

        if (status == 'Terminated' && timestamp != null) {
          final orderDate = timestamp.toDate();
          return orderDate.isAfter(startOfDay) && orderDate.isBefore(endOfDay);
        }
        return false;
      }).toList();
    } else {
      // For all other tabs, exclude terminated and completed orders
      final activeDocs = allDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        return status != 'Terminated' && status != 'PickedUp';
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
            tabs: _statusFilters.map((status) => Tab(text: status)).toList(),
          ),
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: "notification_test",
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              mini: true,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const KitchenNotificationTest()),
                );
              },
              child: const Icon(Icons.bug_report),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: "refresh",
              backgroundColor: const Color(0xFFFFB703),
              foregroundColor: Colors.black87,
              onPressed: () {
                setState(() {});
              },
              child: const Icon(Icons.refresh),
            ),
          ],
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

            // Update terminated count
            final newTerminatedCount = _getTerminatedCountFromDocs(allDocs);
            if (_terminatedCount != newTerminatedCount) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _terminatedCount = newTerminatedCount;
                  });
                }
              });
            }

            // Filter orders for current tab
            final filteredDocs = _filterOrdersForCurrentTab(allDocs);

            if (filteredDocs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        _currentFilter == 'Terminated'
                            ? Icons.delete_sweep_outlined
                            : Icons.food_bank_outlined,
                        size: 80,
                        color: _currentFilter == 'Terminated'
                            ? Colors.red.withOpacity(0.7)
                            : const Color(0xFFFFB703)),
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

            // Sort terminated orders by timestamp (most recent first)
            if (_currentFilter == 'Terminated') {
              filteredDocs.sort((a, b) {
                final aTime = (a.data() as Map<String, dynamic>)['timestamp']
                    as Timestamp?;
                final bTime = (b.data() as Map<String, dynamic>)['timestamp']
                    as Timestamp?;
                if (aTime == null || bTime == null) return 0;
                return bTime.compareTo(aTime); // Descending (most recent first)
              });
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
                    isTerminated: _currentFilter == 'Terminated',
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
      case 'Terminated':
        return "No terminated orders today";
      case 'All':
        return "No active orders";
      default:
        return "No orders with status: $_currentFilter";
    }
  }

  String _getEmptySubMessage() {
    switch (_currentFilter) {
      case 'Terminated':
        return "No orders were terminated today. Great job!";
      case 'All':
        return "All caught up! The kitchen is quiet for now.";
      default:
        return "Check other tabs for orders in different stages.";
    }
  }
}

class EnhancedOrderCard extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final Future<void> Function(String, String) onUpdate;
  final bool isTerminated;

  const EnhancedOrderCard({
    Key? key,
    required this.orderId,
    required this.data,
    required this.onUpdate,
    this.isTerminated = false,
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
      case 'Cooking':
        return Colors.orange;
      case 'Cooked':
        return const Color(0xFFFFB703);
      case 'Pick Up':
        return Colors.purple;
      case 'Terminated':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTerminatedTime(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      DateTime dateTime;
      if (timestamp is DateTime) {
        dateTime = timestamp;
      } else if (timestamp.toDate != null) {
        dateTime = timestamp.toDate();
      } else {
        return '';
      }

      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = capitalize(widget.data['status'] ?? '');
    final fullOrderId =
        widget.orderId; // Show full order ID instead of shortened

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

    // Get pickup time for timer (only for non-terminated orders)
    final pickedUpTime = widget.data['pickedUpTime'] as Timestamp?;

    // Get terminated time for terminated orders
    final terminatedTime = widget.data['terminatedTime'] as Timestamp?;
    final terminatedTimeStr =
        terminatedTime != null ? _formatTerminatedTime(terminatedTime) : '';

    return Card(
      elevation: widget.isTerminated ? 2 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _getStatusColor(status)
              .withOpacity(widget.isTerminated ? 0.3 : 0.5),
          width: 1.5,
        ),
      ),
      color: widget.isTerminated ? Colors.grey.shade50 : Colors.white,
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
                      if (widget.isTerminated) ...[
                        Icon(
                          Icons.cancel,
                          color: _getStatusColor(status),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                      ],
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
                    if (widget.isTerminated &&
                        terminatedTimeStr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        "Terminated: $terminatedTimeStr",
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
                      color:
                          widget.isTerminated ? Colors.black54 : Colors.black87,
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
                    color: widget.isTerminated
                        ? Colors.grey[100]
                        : Colors.grey[50],
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
                        color: widget.isTerminated
                            ? Colors.grey
                            : Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        userEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isTerminated
                              ? Colors.black38
                              : Colors.black54,
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
                        color: widget.isTerminated
                            ? Colors.grey
                            : Colors.grey[600]),
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

                // Status update section - only for non-terminated orders
                if (!widget.isTerminated) ...[
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
                                'Cooking',
                                'Cooked',
                                'Pick Up',
                                'Terminated'
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

                  // Timer widget - only for "Pick Up" status
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
                ] else ...[
                  // Terminated order reason/info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.red, size: 14),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            "Order was terminated due to pickup timeout",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
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

            // Expand/collapse indicator
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: widget.isTerminated ? Colors.black38 : Colors.black54,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
