import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({Key? key}) : super(key: key);

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _filterStatus = "All"; // Filter option

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Custom date formatter without using intl package
  String formatDate(DateTime dateTime) {
    // Month names
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    // Get components
    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    final year = dateTime.year;
    
    // Format hour for 12-hour clock
    int hour = dateTime.hour;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    // Format minute with leading zero if needed
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    // Combine into formatted string
    return '$month $day, $year - $hour:$minute $amPm';
  }

  // Get status icon and color
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Icons.receipt_long;
      case 'cooking':
        return Icons.local_fire_department;
      case 'cooked':
        return Icons.restaurant;
      case 'pick up':
        return Icons.takeout_dining;
      case 'pickedup':
        return Icons.check_circle;
      default:
        return Icons.receipt;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Colors.blue;
      case 'cooking':
        return Colors.orange;
      case 'cooked':
        return const Color(0xFFFFB703);
      case 'pick up':
        return Colors.purple;
      case 'pickedup':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                "Not logged in",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/auth');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB703),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Login",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Query for orders based on filter
    Query ordersQuery = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true);
    
    // Apply status filter if not "All"
    if (_filterStatus != "All") {
      ordersQuery = ordersQuery.where('status', isEqualTo: _filterStatus);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Order History",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Filter dropdown
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              setState(() {
                _filterStatus = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: "All",
                child: Text("All Orders"),
              ),
              const PopupMenuItem(
                value: "Placed",
                child: Text("Placed"),
              ),
              const PopupMenuItem(
                value: "Cooking",
                child: Text("Cooking"),
              ),
              const PopupMenuItem(
                value: "Cooked",
                child: Text("Cooked"),
              ),
              const PopupMenuItem(
                value: "Pick Up",
                child: Text("Ready for Pickup"),
              ),
              const PopupMenuItem(
                value: "PickedUp",
                child: Text("Completed"),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFB703), Color(0xFFFFC107)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter indicator
                if (_filterStatus != "All")
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Filtered by: $_filterStatus",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _filterStatus = "All";
                              });
                            },
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Orders list in a glass card
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: ordersQuery.snapshots(),
                            builder: (context, snapshot) {
                              // Loading state
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
                                  ),
                                );
                              }
                              
                              final orders = snapshot.data!.docs;
                              
                              // Empty orders state
                              if (orders.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.receipt_long,
                                        size: 80,
                                        color: Colors.grey.withOpacity(0.6),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _filterStatus == "All"
                                            ? "You have no orders yet"
                                            : "No $_filterStatus orders found",
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _filterStatus == "All"
                                            ? "Your order history will appear here"
                                            : "Try a different filter option",
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      if (_filterStatus == "All")
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.pushNamed(context, '/menu');
                                          },
                                          icon: const Icon(Icons.restaurant_menu),
                                          label: Text(
                                            "Browse Menu",
                                            style: GoogleFonts.poppins(),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFFFB703),
                                            foregroundColor: Colors.black87,
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }
                              
                              // Build the list of orders
                              return ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: orders.length,
                                itemBuilder: (context, index) {
                                  final orderDoc = orders[index];
                                  final orderId = orderDoc.id;
                                  final data = orderDoc.data() as Map<String, dynamic>;
                                  
                                  // Extract order details
                                  final orderItems = (data['items'] as Map<String, dynamic>?) ?? {};
                                  final status = data['status'] ?? 'Unknown';
                                  
                                  DateTime timestamp;
                                  try {
                                    timestamp = (data['timestamp'] as Timestamp).toDate();
                                  } catch (e) {
                                    // Fallback if timestamp conversion fails
                                    timestamp = DateTime.now();
                                    print('Error parsing timestamp: $e');
                                  }
                                  
                                  // Use our custom date formatter
                                  String formattedDate;
                                  try {
                                    formattedDate = formatDate(timestamp);
                                  } catch (e) {
                                    // Fallback if formatting fails
                                    formattedDate = timestamp.toString();
                                    print('Error formatting date: $e');
                                  }
                                  
                                  final total = data['total'] ?? 0.0;
                                  
                                  // Display a shortened version of the order ID
                                  String shortOrderId;
                                  try {
                                    // Use substring only if ID is long enough
                                    shortOrderId = orderId.length > 6 
                                        ? orderId.substring(0, 6) 
                                        : orderId;
                                  } catch (e) {
                                    // Fallback if substring fails
                                    shortOrderId = orderId;
                                    print('Error shortening order ID: $e');
                                  }
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
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
                                      border: Border.all(
                                        color: _getStatusColor(status).withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                        dividerColor: Colors.transparent,
                                      ),
                                      child: ExpansionTile(
                                        leading: CircleAvatar(
                                          backgroundColor: _getStatusColor(status).withOpacity(0.2),
                                          child: Icon(
                                            _getStatusIcon(status),
                                            color: _getStatusColor(status),
                                          ),
                                        ),
                                        title: Text(
                                          "Order #$shortOrderId",
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    formattedDate,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, 
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(status).withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    status,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: _getStatusColor(status),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "Total: ₹${total.toStringAsFixed(2)}",
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFFFFB703),
                                              ),
                                            ),
                                          ],
                                        ),
                                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        children: [
                                          const Divider(),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    "Order Items",
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              if (orderItems.isNotEmpty)
                                                ...orderItems.entries.map((item) {
                                                  return Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFFFB703).withOpacity(0.1),
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: const Icon(
                                                            Icons.restaurant,
                                                            size: 16,
                                                            color: Color(0xFFFFB703),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Expanded(
                                                          child: Text(
                                                            item.key,
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 14,
                                                              color: Colors.black87,
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFFFB703).withOpacity(0.2),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Text(
                                                            "x ${item.value}",
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.black87,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList()
                                              else
                                                Text(
                                                  "No items in this order",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}