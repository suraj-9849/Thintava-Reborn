import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// Helper
String capitalize(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';

class AdminKitchenViewScreen extends StatelessWidget {
  const AdminKitchenViewScreen({super.key});

  Stream<QuerySnapshot> getOrdersStream() {
    // Simple query without whereNotIn filter
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kitchen Dashboard (Admin View)',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFFFB703),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF3E0), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: getOrdersStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading orders: ${snapshot.error}',
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
              );
            }
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFB703)),
              );
            }

            final allDocs = snapshot.data!.docs;
            
            // Filter active orders in Dart
            final docs = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = (data['status'] as String?)?.toLowerCase() ?? '';
              return status != 'pickedup' && status != 'terminated';
            }).toList();

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.kitchen,
                      size: 72,
                      color: Color(0xFFFFB703),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No active orders',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The kitchen is currently idle',
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
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final doc = docs[i];
                final data = doc.data() as Map<String, dynamic>;
                final orderId = doc.id;
                return _KitchenOrderCard(
                  key: ValueKey(orderId),
                  orderId: orderId,
                  data: data,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _KitchenOrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;

  const _KitchenOrderCard({
    required Key key,
    required this.orderId,
    required this.data,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Safely get values with null checks
    final status = capitalize(data['status'] as String? ?? '');
    final shortId = orderId.substring(0, min(6, orderId.length));
    
    // Handle potentially missing or malformed 'items' field
    Map<String, dynamic> itemsMap = {};
    if (data['items'] is Map) {
      itemsMap = Map<String, dynamic>.from(data['items'] as Map);
    }
    
    final items = itemsMap.entries
        .map((e) => '${e.key} (${e.value})')
        .join(', ');
    
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final timeAgo = timestamp != null 
        ? _getTimeAgo(timestamp) 
        : 'Unknown time';

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'placed':
        statusColor = Colors.blue;
        break;
      case 'cooking':
        statusColor = Colors.orange;
        break;
      case 'cooked':
        statusColor = Colors.green;
        break;
      case 'pick up':
        statusColor = Colors.purple;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Order #$shortId",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusChip(status, statusColor),
              ],
            ),
            const Divider(),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  timeAgo,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Items:",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              items.isNotEmpty ? items : 'No items',
              style: GoogleFonts.poppins(
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Status Flow:",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildStatusFlow(status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Widget _buildStatusFlow(String currentStatus) {
    const statuses = ['Placed', 'Cooking', 'Cooked', 'Pick Up'];
    
    // Find the index of the current status (case-insensitive)
    final currentIndex = statuses.indexWhere(
        (s) => s.toLowerCase() == currentStatus.toLowerCase());

    return Row(
      children: List.generate(statuses.length * 2 - 1, (index) {
        // Check if it's a status or a connector
        if (index % 2 == 0) {
          // Status circle
          final statusIndex = index ~/ 2;
          final status = statuses[statusIndex];
          final isActive = statusIndex <= (currentIndex != -1 ? currentIndex : -1);
          
          return Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? const Color(0xFFFFB703) : Colors.grey[300],
            ),
            child: Icon(
              _getIconForStatus(status),
              color: isActive ? Colors.white : Colors.grey[500],
              size: 18,
            ),
          );
        } else {
          // Connector line
          final beforeIndex = index ~/ 2;
          final isActive = beforeIndex < (currentIndex != -1 ? currentIndex : -1);
          
          return Expanded(
            child: Container(
              height: 2,
              color: isActive ? const Color(0xFFFFB703) : Colors.grey[300],
            ),
          );
        }
      }),
    );
  }

  IconData _getIconForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Icons.receipt_outlined;
      case 'cooking':
        return Icons.soup_kitchen_outlined;
      case 'cooked':
        return Icons.restaurant_outlined;
      case 'pick up':
        return Icons.takeout_dining_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

// Helper function to avoid substring errors
int min(int a, int b) {
  return a < b ? a : b;
}