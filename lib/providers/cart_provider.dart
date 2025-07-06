// lib/providers/cart_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CartProvider extends ChangeNotifier {
  Map<String, int> _cart = {};
  
  Map<String, int> get cart => Map.unmodifiable(_cart);
  
  int get itemCount => _cart.values.fold(0, (sum, quantity) => sum + quantity);
  
  bool get isEmpty => _cart.isEmpty;
  
  List<String> get itemIds => _cart.keys.toList();
  
  // Add item to cart
  void addItem(String itemId, {int quantity = 1}) {
    _cart[itemId] = (_cart[itemId] ?? 0) + quantity;
    _saveToStorage();
    notifyListeners();
    print('Added $quantity of $itemId to cart. Total: ${_cart[itemId]}');
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
  
  // Update item quantity
  void updateQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      _cart.remove(itemId);
    } else {
      _cart[itemId] = quantity;
    }
    _saveToStorage();
    notifyListeners();
    print('Updated $itemId quantity to $quantity');
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
  
  // Save cart to local storage
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = json.encode(_cart);
      await prefs.setString('cart_data', cartJson);
      print('Cart saved to storage: $cartJson');
    } catch (e) {
      print('Error saving cart to storage: $e');
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
        notifyListeners();
        print('Cart loaded from storage: $_cart');
      } else {
        print('No cart data found in storage');
      }
    } catch (e) {
      print('Error loading cart from storage: $e');
      _cart = {};
    }
  }
  
  // Clear storage (call this after successful order)
  Future<void> clearStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cart_data');
      print('Cart storage cleared');
    } catch (e) {
      print('Error clearing cart storage: $e');
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
    print('====================');
  }
}