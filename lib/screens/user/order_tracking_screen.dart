// lib/screens/user/order_tracking_screen.dart - COMPLETE FIXED VERSION
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:canteen_app/widgets/order_expiry_timer.dart';
import 'package:canteen_app/screens/user/user_home.dart';

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

  // FIXED: Get latest order stream to include all statuses and handle terminated orders
  Stream<DocumentSnapshot?> getLatestOrderStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    
    // Get the most recent order regardless of status to handle terminated orders properly
    return FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty ? snap.docs.first : null);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // FIXED: Updated status mapping to match kitchen backend statuses
  String _getDisplayStatus(String status) {
    switch (status) {
      case 'Placed':
        return 'Order Placed';
      case 'Cooking':
        return 'Being Prepared';
      case 'Cooked':
        return 'Ready';
      case 'Pick Up':
        return 'Ready for Pickup';
      case 'PickedUp':
        return 'Completed';
      case 'Terminated':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Placed':
        return Colors.blue;
      case 'Cooking':
        return Colors.orange;
      case 'Cooked':
        return Colors.green;
      case 'Pick Up':
        return const Color(0xFFFFB703);
      case 'PickedUp':
        return Colors.green;
      case 'Terminated':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Placed':
        return Icons.receipt_long;
      case 'Cooking':
        return Icons.restaurant;
      case 'Cooked':
        return Icons.check_circle;
      case 'Pick Up':
        return Icons.delivery_dining;
      case 'PickedUp':
        return Icons.done_all;
      case 'Terminated':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  // FIXED: Updated progress logic to handle correct status flow: Placed -> Cooking -> Cooked -> Pick Up
  bool _isStatusActive(String currentStatus, String checkStatus) {
    final statusOrder = ['Placed', 'Cooking', 'Cooked', 'Pick Up', 'PickedUp'];
    final currentIndex = statusOrder.indexOf(currentStatus);
    final checkIndex = statusOrder.indexOf(checkStatus);
    
    // If status is terminated, no steps should be active
    if (currentStatus == 'Terminated') return false;
    
    return currentIndex >= checkIndex && checkIndex != -1;
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
          
          // FIXED: Handle different cases properly without auto-redirect
          if (doc == null || !doc.exists) {
            return _buildNoOrdersState();
          }

          final data = doc.data()! as Map<String, dynamic>;
          final status = data['status'] ?? 'Unknown';
          
          // FIXED: Handle terminated orders in UI instead of redirecting
          if (status == 'Terminated') {
            return _buildTerminatedOrderState(doc.id, data);
          }
          
          // FIXED: Handle completed orders
          if (status == 'PickedUp') {
            return _buildCompletedOrderState(doc.id, data);
          }
          
          // FIXED: Check if this is actually an active order
          final activeStatuses = ['Placed', 'Cooking', 'Cooked', 'Pick Up'];
          if (!activeStatuses.contains(status)) {
            return _buildNoActiveOrderState(status);
          }
          
          return _buildActiveOrderContent(doc, data, status);
        },
      ),
    );
  }

  Widget _buildNoOrdersState() {
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
            "No orders found",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You don't have any orders to track",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to home tab
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserHome(initialIndex: 0),
                ),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB703),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.restaurant_menu),
            label: Text(
              "Browse Menu",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminatedOrderState(String orderId, Map<String, dynamic> data) {
    final total = data['total'] ?? 0.0;
    final timestamp = data['timestamp'] as Timestamp?;
    final orderDate = timestamp?.toDate() ?? DateTime.now();
    
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Order Cancelled",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Order #${orderId.substring(0, 8)}",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Order Total:",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        "₹${total.toStringAsFixed(2)}",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Order Date:",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        _formatDate(orderDate),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "This order was cancelled due to pickup timeout. If you have any questions, please contact support.",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserHome(initialIndex: 2), // History tab
                        ),
                        (route) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      side: BorderSide(color: Colors.grey[400]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.history, size: 18),
                    label: Text(
                      "View History",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserHome(initialIndex: 0), // Home tab
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB703),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.restaurant_menu, size: 18),
                    label: Text(
                      "Order Again",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedOrderState(String orderId, Map<String, dynamic> data) {
    final total = data['total'] ?? 0.0;
    final timestamp = data['timestamp'] as Timestamp?;
    final orderDate = timestamp?.toDate() ?? DateTime.now();
    
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.done_all,
                size: 48,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Order Completed!",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Order #${orderId.substring(0, 8)}",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.celebration, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Thank you for your order! We hope you enjoyed your meal.",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserHome(initialIndex: 2), // History tab
                        ),
                        (route) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      side: BorderSide(color: Colors.grey[400]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.history, size: 18),
                    label: Text(
                      "View History",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserHome(initialIndex: 0), // Home tab
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB703),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.restaurant_menu, size: 18),
                    label: Text(
                      "Order Again",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoActiveOrderState(String lastStatus) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            "No Active Orders",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your last order status was: $lastStatus",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserHome(initialIndex: 2), // History tab
                    ),
                    (route) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  side: BorderSide(color: Colors.grey[400]!),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.history, size: 18),
                label: Text(
                  "View History",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserHome(initialIndex: 0), // Home tab
                    ),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB703),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.restaurant_menu, size: 18),
                label: Text(
                  "Order Now",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderContent(DocumentSnapshot doc, Map<String, dynamic> data, String status) {
    final displayStatus = _getDisplayStatus(status);
    final total = data['total'] ?? 0.0;
    final timestamp = data['timestamp'] as Timestamp?;
    final orderDate = timestamp != null 
      ? timestamp.toDate()
      : DateTime.now();
    
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    
    // Process items data
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

    // Get pickup time for timer
    final pickedUpTime = data['pickedUpTime'] as Timestamp?;

    return Column(
      children: [
        // FIXED: Made content scrollable but keep pickup button visible
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
                
                // Order Progress
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // FIXED: Order Status timeline with correct progress logic (Placed -> Cooking -> Cooked -> Pick Up)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatusStep(
                              'Placed', 
                              Icons.receipt_long, 
                              _isStatusActive(status, 'Placed')
                            ),
                            Expanded(
                              child: Container(
                                height: 3,
                                color: _isStatusActive(status, 'Cooking') 
                                  ? const Color(0xFFFFB703) 
                                  : Colors.grey[300],
                              ),
                            ),
                            _buildStatusStep(
                              'Cooking', 
                              Icons.restaurant, 
                              _isStatusActive(status, 'Cooking')
                            ),
                            Expanded(
                              child: Container(
                                height: 3,
                                color: _isStatusActive(status, 'Cooked') 
                                  ? const Color(0xFFFFB703) 
                                  : Colors.grey[300],
                              ),
                            ),
                            _buildStatusStep(
                              'Cooked', 
                              Icons.check_circle, 
                              _isStatusActive(status, 'Cooked')
                            ),
                            Expanded(
                              child: Container(
                                height: 3,
                                color: _isStatusActive(status, 'Pick Up') 
                                  ? const Color(0xFFFFB703) 
                                  : Colors.grey[300],
                              ),
                            ),
                            _buildStatusStep(
                              'Pick Up', 
                              Icons.delivery_dining, 
                              _isStatusActive(status, 'Pick Up')
                            ),
                          ],
                        ),
                      ),
                      
                      // Timer widget - only show if status is "Pick Up" and we have pickup time
                      if (status == 'Pick Up' && pickedUpTime != null)
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
                      
                      // FIXED: Show pickup button at top when status is "Pick Up"
                      if (status == 'Pick Up')
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          child: SizedBox(
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
                                  
                                  // Navigate to UserHome with History tab
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const UserHome(initialIndex: 2), // History tab
                                    ),
                                    (route) => false,
                                  );
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
                                elevation: 3,
                              ),
                            ),
                          ),
                        ),
                      
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
                              
                              // Items list
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