// lib/core/utils/user_utils.dart - FIXED COMPILATION ERRORS
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../enums/user_enums.dart';
import '../../services/reservation_service.dart';

class UserUtils {
  // Cache to store recent stock calculations to reduce API calls
  static final Map<String, _StockCache> _stockCache = {};
  static const Duration _cacheValidDuration = Duration(seconds: 30);

  // Date formatting without intl package
  static String formatDate(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    final year = dateTime.year;
    
    int hour = dateTime.hour;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$month $day, $year - $hour:$minute $amPm';
  }
  
  // Status helpers
  static OrderStatusType getOrderStatusType(String status) {
    switch (status) {
      case 'Placed':
        return OrderStatusType.placed;
      case 'Pick Up':
        return OrderStatusType.pickUp;
      case 'PickedUp':
        return OrderStatusType.pickedUp;
      case 'Expired':
        return OrderStatusType.expired;
      default:
        return OrderStatusType.placed;
    }
  }
  
  static IconData getStatusIcon(OrderStatusType status) {
    switch (status) {
      case OrderStatusType.placed:
        return Icons.receipt_long;
      case OrderStatusType.pickUp:
        return Icons.delivery_dining;
      case OrderStatusType.pickedUp:
        return Icons.done_all;
      case OrderStatusType.expired:
        return Icons.access_time_filled;
    }
  }
  
  static Color getStatusColor(OrderStatusType status) {
    switch (status) {
      case OrderStatusType.placed:
        return Colors.blue;
      case OrderStatusType.pickUp:
        return Colors.green;
      case OrderStatusType.pickedUp:
        return Colors.green;
      case OrderStatusType.expired:
        return Colors.red;
    }
  }
  
  // ✅ OPTIMIZED: Stock calculations with caching to reduce flickering
  static Future<int> getAvailableStock(Map<String, dynamic> itemData, String itemId) async {
    final hasUnlimitedStock = itemData['hasUnlimitedStock'] ?? false;
    
    if (hasUnlimitedStock) {
      return 999999;
    }
    
    // Check cache first
    final cached = _stockCache[itemId];
    if (cached != null && cached.isValid()) {
      return cached.availableStock;
    }
    
    try {
      // Get available stock from reservation service (actual - reserved)
      final availableStock = await ReservationService.getAvailableStock(itemId);
      
      // Get actual stock for caching
      final actualStock = itemData['quantity'] ?? 0;
      
      // Cache the result
      _stockCache[itemId] = _StockCache(
        actualStock: actualStock,
        availableStock: availableStock,
        timestamp: DateTime.now(),
      );
      
      return availableStock;
    } catch (e) {
      print('Error getting available stock for $itemId: $e');
      // Return sync calculation as fallback
      return getAvailableStockSync(itemData);
    }
  }
  
  // Improved sync method with better fallback
  static int getAvailableStockSync(Map<String, dynamic> itemData) {
    final hasUnlimitedStock = itemData['hasUnlimitedStock'] ?? false;
    
    if (hasUnlimitedStock) {
      return 999999;
    }
    
    // Return actual stock for immediate display (will be updated by async calls)
    final totalStock = itemData['quantity'] ?? 0;
    return totalStock > 0 ? totalStock : 0;
  }
  
  static Future<StockStatusType> getStockStatus(Map<String, dynamic> itemData, String itemId) async {
    final available = itemData['available'] ?? false;
    final hasUnlimitedStock = itemData['hasUnlimitedStock'] ?? false;
    
    if (!available) return StockStatusType.unavailable;
    if (hasUnlimitedStock) return StockStatusType.unlimited;
    
    final availableStock = await getAvailableStock(itemData, itemId);
    
    if (availableStock <= 0) return StockStatusType.outOfStock;
    if (availableStock <= 5) return StockStatusType.lowStock;
    return StockStatusType.inStock;
  }
  
  // Improved sync method
  static StockStatusType getStockStatusSync(Map<String, dynamic> itemData) {
    final available = itemData['available'] ?? false;
    final hasUnlimitedStock = itemData['hasUnlimitedStock'] ?? false;
    
    if (!available) return StockStatusType.unavailable;
    if (hasUnlimitedStock) return StockStatusType.unlimited;
    
    final availableStock = getAvailableStockSync(itemData);
    
    if (availableStock <= 0) return StockStatusType.outOfStock;
    if (availableStock <= 5) return StockStatusType.lowStock;
    return StockStatusType.inStock;
  }
  
  static Color getStockStatusColor(StockStatusType status) {
    switch (status) {
      case StockStatusType.unlimited:
        return Colors.blue;
      case StockStatusType.inStock:
        return Colors.green;
      case StockStatusType.lowStock:
        return Colors.orange;
      case StockStatusType.outOfStock:
        return Colors.red;
      case StockStatusType.unavailable:
        return Colors.grey;
    }
  }
  
  static String getStockStatusText(StockStatusType status, int? availableStock) {
    switch (status) {
      case StockStatusType.unlimited:
        return 'Available';
      case StockStatusType.inStock:
        return 'In Stock';
      case StockStatusType.lowStock:
        return 'Low Stock (${availableStock ?? 0} left)';
      case StockStatusType.outOfStock:
        return 'Out of Stock';
      case StockStatusType.unavailable:
        return 'Unavailable';
    }
  }
  
  // Validation helpers (WITH RESERVATIONS)
  static Future<bool> canAddToCart(Map<String, dynamic> itemData, String itemId, int currentCartQuantity) async {
    final available = itemData['available'] ?? false;
    if (!available) return false;
    
    final hasUnlimitedStock = itemData['hasUnlimitedStock'] ?? false;
    if (hasUnlimitedStock) return true;
    
    final availableStock = await getAvailableStock(itemData, itemId);
    return (currentCartQuantity + 1) <= availableStock;
  }
  
  // Legacy sync method for immediate validation
  static bool canAddToCartSync(Map<String, dynamic> itemData, int currentCartQuantity) {
    final available = itemData['available'] ?? false;
    if (!available) return false;
    
    final hasUnlimitedStock = itemData['hasUnlimitedStock'] ?? false;
    if (hasUnlimitedStock) return true;
    
    final availableStock = getAvailableStockSync(itemData);
    return (currentCartQuantity + 1) <= availableStock;
  }
  
  // ✅ OPTIMIZED: Enhanced method with caching and better error handling
  static Future<Map<String, int>> getStockInfo(String itemId) async {
    try {
      // Check cache first
      final cached = _stockCache[itemId];
      if (cached != null && cached.isValid()) {
        return {
          'actual': cached.actualStock,
          'available': cached.availableStock,
          'reserved': cached.actualStock - cached.availableStock,
        };
      }
      
      final doc = await FirebaseFirestore.instance.collection('menuItems').doc(itemId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
        
        if (hasUnlimitedStock) {
          // Cache unlimited stock items too
          _stockCache[itemId] = _StockCache(
            actualStock: 999999,
            availableStock: 999999,
            timestamp: DateTime.now(),
          );
          
          return {
            'actual': 999999,
            'available': 999999,
            'reserved': 0,
          };
        }
        
        final actualStock = data['quantity'] ?? 0;
        final reservedStock = await ReservationService.getActiveReservationsForItem(itemId);
        final availableStock = actualStock - reservedStock;
        
        // Cache the result
        _stockCache[itemId] = _StockCache(
          actualStock: actualStock,
          availableStock: availableStock > 0 ? availableStock : 0,
          timestamp: DateTime.now(),
        );
        
        return {
          'actual': actualStock,
          'available': availableStock > 0 ? availableStock : 0,
          'reserved': reservedStock,
        };
      }
      
      return {
        'actual': 0,
        'available': 0,
        'reserved': 0,
      };
    } catch (e) {
      print('Error getting stock info: $e');
      return {
        'actual': 0,
        'available': 0,
        'reserved': 0,
      };
    }
  }
  
  // ✅ NEW: Method to clear cache when needed
  static void clearStockCache([String? itemId]) {
    if (itemId != null) {
      _stockCache.remove(itemId);
    } else {
      _stockCache.clear();
    }
  }
  
  // ✅ NEW: Method to clear expired cache entries
  static void cleanupExpiredCache() {
    final now = DateTime.now();
    _stockCache.removeWhere((key, cache) => !cache.isValid(now));
  }
}

// ✅ NEW: Cache class for stock information
class _StockCache {
  final int actualStock;
  final int availableStock;
  final DateTime timestamp;

  _StockCache({
    required this.actualStock,
    required this.availableStock,
    required this.timestamp,
  });

  bool isValid([DateTime? now]) {
    now ??= DateTime.now();
    return now.difference(timestamp) < UserUtils._cacheValidDuration;
  }
}