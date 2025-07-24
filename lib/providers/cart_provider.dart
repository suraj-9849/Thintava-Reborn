// lib/providers/cart_provider.dart - FIXED VERSION (UPDATED ACTIVE ORDER CHECK)
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:canteen_app/services/stock_management_service.dart';
import 'package:canteen_app/services/reservation_service.dart';
import 'package:canteen_app/models/reservation_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:async';

class CartProvider extends ChangeNotifier {
  Map<String, int> _cart = {};
  bool _isValidatingStock = false;
  bool _hasActiveOrder = false;
  String? _activeOrderId;
  
  // Reservation-related fields
  List<StockReservation> _activeReservations = [];
  bool _isReserving = false;
  CartReservationState _reservationState = CartReservationState();
  StreamSubscription<List<StockReservation>>? _reservationSubscription;
  
  Map<String, int> get cart => Map.unmodifiable(_cart);
  int get itemCount => _cart.values.fold(0, (sum, quantity) => sum + quantity);
  bool get isEmpty => _cart.isEmpty;
  List<String> get itemIds => _cart.keys.toList();
  bool get isValidatingStock => _isValidatingStock;
  bool get hasActiveOrder => _hasActiveOrder;
  String? get activeOrderId => _activeOrderId;
  
  // Reservation getters
  List<StockReservation> get activeReservations => List.unmodifiable(_activeReservations);
  bool get isReserving => _isReserving;
  CartReservationState get reservationState => _reservationState;
  bool get hasActiveReservations => _reservationState.hasActiveReservations;
  
  @override
  void dispose() {
    _reservationSubscription?.cancel();
    super.dispose();
  }
  
  // FIXED: Check for active orders with correct status flow (EXCLUDING TERMINATED ORDERS)
  Future<bool> _checkActiveOrder() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      // FIXED: Exclude 'Terminated' status from active orders check
      final activeOrderQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['Placed', 'Cooking', 'Cooked', 'Pick Up'])
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
  
  // Start listening to reservation changes
  void _startReservationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    _reservationSubscription?.cancel();
    _reservationSubscription = ReservationService
        .watchUserReservations(user.uid)
        .listen((reservations) {
      _activeReservations = reservations;
      _updateReservationState();
      notifyListeners();
    });
  }
  
  void _updateReservationState() {
    if (_activeReservations.isEmpty) {
      _reservationState = CartReservationState();
      return;
    }
    
    final activeReservations = _activeReservations.where((r) => r.isActive).toList();
    
    if (activeReservations.isEmpty) {
      _reservationState = CartReservationState();
      return;
    }
    
    final earliestExpiry = activeReservations
        .map((r) => r.expiresAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    
    final reservedQuantities = <String, int>{};
    for (var reservation in activeReservations) {
      reservedQuantities[reservation.itemId] = 
          (reservedQuantities[reservation.itemId] ?? 0) + reservation.quantity;
    }
    
    _reservationState = CartReservationState(
      hasActiveReservations: true,
      reservations: activeReservations,
      earliestExpiry: earliestExpiry,
      reservedQuantities: reservedQuantities,
    );
  }
  
  // Add item to cart with stock validation and active order check
  Future<bool> addItem(String itemId, {int quantity = 1}) async {
    // Check for active order first
    if (await _checkActiveOrder()) {
      notifyListeners();
      return false;
    }
    
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
    
    // Check if the new quantity is valid (considering reservations)
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
  
  // Clear active order status
  void clearActiveOrderStatus() {
    _hasActiveOrder = false;
    _activeOrderId = null;
    notifyListeners();
    print('Active order status cleared');
  }
  
  // ======================== RESERVATION METHODS ========================
  
  /// Reserve items in cart before payment
  Future<ReservationResult> reserveCartItems({Duration? duration}) async {
    if (_cart.isEmpty) {
      return ReservationResult.failure('Cart is empty');
    }
    
    // Check for active order first
    if (await _checkActiveOrder()) {
      return ReservationResult.failure('You have an active order. Complete it before placing a new one.');
    }
    
    _isReserving = true;
    notifyListeners();
    
    try {
      final result = await ReservationService.reserveCartItems(_cart, reservationDuration: duration);
      
      if (result.success && result.reservations != null) {
        _activeReservations = result.reservations!;
        _updateReservationState();
        print('✅ Successfully reserved ${result.reservations!.length} items');
      }
      
      return result;
    } catch (e) {
      print('❌ Error reserving cart items: $e');
      return ReservationResult.failure('Failed to reserve items: $e');
    } finally {
      _isReserving = false;
      notifyListeners();
    }
  }
  
  /// Release current reservations
  Future<bool> releaseReservations({ReservationStatus status = ReservationStatus.cancelled}) async {
    if (_activeReservations.isEmpty) return true;
    
    final reservationIds = _activeReservations
        .where((r) => r.isActive)
        .map((r) => r.id)
        .toList();
    
    if (reservationIds.isEmpty) return true;
    
    final success = await ReservationService.releaseReservations(reservationIds, status: status);
    
    if (success) {
      _activeReservations.clear();
      _updateReservationState();
      notifyListeners();
      print('✅ Released ${reservationIds.length} reservations');
    }
    
    return success;
  }
  
  /// Confirm reservations (called after successful payment)
  Future<bool> confirmReservations(String orderId) async {
    if (_activeReservations.isEmpty) return true;
    
    final reservationIds = _activeReservations
        .where((r) => r.isActive)
        .map((r) => r.id)
        .toList();
    
    if (reservationIds.isEmpty) return true;
    
    final success = await ReservationService.confirmReservations(reservationIds, orderId);
    
    if (success) {
      _activeReservations.clear();
      _updateReservationState();
      clearCart(); // Clear cart after successful confirmation
      clearStorage();
      notifyListeners();
      print('✅ Confirmed ${reservationIds.length} reservations for order $orderId');
    }
    
    return success;
  }
  
  /// Check if cart can be reserved before payment
  Future<Map<String, dynamic>> checkCartReservability() async {
    if (_cart.isEmpty) {
      return {'canReserve': false, 'error': 'Cart is empty'};
    }
    
    // Check for active order
    if (await _checkActiveOrder()) {
      return {
        'canReserve': false, 
        'error': 'You have an active order. Complete it before placing a new one.'
      };
    }
    
    return await ReservationService.checkCartReservability(_cart);
  }
  
  /// Get items that are currently reserved by this user
  List<String> getReservedItemIds() {
    return _reservationState.reservedQuantities.keys.toList();
  }
  
  /// Check if specific item is reserved
  bool isItemReserved(String itemId) {
    return _reservationState.isItemReserved(itemId);
  }
  
  /// Get reserved quantity for specific item
  int getReservedQuantity(String itemId) {
    return _reservationState.getReservedQuantity(itemId);
  }
  
  // ======================== EXISTING METHODS (Updated) ========================
  
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
  
  // Check if can proceed to checkout
  Future<bool> canProceedToCheckout() async {
    if (_cart.isEmpty) return false;
    
    // Check for active order
    if (await _checkActiveOrder()) return false;
    
    // Check if stock is available
    final stockCheck = await checkStockAvailability();
    return stockCheck.isValid;
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
        
        // Start reservation listener
        _startReservationListener();
        
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
        _startReservationListener();
      }
    } catch (e) {
      print('❌ Error loading cart from storage: $e');
      _cart = {};
      await _checkActiveOrder();
      _startReservationListener();
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
      // Get available stock (considering reservations)
      final availableStock = await ReservationService.getAvailableStock(itemId);
      final maxAddable = availableStock - currentCartQuantity;
      return maxAddable > 0 ? maxAddable : 0;
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
    print('Active Reservations: ${_activeReservations.length}');
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
            availableQuantity: null,
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
  
  // Handle reservation expiry
  void handleReservationExpiry() {
    print('⏰ Reservations have expired');
    _activeReservations.clear();
    _updateReservationState();
    notifyListeners();
  }
  
  // Cleanup method (call on logout)
  Future<void> cleanup() async {
    await releaseReservations();
    _reservationSubscription?.cancel();
    _cart.clear();
    _hasActiveOrder = false;
    _activeOrderId = null;
    _activeReservations.clear();
    _updateReservationState();
    await clearStorage();
    notifyListeners();
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