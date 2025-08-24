// lib/utils/platform_fee_calculator.dart
class PlatformFeeCalculator {
  // Platform fee: ₹1 for ₹0-₹50, ₹2 for ₹51-₹100, etc.
  static const double _feePerSlot = 1.0;
  static const double _slotValue = 50.0;
  
  /// Calculate platform fee based on cart total
  /// Formula: ceil(cartTotal / 50) * 1
  /// Examples: ₹1-₹50 → ₹1, ₹51-₹100 → ₹2, ₹101-₹150 → ₹3
  static double calculatePlatformFee(double cartTotal) {
    if (cartTotal <= 0) return 0.0;
    
    // Calculate number of ₹50 slots using ceiling (round up) and multiply by ₹1
    final slots = (cartTotal / _slotValue).ceil();
    return slots * _feePerSlot;
  }
  
  /// Calculate total amount including platform fee
  static double calculateTotalWithFee(double cartTotal) {
    return cartTotal + calculatePlatformFee(cartTotal);
  }
  
  /// Get breakdown of costs
  static Map<String, double> getCostBreakdown(double cartTotal) {
    final platformFee = calculatePlatformFee(cartTotal);
    final totalWithFee = cartTotal + platformFee;
    
    return {
      'subtotal': cartTotal,
      'platformFee': platformFee,
      'total': totalWithFee,
    };
  }
  
  /// Format platform fee for display
  static String formatPlatformFee(double cartTotal) {
    final fee = calculatePlatformFee(cartTotal);
    if (fee == 0) return "₹0.00";
    
    final slots = (cartTotal / _slotValue).ceil();
    final rangeStart = ((slots - 1) * _slotValue + 1).toInt();
    final rangeEnd = (slots * _slotValue).toInt();
    
    return "₹${fee.toStringAsFixed(2)} (₹$rangeStart-₹$rangeEnd range)";
  }
  
  /// Check if platform fee applies
  static bool hasPlatformFee(double cartTotal) {
    return calculatePlatformFee(cartTotal) > 0;
  }
}