// lib/screens/user/cart_screen.dart - UPDATED WITH PLATFORM FEE
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:canteen_app/presentation/widgets/cart/cart_item_widget.dart';
import 'package:canteen_app/presentation/widgets/cart/cart_payment_handler.dart';
import 'package:canteen_app/presentation/widgets/cart/active_order_banner.dart';
import 'package:canteen_app/services/active_order_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with WidgetsBindingObserver {
  double subtotal = 0;
  double platformFee = 0;
  double total = 0;
  Map<String, dynamic> menuMap = {};
  Map<String, double> itemPrices = {};  // ✅ NEW: Store item prices
  bool isLoading = true;
  bool isProcessing = false;
  CartPaymentHandler? _paymentHandler;
  
  // Enhanced state management
  ActiveOrderResult? _activeOrder;
  bool _showActiveOrderBanner = true;
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  bool _isConnected = true;
  
  // Error state
  String? _errorMessage;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paymentHandler?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkActiveOrder();
      _checkConnectivity();
    }
  }

  /// Initialize screen with comprehensive error handling
  Future<void> _initializeScreen() async {
    try {
      setState(() {
        isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      // Check connectivity first
      await _checkConnectivity();
      
      if (!_isConnected) {
        setState(() {
          _hasError = true;
          _errorMessage = "No internet connection";
          isLoading = false;
        });
        return;
      }

      // Load data in parallel
      await Future.wait([
        _fetchMenuItems(),
        _checkActiveOrder(),
      ]);

      setState(() {
        isLoading = false;
      });

    } catch (e) {
      print('❌ Error initializing cart screen: $e');
      setState(() {
        isLoading = false;
        _hasError = true;
        _errorMessage = "Failed to load cart data";
      });
    }
  }

  /// Check network connectivity
  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      setState(() {
        _connectionStatus = connectivityResult;
        _isConnected = connectivityResult != ConnectivityResult.none;
      });
    } catch (e) {
      print('Error checking connectivity: $e');
      setState(() {
        _isConnected = true; // Assume connected if check fails
      });
    }
  }

  /// Fetch menu items with retry mechanism
  Future<void> _fetchMenuItems() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('menuItems')
            .get()
            .timeout(const Duration(seconds: 10));
        
        final newMenuMap = <String, dynamic>{};
        final newItemPrices = <String, double>{};
        
        for (var doc in snapshot.docs) {
          final data = doc.data();
          newMenuMap[doc.id] = data;
          
          // ✅ NEW: Store item prices separately for easy access
          final price = data['price'];
          if (price != null) {
            newItemPrices[doc.id] = price is double ? price : double.parse(price.toString());
          }
        }
        
        setState(() {
          menuMap = newMenuMap;
          itemPrices = newItemPrices;
        });
        
        recalcTotal();
        
        // Initialize payment handler after menu data is loaded
        _paymentHandler?.dispose();
        _paymentHandler = CartPaymentHandler(
          context: context,
          menuMap: menuMap,
          total: total,  // ✅ This now includes platform fee
        );
        
        return; // Success
        
      } catch (e) {
        retryCount++;
        print('❌ Error fetching menu items (attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          throw Exception('Failed to load menu data after $maxRetries attempts');
        }
        
        // Wait before retry
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }
  }

  /// Check for active orders
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
      // Don't show error for active order check failure
    }
  }

  /// ✅ UPDATED: Recalculate total with platform fee
  void recalcTotal() {
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      
      // Get cost breakdown including platform fee
      final breakdown = cartProvider.getCostBreakdown(itemPrices);
      
      setState(() {
        subtotal = breakdown['subtotal']!;
        platformFee = breakdown['platformFee']!;
        total = breakdown['total']!;
      });
      
      // Update payment handler total if needed
      if (_paymentHandler != null) {
        _paymentHandler = CartPaymentHandler(
          context: context,
          menuMap: menuMap,
          total: total,  // ✅ Pass total including platform fee
        );
      }
    } catch (e) {
      print('Error recalculating total: $e');
    }
  }

  /// Enhanced payment initiation
  Future<void> _startPayment() async {
    if (!_isConnected) {
      _showErrorSnackBar(
        "No Internet Connection",
        "Please check your network and try again",
        Icons.wifi_off,
      );
      return;
    }

    if (_paymentHandler == null) {
      _showErrorSnackBar(
        "Payment Handler Error",
        "Payment system not initialized. Please refresh and try again.",
        Icons.error,
      );
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      await _paymentHandler!.startPayment();
    } catch (e) {
      _showErrorSnackBar(
        "Payment Error",
        "Failed to start payment: ${e.toString()}",
        Icons.payment,
      );
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  /// Enhanced clear cart dialog
  void _showClearCartDialog() {
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
              child: const Icon(Icons.delete_outline, color: Colors.red),
            ),
            const SizedBox(width: 12),
            Text(
              "Clear Cart",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to remove all items from your cart?",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "CANCEL",
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final cartProvider = Provider.of<CartProvider>(context, listen: false);
              cartProvider.clearCart();
              _showSuccessSnackBar("Cart cleared", "All items removed from cart");
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              "CLEAR",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Retry initialization
  Future<void> _retryInitialization() async {
    await _initializeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        // Update total when cart changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (menuMap.isNotEmpty && itemPrices.isNotEmpty) {
            recalcTotal();
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

  /// Enhanced app bar with connectivity indicator
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
        // Connectivity indicator
        if (!_isConnected)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off, color: Colors.white, size: 20),
          ),
        
        // Clear cart button
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

  /// Enhanced body with error handling
  Widget _buildBody(CartProvider cartProvider) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    return Column(
      children: [
        _buildOrderSummaryHeader(cartProvider),
        
        // Connectivity warning
        if (!_isConnected)
          _buildConnectivityWarning(),
        
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
          _buildCartSummary(cartProvider),
      ],
    );
  }

  /// Enhanced loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFFFB703),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            "Loading your cart...",
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          if (!_isConnected) ...[
            const SizedBox(height: 8),
            Text(
              "Waiting for network connection",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.red[400],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Enhanced error state
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isConnected ? Icons.error_outline : Icons.wifi_off,
                size: 64,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isConnected ? "Failed to Load Cart" : "No Internet Connection",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? "Please check your connection and try again",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _retryInitialization,
              icon: const Icon(Icons.refresh),
              label: Text(
                "Try Again",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB703),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Connectivity warning banner
  Widget _buildConnectivityWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.red[50],
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.red[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "No internet connection - some features may not work",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: _checkConnectivity,
            child: Text(
              "Retry",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
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
                  const Icon(
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
          Text(
            "Add some delicious items to get started",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.restaurant_menu),
            label: Text(
              "Browse Menu",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB703),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
        
        if (item == null) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Item not available",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                      Text(
                        "This item is no longer available",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.red[600],
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => cartProvider.removeItemCompletely(itemId),
                  child: Text(
                    "Remove",
                    style: GoogleFonts.poppins(
                      color: Colors.red[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return CartItemWidget(
          itemId: itemId,
          quantity: quantity,
          item: item,
          cartProvider: cartProvider,
        );
      },
    );
  }

  Widget _buildCartSummary(CartProvider cartProvider) {
    return Container(
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
          _buildBillDetails(cartProvider),
          const SizedBox(height: 16),
          _buildOrderButton(),
        ],
      ),
    );
  }

  /// ✅ UPDATED: Build bill details with platform fee
  Widget _buildBillDetails(CartProvider cartProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "BILL DETAILS",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF023047),
          ),
        ),
        const SizedBox(height: 8),
        
        // Item Total (Subtotal)
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
              "₹${subtotal.toStringAsFixed(2)}",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
        // ✅ NEW: Platform Fee Row (only show if > 0)
        if (platformFee > 0) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    "Platform Fee",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: cartProvider.getFormattedPlatformFee(itemPrices),
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              Text(
                "₹${platformFee.toStringAsFixed(2)}",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
        
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
        
        // ✅ UPDATED: Grand Total (now includes platform fee)
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
        

      ],
    );
  }

  /// ✅ UPDATED: Order button with total including platform fee
  Widget _buildOrderButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,  // ✅ INCREASED HEIGHT to prevent text cropping
      child: ElevatedButton(
        onPressed: (isProcessing || !_isConnected) ? null : _startPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: (isProcessing || !_isConnected)
            ? Colors.grey[400] 
            : const Color(0xFFFFB703),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),  // ✅ ADDED EXPLICIT PADDING
        ),
        child: isProcessing
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
                  "Processing Payment...",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.2,  // ✅ ADDED LINE HEIGHT
                  ),
                ),
              ],
            )
          : !_isConnected
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off),
                  const SizedBox(width: 8),
                  Text(
                    "No Internet Connection",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.2,  // ✅ ADDED LINE HEIGHT
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.payment, size: 20),  // ✅ EXPLICIT ICON SIZE
                  const SizedBox(width: 8),
                  Text(
                    "Pay Now • ₹${total.toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.2,  // ✅ ADDED LINE HEIGHT to prevent cropping
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Enhanced snackbar methods
  void _showErrorSnackBar(String title, String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    message,
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    message,
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}