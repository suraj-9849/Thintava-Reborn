// lib/services/reservation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:canteen_app/models/reservation_model.dart';
import 'dart:async';

class ReservationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _reservationsCollection = 'stockReservations';
  static const String _menuItemsCollection = 'menuItems';
  
  // Default reservation timeout (10 minutes)
  static const Duration defaultReservationDuration = Duration(minutes: 10);

  /// Reserve stock for items in cart before payment
  static Future<ReservationResult> reserveCartItems(
    Map<String, int> cartItems, {
    Duration? reservationDuration,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return ReservationResult.failure('User not authenticated');
    }

    final duration = reservationDuration ?? defaultReservationDuration;
    final userId = user.uid;
    final now = DateTime.now();
    final expiresAt = now.add(duration);

    try {
      // Use transaction to ensure atomicity
      return await _firestore.runTransaction<ReservationResult>((transaction) async {
        List<StockReservation> reservations = [];
        Map<String, String> itemErrors = {};

        // Step 1: Check availability for all items
        for (String itemId in cartItems.keys) {
          final requestedQuantity = cartItems[itemId] ?? 0;
          if (requestedQuantity <= 0) continue;

          final itemRef = _firestore.collection(_menuItemsCollection).doc(itemId);
          final itemDoc = await transaction.get(itemRef);

          if (!itemDoc.exists) {
            itemErrors[itemId] = 'Item not found';
            continue;
          }

          final itemData = itemDoc.data()!;
          final hasUnlimitedStock = itemData['hasUnlimitedStock'] ?? false;
          final available = itemData['available'] ?? false;
          
          if (!available) {
            itemErrors[itemId] = 'Item not available';
            continue;
          }

          if (!hasUnlimitedStock) {
            final totalStock = itemData['quantity'] ?? 0;
            final reservedQuantity = itemData['reservedQuantity'] ?? 0;
            final availableStock = totalStock - reservedQuantity;

            if (availableStock < requestedQuantity) {
              if (availableStock <= 0) {
                itemErrors[itemId] = 'Out of stock';
              } else {
                itemErrors[itemId] = 'Only $availableStock available';
              }
              continue;
            }
          }
        }

        // If any items have errors, return failure
        if (itemErrors.isNotEmpty) {
          final errorMessage = itemErrors.length == 1 
            ? itemErrors.values.first
            : 'Some items are not available';
          return ReservationResult.failure(errorMessage, itemErrors: itemErrors);
        }

        // Step 2: Create reservations and update reserved quantities
        for (String itemId in cartItems.keys) {
          final requestedQuantity = cartItems[itemId] ?? 0;
          if (requestedQuantity <= 0) continue;

          // Create reservation document
          final reservationId = _firestore.collection(_reservationsCollection).doc().id;
          final reservation = StockReservation(
            id: reservationId,
            userId: userId,
            itemId: itemId,
            quantity: requestedQuantity,
            createdAt: now,
            expiresAt: expiresAt,
            status: ReservationStatus.active,
          );

          final reservationRef = _firestore.collection(_reservationsCollection).doc(reservationId);
          transaction.set(reservationRef, reservation.toFirestore());

          // Update item's reserved quantity (only for non-unlimited stock items)
          final itemRef = _firestore.collection(_menuItemsCollection).doc(itemId);
          final itemDoc = await transaction.get(itemRef);
          final itemData = itemDoc.data()!;
          final hasUnlimitedStock = itemData['hasUnlimitedStock'] ?? false;

          if (!hasUnlimitedStock) {
            final currentReserved = itemData['reservedQuantity'] ?? 0;
            transaction.update(itemRef, {
              'reservedQuantity': currentReserved + requestedQuantity,
              'lastReservationUpdate': FieldValue.serverTimestamp(),
            });
          }

          reservations.add(reservation);
        }

        print('✅ Reserved stock for ${reservations.length} items');
        return ReservationResult.success(reservations);
      });
    } catch (e) {
      print('❌ Error reserving stock: $e');
      return ReservationResult.failure('Failed to reserve stock: $e');
    }
  }

  /// Release reservations (on payment failure or manual cancellation)
  static Future<bool> releaseReservations(
    List<String> reservationIds, {
    ReservationStatus status = ReservationStatus.cancelled,
  }) async {
    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        for (String reservationId in reservationIds) {
          final reservationRef = _firestore.collection(_reservationsCollection).doc(reservationId);
          final reservationDoc = await transaction.get(reservationRef);

          if (reservationDoc.exists) {
            final reservation = StockReservation.fromFirestore(reservationDoc);
            
            // Only release if currently active
            if (reservation.isActive) {
              // Update reservation status
              transaction.update(reservationRef, {
                'status': status.name,
                'releasedAt': FieldValue.serverTimestamp(),
              });

              // Update item's reserved quantity
              final itemRef = _firestore.collection(_menuItemsCollection).doc(reservation.itemId);
              final itemDoc = await transaction.get(itemRef);
              
              if (itemDoc.exists) {
                final itemData = itemDoc.data()!;
                final hasUnlimitedStock = itemData['hasUnlimitedStock'] ?? false;
                
                if (!hasUnlimitedStock) {
                  final currentReserved = itemData['reservedQuantity'] ?? 0;
                  final newReserved = (currentReserved - reservation.quantity).clamp(0, double.infinity).toInt();
                  
                  transaction.update(itemRef, {
                    'reservedQuantity': newReserved,
                    'lastReservationUpdate': FieldValue.serverTimestamp(),
                  });
                }
              }
            }
          }
        }

        print('✅ Released ${reservationIds.length} reservations');
        return true;
      });
    } catch (e) {
      print('❌ Error releasing reservations: $e');
      return false;
    }
  }

  /// Confirm reservations (convert to order after successful payment)
  static Future<bool> confirmReservations(
    List<String> reservationIds,
    String orderId,
  ) async {
    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        for (String reservationId in reservationIds) {
          final reservationRef = _firestore.collection(_reservationsCollection).doc(reservationId);
          final reservationDoc = await transaction.get(reservationRef);

          if (reservationDoc.exists) {
            final reservation = StockReservation.fromFirestore(reservationDoc);
            
            // Only confirm if currently active
            if (reservation.isActive) {
              // Update reservation status
              transaction.update(reservationRef, {
                'status': ReservationStatus.confirmed.name,
                'orderId': orderId,
                'confirmedAt': FieldValue.serverTimestamp(),
              });

              // Update actual stock quantity and reduce reserved quantity
              final itemRef = _firestore.collection(_menuItemsCollection).doc(reservation.itemId);
              final itemDoc = await transaction.get(itemRef);
              
              if (itemDoc.exists) {
                final itemData = itemDoc.data()!;
                final hasUnlimitedStock = itemData['hasUnlimitedStock'] ?? false;
                
                if (!hasUnlimitedStock) {
                  final currentStock = itemData['quantity'] ?? 0;
                  final currentReserved = itemData['reservedQuantity'] ?? 0;
                  
                  final newStock = (currentStock - reservation.quantity).clamp(0, double.infinity).toInt();
                  final newReserved = (currentReserved - reservation.quantity).clamp(0, double.infinity).toInt();
                  
                  transaction.update(itemRef, {
                    'quantity': newStock,
                    'reservedQuantity': newReserved,
                    'lastStockUpdate': FieldValue.serverTimestamp(),
                  });
                }
              }
            }
          }
        }

        print('✅ Confirmed ${reservationIds.length} reservations for order $orderId');
        return true;
      });
    } catch (e) {
      print('❌ Error confirming reservations: $e');
      return false;
    }
  }

  /// Get user's active reservations
  static Future<List<StockReservation>> getUserActiveReservations(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_reservationsCollection)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: ReservationStatus.active.name)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .get();

      return snapshot.docs.map((doc) => StockReservation.fromFirestore(doc)).toList();
    } catch (e) {
      print('❌ Error getting user reservations: $e');
      return [];
    }
  }

  /// Get available stock for an item (total - reserved)
  static Future<int> getAvailableStock(String itemId) async {
    try {
      final doc = await _firestore.collection(_menuItemsCollection).doc(itemId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
        
        if (hasUnlimitedStock) {
          return 999999; // Large number for unlimited
        }
        
        final totalStock = data['quantity'] ?? 0;
        final reservedQuantity = data['reservedQuantity'] ?? 0;
        return (totalStock - reservedQuantity).clamp(0, double.infinity).toInt();
      }
      
      return 0;
    } catch (e) {
      print('❌ Error getting available stock: $e');
      return 0;
    }
  }

  /// Clean up expired reservations (usually called by Cloud Function)
  static Future<int> cleanupExpiredReservations() async {
    try {
      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection(_reservationsCollection)
          .where('status', isEqualTo: ReservationStatus.active.name)
          .where('expiresAt', isLessThan: now)
          .get();

      if (snapshot.docs.isEmpty) {
        return 0;
      }

      final reservationIds = snapshot.docs.map((doc) => doc.id).toList();
      final success = await releaseReservations(
        reservationIds,
        status: ReservationStatus.expired,
      );

      if (success) {
        print('🧹 Cleaned up ${reservationIds.length} expired reservations');
        return reservationIds.length;
      }
      
      return 0;
    } catch (e) {
      print('❌ Error cleaning up expired reservations: $e');
      return 0;
    }
  }

  /// Release all reservations for a user (useful for logout/cleanup)
  static Future<bool> releaseAllUserReservations(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_reservationsCollection)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: ReservationStatus.active.name)
          .get();

      if (snapshot.docs.isEmpty) {
        return true;
      }

      final reservationIds = snapshot.docs.map((doc) => doc.id).toList();
      return await releaseReservations(reservationIds);
    } catch (e) {
      print('❌ Error releasing user reservations: $e');
      return false;
    }
  }

  /// Check if cart can be reserved (pre-check before actual reservation)
  static Future<Map<String, dynamic>> checkCartReservability(Map<String, int> cartItems) async {
    Map<String, String> issues = {};
    bool canReserve = true;

    try {
      for (String itemId in cartItems.keys) {
        final requestedQuantity = cartItems[itemId] ?? 0;
        if (requestedQuantity <= 0) continue;

        final availableStock = await getAvailableStock(itemId);
        
        if (availableStock < requestedQuantity) {
          if (availableStock <= 0) {
            issues[itemId] = 'Out of stock';
          } else {
            issues[itemId] = 'Only $availableStock available';
          }
          canReserve = false;
        }
      }
    } catch (e) {
      canReserve = false;
      issues['general'] = 'Error checking availability';
    }

    return {
      'canReserve': canReserve,
      'issues': issues,
    };
  }

  /// Stream of user's active reservations for real-time updates
  static Stream<List<StockReservation>> watchUserReservations(String userId) {
    return _firestore
        .collection(_reservationsCollection)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: ReservationStatus.active.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StockReservation.fromFirestore(doc))
            .where((reservation) => !reservation.isExpired)
            .toList());
  }
}