// lib/providers/cart_provider.dart - ENHANCED WITH ACTIVE ORDER CHECKING
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:canteen_app/services/stock_management_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class CartProvider extends ChangeNotifier {
  Map<String, int> _cart = {};
  bool _isValidatingStock = false;
  bool _hasActiveOrder = false;
  String? _activeOrderId;
  
  Map<String, int> get cart => Map.unmodifiable(_cart);
  int get itemCount => _cart.values.fold(0, (sum, quantity) => sum + quantity);
  bool get isEmpty => _cart.isEmpty;
  List<String> get itemIds => _cart.keys.toList();
  bool get isValidatingStock => _isValidatingStock;
  bool get hasActiveOrder => _hasActiveOrder;
  String? get activeOrderId => _activeOrderId;
  
  // Check for active orders
  Future<bool> _checkActiveOrder() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      final activeOrderQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['Placed', 'Preparing', 'Ready', 'Pick Up'])
          .limit(1)
          .get();
      
      if (activeOrderQuery.docs.isNotEmpty) {
        _hasActiveOrder = true;
        _activeOrderId = activeOrderQuery.docs.first.id;
        print('🚫 Active order found: $_activeOrderId');
        return true;
      } else {
        _hasActiveOrder = false;
        _activeOrderId = null;
        return false;
      }
    } catch (e) {
      print('❌ Error checking active order: $e');
      return false;
    }
  }
  
  // Add item to cart with stock validation and active order check
  Future<bool> addItem(String itemId, {int quantity = 1}) async {
    // Check for active order first
    if (await _checkActiveOrder()) {
      notifyListeners();
      return false;
    }
    
    final currentQuantity = _cart[itemId] ?? 0;
    
    // Check if we can add this quantity
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
      print('❌ Cannot add $quantity of $itemId to cart - insufficient stock');
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
  
  // Update item quantity with stock validation and active order check
  Future<bool> updateQuantity(String itemId, int quantity) async {
    // Check for active order first
    if (await _checkActiveOrder()) {
      notifyListeners();
      return false;
    }
    
    if (quantity <= 0) {
      _cart.remove(itemId);
      await _saveToStorage();
      notifyListeners();
      return true;
    }
    
    // Check if the new quantity is valid
    final canAdd = await StockManagementService.canAddToCart(itemId, 0, quantity);
    
    if (canAdd) {
      _cart[itemId] = quantity;
      await _saveToStorage();
      notifyListeners();
      print('✅ Updated $itemId quantity to $quantity');
      return true;
    } else {
      print('❌ Cannot update $itemId quantity to $quantity - insufficient stock');
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
  
  // Clear active order status (call after successful order placement or when order is completed)
  void clearActiveOrderStatus() {
    _hasActiveOrder = false;
    _activeOrderId = null;
    notifyListeners();
    print('Active order status cleared');
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
  
  // Validate entire cart against current stock and active order
  Future<CartValidationResult> validateCartStock() async {
    _isValidatingStock = true;
    notifyListeners();
    
    // Check for active order first
    if (await _checkActiveOrder()) {
      _isValidatingStock = false;
      notifyListeners();
      return CartValidationResult(
        isValid: false,
        itemsToRemove: [],
        itemsToUpdate: {},
      );
    }
    
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
    
    // Update quantities for items with insufficient stock
    validationResult.itemsToUpdate.forEach((itemId, maxQuantity) {
      if (_cart.containsKey(itemId) && _cart[itemId]! > maxQuantity) {
        _cart[itemId] = maxQuantity;
        cartChanged = true;
        print('📝 Updated $itemId quantity to $maxQuantity (limited stock)');
      }
    });
    
    if (cartChanged) {
      await _saveToStorage();
      notifyListeners();
    }
  }
  
  // Check stock availability for entire cart
  Future<StockCheckResult> checkStockAvailability() async {
    return await StockManagementService.checkStockAvailability(_cart);
  }
  
  // Check if can proceed to checkout (no active order and cart not empty)
  Future<bool> canProceedToCheckout() async {
    if (_cart.isEmpty) return false;
    return !(await _checkActiveOrder());
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
  
  // Load cart from local storage
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_data');
      
      if (cartJson != null && cartJson.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(cartJson);
        _cart = decoded.map((key, value) => MapEntry(key, value as int));
        
        // Check for active order on load
        await _checkActiveOrder();
        
        // Validate loaded cart against current stock
        final validationResult = await validateCartStock();
        if (!validationResult.isValid) {
          await autoFixCart(validationResult);
        }
        
        print('📱 Cart loaded from storage: $_cart');
      } else {
        print('📱 No cart data found in storage');
        // Still check for active order even if no cart data
        await _checkActiveOrder();
      }
    } catch (e) {
      print('❌ Error loading cart from storage: $e');
      _cart = {};
      await _checkActiveOrder();
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
  
  // Get items that are low stock or out of stock in current cart
  Future<Map<String, ItemStockStatus>> getCartItemsStockStatus() async {
    Map<String, ItemStockStatus> stockStatus = {};
    
    for (String itemId in _cart.keys) {
      final status = await StockManagementService.getItemStockStatus(itemId);
      stockStatus[itemId] = status;
    }
    
    return stockStatus;
  }
  
  // Get maximum addable quantity for an item
  Future<int> getMaxAddableQuantity(String itemId) async {
    // Check for active order first
    if (await _checkActiveOrder()) {
      return 0;
    }
    
    final currentCartQuantity = getQuantity(itemId);
    
    try {
      // This is a simplified check - in reality you'd want to check against current stock
      final canAdd = await StockManagementService.canAddToCart(itemId, currentCartQuantity, 1);
      if (!canAdd) return 0;
      
      // For now, we'll return a high number if unlimited stock
      // In a real implementation, you'd fetch the actual available stock
      return 99; // Placeholder
    } catch (e) {
      print('Error getting max addable quantity: $e');
      return 0;
    }
  }
  
  // Debug method to print cart contents
  void printCart() {
    print('=== CART CONTENTS ===');
    if (_cart.isEmpty) {
      print('Cart is empty');
    } else {
      _cart.forEach((itemId, quantity) {
        print('$itemId: $quantity');
      });
      print('Total items: $itemCount');
    }
    print('Active Order: $_hasActiveOrder');
    print('====================');
  }
  
  // Get items that have stock issues
  Future<List<CartStockIssue>> getCartStockIssues() async {
    List<CartStockIssue> issues = [];
    
    // Check for active order first
    if (await _checkActiveOrder()) {
      issues.add(CartStockIssue(
        itemId: 'active_order',
        issueType: StockIssueType.unavailable,
        currentQuantity: 0,
        availableQuantity: 0,
        message: 'You have an active order. Complete it before placing a new one.',
      ));
      return issues;
    }
    
    final stockStatuses = await getCartItemsStockStatus();
    
    stockStatuses.forEach((itemId, status) {
      final quantity = getQuantity(itemId);
      
      switch (status) {
        case ItemStockStatus.outOfStock:
          issues.add(CartStockIssue(
            itemId: itemId,
            issueType: StockIssueType.outOfStock,
            currentQuantity: quantity,
            availableQuantity: 0,
            message: 'This item is out of stock',
          ));
          break;
        case ItemStockStatus.lowStock:
          issues.add(CartStockIssue(
            itemId: itemId,
            issueType: StockIssueType.lowStock,
            currentQuantity: quantity,
            availableQuantity: null, // Would need to fetch actual quantity
            message: 'This item has low stock',
          ));
          break;
        case ItemStockStatus.unavailable:
          issues.add(CartStockIssue(
            itemId: itemId,
            issueType: StockIssueType.unavailable,
            currentQuantity: quantity,
            availableQuantity: 0,
            message: 'This item is no longer available',
          ));
          break;
        default:
          break;
      }
    });
    
    return issues;
  }
}

// Helper class for cart stock issues
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
}