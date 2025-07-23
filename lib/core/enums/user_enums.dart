// lib/core/enums/user_enums.dart
enum OrderStatusType {
  placed,
  cooking,
  cooked,
  pickUp,
  pickedUp,
  terminated,
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
      case OrderStatusType.cooking:
        return 'Being Prepared';
      case OrderStatusType.cooked:
        return 'Ready';
      case OrderStatusType.pickUp:
        return 'Ready for Pickup';
      case OrderStatusType.pickedUp:
        return 'Completed';
      case OrderStatusType.terminated:
        return 'Cancelled';
    }
  }
  
  String get rawValue {
    switch (this) {
      case OrderStatusType.placed:
        return 'Placed';
      case OrderStatusType.cooking:
        return 'Cooking';
      case OrderStatusType.cooked:
        return 'Cooked';
      case OrderStatusType.pickUp:
        return 'Pick Up';
      case OrderStatusType.pickedUp:
        return 'PickedUp';
      case OrderStatusType.terminated:
        return 'Terminated';
    }
  }
}