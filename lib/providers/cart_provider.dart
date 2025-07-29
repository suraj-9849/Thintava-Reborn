// lib/providers/cart_provider.dart - WITH RESERVATION SYSTEM
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:canteen_app/services/stock_management_service.dart';
import 'package:canteen_app/services/reservation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class CartProvider extends ChangeNotifier {
  Map<String, int> _cart = {};
  bool _isValidatingStock = false;
  
  Map<String, int> get cart => Map.unmodifiable(_cart);
  int get itemCount => _cart.values.fold(0, (sum, quantity) => sum + quantity);
  bool get isEmpty => _cart.isEmpty;
  List<String> get itemIds => _cart.keys.toList();
  bool get isValidatingStock => _isValidatingStock;
  
  // Add item to cart with reservation-aware stock validation
  Future<bool> addItem(String itemId, {int quantity = 1}) async {
    final currentQuantity = _cart[itemId] ?? 0;
    
    // Check if we can add this quantity (considering reservations)
    final canAdd = await StockManagementService.canAddToCart(
      itemId, 
      currentQuantity, 
      quantity
    );
    
    if (canAdd) {
      _cart[itemId] = currentQuantity + quantity;
      await _saveToStorage();
      notifyListeners();
      print('✅ Added $quantity of $itemId to cart. Total: ${_cart[itemId]}');
      return true;
    } else {
      print('❌ Cannot add $quantity of $itemId to cart - insufficient available stock');
      return false;
    }
  }
  
  // Remove one quantity of item
  void removeItem(String itemId) {
    if (_cart.containsKey(itemId)) {
      if (_cart[itemId]! > 1) {
        _cart[itemId] = _cart[itemId]! - 1;
      } else {
        _cart.remove(itemId);
      }
      _saveToStorage();
      notifyListeners();
      print('Removed 1 of $itemId from cart');
    }
  }
  
  // Remove item completely
  void removeItemCompletely(String itemId) {
    if (_cart.containsKey(itemId)) {
      _cart.remove(itemId);
      _saveToStorage();
      notifyListeners();
      print('Removed $itemId completely from cart');
    }
  }
  
  // Update item quantity with reservation-aware stock validation
  Future<bool> updateQuantity(String itemId, int quantity) async {
    if (quantity <= 0) {
      _cart.remove(itemId);
      await _saveToStorage();
      notifyListeners();
      return true;
    }
    
    // Check if the new quantity is valid (considering reservations)
    final canAdd = await StockManagementService.canAddToCart(itemId, 0, quantity);
    
    if (canAdd) {
      _cart[itemId] = quantity;
      await _saveToStorage();
      notifyListeners();
      print('✅ Updated $itemId quantity to $quantity');
      return true;
    } else {
      print('❌ Cannot update $itemId quantity to $quantity - insufficient available stock');
      return false;
    }
  }
  
  // Clear entire cart
  void clearCart() {
    _cart.clear();
    _saveToStorage();
    notifyListeners();
    print('Cart cleared');
  }
  
  // Get quantity of specific item
  int getQuantity(String itemId) {
    return _cart[itemId] ?? 0;
  }
  
  // Check if item is in cart
  bool isInCart(String itemId) {
    return _cart.containsKey(itemId) && _cart[itemId]! > 0;
  }
  
  // Get total price (requires item prices)
  double getTotalPrice(Map<String, double> itemPrices) {
    double total = 0.0;
    _cart.forEach((itemId, quantity) {
      final price = itemPrices[itemId] ?? 0.0;
      total += price * quantity;
    });
    return total;
  }
  
  // Validate entire cart against current available stock (with reservations)
  Future<CartValidationResult> validateCartStock() async {
    _isValidatingStock = true;
    notifyListeners();
    
    final result = await StockManagementService.validateCart(_cart);
    
    _isValidatingStock = false;
    notifyListeners();
    
    return result;
  }
  
  // Auto-fix cart based on validation result
  Future<void> autoFixCart(CartValidationResult validationResult) async {
    bool cartChanged = false;
    
    // Remove items that are no longer available
    for (String itemId in validationResult.itemsToRemove) {
      if (_cart.containsKey(itemId)) {
        _cart.remove(itemId);
        cartChanged = true;
        print('🗑️ Removed $itemId from cart (no longer available)');
      }
    }
    
    // Update quantities for items with insufficient available stock
    validationResult.itemsToUpdate.forEach((itemId, maxAvailableQuantity) {
      if (_cart.containsKey(itemId) && _cart[itemId]! > maxAvailableQuantity) {
        _cart[itemId] = maxAvailableQuantity;
        cartChanged = true;
        print('📝 Updated $itemId quantity to $maxAvailableQuantity (limited available stock)');
      }
    });
    
    if (cartChanged) {
      await _saveToStorage();
      notifyListeners();
    }
  }
  
  // Check available stock for entire cart (considering reservations)
  Future<StockCheckResult> checkStockAvailability() async {
    return await StockManagementService.checkStockAvailability(_cart);
  }
  
  // Check if can proceed to checkout (considering reservations)
  Future<bool> canProceedToCheckout() async {
    if (_cart.isEmpty) return false;
    
    // Check if available stock exists for all items
    final stockCheck = await checkStockAvailability();
    return stockCheck.isValid;
  }
  
  // Get reservation-aware stock status for cart items
  Future<Map<String, ItemStockStatus>> getCartItemsStockStatus() async {
    Map<String, ItemStockStatus> stockStatus = {};
    
    for (String itemId in _cart.keys) {
      final status = await StockManagementService.getItemStockStatus(itemId);
      stockStatus[itemId] = status;
    }
    
    return stockStatus;
  }
  
  // Get maximum addable quantity for an item (considering reservations)
  Future<int> getMaxAddableQuantity(String itemId) async {
    final currentCartQuantity = getQuantity(itemId);
    
    try {
      // Get available stock (actual - reserved)
      final availableStock = await ReservationService.getAvailableStock(itemId);
      final maxAddable = availableStock - currentCartQuantity;
      return maxAddable > 0 ? maxAddable : 0;
    } catch (e) {
      print('Error getting max addable quantity: $e');
      return 0;
    }
  }
  
  // Get detailed stock info for cart items (including reservations)
  Future<Map<String, Map<String, int>>> getCartStockInfo() async {
    Map<String, Map<String, int>> stockInfo = {};
    
    for (String itemId in _cart.keys) {
      try {
        final doc = await FirebaseFirestore.instance.collection('menuItems').doc(itemId).get();
        
        if (doc.exists) {
          final data = doc.data()!;
          final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
          
          if (hasUnlimitedStock) {
            stockInfo[itemId] = {
              'actual': 999999,
              'available': 999999,
              'reserved': 0,
            };
          } else {
            final actualStock = data['quantity'] ?? 0;
            final reservedStock = await ReservationService.getActiveReservationsForItem(itemId);
            final availableStock = actualStock - reservedStock;
            
            stockInfo[itemId] = {
              'actual': actualStock,
              'available': availableStock > 0 ? availableStock : 0,
              'reserved': reservedStock,
            };
          }
        } else {
          stockInfo[itemId] = {
            'actual': 0,
            'available': 0,
            'reserved': 0,
          };
        }
      } catch (e) {
        print('Error getting stock info for $itemId: $e');
        stockInfo[itemId] = {
          'actual': 0,
          'available': 0,
          'reserved': 0,
        };
      }
    }
    
    return stockInfo;
  }
  
  // Get items that have stock issues (considering reservations)
  Future<List<CartStockIssue>> getCartStockIssues() async {
    List<CartStockIssue> issues = [];
    
    final stockInfo = await getCartStockInfo();
    
    stockInfo.forEach((itemId, info) {
      final cartQuantity = getQuantity(itemId);
      final availableQuantity = info['available'] ?? 0;
      final actualQuantity = info['actual'] ?? 0;
      final reservedQuantity = info['reserved'] ?? 0;
      
      if (availableQuantity == 0 && actualQuantity == 0) {
        issues.add(CartStockIssue(
          itemId: itemId,
          issueType: StockIssueType.outOfStock,
          currentQuantity: cartQuantity,
          availableQuantity: 0,
          message: 'This item is out of stock',
        ));
      } else if (availableQuantity == 0 && reservedQuantity > 0) {
        issues.add(CartStockIssue(
          itemId: itemId,
          issueType: StockIssueType.fullyReserved,
          currentQuantity: cartQuantity,
          availableQuantity: 0,
          message: 'This item is currently reserved by other customers',
        ));
      } else if (availableQuantity < cartQuantity) {
        issues.add(CartStockIssue(
          itemId: itemId,
          issueType: StockIssueType.insufficientStock,
          currentQuantity: cartQuantity,
          availableQuantity: availableQuantity,
          message: 'Only $availableQuantity available (you have $cartQuantity in cart)',
        ));
      } else if (availableQuantity <= 5 && availableQuantity > 0) {
        issues.add(CartStockIssue(
          itemId: itemId,
          issueType: StockIssueType.lowStock,
          currentQuantity: cartQuantity,
          availableQuantity: availableQuantity,
          message: 'Low stock: only $availableQuantity left',
        ));
      }
    });
    
    return issues;
  }
  
  // Pre-checkout validation (comprehensive check before payment)
  Future<PreCheckoutValidation> validateForCheckout() async {
    final issues = await getCartStockIssues();
    final stockCheck = await checkStockAvailability();
    
    final criticalIssues = issues.where((issue) => 
      issue.issueType == StockIssueType.outOfStock ||
      issue.issueType == StockIssueType.insufficientStock ||
      issue.issueType == StockIssueType.fullyReserved
    ).toList();
    
    final warnings = issues.where((issue) => 
      issue.issueType == StockIssueType.lowStock
    ).toList();
    
    return PreCheckoutValidation(
      canProceed: criticalIssues.isEmpty && stockCheck.isValid,
      criticalIssues: criticalIssues,
      warnings: warnings,
      needsCartUpdate: criticalIssues.isNotEmpty,
    );
  }
  
  // Save cart to local storage
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = json.encode(_cart);
      await prefs.setString('cart_data', cartJson);
      print('💾 Cart saved to storage: $cartJson');
    } catch (e) {
      print('❌ Error saving cart to storage: $e');
    }
  }
  
  // Load cart from local storage with reservation validation
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_data');
      
      if (cartJson != null && cartJson.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(cartJson);
        _cart = decoded.map((key, value) => MapEntry(key, value as int));
        
        // Validate loaded cart against current available stock (with reservations)
        final validationResult = await validateCartStock();
        if (!validationResult.isValid) {
          await autoFixCart(validationResult);
        }
        
        print('📱 Cart loaded from storage and validated: $_cart');
      } else {
        print('📱 No cart data found in storage');
      }
    } catch (e) {
      print('❌ Error loading cart from storage: $e');
      _cart = {};
    }
    notifyListeners();
  }
  
  // Clear storage (call this after successful order)
  Future<void> clearStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cart_data');
      print('🧹 Cart storage cleared');
    } catch (e) {
      print('❌ Error clearing cart storage: $e');
    }
  }
  
  // Get cart summary for display
  String getCartSummary() {
    if (_cart.isEmpty) return 'Cart is empty';
    
    List<String> items = [];
    _cart.forEach((itemId, quantity) {
      items.add('$itemId x$quantity');
    });
    
    return items.join(', ');
  }
  
  // Debug method to print cart contents with stock info
  Future<void> printCartWithStockInfo() async {
    print('=== CART CONTENTS WITH STOCK INFO ===');
    if (_cart.isEmpty) {
      print('Cart is empty');
    } else {
      final stockInfo = await getCartStockInfo();
      
      _cart.forEach((itemId, quantity) {
        final info = stockInfo[itemId] ?? {'actual': 0, 'available': 0, 'reserved': 0};
        print('$itemId: $quantity (Actual: ${info['actual']}, Available: ${info['available']}, Reserved: ${info['reserved']})');
      });
      print('Total items: $itemCount');
    }
    print('======================================');
  }
  
  // Cleanup method (call on logout)
  Future<void> cleanup() async {
    _cart.clear();
    await clearStorage();
    notifyListeners();
  }
}

// Enhanced helper class for cart stock issues (with reservation awareness)
class CartStockIssue {
  final String itemId;
  final StockIssueType issueType;
  final int currentQuantity;
  final int? availableQuantity;
  final String message;

  CartStockIssue({
    required this.itemId,
    required this.issueType,
    required this.currentQuantity,
    this.availableQuantity,
    required this.message,
  });
}

enum StockIssueType {
  outOfStock,
  lowStock,
  insufficientStock,
  unavailable,
  fullyReserved, // New: when item has stock but it's all reserved
}

// New helper class for pre-checkout validation
class PreCheckoutValidation {
  final bool canProceed;
  final List<CartStockIssue> criticalIssues;
  final List<CartStockIssue> warnings;
  final bool needsCartUpdate;

  PreCheckoutValidation({
    required this.canProceed,
    required this.criticalIssues,
    required this.warnings,
    required this.needsCartUpdate,
  });

  bool get hasIssues => criticalIssues.isNotEmpty || warnings.isNotEmpty;
  bool get hasCriticalIssues => criticalIssues.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}