// lib/core/enums/user_enums.dart
enum OrderStatusType {
  placed,
  pickUp,
  pickedUp,
  expired,
}

enum StockStatusType {
  unlimited,
  inStock,
  lowStock,
  outOfStock,
  unavailable,
}

enum UserTabType {
  home,
  track,
  history,
  profile,
}

extension OrderStatusExtension on OrderStatusType {
  String get displayName {
    switch (this) {
      case OrderStatusType.placed:
        return 'Order Placed';
      case OrderStatusType.pickUp:
        return 'Ready for Pickup';
      case OrderStatusType.pickedUp:
        return 'Completed';
      case OrderStatusType.expired:
        return 'Expired';
    }
  }
  
  String get rawValue {
    switch (this) {
      case OrderStatusType.placed:
        return 'Placed';
      case OrderStatusType.pickUp:
        return 'Pick Up';
      case OrderStatusType.pickedUp:
        return 'PickedUp';
      case OrderStatusType.expired:
        return 'Expired';
    }
  }
}