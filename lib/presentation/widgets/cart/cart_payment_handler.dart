// lib/presentation/widgets/cart/cart_payment_handler.dart - UPDATED WITH ACTIVE ORDER CHECK
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:canteen_app/models/reservation_model.dart';
import 'package:canteen_app/services/reservation_service.dart';
import 'package:canteen_app/services/active_order_service.dart';
import 'package:canteen_app/presentation/widgets/cart/cart_dialogs.dart';

class CartPaymentHandler {
  final BuildContext context;
  final Map<String, dynamic> menuMap;
  final double total;
  late Razorpay _razorpay;
  
  List<String>? currentReservationIds;
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

      if (result.data['success'] == true) {
        final orderId = result.data['order']['id'];
        print('✅ Firebase Function created Razorpay order: $orderId');
        return orderId;
      } else {
        throw Exception('Failed to create order: ${result.data}');
      }
    } catch (e) {
      print('❌ Error calling Firebase Function: $e');
      throw Exception('Failed to create payment order: $e');
    }
  }

  /// Reserve stock and proceed to payment (WITH ACTIVE ORDER CHECK)
  Future<void> reserveAndProceedToPayment() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    if (cartProvider.isEmpty) {
      _showSnackBar("Your cart is empty", Colors.orange, Icons.shopping_cart_outlined);
      return;
    }

    try {
      // STEP 1: CHECK FOR ACTIVE ORDER FIRST
      print('🔍 Checking for active orders before proceeding...');
      final activeOrderResult = await ActiveOrderService.checkActiveOrder();
      
      if (activeOrderResult.hasActiveOrder) {
        print('❌ Active order found: ${activeOrderResult.orderId} - Status: ${activeOrderResult.status}');
        CartDialogs.showActiveOrderBlockDialog(context, activeOrderResult);
        return;
      }
      
      print('✅ No active orders found, proceeding with reservation...');

      // STEP 2: Check if cart can be reserved
      final reservabilityCheck = await cartProvider.checkCartReservability();
      
      if (!reservabilityCheck['canReserve']) {
        final error = reservabilityCheck['error'] ?? 'Cannot reserve items';
        final issues = reservabilityCheck['issues'] as Map<String, String>? ?? {};
        
        CartDialogs.showReservationErrorDialog(context, error, issues, menuMap);
        return;
      }

      // STEP 3: Show reservation confirmation
      final shouldProceed = await CartDialogs.showReservationConfirmDialog(context);
      if (!shouldProceed) return;

      // STEP 4: Double-check for active order before reserving (race condition protection)
      final finalActiveOrderCheck = await ActiveOrderService.checkActiveOrder();
      if (finalActiveOrderCheck.hasActiveOrder) {
        print('❌ Active order found during final check: ${finalActiveOrderCheck.orderId}');
        CartDialogs.showActiveOrderBlockDialog(context, finalActiveOrderCheck);
        return;
      }

      // STEP 5: Reserve the items
      final reservationResult = await cartProvider.reserveCartItems();
      
      if (!reservationResult.success) {
        final error = reservationResult.error ?? 'Failed to reserve items';
        final itemErrors = reservationResult.itemErrors ?? {};
        
        CartDialogs.showReservationErrorDialog(context, error, itemErrors, menuMap);
        return;
      }

      // STEP 6: Store reservation IDs
      currentReservationIds = reservationResult.reservations?.map((r) => r.id).toList();

      // STEP 7: Create Razorpay order for auto-capture
      currentRazorpayOrderId = await _createRazorpayOrder(total);
      
      if (currentRazorpayOrderId == null) {
        throw Exception('Failed to create payment order');
      }

      // STEP 8: Proceed to payment gateway
      _startPaymentWithOrder();

    } catch (e) {
      _showSnackBar("Error processing payment: $e", Colors.red, Icons.error_outline);
      
      // Release reservations on error
      if (currentReservationIds != null) {
        await cartProvider.releaseReservations(status: ReservationStatus.failed);
        currentReservationIds = null;
      }
    }
  }

  /// Direct payment without reservation (for already reserved items) - WITH ACTIVE ORDER CHECK
  Future<void> startPayment() async {
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

      final orderId = await _createRazorpayOrder(total);
      if (orderId != null) {
        currentRazorpayOrderId = orderId;
        _startPaymentWithOrder();
      } else {
        _showSnackBar("Payment setup failed", Colors.red, Icons.error_outline);
      }
    } catch (error) {
      _showSnackBar("Payment setup failed: $error", Colors.red, Icons.error_outline);
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
        
        // Release reservations and refund if possible
        if (currentReservationIds != null) {
          final cartProvider = Provider.of<CartProvider>(context, listen: false);
          await cartProvider.releaseReservations(status: ReservationStatus.failed);
          currentReservationIds = null;
        }
        
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

      // Confirm reservations
      bool confirmSuccess = false;
      
      if (currentReservationIds != null && currentReservationIds!.isNotEmpty) {
        confirmSuccess = await ReservationService.confirmReservations(currentReservationIds!, orderDocRef.id);
      } 
      else if (cartProvider.hasActiveReservations) {
        final reservationIds = cartProvider.activeReservations.map((r) => r.id).toList();
        confirmSuccess = await ReservationService.confirmReservations(reservationIds, orderDocRef.id);
      }
      else {
        confirmSuccess = await _manuallyUpdateStock(cartProvider.cart);
      }
      
      if (!confirmSuccess) {
        await _manuallyUpdateStock(cartProvider.cart);
      }
      
      // Clear tracking
      currentReservationIds = null;
      currentRazorpayOrderId = null;
      
      Navigator.pop(context);
      CartDialogs.showPaymentSuccessDialog(context, response, orderDocRef.id, total);

    } catch (e) {
      Navigator.pop(context);
      
      if (currentReservationIds != null) {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        await cartProvider.releaseReservations(status: ReservationStatus.failed);
        currentReservationIds = null;
      }
      
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
      return false;
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) async {
    if (currentReservationIds != null) {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.releaseReservations(status: ReservationStatus.failed);
      currentReservationIds = null;
    }

    currentRazorpayOrderId = null;

    print('❌ Payment failed: ${response.code} - ${response.message}');
    // _showSnackBar("Payment failed! Items have been released. Error: ${response.message}", Colors.red, Icons.payment);
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