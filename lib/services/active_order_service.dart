// lib/services/active_order_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActiveOrderService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Check if user has an active order (not picked up or terminated)
  static Future<ActiveOrderResult> checkActiveOrder() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return ActiveOrderResult(hasActiveOrder: false);
      }

      // Get the most recent order for the user
      final orderSnapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (orderSnapshot.docs.isEmpty) {
        return ActiveOrderResult(hasActiveOrder: false);
      }

      final orderDoc = orderSnapshot.docs.first;
      final orderData = orderDoc.data();
      final status = orderData['status'] ?? 'Unknown';
      final orderId = orderDoc.id;
      final timestamp = orderData['timestamp'] as Timestamp?;
      final total = orderData['total'] ?? 0.0;

      // Define active statuses (orders that are still in progress)
      final activeStatuses = ['Placed', 'Cooking', 'Cooked', 'Pick Up'];
      
      if (activeStatuses.contains(status)) {
        return ActiveOrderResult(
          hasActiveOrder: true,
          orderId: orderId,
          status: status,
          timestamp: timestamp?.toDate(),
          total: total,
          orderData: orderData,
        );
      } else {
        return ActiveOrderResult(hasActiveOrder: false);
      }
    } catch (e) {
      print('❌ Error checking active order: $e');
      // Return false on error to avoid blocking users
      return ActiveOrderResult(hasActiveOrder: false);
    }
  }

  /// Get active order stream for real-time updates
  static Stream<ActiveOrderResult> watchActiveOrder() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(ActiveOrderResult(hasActiveOrder: false));
    }

    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return ActiveOrderResult(hasActiveOrder: false);
      }

      final orderDoc = snapshot.docs.first;
      final orderData = orderDoc.data();
      final status = orderData['status'] ?? 'Unknown';
      final orderId = orderDoc.id;
      final timestamp = orderData['timestamp'] as Timestamp?;
      final total = orderData['total'] ?? 0.0;

      final activeStatuses = ['Placed', 'Cooking', 'Cooked', 'Pick Up'];
      
      if (activeStatuses.contains(status)) {
        return ActiveOrderResult(
          hasActiveOrder: true,
          orderId: orderId,
          status: status,
          timestamp: timestamp?.toDate(),
          total: total,
          orderData: orderData,
        );
      } else {
        return ActiveOrderResult(hasActiveOrder: false);
      }
    }).handleError((error) {
      print('❌ Error in active order stream: $error');
      return ActiveOrderResult(hasActiveOrder: false);
    });
  }

  /// Check if user can place a new order
  static Future<bool> canPlaceNewOrder() async {
    final result = await checkActiveOrder();
    return !result.hasActiveOrder;
  }

  /// Get user's order history count
  static Future<int> getUserOrderCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final snapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting order count: $e');
      return 0;
    }
  }
}

class ActiveOrderResult {
  final bool hasActiveOrder;
  final String? orderId;
  final String? status;
  final DateTime? timestamp;
  final double? total;
  final Map<String, dynamic>? orderData;

  ActiveOrderResult({
    required this.hasActiveOrder,
    this.orderId,
    this.status,
    this.timestamp,
    this.total,
    this.orderData,
  });

  String get displayStatus {
    switch (status) {
      case 'Placed':
        return 'Order Placed';
      case 'Cooking':
        return 'Being Prepared';
      case 'Cooked':
        return 'Ready';
      case 'Pick Up':
        return 'Ready for Pickup';
      default:
        return status ?? 'Unknown';
    }
  }

  String get shortOrderId {
    if (orderId == null) return 'Unknown';
    return orderId!.length > 6 ? orderId!.substring(0, 6) : orderId!;
  }

  bool get isReadyForPickup => status == 'Pick Up';
  bool get isBeingPrepared => status == 'Cooking';
  bool get isReady => status == 'Cooked' || status == 'Pick Up';
}