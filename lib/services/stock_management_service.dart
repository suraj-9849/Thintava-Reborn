// lib/services/stock_management_service.dart - UPDATED WITH RESERVATION SYSTEM
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/menu_type.dart';
import '../services/reservation_service.dart';
import 'menu_operations_service.dart';

class StockManagementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if items are available in required quantities (with reservations)
  static Future<StockCheckResult> checkStockAvailability(Map<String, int> cartItems) async {
    List<String> outOfStockItems = [];
    List<String> insufficientStockItems = [];
    Map<String, int> availableStock = {};
    bool isValid = true;

    try {
      for (String itemId in cartItems.keys) {
        final requestedQuantity = cartItems[itemId] ?? 0;
        
        final doc = await _firestore.collection('menuItems').doc(itemId).get();
        
        if (doc.exists) {
          final data = doc.data()!;
          final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
          final available = data['available'] ?? false;
          final itemName = data['name'] ?? 'Unknown Item';
          final menuType = data['menuType'] ?? 'breakfast';
          
          // Check if item's menu type is currently enabled
          final isMenuEnabled = await _isMenuTypeEnabled(MenuType.fromString(menuType));
          
          if (!available || !isMenuEnabled) {
            outOfStockItems.add(itemName);
            isValid = false;
            continue;
          }

          if (!hasUnlimitedStock) {
            // Get available stock (actual - reserved)
            final availableStockCount = await ReservationService.getAvailableStock(itemId);
            availableStock[itemId] = availableStockCount;

            if (availableStockCount <= 0) {
              outOfStockItems.add(itemName);
              isValid = false;
            } else if (availableStockCount < requestedQuantity) {
              insufficientStockItems.add(
                '$itemName (Available: $availableStockCount, Requested: $requestedQuantity)'
              );
              isValid = false;
            }
          } else {
            availableStock[itemId] = 999999; // Unlimited stock
          }
        } else {
          outOfStockItems.add('Item not found');
          isValid = false;
        }
      }
    } catch (e) {
      print('Error checking stock availability: $e');
      isValid = false;
    }

    return StockCheckResult(
      isValid: isValid,
      outOfStockItems: outOfStockItems,
      insufficientStockItems: insufficientStockItems,
      availableStock: availableStock,
    );
  }

  /// Update stock quantities after order placement (only when payment succeeds)
  static Future<bool> updateStockAfterOrder(Map<String, int> orderItems) async {
    try {
      WriteBatch batch = _firestore.batch();
      
      for (String itemId in orderItems.keys) {
        final orderedQuantity = orderItems[itemId] ?? 0;
        final docRef = _firestore.collection('menuItems').doc(itemId);
        
        final doc = await docRef.get();
        if (doc.exists) {
          final data = doc.data()!;
          final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
          
          if (!hasUnlimitedStock) {
            final currentStock = data['quantity'] ?? 0;
            final newStock = currentStock - orderedQuantity;
            
            batch.update(docRef, {
              'quantity': newStock >= 0 ? newStock : 0,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            
            print('📦 Stock update (after payment): $itemId: $currentStock -> ${newStock >= 0 ? newStock : 0}');
          }
        }
      }
      
      await batch.commit();
      print('✅ All stock quantities updated after payment');
      
      // Update menu operation counts after stock changes
      await _updateMenuOperationCounts();
      
      return true;
    } catch (e) {
      print('❌ Error updating stock quantities after payment: $e');
      return false;
    }
  }

  /// Get current stock status for a single item (considering reservations)
  static Future<ItemStockStatus> getItemStockStatus(String itemId) async {
    try {
      final doc = await _firestore.collection('menuItems').doc(itemId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
        final available = data['available'] ?? false;
        final menuType = data['menuType'] ?? 'breakfast';
        
        // Check if menu type is currently enabled
        final isMenuEnabled = await _isMenuTypeEnabled(MenuType.fromString(menuType));
        
        if (!available || !isMenuEnabled) {
          return ItemStockStatus.unavailable;
        } else if (hasUnlimitedStock) {
          return ItemStockStatus.unlimited;
        } else {
          // Get available stock (actual - reserved)
          final availableStock = await ReservationService.getAvailableStock(itemId);
          
          if (availableStock <= 0) {
            return ItemStockStatus.outOfStock;
          } else if (availableStock <= 5) {
            return ItemStockStatus.lowStock;
          } else {
            return ItemStockStatus.inStock;
          }
        }
      } else {
        return ItemStockStatus.notFound;
      }
    } catch (e) {
      print('Error getting item stock status: $e');
      return ItemStockStatus.error;
    }
  }

  /// Check if specific quantity can be added to cart (considering reservations)
  static Future<bool> canAddToCart(String itemId, int currentCartQuantity, int additionalQuantity) async {
    try {
      final doc = await _firestore.collection('menuItems').doc(itemId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
        final available = data['available'] ?? false;
        final menuType = data['menuType'] ?? 'breakfast';
        
        // Check if menu type is currently enabled
        final isMenuEnabled = await _isMenuTypeEnabled(MenuType.fromString(menuType));
        
        if (!available || !isMenuEnabled) return false;
        if (hasUnlimitedStock) return true;
        
        // Get available stock (actual - reserved)
        final availableStock = await ReservationService.getAvailableStock(itemId);
        final totalRequested = currentCartQuantity + additionalQuantity;
        
        return totalRequested <= availableStock;
      }
      return false;
    } catch (e) {
      print('Error checking if can add to cart: $e');
      return false;
    }
  }

  /// Validate cart against current stock and reservations
  static Future<CartValidationResult> validateCart(Map<String, int> cartItems) async {
    List<String> itemsToRemove = [];
    Map<String, int> itemsToUpdate = {};
    
    try {
      for (String itemId in cartItems.keys) {
        final cartQuantity = cartItems[itemId] ?? 0;
        
        final doc = await _firestore.collection('menuItems').doc(itemId).get();
        
        if (doc.exists) {
          final data = doc.data()!;
          final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
          final available = data['available'] ?? false;
          final menuType = data['menuType'] ?? 'breakfast';
          
          // Check if menu type is currently enabled
          final isMenuEnabled = await _isMenuTypeEnabled(MenuType.fromString(menuType));
          
          if (!available || !isMenuEnabled) {
            itemsToRemove.add(itemId);
          } else if (!hasUnlimitedStock) {
            // Get available stock (actual - reserved)
            final availableStock = await ReservationService.getAvailableStock(itemId);
            
            if (availableStock <= 0) {
              itemsToRemove.add(itemId);
            } else if (availableStock < cartQuantity) {
              itemsToUpdate[itemId] = availableStock;
            }
          }
        } else {
          itemsToRemove.add(itemId);
        }
      }
    } catch (e) {
      print('Error validating cart: $e');
    }
    
    return CartValidationResult(
      isValid: itemsToRemove.isEmpty && itemsToUpdate.isEmpty,
      itemsToRemove: itemsToRemove,
      itemsToUpdate: itemsToUpdate,
    );
  }

  /// Get detailed stock information including reservations
  static Future<Map<String, dynamic>> getDetailedStockInfo(String itemId) async {
    try {
      final doc = await _firestore.collection('menuItems').doc(itemId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final actualQuantity = data['quantity'] ?? 0;
        final menuType = data['menuType'] ?? 'breakfast';
        
        // Get reservation info
        final reservedQuantity = await ReservationService.getActiveReservationsForItem(itemId);
        final availableQuantity = await ReservationService.getAvailableStock(itemId);
        
        return {
          'itemId': itemId,
          'name': data['name'] ?? 'Unknown Item',
          'hasUnlimitedStock': data['hasUnlimitedStock'] ?? false,
          'actualQuantity': actualQuantity,
          'reservedQuantity': reservedQuantity,
          'availableQuantity': availableQuantity,
          'available': data['available'] ?? false,
          'menuType': menuType,
          'price': data['price'] ?? 0.0,
          'lastStockUpdate': data['lastStockUpdate'],
          'isMenuEnabled': await _isMenuTypeEnabled(MenuType.fromString(menuType)),
        };
      }
      
      return {'error': 'Item not found'};
    } catch (e) {
      print('Error getting detailed stock info: $e');
      return {'error': 'Error retrieving stock info'};
    }
  }

  /// Get stock summary by menu type (including reservations)
  static Future<Map<String, dynamic>> getStockSummaryByMenuType(MenuType menuType) async {
    try {
      final snapshot = await _firestore
          .collection('menuItems')
          .where('menuType', isEqualTo: menuType.value)
          .get();

      int totalItems = 0;
      int availableItems = 0;
      int outOfStockItems = 0;
      int lowStockItems = 0;
      int unlimitedStockItems = 0;
      int reservedItems = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final available = data['available'] ?? false;
        final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
        
        totalItems++;

        if (!available) continue;

        if (hasUnlimitedStock) {
          unlimitedStockItems++;
          availableItems++;
        } else {
          final availableQuantity = await ReservationService.getAvailableStock(doc.id);
          final reservedQuantity = await ReservationService.getActiveReservationsForItem(doc.id);
          
          if (reservedQuantity > 0) {
            reservedItems++;
          }
          
          if (availableQuantity <= 0) {
            outOfStockItems++;
          } else if (availableQuantity <= 5) {
            lowStockItems++;
            availableItems++;
          } else {
            availableItems++;
          }
        }
      }

      return {
        'menuType': menuType.value,
        'totalItems': totalItems,
        'availableItems': availableItems,
        'outOfStockItems': outOfStockItems,
        'lowStockItems': lowStockItems,
        'unlimitedStockItems': unlimitedStockItems,
        'reservedItems': reservedItems,
        'isMenuEnabled': await _isMenuTypeEnabled(menuType),
      };
    } catch (e) {
      print('Error getting stock summary for ${menuType.displayName}: $e');
      return {
        'menuType': menuType.value,
        'totalItems': 0,
        'availableItems': 0,
        'outOfStockItems': 0,
        'lowStockItems': 0,
        'unlimitedStockItems': 0,
        'reservedItems': 0,
        'isMenuEnabled': false,
        'error': e.toString(),
      };
    }
  }

  // Keep all existing methods...
  static Future<bool> restoreStock(Map<String, int> orderItems) async {
    try {
      WriteBatch batch = _firestore.batch();
      
      for (String itemId in orderItems.keys) {
        final restoredQuantity = orderItems[itemId] ?? 0;
        final docRef = _firestore.collection('menuItems').doc(itemId);
        
        final doc = await docRef.get();
        if (doc.exists) {
          final data = doc.data()!;
          final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
          
          if (!hasUnlimitedStock) {
            final currentStock = data['quantity'] ?? 0;
            final newStock = currentStock + restoredQuantity;
            
            batch.update(docRef, {
              'quantity': newStock,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            
            print('📦 Stock restore: $itemId: $currentStock -> $newStock');
          }
        }
      }
      
      await batch.commit();
      print('✅ All stock quantities restored successfully');
      
      await _updateMenuOperationCounts();
      return true;
    } catch (e) {
      print('❌ Error restoring stock quantities: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getLowStockItems({
    int threshold = 5,
    MenuType? menuType,
  }) async {
    try {
      Query query = _firestore
          .collection('menuItems')
          .where('hasUnlimitedStock', isEqualTo: false)
          .where('available', isEqualTo: true);

      if (menuType != null) {
        query = query.where('menuType', isEqualTo: menuType.value);
      }

      final snapshot = await query.get();
      List<Map<String, dynamic>> lowStockItems = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final availableQuantity = await ReservationService.getAvailableStock(doc.id);
        
        if (availableQuantity <= threshold) {
          lowStockItems.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown Item',
            'actualQuantity': data['quantity'] ?? 0,
            'availableQuantity': availableQuantity,
            'reservedQuantity': await ReservationService.getActiveReservationsForItem(doc.id),
            'price': data['price'] ?? 0.0,
            'menuType': data['menuType'] ?? 'breakfast',
          });
        }
      }

      return lowStockItems;
    } catch (e) {
      print('Error getting low stock items: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getOutOfStockItems({MenuType? menuType}) async {
    try {
      Query query = _firestore
          .collection('menuItems')
          .where('hasUnlimitedStock', isEqualTo: false)
          .where('available', isEqualTo: true);

      if (menuType != null) {
        query = query.where('menuType', isEqualTo: menuType.value);
      }

      final snapshot = await query.get();
      List<Map<String, dynamic>> outOfStockItems = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final availableQuantity = await ReservationService.getAvailableStock(doc.id);
        
        if (availableQuantity <= 0) {
          outOfStockItems.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown Item',
            'actualQuantity': data['quantity'] ?? 0,
            'availableQuantity': availableQuantity,
            'reservedQuantity': await ReservationService.getActiveReservationsForItem(doc.id),
            'price': data['price'] ?? 0.0,
            'menuType': data['menuType'] ?? 'breakfast',
          });
        }
      }

      return outOfStockItems;
    } catch (e) {
      print('Error getting out of stock items: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getOverallStockSummary() async {
    try {
      Map<String, dynamic> summary = {
        'totalItems': 0,
        'availableItems': 0,
        'outOfStockItems': 0,
        'lowStockItems': 0,
        'unlimitedStockItems': 0,
        'reservedItems': 0,
        'byMenuType': <String, Map<String, dynamic>>{},
      };

      for (MenuType menuType in MenuType.values) {
        final menuSummary = await getStockSummaryByMenuType(menuType);
        summary['byMenuType'][menuType.value] = menuSummary;
        
        summary['totalItems'] += menuSummary['totalItems'] as int;
        summary['availableItems'] += menuSummary['availableItems'] as int;
        summary['outOfStockItems'] += menuSummary['outOfStockItems'] as int;
        summary['lowStockItems'] += menuSummary['lowStockItems'] as int;
        summary['unlimitedStockItems'] += menuSummary['unlimitedStockItems'] as int;
        summary['reservedItems'] += menuSummary['reservedItems'] as int;
      }

      return summary;
    } catch (e) {
      print('Error getting overall stock summary: $e');
      return {
        'totalItems': 0,
        'availableItems': 0,
        'outOfStockItems': 0,
        'lowStockItems': 0,
        'unlimitedStockItems': 0,
        'reservedItems': 0,
        'byMenuType': {},
        'error': e.toString(),
      };
    }
  }

  static Future<bool> bulkUpdateStock(Map<String, int> itemQuantities) async {
    try {
      WriteBatch batch = _firestore.batch();
      
      for (String itemId in itemQuantities.keys) {
        final newQuantity = itemQuantities[itemId] ?? 0;
        final docRef = _firestore.collection('menuItems').doc(itemId);
        
        batch.update(docRef, {
          'quantity': newQuantity >= 0 ? newQuantity : 0,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastStockUpdate': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      await _updateMenuOperationCounts();
      
      print('✅ Bulk stock update completed for ${itemQuantities.length} items');
      return true;
    } catch (e) {
      print('❌ Error in bulk stock update: $e');
      return false;
    }
  }

  static Future<bool> setMenuTypeAvailability(MenuType menuType, bool available) async {
    try {
      final snapshot = await _firestore
          .collection('menuItems')
          .where('menuType', isEqualTo: menuType.value)
          .get();

      WriteBatch batch = _firestore.batch();
      
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'available': available,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      await _updateMenuOperationCounts();
      
      print('✅ Set ${menuType.displayName} menu availability to $available');
      return true;
    } catch (e) {
      print('❌ Error setting menu type availability: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getItemsNeedingRestock({
    MenuType? menuType,
    int threshold = 10,
  }) async {
    try {
      Query query = _firestore
          .collection('menuItems')
          .where('hasUnlimitedStock', isEqualTo: false);

      if (menuType != null) {
        query = query.where('menuType', isEqualTo: menuType.value);
      }

      final snapshot = await query.get();
      List<Map<String, dynamic>> needingRestock = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final availableQuantity = await ReservationService.getAvailableStock(doc.id);
        
        if (availableQuantity <= threshold) {
          needingRestock.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown Item',
            'actualQuantity': data['quantity'] ?? 0,
            'availableQuantity': availableQuantity,
            'reservedQuantity': await ReservationService.getActiveReservationsForItem(doc.id),
            'menuType': data['menuType'] ?? 'breakfast',
            'price': data['price'] ?? 0.0,
            'available': data['available'] ?? false,
            'suggestedRestockAmount': threshold - availableQuantity + 20,
          });
        }
      }

      return needingRestock;
    } catch (e) {
      print('Error getting items needing restock: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> generateStockAlerts() async {
    try {
      List<Map<String, dynamic>> alerts = [];
      
      for (MenuType menuType in MenuType.values) {
        final isEnabled = await _isMenuTypeEnabled(menuType);
        
        if (isEnabled) {
          final lowStock = await getLowStockItems(threshold: 2, menuType: menuType);
          final outOfStock = await getOutOfStockItems(menuType: menuType);
          
          for (var item in outOfStock) {
            alerts.add({
              'type': 'OUT_OF_STOCK',
              'severity': 'HIGH',
              'menuType': menuType.displayName,
              'itemName': item['name'],
              'actualQuantity': item['actualQuantity'],
              'availableQuantity': item['availableQuantity'],
              'reservedQuantity': item['reservedQuantity'],
              'message': '${item['name']} is out of stock in ${menuType.displayName} menu (Reserved: ${item['reservedQuantity']})',
            });
          }
          
          for (var item in lowStock) {
            alerts.add({
              'type': 'LOW_STOCK',
              'severity': 'MEDIUM',
              'menuType': menuType.displayName,
              'itemName': item['name'],
              'actualQuantity': item['actualQuantity'],
              'availableQuantity': item['availableQuantity'],
              'reservedQuantity': item['reservedQuantity'],
              'message': '${item['name']} is running low (${item['availableQuantity']} available, ${item['reservedQuantity']} reserved) in ${menuType.displayName} menu',
            });
          }
        }
      }
      
      return alerts;
    } catch (e) {
      print('Error generating stock alerts: $e');
      return [];
    }
  }

  static Future<bool> _isMenuTypeEnabled(MenuType menuType) async {
    try {
      final doc = await _firestore.collection('menuOperations').doc(menuType.value).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final isEnabled = data['isEnabled'] ?? false;
        return isEnabled;
      }
      
      return false;
    } catch (e) {
      print('Error checking if menu type is enabled: $e');
      return false;
    }
  }

  static Future<void> _updateMenuOperationCounts() async {
    try {
      await MenuOperationsService.updateMenuItemCounts();
    } catch (e) {
      print('Error updating menu operation counts: $e');
    }
  }
}

// Keep all existing classes and enums...
class StockCheckResult {
  final bool isValid;
  final List<String> outOfStockItems;
  final List<String> insufficientStockItems;
  final Map<String, int> availableStock;

  StockCheckResult({
    required this.isValid,
    required this.outOfStockItems,
    required this.insufficientStockItems,
    required this.availableStock,
  });
}

class CartValidationResult {
  final bool isValid;
  final List<String> itemsToRemove;
  final Map<String, int> itemsToUpdate;

  CartValidationResult({
    required this.isValid,
    required this.itemsToRemove,
    required this.itemsToUpdate,
  });
}

enum ItemStockStatus {
  unlimited,
  inStock,
  lowStock,
  outOfStock,
  unavailable,
  notFound,
  error,
}

extension ItemStockStatusExtension on ItemStockStatus {
  String get displayText {
    switch (this) {
      case ItemStockStatus.unlimited:
        return 'Unlimited';
      case ItemStockStatus.inStock:
        return 'In Stock';
      case ItemStockStatus.lowStock:
        return 'Low Stock';
      case ItemStockStatus.outOfStock:
        return 'Out of Stock';
      case ItemStockStatus.unavailable:
        return 'Unavailable';
      case ItemStockStatus.notFound:
        return 'Not Found';
      case ItemStockStatus.error:
        return 'Error';
    }
  }

  Color get color {
    switch (this) {
      case ItemStockStatus.unlimited:
        return Color(0xFF2196F3);
      case ItemStockStatus.inStock:
        return Color(0xFF4CAF50);
      case ItemStockStatus.lowStock:
        return Color(0xFFFF9800);
      case ItemStockStatus.outOfStock:
        return Color(0xFFF44336);
      case ItemStockStatus.unavailable:
        return Color(0xFF9E9E9E);
      case ItemStockStatus.notFound:
        return Color(0xFF9E9E9E);
      case ItemStockStatus.error:
        return Color(0xFFF44336);
    }
  }

  bool get canAddToCart {
    switch (this) {
      case ItemStockStatus.unlimited:
      case ItemStockStatus.inStock:
      case ItemStockStatus.lowStock:
        return true;
      case ItemStockStatus.outOfStock:
      case ItemStockStatus.unavailable:
      case ItemStockStatus.notFound:
      case ItemStockStatus.error:
        return false;
    }
  }
}