// lib/models/reservation_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class StockReservation {
  final String id;
  final String userId;
  final String itemId;
  final int quantity;
  final DateTime createdAt;
  final DateTime expiresAt;
  final ReservationStatus status;
  final String? orderId;

  StockReservation({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.quantity,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.orderId,
  });

  // Create from Firestore document
  factory StockReservation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockReservation(
      id: doc.id,
      userId: data['userId'] ?? '',
      itemId: data['itemId'] ?? '',
      quantity: data['quantity'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      status: ReservationStatus.values.firstWhere(
        (e) => e.toString() == 'ReservationStatus.${data['status']}',
        orElse: () => ReservationStatus.active,
      ),
      orderId: data['orderId'],
    );
  }

  // Convert to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'itemId': itemId,
      'quantity': quantity,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': status.name,
      'orderId': orderId,
    };
  }

  // Check if reservation is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  // Check if reservation is active
  bool get isActive => status == ReservationStatus.active && !isExpired;

  // Get remaining time
  Duration get remainingTime {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  // Copy with new values
  StockReservation copyWith({
    String? id,
    String? userId,
    String? itemId,
    int? quantity,
    DateTime? createdAt,
    DateTime? expiresAt,
    ReservationStatus? status,
    String? orderId,
  }) {
    return StockReservation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      itemId: itemId ?? this.itemId,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      orderId: orderId ?? this.orderId,
    );
  }
}

enum ReservationStatus {
  active,     // Currently reserved
  confirmed,  // Payment successful, converted to order
  expired,    // Time expired, released
  cancelled,  // Manually cancelled
  failed,     // Payment failed, released
}

extension ReservationStatusExtension on ReservationStatus {
  String get displayName {
    switch (this) {
      case ReservationStatus.active:
        return 'Reserved';
      case ReservationStatus.confirmed:
        return 'Confirmed';
      case ReservationStatus.expired:
        return 'Expired';
      case ReservationStatus.cancelled:
        return 'Cancelled';
      case ReservationStatus.failed:
        return 'Failed';
    }
  }

  bool get isActive => this == ReservationStatus.active;
  bool get isFinalized => [ReservationStatus.confirmed, ReservationStatus.expired, 
                          ReservationStatus.cancelled, ReservationStatus.failed].contains(this);
}

class ReservationResult {
  final bool success;
  final String? error;
  final List<StockReservation>? reservations;
  final Map<String, String>? itemErrors; // itemId -> error message

  ReservationResult({
    required this.success,
    this.error,
    this.reservations,
    this.itemErrors,
  });

  factory ReservationResult.success(List<StockReservation> reservations) {
    return ReservationResult(
      success: true,
      reservations: reservations,
    );
  }

  factory ReservationResult.failure(String error, {Map<String, String>? itemErrors}) {
    return ReservationResult(
      success: false,
      error: error,
      itemErrors: itemErrors,
    );
  }
}

class CartReservationState {
  final bool hasActiveReservations;
  final List<StockReservation> reservations;
  final DateTime? earliestExpiry;
  final Map<String, int> reservedQuantities; // itemId -> quantity

  CartReservationState({
    this.hasActiveReservations = false,
    this.reservations = const [],
    this.earliestExpiry,
    this.reservedQuantities = const {},
  });

  Duration? get timeUntilExpiry {
    if (earliestExpiry == null) return null;
    final remaining = earliestExpiry!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool isItemReserved(String itemId) {
    return reservedQuantities.containsKey(itemId);
  }

  int getReservedQuantity(String itemId) {
    return reservedQuantities[itemId] ?? 0;
  }
}