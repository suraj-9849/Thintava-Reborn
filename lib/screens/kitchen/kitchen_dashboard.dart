import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Capitalize helper
String capitalize(String s) =>
    s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';

class KitchenDashboard extends StatefulWidget {
  const KitchenDashboard({Key? key}) : super(key: key);

  @override
  State<KitchenDashboard> createState() => _KitchenDashboardState();
}

class _KitchenDashboardState extends State<KitchenDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _statusFilters = ['All', 'Placed', 'Cooking', 'Cooked', 'Pick Up'];
  String _currentFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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

  Stream<QuerySnapshot> getOrdersStream() {
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
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
    
    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order $orderId updated to $newStatus'),
          backgroundColor: const Color(0xFFFFB703),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFB703),
        foregroundColor: Colors.black87,
        title: const Text("Kitchen Dashboard", style: TextStyle(color: Colors.black87)),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () => Navigator.pushReplacementNamed(context, '/kitchen-menu'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/auth');
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
          // Refresh by rebuilding the widget
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

          // Filter orders based on selected tab
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
  Timer? _timer;
  Duration _remaining = Duration.zero;
  Timestamp? _lastPickedTs;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _maybeStartTimer(widget.data);
  }

  @override
  void didUpdateWidget(covariant EnhancedOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTs = widget.data['pickedUpTime'] as Timestamp?;
    if (widget.data['status'] == 'Pick Up' && newTs != null && newTs != _lastPickedTs) {
      _maybeStartTimer(widget.data);
    }
  }

  void _maybeStartTimer(Map<String, dynamic> data) {
    _timer?.cancel();
    final status = data['status'];
    final ts = data['pickedUpTime'] as Timestamp?;
    if (status == 'Pick Up' && ts != null) {
      _lastPickedTs = ts;
      final expiry = ts.toDate().add(const Duration(minutes: 5));
      _remaining = expiry.difference(DateTime.now());
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final diff = expiry.difference(DateTime.now());
        setState(() => _remaining = diff);
        if (diff.isNegative) {
          _timer?.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
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
        return const Color(0xFFFFB703);  // Using yellow for cooked
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
    
    // Extract items with better formatting
    final itemsMap = widget.data['items'] as Map<String, dynamic>? ?? {};
    final timestamp = widget.data['timestamp'] as Timestamp?;
    final orderTime = timestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch)
        : DateTime.now();
    
    // Format time
    final timeStr = '${orderTime.hour.toString().padLeft(2, '0')}:${orderTime.minute.toString().padLeft(2, '0')}';
    
    Widget timerWidget = const SizedBox();
    if (status == 'Pick Up') {
      if (_remaining.isNegative) {
        timerWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.timer_off, color: Colors.red, size: 16),
              SizedBox(width: 4),
              Text("EXPIRED", 
                style: TextStyle(
                  color: Colors.red, 
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      } else {
        final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
        final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
        timerWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB703).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer, color: Color(0xFFFFB703), size: 16),
              const SizedBox(width: 4),
              Text("$m:$s", 
                style: const TextStyle(
                  color: Color(0xFFFFB703), 
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }
    }

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
                  Text(
                    "Order #$shortId",
                    style: const TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  const Spacer(),
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Items",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          itemsMap.entries.length > 0 
                              ? "${itemsMap.entries.length} item${itemsMap.entries.length > 1 ? 's' : ''}"
                              : "No items",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  DropdownButton<String>(
                    value: status,
                    underline: Container(),
                    icon: const Icon(Icons.arrow_drop_down_circle, color: Color(0xFFFFB703)),
                    borderRadius: BorderRadius.circular(12),
                    onChanged: (newStatus) {
                      if (newStatus != null) {
                        widget.onUpdate(widget.orderId, newStatus);
                      }
                    },
                    items: ['Placed', 'Cooking', 'Cooked', 'Pick Up']
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(s),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(s),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                  if (status == 'Pick Up') timerWidget,
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
                ...itemsMap.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB703).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'x${entry.value}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
                if (itemsMap.isEmpty)
                  const Text(
                    "No items in this order",
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.black54,
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