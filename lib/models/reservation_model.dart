// lib/models/reservation_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum ReservationStatus {
  active,
  completed,
  failed,
  expired,
}

extension ReservationStatusExtension on ReservationStatus {
  String get value {
    switch (this) {
      case ReservationStatus.active:
        return 'active';
      case ReservationStatus.completed:
        return 'completed';
      case ReservationStatus.failed:
        return 'failed';
      case ReservationStatus.expired:
        return 'expired';
    }
  }

  static ReservationStatus fromString(String value) {
    switch (value) {
      case 'active':
        return ReservationStatus.active;
      case 'completed':
        return ReservationStatus.completed;
      case 'failed':
        return ReservationStatus.failed;
      case 'expired':
        return ReservationStatus.expired;
      default:
        return ReservationStatus.active;
    }
  }
}

class ReservationItem {
  final String itemId;
  final int quantity;
  final String itemName;
  final double itemPrice;

  ReservationItem({
    required this.itemId,
    required this.quantity,
    required this.itemName,
    required this.itemPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'quantity': quantity,
      'itemName': itemName,
      'itemPrice': itemPrice,
    };
  }

  factory ReservationItem.fromMap(Map<String, dynamic> map) {
    return ReservationItem(
      itemId: map['itemId'] ?? '',
      quantity: map['quantity'] ?? 0,
      itemName: map['itemName'] ?? '',
      itemPrice: (map['itemPrice'] ?? 0.0).toDouble(),
    );
  }
}

class Reservation {
  final String id;
  final String paymentId;
  final List<ReservationItem> items;
  final ReservationStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final double totalAmount;
  final Map<String, dynamic>? metadata;

  Reservation({
    required this.id,
    required this.paymentId,
    required this.items,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.totalAmount,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'items': items.map((item) => item.toMap()).toList(),
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'totalAmount': totalAmount,
      'metadata': metadata ?? {},
    };
  }

  factory Reservation.fromMap(String id, Map<String, dynamic> map) {
    final itemsList = (map['items'] as List<dynamic>? ?? [])
        .map((item) => ReservationItem.fromMap(item as Map<String, dynamic>))
        .toList();

    return Reservation(
      id: id,
      paymentId: map['paymentId'] ?? '',
      items: itemsList,
      status: ReservationStatusExtension.fromString(map['status'] ?? 'active'),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      expiresAt: (map['expiresAt'] as Timestamp).toDate(),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  bool get isActive => status == ReservationStatus.active;
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get canBeReleased => isExpired || status == ReservationStatus.failed;

  Duration get timeRemaining {
    if (isExpired) return Duration.zero;
    return expiresAt.difference(DateTime.now());
  }

  int get totalQuantity {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  Reservation copyWith({
    String? paymentId,
    List<ReservationItem>? items,
    ReservationStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    double? totalAmount,
    Map<String, dynamic>? metadata,
  }) {
    return Reservation(
      id: id,
      paymentId: paymentId ?? this.paymentId,
      items: items ?? this.items,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      totalAmount: totalAmount ?? this.totalAmount,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'Reservation(id: $id, paymentId: $paymentId, status: ${status.value}, items: ${items.length}, totalAmount: $totalAmount)';
  }
}

// Helper class for reservation creation
class ReservationCreateRequest {
  final String paymentId;
  final Map<String, int> cartItems;
  final Map<String, dynamic> menuMap;
  final double totalAmount;
  final Duration reservationDuration;

  ReservationCreateRequest({
    required this.paymentId,
    required this.cartItems,
    required this.menuMap,
    required this.totalAmount,
    this.reservationDuration = const Duration(minutes: 10),
  });

  List<ReservationItem> get reservationItems {
    return cartItems.entries.map((entry) {
      final itemId = entry.key;
      final quantity = entry.value;
      final itemData = menuMap[itemId] ?? {};
      
      return ReservationItem(
        itemId: itemId,
        quantity: quantity,
        itemName: itemData['name'] ?? 'Unknown Item',
        itemPrice: (itemData['price'] ?? 0.0).toDouble(),
      );
    }).toList();
  }
}