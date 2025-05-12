import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminLiveOrdersScreen extends StatelessWidget {
  const AdminLiveOrdersScreen({super.key});

  Stream<QuerySnapshot> getActiveOrdersStream() {
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<String> fetchUserEmail(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['email'] ?? 'Unknown Email';
      }
    } catch (e) {
      print('Error fetching user email: $e');
    }
    return 'Unknown Email';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Live Orders',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFFFFB703),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF3E0), Colors.white],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: getActiveOrdersStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading orders: ${snapshot.error}',
                  style: GoogleFonts.poppins(),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB703)));
            }

            final orders = snapshot.data!.docs;
            
            // Filter out terminated and picked up orders
            final activeOrders = orders.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] as String?;
              return status != 'PickedUp' && status != 'Terminated';
            }).toList();

            if (activeOrders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      size: 72,
                      color: Color(0xFFDDDDDD),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No active orders at the moment',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'New orders will appear here when placed',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: activeOrders.length,
              itemBuilder: (context, index) {
                final orderDoc = activeOrders[index];
                final orderData = orderDoc.data() as Map<String, dynamic>;
                final orderId = orderDoc.id;
                
                // Safely get values with null checks
                final status = orderData['status'] as String? ?? 'Unknown';
                final timestamp = orderData['timestamp'] as Timestamp?;
                final userId = orderData['userId'] as String? ?? '';
                final total = orderData['total'] ?? 0.0;
                
                // Handle potentially missing or malformed 'items' field
                Map<String, dynamic> itemsMap = {};
                if (orderData['items'] is Map) {
                  itemsMap = Map<String, dynamic>.from(orderData['items'] as Map);
                }
                
                final items = itemsMap.entries
                    .map((e) => '${e.key} × ${e.value}')
                    .join(', ');

                return FutureBuilder<String>(
                  future: fetchUserEmail(userId),
                  builder: (context, emailSnapshot) {
                    final email = emailSnapshot.data ?? 'Loading...';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 4,
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
                                Row(
                                  children: [
                                    _buildStatusBadge(status),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Order #${orderId.substring(0, min(6, orderId.length))}',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '₹$total',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: const Color(0xFFFFB703),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    email,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  timestamp != null
                                      ? _formatDateTime(timestamp.toDate())
                                      : 'Unknown time',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Items:',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              items.isNotEmpty ? items : 'No items',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'placed':
        color = Colors.blue;
        break;
      case 'cooking':
        color = Colors.orange;
        break;
      case 'cooked':
        color = Colors.green;
        break;
      case 'pick up':
        color = Colors.purple;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    // Check if it's today
    final now = DateTime.now();
    if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
      return 'Today at ${_formatTime(dateTime)}';
    }
    
    // Check if it's yesterday
    final yesterday = now.subtract(const Duration(days: 1));
    if (dateTime.year == yesterday.year && dateTime.month == yesterday.month && dateTime.day == yesterday.day) {
      return 'Yesterday at ${_formatTime(dateTime)}';
    }
    
    // Otherwise return the full date
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${_formatTime(dateTime)}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// Helper function to avoid substring errors
int min(int a, int b) {
  return a < b ? a : b;
}