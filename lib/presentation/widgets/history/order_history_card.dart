// lib/presentation/widgets/history/order_history_card.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/user_utils.dart';
import '../../../core/enums/user_enums.dart';
import '../common/status_indicator.dart';

class OrderHistoryCard extends StatelessWidget {
  final DocumentSnapshot orderDoc;
  final int index;
  
  const OrderHistoryCard({
    Key? key,
    required this.orderDoc,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final orderId = orderDoc.id;
    final data = orderDoc.data() as Map<String, dynamic>;
    
    final itemsData = data['items'];
    final orderItems = _processOrderItems(itemsData);
    
    final status = data['status'] ?? 'Unknown';
    final statusType = UserUtils.getOrderStatusType(status);
    
    DateTime timestamp;
    try {
      timestamp = (data['timestamp'] as Timestamp).toDate();
    } catch (e) {
      timestamp = DateTime.now();
      print('Error parsing timestamp: $e');
    }
    
    String formattedDate;
    try {
      formattedDate = UserUtils.formatDate(timestamp);
    } catch (e) {
      formattedDate = timestamp.toString();
      print('Error formatting date: $e');
    }
    
    final total = data['total'] ?? 0.0;
    final shortOrderId = orderId.length > 6 ? orderId.substring(0, 6) : orderId;
    
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
          color: UserUtils.getStatusColor(statusType).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: UserUtils.getStatusColor(statusType).withOpacity(0.2),
            child: Icon(
              UserUtils.getStatusIcon(statusType),
              color: UserUtils.getStatusColor(statusType),
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
              Text(
                formattedDate,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black54,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    flex: 1,
                    child: StatusIndicator(
                      status: statusType,
                      isCompact: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 1,
                    child: Text(
                      "₹${total.toStringAsFixed(2)}",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFFB703),
                      ),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Divider(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Order Items",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                if (orderItems.isNotEmpty)
                  ...orderItems.map((item) => _buildOrderItem(item)).toList()
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
  }

  List<Map<String, dynamic>> _processOrderItems(dynamic itemsData) {
    final List<Map<String, dynamic>> orderItems = [];
    
    if (itemsData != null) {
      if (itemsData is List<dynamic>) {
        // Handle new List format from cart_screen.dart
        for (var item in itemsData) {
          if (item is Map<String, dynamic>) {
            orderItems.add({
              'name': item['name'] ?? 'Unknown Item',
              'quantity': item['quantity'] ?? 1,
              'price': item['price'] ?? 0.0,
              'subtotal': item['subtotal'] ?? 0.0,
            });
          }
        }
      } else if (itemsData is Map<String, dynamic>) {
        // Handle old Map format (for backward compatibility)
        itemsData.forEach((key, value) {
          orderItems.add({
            'name': key,
            'quantity': value is int ? value : (int.tryParse(value.toString()) ?? 1),
            'price': 0.0, // Price not available in old format
            'subtotal': 0.0,
          });
        });
      }
    }
    
    return orderItems;
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB703).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant,
                size: 14,
                color: Color(0xFFFFB703),
              ),
            ),
            const SizedBox(width: 8),
            // Item details in a column layout
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item['name'] ?? 'Unknown Item',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        "Qty: ${item['quantity']}",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item['price'] != null && item['price'] > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          "₹${item['price'].toStringAsFixed(2)} each",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Subtotal (if available)
            if (item['subtotal'] != null && item['subtotal'] > 0)
              Text(
                "₹${item['subtotal'].toStringAsFixed(2)}",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFFB703),
                ),
              ),
          ],
        ),
      ),
    );
  }
}