// lib/screens/user/cart_screen.dart - FIXED WITH RAZORPAY ORDERS API FOR AUTO-CAPTURE
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:canteen_app/models/reservation_model.dart';
import 'package:canteen_app/services/reservation_service.dart';
import 'package:canteen_app/widgets/reservation_timer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:canteen_app/screens/user/user_home.dart';
import 'package:cloud_functions/cloud_functions.dart';


class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  double total = 0;
  Map<String, dynamic> menuMap = {};
  late Razorpay _razorpay;
  bool isLoading = true;
  bool isReserving = false;
  List<String>? currentReservationIds;
  String? currentRazorpayOrderId; // Store Razorpay order ID

  // Razorpay credentials - MOVE TO ENVIRONMENT VARIABLES IN PRODUCTION
   // Add your secret

  @override
  void initState() {
    super.initState();
    fetchItems();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> fetchItems() async {
    setState(() {
      isLoading = true;
    });
    
    final snapshot = await FirebaseFirestore.instance.collection('menuItems').get();
    
    setState(() {
      for (var doc in snapshot.docs) {
        menuMap[doc.id] = doc.data();
      }
      recalcTotal();
      isLoading = false;
    });
  }

  void recalcTotal() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    double newTotal = 0;
    cartProvider.cart.forEach((key, qty) {
      final price = menuMap[key]?['price'] ?? 0;
      newTotal += price * qty;
    });
    setState(() {
      total = newTotal;
    });
  }

  /// Create Razorpay Order using Orders API
  /// Create Razorpay Order using Firebase Cloud Function
Future<String?> _createRazorpayOrder(double amount) async {
  try {
    print('🔄 Creating Razorpay order via Firebase Function for amount: ₹$amount');
    
    // Call Firebase Cloud Function instead of direct API
    final callable = FirebaseFunctions.instance.httpsCallable('createRazorpayOrder');
    
    final result = await callable.call({
      'amount': (amount * 100).toInt(), // Amount in paise
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

  /// Reserve stock and proceed to payment - UPDATED WITH ORDERS API
  Future<void> _reserveAndProceedToPayment() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    if (cartProvider.isEmpty) {
      _showSnackBar("Your cart is empty", Colors.orange, Icons.shopping_cart_outlined);
      return;
    }

    setState(() {
      isReserving = true;
    });

    try {
      // Step 1: Check if cart can be reserved
      final reservabilityCheck = await cartProvider.checkCartReservability();
      
      if (!reservabilityCheck['canReserve']) {
        final error = reservabilityCheck['error'] ?? 'Cannot reserve items';
        final issues = reservabilityCheck['issues'] as Map<String, String>? ?? {};
        
        _showReservationErrorDialog(error, issues);
        return;
      }

      // Step 2: Show reservation confirmation
      final shouldProceed = await _showReservationConfirmDialog();
      if (!shouldProceed) return;

      // Step 3: Reserve the items
      final reservationResult = await cartProvider.reserveCartItems();
      
      if (!reservationResult.success) {
        final error = reservationResult.error ?? 'Failed to reserve items';
        final itemErrors = reservationResult.itemErrors ?? {};
        
        _showReservationErrorDialog(error, itemErrors);
        return;
      }

      // Step 4: Store reservation IDs
      currentReservationIds = reservationResult.reservations?.map((r) => r.id).toList();

      // Step 5: Create Razorpay order (for auto-capture)
      currentRazorpayOrderId = await _createRazorpayOrder(total);
      
      if (currentRazorpayOrderId == null) {
        throw Exception('Failed to create payment order');
      }

      // Step 6: Proceed to payment gateway with order ID
      _startPaymentWithOrder();

    } catch (e) {
      _showSnackBar("Error processing payment: $e", Colors.red, Icons.error_outline);
      
      // Release reservations on error
      if (currentReservationIds != null) {
        await cartProvider.releaseReservations(status: ReservationStatus.failed);
        currentReservationIds = null;
      }
    } finally {
      setState(() {
        isReserving = false;
      });
    }
  }

  Future<bool> _showReservationConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.schedule,
                color: Colors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Reserve Items?',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We\'ll reserve these items for you for 10 minutes while you complete payment.',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If payment isn\'t completed within 10 minutes, items will be released.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment will be automatically captured after successful authorization.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB703),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            icon: const Icon(Icons.schedule, size: 18),
            label: Text(
              'Reserve & Pay',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showReservationErrorDialog(String error, Map<String, String> itemErrors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cannot Reserve Items',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error,
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            if (itemErrors.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Item Issues:',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...itemErrors.entries.map((entry) {
                final itemName = menuMap[entry.key]?['name'] ?? entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$itemName: ${entry.value}',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB703),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Start payment with Razorpay order (for auto-capture)
  void _startPaymentWithOrder() {
    if (currentRazorpayOrderId == null) {
      _showSnackBar("Payment setup failed", Colors.red, Icons.error_outline);
      return;
    }

    var options = {
      'key': 'rzp_live_cDOinLBuxva4w0',
      'amount': (total * 100).toInt(), // Amount in paise
      'currency': 'INR',
      'name': 'Thintava',
      'description': 'Food Order Payment - Auto Capture Enabled',
      'order_id': currentRazorpayOrderId, // 🔑 THIS IS KEY FOR AUTO-CAPTURE
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

  /// Direct payment without reservation (for already reserved items)
  void _startPayment() {
    // For already reserved items, still create order for auto-capture
    _createRazorpayOrder(total).then((orderId) {
      if (orderId != null) {
        currentRazorpayOrderId = orderId;
        _startPaymentWithOrder();
      } else {
        _showSnackBar("Payment setup failed", Colors.red, Icons.error_outline);
      }
    }).catchError((error) {
      _showSnackBar("Payment setup failed: $error", Colors.red, Icons.error_outline);
    });
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Show loading indicator
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

      // Create order document with Razorpay order ID
      final orderDocRef = await FirebaseFirestore.instance.collection('orders').add({
        'userId': user.uid,
        'userEmail': user.email,
        'items': orderItems,
        'status': 'Placed',
        'timestamp': Timestamp.now(),
        'total': total,
        'paymentId': response.paymentId,
        'razorpayOrderId': currentRazorpayOrderId, // Store Razorpay order ID
        'paymentStatus': 'success',
        'autoCaptureEnabled': true, // Flag to indicate auto-capture was used
      });

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
      
      // Clear current reservation tracking
      currentReservationIds = null;
      currentRazorpayOrderId = null;
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Show success dialog
      _showPaymentSuccessDialog(response, orderDocRef.id);

    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);
      
      // Release reservations on error
      if (currentReservationIds != null) {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        await cartProvider.releaseReservations(status: ReservationStatus.failed);
        currentReservationIds = null;
      }
      
      _showSnackBar("Error processing order: ${e.toString()}", Colors.red, Icons.error_outline);
    }
  }

  // Fallback method to manually update stock
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
    // Release reservations on payment failure
    if (currentReservationIds != null) {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.releaseReservations(status: ReservationStatus.failed);
      currentReservationIds = null;
    }

    // Clear Razorpay order ID
    currentRazorpayOrderId = null;

    print('❌ Payment failed: ${response.code} - ${response.message}');
    _showSnackBar("Payment failed! Items have been released. Error: ${response.message}", Colors.red, Icons.payment);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showSnackBar("External Wallet selected: ${response.walletName}", Color(0xFFFFB703), Icons.account_balance_wallet);
  }

  void _showPaymentSuccessDialog(PaymentSuccessResponse response, String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle, 
                color: Colors.green, 
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Order Placed Successfully!",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB703).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFB703).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Your order has been placed successfully and payment will be automatically captured.",
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Order ID:",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        orderId.substring(0, 8),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFFB703),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Order Total:",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        "₹${total.toStringAsFixed(2)}",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFFB703),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Payment ID:",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          response.paymentId ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (currentRazorpayOrderId != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Razorpay Order:",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentRazorpayOrderId!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Payment will be automatically captured within 12 minutes of authorization.",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "You can track your order status and get updates on preparation time.",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close success dialog
              
              // Navigate to UserHome with Track tab selected
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserHome(initialIndex: 1), // Track tab
                ),
                (route) => false, // Remove all previous routes
              );
            },
            icon: const Icon(Icons.track_changes),
            label: Text(
              "TRACK ORDER",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB703),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    if (mounted) {
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
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        // Recalculate total when cart changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          recalcTotal();
        });

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            backgroundColor: const Color(0xFFFFB703),
            title: Text(
              "Your Cart",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            elevation: 0,
            actions: [
              if (!cartProvider.isEmpty)
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Text(
                          "Clear Cart",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                        ),
                        content: Text(
                          "Are you sure you want to clear your cart? Any active reservations will be released.",
                          style: GoogleFonts.poppins(),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("CANCEL", style: GoogleFonts.poppins()),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await cartProvider.releaseReservations();
                              cartProvider.clearCart();
                            },
                            child: Text("CLEAR", style: GoogleFonts.poppins()),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  label: Text(
                    "Clear",
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
            ],
          ),
          body: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFB703),
                  ),
                )
              : Column(
                  children: [
                    // Active Order Warning Banner
                    if (cartProvider.hasActiveOrder)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Active Order Detected",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    "Complete your current order before placing a new one.",
                                    style: GoogleFonts.poppins(
                                      color: Colors.orange.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/track',
                                  (route) => route.settings.name == '/user/user-home',
                                );
                              },
                              child: Text(
                                "Track",
                                style: GoogleFonts.poppins(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Order summary header
                    Container(
                      color: const Color(0xFFFFB703),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "ORDER SUMMARY",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "${cartProvider.itemCount} item${cartProvider.itemCount != 1 ? 's' : ''}",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                            ),
                          ),
                          if (cartProvider.hasActiveReservations) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Reserved",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Cart items list
                    Expanded(
                      child: cartProvider.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 80,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Your cart is empty",
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFB703),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: Text(
                                      "Browse Menu",
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: cartProvider.cart.length,
                              itemBuilder: (context, index) {
                                final itemId = cartProvider.cart.keys.elementAt(index);
                                final quantity = cartProvider.cart[itemId]!;
                                final item = menuMap[itemId];
                                if (item == null) return const SizedBox();
                                final price = item['price'] ?? 0;
                                final isVeg = item['isVeg'] ?? false;
                                final isReserved = cartProvider.isItemReserved(itemId);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isReserved 
                                      ? Border.all(color: Colors.blue, width: 2)
                                      : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      children: [
                                        // Reservation indicator
                                        if (isReserved)
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                            margin: const EdgeInsets.only(bottom: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.schedule, color: Colors.blue, size: 16),
                                                const SizedBox(width: 6),
                                                Text(
                                                  "Reserved for you",
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.blue,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (cartProvider.reservationState.earliestExpiry != null)
                                                  ReservationTimer(
                                                    expiryTime: cartProvider.reservationState.earliestExpiry!,
                                                    showBackground: false,
                                                    showIcon: false,
                                                    textStyle: GoogleFonts.poppins(fontSize: 10),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Food image
                                            Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: item['imageUrl'] != null
                                                      ? Image.network(
                                                          item['imageUrl'],
                                                          width: 80,
                                                          height: 80,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (_, __, ___) => Container(
                                                            width: 80,
                                                            height: 80,
                                                            color: Colors.grey[200],
                                                            child: Icon(
                                                              Icons.restaurant,
                                                              size: 40,
                                                              color: Colors.grey[400],
                                                            ),
                                                          ),
                                                        )
                                                      : Container(
                                                          width: 80,
                                                          height: 80,
                                                          color: Colors.grey[200],
                                                          child: Icon(
                                                            Icons.restaurant,
                                                            size: 40,
                                                            color: Colors.grey[400],
                                                          ),
                                                        ),
                                                ),
                                                // Veg/Non-veg indicator
                                                Positioned(
                                                  top: 0,
                                                  left: 0,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: isVeg ? Colors.green : Colors.red,
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(8),
                                                        bottomRight: Radius.circular(8),
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      Icons.circle,
                                                      size: 8,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 12),
                                            
                                            // Dish details
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item['name'] ?? 'Item',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF023047),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  if (item['description'] != null)
                                                    Text(
                                                      item['description'],
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        "₹${price.toStringAsFixed(2)} × $quantity",
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 14,
                                                          color: Colors.grey[700],
                                                        ),
                                                      ),
                                                      Text(
                                                        "₹${(price * quantity).toStringAsFixed(2)}",
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: const Color(0xFFFFB703),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  
                                                  // Quantity controls (disabled if reserved)
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Container(
                                                        decoration: BoxDecoration(
                                                          color: isReserved ? Colors.grey[200] : Colors.grey[100],
                                                          borderRadius: BorderRadius.circular(20),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            IconButton(
                                                              icon: Icon(
                                                                Icons.remove_circle_outline,
                                                                color: isReserved ? Colors.grey : const Color(0xFF023047),
                                                                size: 20,
                                                              ),
                                                              onPressed: isReserved ? null : () => cartProvider.removeItem(itemId),
                                                              constraints: const BoxConstraints(
                                                                minWidth: 32,
                                                                minHeight: 32,
                                                              ),
                                                              padding: EdgeInsets.zero,
                                                            ),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: isReserved ? Colors.grey : const Color(0xFFFFB703),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: Text(
                                                                quantity.toString(),
                                                                style: GoogleFonts.poppins(
                                                                  color: Colors.white,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ),
                                                            IconButton(
                                                              icon: Icon(
                                                                Icons.add_circle_outline,
                                                                color: isReserved ? Colors.grey : const Color(0xFF023047),
                                                                size: 20,
                                                              ),
                                                              onPressed: isReserved ? null : () => cartProvider.addItem(itemId),
                                                              constraints: const BoxConstraints(
                                                                minWidth: 32,
                                                                minHeight: 32,
                                                              ),
                                                              padding: EdgeInsets.zero,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: Icon(
                                                          Icons.delete_outline,
                                                          color: isReserved ? Colors.grey : Colors.red,
                                                          size: 20,
                                                        ),
                                                        onPressed: isReserved ? null : () => cartProvider.removeItemCompletely(itemId),
                                                        constraints: const BoxConstraints(
                                                          minWidth: 32,
                                                          minHeight: 32,
                                                        ),
                                                        padding: EdgeInsets.zero,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    
                    // Order Summary
                    if (!cartProvider.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bill details
                            Text(
                              "BILL DETAILS",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF023047),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Item Total",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  "₹${total.toStringAsFixed(2)}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "GST",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  "Included",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Divider(),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Grand Total",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF023047),
                                  ),
                                ),
                                Text(
                                  "₹${total.toStringAsFixed(2)}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFFB703),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Auto-capture info banner
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.auto_awesome, color: Colors.green, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Auto-capture enabled - Payment will be captured automatically after authorization",
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Place order button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: (cartProvider.hasActiveOrder || isReserving) 
                                  ? null 
                                  : (cartProvider.hasActiveReservations 
                                      ? _startPayment  // If already reserved, go directly to payment
                                      : _reserveAndProceedToPayment), // If not reserved, reserve first
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (cartProvider.hasActiveOrder || isReserving)
                                    ? Colors.grey[400] 
                                    : const Color(0xFFFFB703),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: isReserving
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "Reserving Items...",
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          cartProvider.hasActiveOrder 
                                            ? Icons.block 
                                            : (cartProvider.hasActiveReservations 
                                                ? Icons.payment 
                                                : Icons.schedule),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          cartProvider.hasActiveOrder
                                            ? "Complete Active Order First"
                                            : (cartProvider.hasActiveReservations
                                                ? "Pay Now • ₹${total.toStringAsFixed(2)}"
                                                : "Reserve & Pay • ₹${total.toStringAsFixed(2)}"),
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                              ),
                            ),
                            
                            // Info text
                            if (!cartProvider.hasActiveOrder) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  cartProvider.hasActiveReservations 
                                    ? "Items are reserved for you. Complete payment to confirm order."
                                    : "Items will be reserved while you complete payment",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}