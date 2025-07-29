// lib/presentation/widgets/cart/cart_payment_handler.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:canteen_app/services/active_order_service.dart';
import 'package:canteen_app/services/reservation_service.dart';
import 'package:canteen_app/models/reservation_model.dart';
import 'package:canteen_app/presentation/widgets/cart/cart_dialogs.dart';

class CartPaymentHandler {
  final BuildContext context;
  final Map<String, dynamic> menuMap;
  final double total;
  late Razorpay _razorpay;
  
  String? currentRazorpayOrderId;
  Reservation? currentReservation;

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

  /// Start payment with reservation system
  Future<void> startPayment() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    if (cartProvider.isEmpty) {
      _showSnackBar("Your cart is empty", Colors.orange, Icons.shopping_cart_outlined);
      return;
    }

    try {
      // STEP 1: CHECK FOR ACTIVE ORDER
      print('🔍 Checking for active orders before payment...');
      final activeOrderResult = await ActiveOrderService.checkActiveOrder();
      
      if (activeOrderResult.hasActiveOrder) {
        print('❌ Active order found during payment: ${activeOrderResult.orderId}');
        CartDialogs.showActiveOrderBlockDialog(context, activeOrderResult);
        return;
      }
      
      print('✅ No active orders found, proceeding with payment...');

      // STEP 2: CREATE RAZORPAY ORDER
      currentRazorpayOrderId = await _createRazorpayOrder(total);
      
      if (currentRazorpayOrderId == null) {
        throw Exception('Failed to create payment order');
      }

      // STEP 3: CREATE RESERVATION (Dart service for UI feedback)
      print('🔄 Creating reservation for payment: $currentRazorpayOrderId');
      
      final reservationRequest = ReservationCreateRequest(
        paymentId: currentRazorpayOrderId!,
        cartItems: cartProvider.cart,
        menuMap: menuMap,
        totalAmount: total,
      );

      currentReservation = await ReservationService.createReservation(reservationRequest);
      
      if (currentReservation == null) {
        throw Exception('Failed to reserve items - they may no longer be available');
      }

      print('✅ Reservation created: ${currentReservation!.id}');
      print('📋 Reserved items: ${currentReservation!.items.map((e) => '${e.itemName} x${e.quantity}').join(', ')}');

      // STEP 4: START PAYMENT
      _startPaymentWithOrder();

    } catch (e) {
      // Clean up if anything fails
      if (currentReservation != null) {
        await ReservationService.failReservation(currentRazorpayOrderId!);
      }
      
      _showSnackBar("Error processing payment: $e", Colors.red, Icons.error_outline);
    }
  }

  /// Start payment with Razorpay order
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
      'description': 'Food Order Payment - Items Reserved',
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
        'reservation_id': currentReservation?.id ?? '',
        'auto_capture': 'enabled',
      }
    };

    try {
      print('🚀 Starting Razorpay payment with reservation: ${currentReservation?.id}');
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

      print('✅ Payment successful: ${response.paymentId}');

      // STEP 1: VERIFY PAYMENT (This will complete the reservation automatically)
      // ✅ FIXED: Use Firebase Function that handles reservation completion
      final callable = FirebaseFunctions.instance.httpsCallable('verifyRazorpayPayment');
      
      final verificationResult = await callable.call({
        'razorpay_payment_id': response.paymentId,
        'razorpay_order_id': currentRazorpayOrderId,
        'razorpay_signature': response.signature,
      });

      if (verificationResult.data['success'] != true) {
        throw Exception('Payment verification failed');
      }

      print('✅ Payment verified and reservation completed automatically by Firebase Function');

      // STEP 2: FINAL CHECK FOR ACTIVE ORDER
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
      
      // STEP 3: CREATE ORDER DOCUMENT
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

      final orderDocRef = await FirebaseFirestore.instance.collection('orders').add({
        'userId': user.uid,
        'userEmail': user.email,
        'items': orderItems,
        'status': 'Placed',
        'timestamp': Timestamp.now(),
        'total': total,
        'paymentId': response.paymentId,
        'razorpayOrderId': currentRazorpayOrderId,
        'reservationId': currentReservation?.id,
        'paymentStatus': 'success',
        'autoCaptureEnabled': true,
        'reservationCompleted': true, // ✅ ADDED: Mark reservation as completed
      });

      print('✅ Order created successfully: ${orderDocRef.id}');
      
      // STEP 4: CLEAR CART AND TRACKING
      cartProvider.clearCart();
      currentRazorpayOrderId = null;
      currentReservation = null;
      
      Navigator.pop(context);
      CartDialogs.showPaymentSuccessDialog(context, response, orderDocRef.id, total);

    } catch (e) {
      Navigator.pop(context);
      
      // ✅ FIXED: Let Firebase Function handle reservation failure via verifyRazorpayPayment
      // The enhanced verifyRazorpayPayment function will fail the reservation if verification fails
      
      _showSnackBar("Error processing order: ${e.toString()}", Colors.red, Icons.error_outline);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) async {
    print('❌ Payment failed: ${response.code} - ${response.message}');
    
    // ✅ FIXED: Use Dart service to fail reservation immediately (for quick user feedback)
    // The webhook will also handle this, but this provides immediate feedback
    if (currentReservation != null && currentRazorpayOrderId != null) {
      final reservationFailed = await ReservationService.failReservation(currentRazorpayOrderId!);
      
      if (reservationFailed) {
        print('✅ Reservation failed and items released');
      } else {
        print('⚠️ Warning: Failed to release reservation - items will auto-expire in 10 minutes');
      }
    }

    // Clean up tracking
    currentRazorpayOrderId = null;
    currentReservation = null;

    _showSnackBar("Payment failed! Items have been released. Please try again.", Colors.red, Icons.payment);
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