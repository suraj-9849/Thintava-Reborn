// lib/presentation/widgets/menu/menu_item_card.dart - FIXED STOCK FLICKERING ISSUE
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/enums/user_enums.dart';
import '../../../core/utils/user_utils.dart';
import '../../../providers/cart_provider.dart';
import '../common/stock_indicator.dart';
import 'cart_controls.dart';

// Enhanced stock state to prevent flickering
class StockState {
  final StockStatusType status;
  final int availableStock;
  final bool isLoading;
  final bool hasUnlimitedStock;

  StockState({
    required this.status,
    required this.availableStock,
    this.isLoading = false,
    this.hasUnlimitedStock = false,
  });

  StockState copyWith({
    StockStatusType? status,
    int? availableStock,
    bool? isLoading,
    bool? hasUnlimitedStock,
  }) {
    return StockState(
      status: status ?? this.status,
      availableStock: availableStock ?? this.availableStock,
      isLoading: isLoading ?? this.isLoading,
      hasUnlimitedStock: hasUnlimitedStock ?? this.hasUnlimitedStock,
    );
  }
}

class MenuItemCard extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  final int index;
  final bool hasActiveOrder;
  final VoidCallback? onStockError;
  
  const MenuItemCard({
    Key? key,
    required this.id,
    required this.data,
    required this.index,
    this.hasActiveOrder = false,
    this.onStockError,
  }) : super(key: key);

  @override
  State<MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<MenuItemCard> {
  late StockState _stockState;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeStockState();
  }

  void _initializeStockState() {
    final hasUnlimitedStock = widget.data['hasUnlimitedStock'] ?? false;
    final available = widget.data['available'] ?? true;
    
    if (!available) {
      _stockState = StockState(
        status: StockStatusType.unavailable,
        availableStock: 0,
        hasUnlimitedStock: false,
      );
      _isInitialized = true;
      return;
    }

    if (hasUnlimitedStock) {
      _stockState = StockState(
        status: StockStatusType.unlimited,
        availableStock: 999999,
        hasUnlimitedStock: true,
      );
      _isInitialized = true;
      return;
    }

    // For limited stock items, start with loading state to prevent flickering
    _stockState = StockState(
      status: StockStatusType.inStock, // Start with reasonable default
      availableStock: UserUtils.getAvailableStockSync(widget.data),
      isLoading: true,
      hasUnlimitedStock: false,
    );

    // Load actual stock asynchronously
    _loadActualStock();
  }

  Future<void> _loadActualStock() async {
    try {
      final stockInfo = await UserUtils.getStockInfo(widget.id);
      final actualStock = stockInfo['actual'] ?? 0;
      final availableStock = stockInfo['available'] ?? 0;
      final hasUnlimitedStock = widget.data['hasUnlimitedStock'] ?? false;

      if (!mounted) return;

      StockStatusType status;
      if (hasUnlimitedStock) {
        status = StockStatusType.unlimited;
      } else if (availableStock <= 0) {
        status = StockStatusType.outOfStock;
      } else if (availableStock <= 5) {
        status = StockStatusType.lowStock;
      } else {
        status = StockStatusType.inStock;
      }

      setState(() {
        _stockState = StockState(
          status: status,
          availableStock: availableStock,
          isLoading: false,
          hasUnlimitedStock: hasUnlimitedStock,
        );
        _isInitialized = true;
      });
    } catch (e) {
      print('Error loading stock for ${widget.id}: $e');
      if (!mounted) return;
      
      // Fallback to sync calculation
      final syncStock = UserUtils.getAvailableStockSync(widget.data);
      final syncStatus = UserUtils.getStockStatusSync(widget.data);
      
      setState(() {
        _stockState = StockState(
          status: syncStatus,
          availableStock: syncStock,
          isLoading: false,
          hasUnlimitedStock: widget.data['hasUnlimitedStock'] ?? false,
        );
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.data['name'] ?? 'Unknown Item';
    final price = (widget.data['price'] ?? 0.0) is double 
      ? (widget.data['price'] ?? 0.0) 
      : double.parse((widget.data['price'] ?? '0').toString());
    final description = widget.data['description'] ?? '';
    final imageUrl = widget.data['imageUrl'] as String?;
    final isVeg = widget.data['isVeg'] ?? false;
    final available = widget.data['available'] ?? true;
    
    final isOutOfStock = !available || 
        (!_stockState.hasUnlimitedStock && _stockState.availableStock <= 0);

    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final cartQuantity = cartProvider.getQuantity(widget.id);
        
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (widget.index * 100)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: isOutOfStock
                      ? Border.all(color: Colors.red.withOpacity(0.3), width: 1)
                      : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFoodImage(imageUrl, isVeg, isOutOfStock),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildFoodDetails(
                                name, price, description, 
                                available, cartProvider, cartQuantity, context
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOutOfStock && !_stockState.hasUnlimitedStock) 
                        _buildOutOfStockOverlay(),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFoodImage(String? imageUrl, bool isVeg, bool isOutOfStock) {
    return Stack(
      children: [
        Container(
          width: 85,
          height: 85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageUrl != null && imageUrl.isNotEmpty
              ? ColorFiltered(
                  colorFilter: isOutOfStock
                    ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                    : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                  ),
                )
              : _buildImagePlaceholder(),
          ),
        ),
        // Veg/Non-veg indicator
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 3,
                ),
              ],
            ),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isVeg ? Colors.green : Colors.red,
                shape: isVeg ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isVeg ? BorderRadius.circular(2) : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 40,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildFoodDetails(String name, double price, String description, 
      bool available, CartProvider cartProvider, int cartQuantity, BuildContext context) {
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name
        Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: available ? Colors.black87 : Colors.grey[600],
            decoration: available ? null : TextDecoration.lineThrough,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 4),
        
        // ✅ FIXED: Use stable stock indicator that doesn't flicker
        _buildStableStockIndicator(),
        
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: available ? Colors.grey[600] : Colors.grey[500],
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        
        const SizedBox(height: 12),
        
        // Price
        Text(
          "₹${price.toStringAsFixed(2)}",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: available ? const Color(0xFFFFB703) : Colors.grey[500],
            decoration: available ? null : TextDecoration.lineThrough,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // ✅ FIXED: Use stable cart controls that don't flicker
        _buildStableCartControls(cartProvider, cartQuantity, context),
      ],
    );
  }

  // ✅ FIXED: Stable stock indicator without flickering
  Widget _buildStableStockIndicator() {
    return StockIndicator(
      status: _stockState.status,
      availableStock: _stockState.availableStock,
      isCompact: true,
      isLoading: _stockState.isLoading && !_isInitialized,
    );
  }

  // ✅ FIXED: Stable cart controls without flickering
  Widget _buildStableCartControls(CartProvider cartProvider, int cartQuantity, BuildContext context) {
    final available = widget.data['available'] ?? true;
    
    if (!available) {
      return _buildUnavailableButton('Currently Unavailable');
    }

    if (_stockState.hasUnlimitedStock) {
      return CartControls(
        itemId: widget.id,
        cartQuantity: cartQuantity,
        canAdd: true,
        onStockError: () => _showStockError(context),
      );
    }

    if (_stockState.availableStock <= 0) {
      return _buildUnavailableButton('Out of Stock');
    }

    // Check if can add more to cart based on current available stock
    final canAdd = (cartQuantity + 1) <= _stockState.availableStock;

    return CartControls(
      itemId: widget.id,
      cartQuantity: cartQuantity,
      canAdd: canAdd,
      onStockError: () => _showStockError(context, _stockState.availableStock),
    );
  }

  Widget _buildUnavailableButton(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            message.contains('Unavailable') ? Icons.block_rounded : Icons.hourglass_empty_rounded,
            color: Colors.grey[600],
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutOfStockOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'OUT OF STOCK',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showStockError(BuildContext context, [int? availableStock]) {
    final stock = availableStock ?? _stockState.availableStock;
    
    String message;
    if (stock <= 0) {
      message = '${widget.data['name']} is out of stock';
    } else {
      message = 'Only $stock ${widget.data['name']} available';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}