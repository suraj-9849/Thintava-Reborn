// lib/services/reservation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/reservation_model.dart';
import '../core/constants/app_constants.dart';

class ReservationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _reservationsCollection = 'reservations';

  /// Create a new reservation
  static Future<Reservation?> createReservation(ReservationCreateRequest request) async {
    try {
      print('🔄 Creating reservation for payment: ${request.paymentId}');
      
      // Check if we can reserve all items
      final canReserve = await _canReserveItems(request.cartItems);
      if (!canReserve.isValid) {
        print('❌ Cannot create reservation: ${canReserve.issues.join(', ')}');
        return null;
      }

      final now = DateTime.now();
      final expiresAt = now.add(request.reservationDuration);
      
      final reservation = Reservation(
        id: '', // Will be set by Firestore
        paymentId: request.paymentId,
        items: request.reservationItems,
        status: ReservationStatus.active,
        createdAt: now,
        expiresAt: expiresAt,
        totalAmount: request.totalAmount,
        metadata: {
          'createdBy': 'reservation_service',
          'version': '1.0',
        },
      );

      // Create reservation document
      final docRef = await _firestore.collection(_reservationsCollection).add(reservation.toMap());
      
      final createdReservation = reservation.copyWith();
      
      print('✅ Reservation created: ${docRef.id}');
      print('📋 Reserved items: ${request.cartItems}');
      print('⏰ Expires at: ${expiresAt.toIso8601String()}');
      
      return Reservation(
        id: docRef.id,
        paymentId: createdReservation.paymentId,
        items: createdReservation.items,
        status: createdReservation.status,
        createdAt: createdReservation.createdAt,
        expiresAt: createdReservation.expiresAt,
        totalAmount: createdReservation.totalAmount,
        metadata: createdReservation.metadata,
      );
    } catch (e) {
      print('❌ Error creating reservation: $e');
      return null;
    }
  }

  /// Complete a reservation (when payment succeeds)
  static Future<bool> completeReservation(String paymentId) async {
    try {
      print('🔄 Completing reservation for payment: $paymentId');
      
      final reservation = await getReservationByPaymentId(paymentId);
      if (reservation == null) {
        print('❌ Reservation not found for payment: $paymentId');
        return false;
      }

      if (reservation.status != ReservationStatus.active) {
        print('❌ Reservation is not active: ${reservation.status.value}');
        return false;
      }

      // Update reservation status
      await _firestore.collection(_reservationsCollection).doc(reservation.id).update({
        'status': ReservationStatus.completed.value,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Decrease actual stock
      final stockUpdateSuccess = await _decreaseActualStock(reservation.items);
      if (!stockUpdateSuccess) {
        print('⚠️ Warning: Stock update failed for completed reservation ${reservation.id}');
      }

      print('✅ Reservation completed: ${reservation.id}');
      return true;
    } catch (e) {
      print('❌ Error completing reservation: $e');
      return false;
    }
  }

  /// Fail a reservation (when payment fails)
  static Future<bool> failReservation(String paymentId) async {
    try {
      print('🔄 Failing reservation for payment: $paymentId');
      
      final reservation = await getReservationByPaymentId(paymentId);
      if (reservation == null) {
        print('❌ Reservation not found for payment: $paymentId');
        return false;
      }

      if (reservation.status != ReservationStatus.active) {
        print('❌ Reservation is not active: ${reservation.status.value}');
        return true; // Already processed
      }

      // Update reservation status
      await _firestore.collection(_reservationsCollection).doc(reservation.id).update({
        'status': ReservationStatus.failed.value,
        'failedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Reservation failed and released: ${reservation.id}');
      return true;
    } catch (e) {
      print('❌ Error failing reservation: $e');
      return false;
    }
  }

  /// Expire old reservations (called by cleanup function)
  static Future<int> expireOldReservations() async {
    try {
      final now = Timestamp.now();
      
      final query = await _firestore
          .collection(_reservationsCollection)
          .where('status', isEqualTo: ReservationStatus.active.value)
          .where('expiresAt', isLessThan: now)
          .get();

      if (query.docs.isEmpty) {
        return 0;
      }

      final batch = _firestore.batch();
      int expiredCount = 0;

      for (final doc in query.docs) {
        batch.update(doc.reference, {
          'status': ReservationStatus.expired.value,
          'expiredAt': FieldValue.serverTimestamp(),
        });
        expiredCount++;
      }

      await batch.commit();
      
      print('✅ Expired $expiredCount old reservations');
      return expiredCount;
    } catch (e) {
      print('❌ Error expiring old reservations: $e');
      return 0;
    }
  }

  /// Get reservation by payment ID
  static Future<Reservation?> getReservationByPaymentId(String paymentId) async {
    try {
      final query = await _firestore
          .collection(_reservationsCollection)
          .where('paymentId', isEqualTo: paymentId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final doc = query.docs.first;
      return Reservation.fromMap(doc.id, doc.data());
    } catch (e) {
      print('❌ Error getting reservation by payment ID: $e');
      return null;
    }
  }

  /// Get active reservations count for an item
  static Future<int> getActiveReservationsForItem(String itemId) async {
    try {
      final query = await _firestore
          .collection(_reservationsCollection)
          .where('status', isEqualTo: ReservationStatus.active.value)
          .get();

      int totalReserved = 0;

      for (final doc in query.docs) {
        final data = doc.data();
        final items = data['items'] as List<dynamic>? ?? [];
        
        for (final item in items) {
          if (item['itemId'] == itemId) {
            totalReserved += (item['quantity'] as int? ?? 0);
          }
        }
      }

      return totalReserved;
    } catch (e) {
      print('❌ Error getting active reservations for item: $e');
      return 0;
    }
  }

  /// Get available stock (actual stock - reserved stock)
  static Future<int> getAvailableStock(String itemId) async {
    try {
      // Get actual stock
      final doc = await _firestore.collection('menuItems').doc(itemId).get();
      if (!doc.exists) return 0;

      final data = doc.data()!;
      final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
      
      if (hasUnlimitedStock) {
        return 999999; // Unlimited
      }

      final actualStock = data['quantity'] ?? 0;
      
      // Get reserved stock
      final reservedStock = await getActiveReservationsForItem(itemId);
      
      final availableStock = actualStock - reservedStock;
      return availableStock > 0 ? availableStock : 0;
    } catch (e) {
      print('❌ Error getting available stock: $e');
      return 0;
    }
  }

  /// Check if items can be reserved
  static Future<ReservationCheckResult> _canReserveItems(Map<String, int> cartItems) async {
    try {
      List<String> issues = [];
      bool isValid = true;

      for (final entry in cartItems.entries) {
        final itemId = entry.key;
        final requestedQuantity = entry.value;
        
        final availableStock = await getAvailableStock(itemId);
        
        if (availableStock < requestedQuantity) {
          issues.add('$itemId: requested $requestedQuantity, available $availableStock');
          isValid = false;
        }
      }

      return ReservationCheckResult(isValid: isValid, issues: issues);
    } catch (e) {
      print('❌ Error checking if items can be reserved: $e');
      return ReservationCheckResult(isValid: false, issues: ['Error checking availability']);
    }
  }

  /// Decrease actual stock after payment completion
  static Future<bool> _decreaseActualStock(List<ReservationItem> items) async {
    try {
      final batch = _firestore.batch();
      
      for (final item in items) {
        final docRef = _firestore.collection('menuItems').doc(item.itemId);
        
        final doc = await docRef.get();
        if (doc.exists) {
          final data = doc.data()!;
          final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
          
          if (!hasUnlimitedStock) {
            final currentStock = data['quantity'] ?? 0;
            final newStock = currentStock - item.quantity;
            
            batch.update(docRef, {
              'quantity': newStock >= 0 ? newStock : 0,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      print('❌ Error decreasing actual stock: $e');
      return false;
    }
  }

  /// Get reservation statistics (for admin)
  static Future<Map<String, dynamic>> getReservationStats() async {
    try {
      final query = await _firestore.collection(_reservationsCollection).get();
      
      int activeCount = 0;
      int completedCount = 0;
      int failedCount = 0;
      int expiredCount = 0;
      double totalReservedValue = 0;

      for (final doc in query.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'active';
        final amount = (data['totalAmount'] as num? ?? 0).toDouble();

        switch (status) {
          case 'active':
            activeCount++;
            totalReservedValue += amount;
            break;
          case 'completed':
            completedCount++;
            break;
          case 'failed':
            failedCount++;
            break;
          case 'expired':
            expiredCount++;
            break;
        }
      }

      return {
        'activeReservations': activeCount,
        'completedReservations': completedCount,
        'failedReservations': failedCount,
        'expiredReservations': expiredCount,
        'totalReservedValue': totalReservedValue,
        'totalReservations': query.docs.length,
      };
    } catch (e) {
      print('❌ Error getting reservation stats: $e');
      return {
        'activeReservations': 0,
        'completedReservations': 0,
        'failedReservations': 0,
        'expiredReservations': 0,
        'totalReservedValue': 0.0,
        'totalReservations': 0,
      };
    }
  }

  /// Clean up old reservations (delete expired ones older than 24 hours)
  static Future<int> cleanupOldReservations() async {
    try {
      final twentyFourHoursAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24))
      );
      
      final query = await _firestore
          .collection(_reservationsCollection)
          .where('status', whereIn: [ReservationStatus.expired.value, ReservationStatus.failed.value])
          .where('expiresAt', isLessThan: twentyFourHoursAgo)
          .get();

      if (query.docs.isEmpty) {
        return 0;
      }

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      
      print('✅ Cleaned up ${query.docs.length} old reservations');
      return query.docs.length;
    } catch (e) {
      print('❌ Error cleaning up old reservations: $e');
      return 0;
    }
  }

  /// Get all active reservations (for debugging)
  static Future<List<Reservation>> getActiveReservations() async {
    try {
      final query = await _firestore
          .collection(_reservationsCollection)
          .where('status', isEqualTo: ReservationStatus.active.value)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => Reservation.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      print('❌ Error getting active reservations: $e');
      return [];
    }
  }
}

// Helper class for reservation check results
class ReservationCheckResult {
  final bool isValid;
  final List<String> issues;

  ReservationCheckResult({
    required this.isValid,
    required this.issues,
  });
}