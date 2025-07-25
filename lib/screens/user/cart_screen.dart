// lib/screens/user/cart_screen.dart - UPDATED WITH ACTIVE ORDER CHECK
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:canteen_app/presentation/widgets/cart/cart_item_widget.dart';
import 'package:canteen_app/presentation/widgets/cart/cart_summary_widget.dart';
import 'package:canteen_app/presentation/widgets/cart/cart_payment_handler.dart';
import 'package:canteen_app/presentation/widgets/cart/active_order_banner.dart';
import 'package:canteen_app/services/active_order_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  double total = 0;
  Map<String, dynamic> menuMap = {};
  bool isLoading = true;
  bool isReserving = false;
  CartPaymentHandler? _paymentHandler;
  
  // Active order state
  ActiveOrderResult? _activeOrder;
  bool _showActiveOrderBanner = true;

  @override
  void initState() {
    super.initState();
    fetchItems();
    _checkActiveOrder();
  }

  @override
  void dispose() {
    _paymentHandler?.dispose();
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

    // Initialize payment handler after menu data is loaded
    _paymentHandler = CartPaymentHandler(
      context: context,
      menuMap: menuMap,
      total: total,
    );
  }

  Future<void> _checkActiveOrder() async {
    try {
      final activeOrderResult = await ActiveOrderService.checkActiveOrder();
      if (mounted) {
        setState(() {
          _activeOrder = activeOrderResult.hasActiveOrder ? activeOrderResult : null;
        });
      }
    } catch (e) {
      print('Error checking active order: $e');
    }
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

  Future<void> _reserveAndProceedToPayment() async {
    setState(() {
      isReserving = true;
    });

    try {
      await _paymentHandler?.reserveAndProceedToPayment();
    } finally {
      if (mounted) {
        setState(() {
          isReserving = false;
        });
      }
    }
  }

  void _startPayment() async {
    await _paymentHandler?.startPayment();
  }

  void _showClearCartDialog() {
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
              final cartProvider = Provider.of<CartProvider>(context, listen: false);
              await cartProvider.releaseReservations();
              cartProvider.clearCart();
            },
            child: Text("CLEAR", style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          recalcTotal();
          // Update payment handler total if needed
          if (_paymentHandler != null) {
            _paymentHandler = CartPaymentHandler(
              context: context,
              menuMap: menuMap,
              total: total,
            );
          }
        });

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: _buildAppBar(cartProvider),
          body: _buildBody(cartProvider),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(CartProvider cartProvider) {
    return AppBar(
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
            onPressed: _showClearCartDialog,
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            label: Text(
              "Clear",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildBody(CartProvider cartProvider) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFFB703),
        ),
      );
    }

    return Column(
      children: [
        _buildOrderSummaryHeader(cartProvider),
        
        // Active Order Banner
        if (_activeOrder != null && _showActiveOrderBanner)
          ActiveOrderBanner(
            activeOrder: _activeOrder!,
            onDismiss: () {
              setState(() {
                _showActiveOrderBanner = false;
              });
            },
          ),
        
        _buildCartContent(cartProvider),
        
        if (!cartProvider.isEmpty)
          CartSummaryWidget(
            total: total,
            isReserving: isReserving,
            hasActiveReservations: cartProvider.hasActiveReservations,
            onReserveAndPay: _reserveAndProceedToPayment,
            onPayNow: _startPayment,
          ),
      ],
    );
  }

  Widget _buildOrderSummaryHeader(CartProvider cartProvider) {
    return Container(
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
          if (_activeOrder != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Active Order",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartContent(CartProvider cartProvider) {
    return Expanded(
      child: cartProvider.isEmpty
          ? _buildEmptyCart()
          : _buildCartList(cartProvider),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
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
    );
  }

  Widget _buildCartList(CartProvider cartProvider) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: cartProvider.cart.length,
      itemBuilder: (context, index) {
        final itemId = cartProvider.cart.keys.elementAt(index);
        final quantity = cartProvider.cart[itemId]!;
        final item = menuMap[itemId];
        
        if (item == null) return const SizedBox();
        
        final isReserved = cartProvider.isItemReserved(itemId);

        return CartItemWidget(
          itemId: itemId,
          quantity: quantity,
          item: item,
          isReserved: isReserved,
          cartProvider: cartProvider,
        );
      },
    );
  }
}