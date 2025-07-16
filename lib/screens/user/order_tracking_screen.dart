import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({Key? key}) : super(key: key);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  DateTime? _expiry;
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut)
    );
  }

  Stream<DocumentSnapshot?> getLatestOrderStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty ? snap.docs.first : null);
  }

  void _startCountdown(DateTime pickedAt) {
    _expiry = pickedAt.add(const Duration(minutes: 5));
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final diff = _expiry!.difference(DateTime.now());
      setState(() => _remaining = diff);
      if (diff.isNegative) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Placed':
        return Colors.blue;
      case 'Preparing':
        return Colors.orange;
      case 'Ready':
        return Colors.green;
      case 'Pick Up':
        return const Color(0xFFFFB703);
      case 'PickedUp':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Placed':
        return Icons.receipt_long;
      case 'Preparing':
        return Icons.restaurant;
      case 'Ready':
        return Icons.check_circle;
      case 'Pick Up':
        return Icons.delivery_dining;
      case 'PickedUp':
        return Icons.done_all;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Track Your Order",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFFFB703),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/history');
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot?>(
        stream: getLatestOrderStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Loading order details...",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }
          
          final doc = snap.data;
          if (doc == null || !doc.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_late_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No active orders found",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "You don't have any current orders to track",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/menu');
                    },
                    icon: const Icon(Icons.restaurant_menu),
                    label: const Text("Browse Menu"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB703),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          
          final data = doc.data()! as Map<String, dynamic>;
          final status = data['status'] ?? 'Unknown';
          final total = data['total'] ?? 0.0;
          final timestamp = data['timestamp'] as Timestamp?;
          final orderDate = timestamp != null 
            ? timestamp.toDate()
            : DateTime.now();
          
          final statusColor = _getStatusColor(status);
          final statusIcon = _getStatusIcon(status);
          
          // Process items data - FIXED TO HANDLE LIST FORMAT
          final itemsList = data['items'] as List<dynamic>?;
          final orderItems = <Map<String, dynamic>>[];
          
          if (itemsList != null) {
            for (var item in itemsList) {
              if (item is Map<String, dynamic>) {
                orderItems.add({
                  'id': item['id'] ?? '',
                  'name': item['name'] ?? 'Unknown Item',
                  'price': item['price'] ?? 0.0,
                  'quantity': item['quantity'] ?? 1,
                  'subtotal': item['subtotal'] ?? 0.0,
                });
              }
            }
          }

          // Countdown timer
          Widget countdown = const SizedBox();
          if (status == 'Pick Up' && data['pickedUpTime'] != null) {
            final pickedAt = (data['pickedUpTime'] as Timestamp).toDate();
            if (_expiry == null || _expiry!.difference(pickedAt).inMinutes < 5) {
              _startCountdown(pickedAt);
            }
            
            if (_remaining.isNegative) {
              countdown = Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_off, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      "Order expired",
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            } else {
              final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
              final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
              
              countdown = Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      "Time remaining: $m:$s",
                      style: GoogleFonts.poppins(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }
          }

          // If terminated, redirect to history
          if (status == 'Terminated') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(context, '/history');
            });
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB703),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          statusIcon,
                          size: 40,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Order Status",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Order Progress
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order Status timeline
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatusStep(
                              'Placed', 
                              Icons.receipt_long, 
                              status == 'Placed' || status == 'Preparing' || status == 'Ready' || status == 'Pick Up' || status == 'PickedUp' || status == 'Completed'
                            ),
                            Expanded(
                              child: Container(
                                height: 3,
                                color: status == 'Placed' || status == 'Unknown' 
                                  ? Colors.grey[300] 
                                  : const Color(0xFFFFB703),
                              ),
                            ),
                            _buildStatusStep(
                              'Preparing', 
                              Icons.restaurant, 
                              status == 'Preparing' || status == 'Ready' || status == 'Pick Up' || status == 'PickedUp' || status == 'Completed'
                            ),
                            Expanded(
                              child: Container(
                                height: 3,
                                color: status == 'Placed' || status == 'Preparing' || status == 'Unknown' 
                                  ? Colors.grey[300] 
                                  : const Color(0xFFFFB703),
                              ),
                            ),
                            _buildStatusStep(
                              'Ready', 
                              Icons.check_circle, 
                              status == 'Ready' || status == 'Pick Up' || status == 'PickedUp' || status == 'Completed'
                            ),
                            Expanded(
                              child: Container(
                                height: 3,
                                color: status == 'Placed' || status == 'Preparing' || status == 'Ready' || status == 'Unknown' 
                                  ? Colors.grey[300] 
                                  : const Color(0xFFFFB703),
                              ),
                            ),
                            _buildStatusStep(
                              'Pick Up', 
                              Icons.delivery_dining, 
                              status == 'Pick Up' || status == 'PickedUp' || status == 'Completed'
                            ),
                          ],
                        ),
                      ),
                      
                      // Countdown timer
                      if (countdown != const SizedBox())
                        Center(child: countdown),
                      
                      const SizedBox(height: 24),
                      
                      // Order details card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Order Details",
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF023047),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFB703).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "₹${total.toStringAsFixed(2)}",
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFFFB703),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Text(
                                "Items",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF023047),
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              // Items list - UPDATED TO HANDLE LIST FORMAT
                              if (orderItems.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    "No items in this order",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: orderItems.length,
                                  itemBuilder: (context, index) {
                                    final item = orderItems[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              "${item['quantity']}x",
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF023047),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['name'] ?? 'Unknown Item',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (item['price'] != null && item['price'] is num)
                                                  Text(
                                                    "₹${item['price'].toStringAsFixed(2)} per item",
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            "₹${item['subtotal'] != null && item['subtotal'] is num ? item['subtotal'].toStringAsFixed(2) : ((item['price'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}",
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF023047),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              
                              const Divider(height: 24),
                              
                              // Order time details
                              Row(
                                children: [
                                  const Icon(Icons.access_time, color: Colors.grey, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Ordered on: ${_formatDate(orderDate)}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Order ID
                              Row(
                                children: [
                                  const Icon(Icons.assignment, color: Colors.grey, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Order ID: ${doc.id.substring(0, 8)}...",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Pick up button
                      if (status == 'Pick Up')
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Show confirmation dialog
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(
                                    "Confirm Pick Up",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  content: Text(
                                    "Have you picked up your order? This action cannot be undone.",
                                    style: GoogleFonts.poppins(),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: Text(
                                        "CANCEL",
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFFB703),
                                      ),
                                      child: Text(
                                        "CONFIRM",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ) ?? false;
                              
                              if (!confirm) return;
                              
                              // Show loading dialog
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
                                  ),
                                ),
                              );
                              
                              try {
                                final id = doc.id;
                                final userId = FirebaseAuth.instance.currentUser!.uid;

                                final orderData = {...data, 'status': 'PickedUp'};

                                await FirebaseFirestore.instance
                                    .collection('orders')
                                    .doc(id)
                                    .update({
                                  'status': 'PickedUp',
                                  'pickedUpByUserTime': FieldValue.serverTimestamp(),
                                });

                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .collection('orderHistory')
                                    .doc(id)
                                    .set(orderData);

                                await FirebaseFirestore.instance
                                    .collection('adminOrderHistory')
                                    .doc(id)
                                    .set(orderData);
                                
                                // Close loading dialog
                                Navigator.pop(context);
                                
                                // Show success snackbar
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Order marked as picked up!",
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                
                                // Navigate to history
                                Navigator.pushReplacementNamed(context, '/history');
                              } catch (e) {
                                // Close loading dialog
                                Navigator.pop(context);
                                
                                // Show error snackbar
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Error updating order: $e",
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_circle),
                            label: Text(
                              "CONFIRM ORDER PICK UP",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFB703),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildStatusStep(String title, IconData icon, bool isActive) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFB703) : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : Colors.grey[600],
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isActive ? const Color(0xFF023047) : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
  
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    
    return "$day/$month/$year, $hour:$minute";
  }
}