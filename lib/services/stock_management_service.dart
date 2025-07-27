// lib/services/stock_management_service.dart - UPDATED WITH MENU TYPE FILTERING
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/menu_type.dart';
import 'menu_operations_service.dart';


class StockManagementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if items are available in required quantities (with menu type filtering)
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
          
          // Check if item's menu type is currently active
          final isMenuActive = await _isMenuTypeActive(MenuType.fromString(menuType));
          
          if (!available || !isMenuActive) {
            outOfStockItems.add(itemName);
            isValid = false;
            continue;
          }

          if (!hasUnlimitedStock) {
            final totalStock = data['quantity'] ?? 0;
            
            availableStock[itemId] = totalStock;

            if (totalStock <= 0) {
              outOfStockItems.add(itemName);
              isValid = false;
            } else if (totalStock < requestedQuantity) {
              insufficientStockItems.add(
                '$itemName (Available: $totalStock, Requested: $requestedQuantity)'
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

  /// Update stock quantities after order placement
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
            
            print('📦 Stock update: $itemId: $currentStock -> ${newStock >= 0 ? newStock : 0}');
          }
        }
      }
      
      await batch.commit();
      print('✅ All stock quantities updated successfully');
      
      // Update menu operation counts after stock changes
      await _updateMenuOperationCounts();
      
      return true;
    } catch (e) {
      print('❌ Error updating stock quantities: $e');
      return false;
    }
  }

  /// Restore stock quantities (useful for order cancellations)
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
      
      // Update menu operation counts after stock changes
      await _updateMenuOperationCounts();
      
      return true;
    } catch (e) {
      print('❌ Error restoring stock quantities: $e');
      return false;
    }
  }

  /// Get current stock status for a single item
  static Future<ItemStockStatus> getItemStockStatus(String itemId) async {
    try {
      final doc = await _firestore.collection('menuItems').doc(itemId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
        final totalQuantity = data['quantity'] ?? 0;
        final available = data['available'] ?? false;
        final menuType = data['menuType'] ?? 'breakfast';
        
        // Check if menu type is currently active
        final isMenuActive = await _isMenuTypeActive(MenuType.fromString(menuType));
        
        if (!available || !isMenuActive) {
          return ItemStockStatus.unavailable;
        } else if (hasUnlimitedStock) {
          return ItemStockStatus.unlimited;
        } else if (totalQuantity <= 0) {
          return ItemStockStatus.outOfStock;
        } else if (totalQuantity <= 5) {
          return ItemStockStatus.lowStock;
        } else {
          return ItemStockStatus.inStock;
        }
      } else {
        return ItemStockStatus.notFound;
      }
    } catch (e) {
      print('Error getting item stock status: $e');
      return ItemStockStatus.error;
    }
  }

  /// Get low stock items by menu type (for admin notifications)
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

      return snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final totalQuantity = data['quantity'] ?? 0;
        return totalQuantity <= threshold;
      }).map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Item',
          'quantity': data['quantity'] ?? 0,
          'price': data['price'] ?? 0.0,
          'menuType': data['menuType'] ?? 'breakfast',
        };
      }).toList();
    } catch (e) {
      print('Error getting low stock items: $e');
      return [];
    }
  }

  /// Get out of stock items by menu type
  static Future<List<Map<String, dynamic>>> getOutOfStockItems({MenuType? menuType}) async {
    try {
      Query query = _firestore
          .collection('menuItems')
          .where('hasUnlimitedStock', isEqualTo: false)
          .where('available', isEqualTo: true)
          .where('quantity', isLessThanOrEqualTo: 0);

      if (menuType != null) {
        query = query.where('menuType', isEqualTo: menuType.value);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Item',
          'quantity': data['quantity'] ?? 0,
          'price': data['price'] ?? 0.0,
          'menuType': data['menuType'] ?? 'breakfast',
        };
      }).toList();
    } catch (e) {
      print('Error getting out of stock items: $e');
      return [];
    }
  }

  /// Validate cart against current stock and active menus (real-time check)
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
          final totalStock = data['quantity'] ?? 0;
          final available = data['available'] ?? false;
          final menuType = data['menuType'] ?? 'breakfast';
          
          // Check if menu type is currently active
          final isMenuActive = await _isMenuTypeActive(MenuType.fromString(menuType));
          
          if (!available || !isMenuActive) {
            itemsToRemove.add(itemId);
          } else if (!hasUnlimitedStock) {
            if (totalStock <= 0) {
              itemsToRemove.add(itemId);
            } else if (totalStock < cartQuantity) {
              itemsToUpdate[itemId] = totalStock;
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

  /// Check if specific quantity can be added to cart (considering menu type status)
  static Future<bool> canAddToCart(String itemId, int currentCartQuantity, int additionalQuantity) async {
    try {
      final doc = await _firestore.collection('menuItems').doc(itemId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
        final totalStock = data['quantity'] ?? 0;
        final available = data['available'] ?? false;
        final menuType = data['menuType'] ?? 'breakfast';
        
        // Check if menu type is currently active
        final isMenuActive = await _isMenuTypeActive(MenuType.fromString(menuType));
        
        if (!available || !isMenuActive) return false;
        if (hasUnlimitedStock) return true;
        
        final totalRequested = currentCartQuantity + additionalQuantity;
        return totalRequested <= totalStock;
      }
      return false;
    } catch (e) {
      print('Error checking if can add to cart: $e');
      return false;
    }
  }

  /// Get detailed stock information by menu type (for admin)
  static Future<Map<String, dynamic>> getDetailedStockInfo(String itemId) async {
    try {
      final doc = await _firestore.collection('menuItems').doc(itemId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final totalQuantity = data['quantity'] ?? 0;
        final menuType = data['menuType'] ?? 'breakfast';
        
        return {
          'itemId': itemId,
          'name': data['name'] ?? 'Unknown Item',
          'hasUnlimitedStock': data['hasUnlimitedStock'] ?? false,
          'quantity': totalQuantity,
          'available': data['available'] ?? false,
          'menuType': menuType,
          'price': data['price'] ?? 0.0,
          'lastStockUpdate': data['lastStockUpdate'],
          'isMenuActive': await _isMenuTypeActive(MenuType.fromString(menuType)),
        };
      }
      
      return {'error': 'Item not found'};
    } catch (e) {
      print('Error getting detailed stock info: $e');
      return {'error': 'Error retrieving stock info'};
    }
  }

  /// Get stock summary by menu type
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

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final available = data['available'] ?? false;
        final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
        final quantity = data['quantity'] ?? 0;

        totalItems++;

        if (!available) continue;

        if (hasUnlimitedStock) {
          unlimitedStockItems++;
          availableItems++;
        } else if (quantity <= 0) {
          outOfStockItems++;
        } else if (quantity <= 5) {
          lowStockItems++;
          availableItems++;
        } else {
          availableItems++;
        }
      }

      return {
        'menuType': menuType.value,
        'totalItems': totalItems,
        'availableItems': availableItems,
        'outOfStockItems': outOfStockItems,
        'lowStockItems': lowStockItems,
        'unlimitedStockItems': unlimitedStockItems,
        'isMenuActive': await _isMenuTypeActive(menuType),
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
        'isMenuActive': false,
        'error': e.toString(),
      };
    }
  }

  /// Get overall stock summary across all menu types
  static Future<Map<String, dynamic>> getOverallStockSummary() async {
    try {
      Map<String, dynamic> summary = {
        'totalItems': 0,
        'availableItems': 0,
        'outOfStockItems': 0,
        'lowStockItems': 0,
        'unlimitedStockItems': 0,
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
        'byMenuType': {},
        'error': e.toString(),
      };
    }
  }

  /// Bulk update stock for multiple items (admin function)
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
      
      // Update menu operation counts after bulk stock changes
      await _updateMenuOperationCounts();
      
      print('✅ Bulk stock update completed for ${itemQuantities.length} items');
      return true;
    } catch (e) {
      print('❌ Error in bulk stock update: $e');
      return false;
    }
  }

  /// Set all items in a menu type to a specific availability status
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
      
      // Update menu operation counts
      await _updateMenuOperationCounts();
      
      print('✅ Set ${menuType.displayName} menu availability to $available');
      return true;
    } catch (e) {
      print('❌ Error setting menu type availability: $e');
      return false;
    }
  }

  /// Private helper to check if menu type is currently active
  static Future<bool> _isMenuTypeActive(MenuType menuType) async {
    try {
      final doc = await _firestore.collection('menuOperations').doc(menuType.value).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final isEnabled = data['isEnabled'] ?? false;
        
        if (!isEnabled) return false;
        
        // Check if current time is within operational hours
        final scheduleData = data['schedule'] as Map<String, dynamic>?;
        if (scheduleData != null) {
          final startTimeParts = scheduleData['startTime'].split(':');
          final endTimeParts = scheduleData['endTime'].split(':');
          
          final startTime = TimeOfDay(
            hour: int.parse(startTimeParts[0]),
            minute: int.parse(startTimeParts[1]),
          );
          final endTime = TimeOfDay(
            hour: int.parse(endTimeParts[0]),
            minute: int.parse(endTimeParts[1]),
          );
          
          final now = TimeOfDay.now();
          final currentMinutes = now.hour * 60 + now.minute;
          final startMinutes = startTime.hour * 60 + startTime.minute;
          final endMinutes = endTime.hour * 60 + endTime.minute;
          
          return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking if menu type is active: $e');
      return false;
    }
  }

  /// Private helper to update menu operation counts
  static Future<void> _updateMenuOperationCounts() async {
    try {
      await MenuOperationsService.updateMenuItemCounts();
    } catch (e) {
      print('Error updating menu operation counts: $e');
    }
  }

  /// Get items that need restocking by menu type
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

      return snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final quantity = data['quantity'] ?? 0;
        return quantity <= threshold;
      }).map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Item',
          'quantity': data['quantity'] ?? 0,
          'menuType': data['menuType'] ?? 'breakfast',
          'price': data['price'] ?? 0.0,
          'available': data['available'] ?? false,
          'suggestedRestockAmount': threshold - (data['quantity'] ?? 0) + 20,
        };
      }).toList();
    } catch (e) {
      print('Error getting items needing restock: $e');
      return [];
    }
  }

  /// Generate stock alert notifications for admin
  static Future<List<Map<String, dynamic>>> generateStockAlerts() async {
    try {
      List<Map<String, dynamic>> alerts = [];
      
      for (MenuType menuType in MenuType.values) {
        final isActive = await _isMenuTypeActive(menuType);
        
        if (isActive) {
          // Get critical stock items for active menus
          final lowStock = await getLowStockItems(threshold: 2, menuType: menuType);
          final outOfStock = await getOutOfStockItems(menuType: menuType);
          
          for (var item in outOfStock) {
            alerts.add({
              'type': 'OUT_OF_STOCK',
              'severity': 'HIGH',
              'menuType': menuType.displayName,
              'itemName': item['name'],
              'quantity': item['quantity'],
              'message': '${item['name']} is out of stock in ${menuType.displayName} menu',
            });
          }
          
          for (var item in lowStock) {
            alerts.add({
              'type': 'LOW_STOCK',
              'severity': 'MEDIUM',
              'menuType': menuType.displayName,
              'itemName': item['name'],
              'quantity': item['quantity'],
              'message': '${item['name']} is running low (${item['quantity']} left) in ${menuType.displayName} menu',
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
}

/// Result class for stock check operations
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

/// Result class for cart validation
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

/// Enum for item stock status
enum ItemStockStatus {
  unlimited,
  inStock,
  lowStock,
  outOfStock,
  unavailable,
  notFound,
  error,
}

/// Extension for ItemStockStatus to get display properties
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
        return Color(0xFF2196F3); // Blue
      case ItemStockStatus.inStock:
        return Color(0xFF4CAF50); // Green
      case ItemStockStatus.lowStock:
        return Color(0xFFFF9800); // Orange
      case ItemStockStatus.outOfStock:
        return Color(0xFFF44336); // Red
      case ItemStockStatus.unavailable:
        return Color(0xFF9E9E9E); // Grey
      case ItemStockStatus.notFound:
        return Color(0xFF9E9E9E); // Grey
      case ItemStockStatus.error:
        return Color(0xFFF44336); // Red
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