// lib/presentation/widgets/history/order_history_card.dart - FIXED OVERFLOW VERSION
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
    
    // FIXED: Special handling for terminated orders
    Widget statusWidget;
    if (statusType == OrderStatusType.terminated) {
      // Check if terminated order is from today
      final now = DateTime.now();
      final isToday = timestamp.year == now.year && 
                     timestamp.month == now.month && 
                     timestamp.day == now.day;
      
      statusWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isToday ? Colors.orange.withOpacity(0.1) : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isToday ? Colors.orange.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isToday ? Icons.access_time : Icons.cancel,
              color: isToday ? Colors.orange : Colors.red,
              size: 10,
            ),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                isToday ? 'Expired' : 'Terminated',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isToday ? Colors.orange : Colors.red,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else {
      statusWidget = StatusIndicator(
        status: statusType,
        isCompact: true,
      );
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
          color: _getBorderColor(statusType, timestamp).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: _getBorderColor(statusType, timestamp).withOpacity(0.2),
            child: Icon(
              _getStatusIcon(statusType, timestamp),
              color: _getBorderColor(statusType, timestamp),
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
              const SizedBox(height: 6),
              // FIXED: Use Intrinsic widgets to prevent overflow
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status widget with flexible sizing
                    Flexible(
                      flex: 2,
                      child: Container(
                        alignment: Alignment.centerLeft,
                        child: statusWidget,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Price with flexible sizing
                    Flexible(
                      flex: 1,
                      child: Container(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "₹${total.toStringAsFixed(2)}",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFFB703),
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ),
                  ],
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
                
                // FIXED: Show pickup instructions for terminated orders from today
                if (statusType == OrderStatusType.terminated && _isFromToday(timestamp))
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB703).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFB703).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFFFFB703), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Still available for pickup today!",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFFB703),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Show Order ID to kitchen staff: $orderId",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // FIXED: Helper methods for terminated orders
  Color _getBorderColor(OrderStatusType statusType, DateTime timestamp) {
    if (statusType == OrderStatusType.terminated) {
      return _isFromToday(timestamp) ? Colors.orange : Colors.red;
    }
    return UserUtils.getStatusColor(statusType);
  }

  IconData _getStatusIcon(OrderStatusType statusType, DateTime timestamp) {
    if (statusType == OrderStatusType.terminated) {
      return _isFromToday(timestamp) ? Icons.access_time : Icons.cancel;
    }
    return UserUtils.getStatusIcon(statusType);
  }

  bool _isFromToday(DateTime timestamp) {
    final now = DateTime.now();
    return timestamp.year == now.year && 
           timestamp.month == now.month && 
           timestamp.day == now.day;
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
            // FIXED: Item details with proper flex handling
            Expanded(
              flex: 3,
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
                  // FIXED: Wrap quantity and price info properly
                  Wrap(
                    spacing: 8,
                    children: [
                      Text(
                        "Qty: ${item['quantity']}",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item['price'] != null && item['price'] > 0)
                        Text(
                          "₹${item['price'].toStringAsFixed(2)} each",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // FIXED: Subtotal with constrained width
            if (item['subtotal'] != null && item['subtotal'] > 0)
              Flexible(
                flex: 1,
                child: Container(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "₹${item['subtotal'].toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFFB703),
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}