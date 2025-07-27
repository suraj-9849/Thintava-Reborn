// lib/presentation/widgets/cart/cart_payment_handler.dart - SIMPLIFIED (NO RESERVATION SYSTEM)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:canteen_app/services/active_order_service.dart';
import 'package:canteen_app/presentation/widgets/cart/cart_dialogs.dart';

class CartPaymentHandler {
  final BuildContext context;
  final Map<String, dynamic> menuMap;
  final double total;
  late Razorpay _razorpay;
  
  String? currentRazorpayOrderId;

  CartPaymentHandler({
    required this.context,
    required this.menuMap,
    required this.total,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  /// Create Razorpay Order using Firebase Cloud Function
  Future<String?> _createRazorpayOrder(double amount) async {
    try {
      print('🔄 Creating Razorpay order via Firebase Function for amount: ₹$amount');
      
      final callable = FirebaseFunctions.instance.httpsCallable('createRazorpayOrder');
      
      final result = await callable.call({
        'amount': (amount * 100).toInt(),
        'currency': 'INR',
        'receipt': 'order_${DateTime.now().millisecondsSinceEpoch}',
        'notes': {
          'app': 'Thintava',
          'order_type': 'food_order',
        }
      });

      print('🔍 Firebase Function response: ${result.data}');

      if (result.data != null && result.data['success'] == true) {
        // Handle both possible response structures
        String? orderId;
        if (result.data['orderId'] != null) {
          orderId = result.data['orderId'];
        } else if (result.data['order'] != null && result.data['order']['id'] != null) {
          orderId = result.data['order']['id'];
        }
        
        if (orderId != null) {
          print('✅ Firebase Function created Razorpay order: $orderId');
          return orderId;
        } else {
          throw Exception('Order ID not found in response: ${result.data}');
        }
      } else {
        throw Exception('Failed to create order: ${result.data}');
      }
    } catch (e) {
      print('❌ Error calling Firebase Function: $e');
      throw Exception('Failed to create payment order: $e');
    }
  }

  /// Start payment directly (WITH ACTIVE ORDER CHECK)
  Future<void> startPayment() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    if (cartProvider.isEmpty) {
      _showSnackBar("Your cart is empty", Colors.orange, Icons.shopping_cart_outlined);
      return;
    }

    try {
      // CHECK FOR ACTIVE ORDER BEFORE ALLOWING PAYMENT
      print('🔍 Checking for active orders before payment...');
      final activeOrderResult = await ActiveOrderService.checkActiveOrder();
      
      if (activeOrderResult.hasActiveOrder) {
        print('❌ Active order found during payment: ${activeOrderResult.orderId}');
        CartDialogs.showActiveOrderBlockDialog(context, activeOrderResult);
        return;
      }
      
      print('✅ No active orders found, proceeding with payment...');

      // Create Razorpay order for auto-capture
      currentRazorpayOrderId = await _createRazorpayOrder(total);
      
      if (currentRazorpayOrderId == null) {
        throw Exception('Failed to create payment order');
      }

      // Proceed to payment gateway
      _startPaymentWithOrder();

    } catch (e) {
      _showSnackBar("Error processing payment: $e", Colors.red, Icons.error_outline);
    }
  }

  /// Start payment with Razorpay order (for auto-capture)
  void _startPaymentWithOrder() {
    if (currentRazorpayOrderId == null) {
      _showSnackBar("Payment setup failed", Colors.red, Icons.error_outline);
      return;
    }

    var options = {
      'key': 'rzp_live_cDOinLBuxva4w0',
      'amount': (total * 100).toInt(),
      'currency': 'INR',
      'name': 'Thintava',
      'description': 'Food Order Payment - Auto Capture Enabled',
      'order_id': currentRazorpayOrderId,
      'prefill': {
        'contact': '',
        'email': FirebaseAuth.instance.currentUser?.email ?? '',
      },
      'theme': {
        'color': '#FFB703',
      },
      'notes': {
        'app': 'Thintava',
        'user_id': FirebaseAuth.instance.currentUser?.uid ?? '',
        'auto_capture': 'enabled',
      }
    };

    try {
      print('🚀 Starting Razorpay payment with order ID: $currentRazorpayOrderId');
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Error: $e");
      _showSnackBar("Payment error: ${e.toString()}", Colors.red, Icons.error_outline);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFFB703),
        ),
      ),
    );
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // FINAL CHECK: Ensure no active order exists before creating new one
      final finalCheck = await ActiveOrderService.checkActiveOrder();
      if (finalCheck.hasActiveOrder) {
        Navigator.pop(context); // Close loading dialog
        
        _showSnackBar(
          "Payment completed but another order is active. Please contact support for refund.",
          Colors.red,
          Icons.error_outline,
        );
        
        CartDialogs.showActiveOrderBlockDialog(context, finalCheck);
        return;
      }

      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      
      // Create order items list
      final List<Map<String, dynamic>> orderItems = [];
      cartProvider.cart.forEach((itemId, qty) {
        final itemData = menuMap[itemId];
        if (itemData != null) {
          orderItems.add({
            'id': itemId,
            'name': itemData['name'] ?? 'Unknown',
            'price': itemData['price'] ?? 0,
            'quantity': qty,
            'subtotal': (itemData['price'] ?? 0) * qty,
          });
        }
      });

      // Create order document
      final orderDocRef = await FirebaseFirestore.instance.collection('orders').add({
        'userId': user.uid,
        'userEmail': user.email,
        'items': orderItems,
        'status': 'Placed',
        'timestamp': Timestamp.now(),
        'total': total,
        'paymentId': response.paymentId,
        'razorpayOrderId': currentRazorpayOrderId,
        'paymentStatus': 'success',
        'autoCaptureEnabled': true,
      });

      print('✅ Order created successfully: ${orderDocRef.id}');

      // Update stock manually
      bool stockUpdateSuccess = await _manuallyUpdateStock(cartProvider.cart);
      
      if (!stockUpdateSuccess) {
        print('⚠️ Stock update had issues but order was created');
      }
      
      // Clear cart and tracking
      cartProvider.clearCart();
      currentRazorpayOrderId = null;
      
      Navigator.pop(context);
      CartDialogs.showPaymentSuccessDialog(context, response, orderDocRef.id, total);

    } catch (e) {
      Navigator.pop(context);
      _showSnackBar("Error processing order: ${e.toString()}", Colors.red, Icons.error_outline);
    }
  }

  Future<bool> _manuallyUpdateStock(Map<String, int> cartItems) async {
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      for (String itemId in cartItems.keys) {
        final orderedQuantity = cartItems[itemId] ?? 0;
        final docRef = FirebaseFirestore.instance.collection('menuItems').doc(itemId);
        
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
          }
        }
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      print('❌ Error updating stock: $e');
      return false;
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) async {
    currentRazorpayOrderId = null;

    print('❌ Payment failed: ${response.code} - ${response.message}');
    _showSnackBar("Payment failed! Please try again.", Colors.red, Icons.payment);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showSnackBar("External Wallet selected: ${response.walletName}", Color(0xFFFFB703), Icons.account_balance_wallet);
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}