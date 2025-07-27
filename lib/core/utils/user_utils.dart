// lib/core/utils/user_utils.dart - SIMPLIFIED (NO RESERVATION SYSTEM)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../enums/user_enums.dart';

class UserUtils {
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
      case 'Cooking':
        return OrderStatusType.cooking;
      case 'Cooked':
        return OrderStatusType.cooked;
      case 'Pick Up':
        return OrderStatusType.pickUp;
      case 'PickedUp':
        return OrderStatusType.pickedUp;
      case 'Terminated':
        return OrderStatusType.terminated;
      default:
        return OrderStatusType.placed;
    }
  }
  
  static IconData getStatusIcon(OrderStatusType status) {
    switch (status) {
      case OrderStatusType.placed:
        return Icons.receipt_long;
      case OrderStatusType.cooking:
        return Icons.restaurant;
      case OrderStatusType.cooked:
        return Icons.check_circle;
      case OrderStatusType.pickUp:
        return Icons.delivery_dining;
      case OrderStatusType.pickedUp:
        return Icons.done_all;
      case OrderStatusType.terminated:
        return Icons.cancel;
    }
  }
  
  static Color getStatusColor(OrderStatusType status) {
    switch (status) {
      case OrderStatusType.placed:
        return Colors.blue;
      case OrderStatusType.cooking:
        return Colors.orange;
      case OrderStatusType.cooked:
        return Colors.green;
      case OrderStatusType.pickUp:
        return const Color(0xFFFFB703);
      case OrderStatusType.pickedUp:
        return Colors.green;
      case OrderStatusType.terminated:
        return Colors.red;
    }
  }
  
  // Stock calculations (simplified - no reservations)
  static int getAvailableStock(Map<String, dynamic> itemData) {
    final hasUnlimitedStock = itemData['hasUnlimitedStock'] ?? false;
    
    if (hasUnlimitedStock) {
      return 999999;
    }
    
    final totalStock = itemData['quantity'] ?? 0;
    return totalStock > 0 ? totalStock : 0;
  }
  
  static StockStatusType getStockStatus(Map<String, dynamic> itemData) {
    final available = itemData['available'] ?? false;
    final hasUnlimitedStock = itemData['hasUnlimitedStock'] ?? false;
    
    if (!available) return StockStatusType.unavailable;
    if (hasUnlimitedStock) return StockStatusType.unlimited;
    
    final availableStock = getAvailableStock(itemData);
    
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
  
  // Validation helpers (simplified - no reservations)
  static bool canAddToCart(Map<String, dynamic> itemData, int currentCartQuantity) {
    final available = itemData['available'] ?? false;
    if (!available) return false;
    
    final hasUnlimitedStock = itemData['hasUnlimitedStock'] ?? false;
    if (hasUnlimitedStock) return true;
    
    final availableStock = getAvailableStock(itemData);
    return (currentCartQuantity + 1) <= availableStock;
  }
}