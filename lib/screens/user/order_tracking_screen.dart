// lib/screens/user/order_tracking_screen.dart - OPTIMIZED VERSION
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:canteen_app/widgets/order_expiry_timer.dart';
import 'package:canteen_app/screens/user/user_home.dart';
import 'package:canteen_app/core/utils/user_utils.dart';
import 'package:canteen_app/core/enums/user_enums.dart';
import 'package:canteen_app/presentation/widgets/order/order_progress_bar.dart';
import 'package:canteen_app/presentation/widgets/order/order_details_card.dart';
import 'package:canteen_app/presentation/widgets/order/pickup_button.dart';
import 'package:canteen_app/presentation/widgets/order/order_state_handlers.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({Key? key}) : super(key: key);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with SingleTickerProviderStateMixin {
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  void _handleTimerExpired() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your order pickup time has expired! Please contact support if needed.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
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
            return const NoOrdersState();
          }

          final data = doc.data()! as Map<String, dynamic>;
          final status = data['status'] ?? 'Unknown';
          final statusType = UserUtils.getOrderStatusType(status);
          
          if (statusType == OrderStatusType.terminated) {
            return TerminatedOrderState(
              orderId: doc.id,
              orderData: data,
            );
          }
          
          if (statusType == OrderStatusType.pickedUp) {
            return CompletedOrderState(
              orderId: doc.id,
              orderData: data,
            );
          }
          
          final activeStatuses = [
            OrderStatusType.placed,
            OrderStatusType.cooking,
            OrderStatusType.cooked,
            OrderStatusType.pickUp
          ];
          
          if (!activeStatuses.contains(statusType)) {
            return NoActiveOrderState(lastStatus: status);
          }
          
          return _buildActiveOrderContent(doc, data, statusType);
        },
      ),
    );
  }

  Widget _buildActiveOrderContent(DocumentSnapshot doc, Map<String, dynamic> data, OrderStatusType statusType) {
    final displayStatus = statusType.displayName;
    final total = data['total'] ?? 0.0;
    final timestamp = data['timestamp'] as Timestamp?;
    final orderDate = timestamp?.toDate() ?? DateTime.now();
    
    final statusColor = UserUtils.getStatusColor(statusType);
    final statusIcon = UserUtils.getStatusIcon(statusType);
    
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

    final pickedUpTime = data['pickedUpTime'] as Timestamp?;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
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
                        displayStatus,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order Progress
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 24),
                        child: OrderProgressBar(currentStatus: statusType),
                      ),
                      
                      // Timer widget
                      if (statusType == OrderStatusType.pickUp && pickedUpTime != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Center(
                            child: OrderExpiryTimer(
                              pickedUpTime: pickedUpTime.toDate(),
                              onExpired: _handleTimerExpired,
                              expiryDuration: const Duration(minutes: 5),
                            ),
                          ),
                        ),
                      
                      // Pickup button
                      if (statusType == OrderStatusType.pickUp)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          child: PickupButton(
                            orderId: doc.id,
                            orderData: data,
                          ),
                        ),
                      
                      const SizedBox(height: 24),
                      
                      // Order details
                      OrderDetailsCard(
                        orderId: doc.id,
                        orderDate: orderDate,
                        total: total,
                        orderItems: orderItems,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}