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
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFoodImage(imageUrl, isVeg, isOutOfStock),
                            const SizedBox(width: 12),
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
          width: 95,
          height: 95,
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
        
        // Price and Cart Controls Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "₹${price.toStringAsFixed(2)}",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: available ? const Color(0xFFFFB703) : Colors.grey[500],
                decoration: available ? null : TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(width: 8),
            _buildCompactCartControls(cartProvider, cartQuantity, context),
          ],
        ),
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

  // ✅ FIXED: Compact cart controls for right side positioning
  Widget _buildCompactCartControls(CartProvider cartProvider, int cartQuantity, BuildContext context) {
    final available = widget.data['available'] ?? true;
    
    if (!available) {
      return _buildCompactUnavailableButton('Unavailable');
    }

    if (_stockState.availableStock <= 0 && !_stockState.hasUnlimitedStock) {
      return _buildCompactUnavailableButton('Out of Stock');
    }

    // Check if can add more to cart based on current available stock
    final canAdd = _stockState.hasUnlimitedStock || (cartQuantity + 1) <= _stockState.availableStock;

    return _CompactCartControls(
      itemId: widget.id,
      cartQuantity: cartQuantity,
      canAdd: canAdd,
      onStockError: () => _showStockError(context, _stockState.availableStock),
    );
  }

  Widget _buildCompactUnavailableButton(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: Colors.grey[600],
          fontWeight: FontWeight.w600,
        ),
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

// Compact Cart Controls Widget
class _CompactCartControls extends StatefulWidget {
  final String itemId;
  final int cartQuantity;
  final bool canAdd;
  final VoidCallback? onStockError;
  
  const _CompactCartControls({
    required this.itemId,
    required this.cartQuantity,
    required this.canAdd,
    this.onStockError,
  });

  @override
  State<_CompactCartControls> createState() => _CompactCartControlsState();
}

class _CompactCartControlsState extends State<_CompactCartControls> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        if (widget.cartQuantity > 0) {
          return _buildQuantityControls(cartProvider);
        } else {
          return _buildAddButton(cartProvider);
        }
      },
    );
  }

  Widget _buildQuantityControls(CartProvider cartProvider) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFB703).withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFFFB703).withOpacity(0.3)
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCartButton(
            icon: Icons.remove_rounded,
            onTap: _isLoading ? null : () => _handleRemove(cartProvider),
            color: const Color(0xFFFFB703),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB703),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _isLoading 
              ? SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.cartQuantity.toString(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
          ),
          _buildCartButton(
            icon: Icons.add_rounded,
            onTap: (_isLoading || !widget.canAdd) ? null : () => _handleAdd(cartProvider),
            color: (!widget.canAdd || _isLoading) ? Colors.grey : const Color(0xFFFFB703),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(CartProvider cartProvider) {
    return GestureDetector(
      onTap: (_isLoading || !widget.canAdd) ? null : () => _handleAdd(cartProvider),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: widget.canAdd ? const Color(0xFFFFB703) : Colors.grey[400],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _isLoading 
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  Icons.add_shopping_cart_rounded, 
                  size: 16, 
                  color: Colors.white
                ),
            const SizedBox(width: 4),
            Text(
              _isLoading ? "Adding..." : "Add",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartButton({
    required IconData icon, 
    required VoidCallback? onTap, 
    required Color color
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: color,
          size: 18,
        ),
      ),
    );
  }

  Future<void> _handleAdd(CartProvider cartProvider) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await cartProvider.addItem(widget.itemId);
      
      if (!success && widget.onStockError != null) {
        widget.onStockError!();
      }
    } catch (e) {
      print('Error adding item to cart: $e');
      if (widget.onStockError != null) {
        widget.onStockError!();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRemove(CartProvider cartProvider) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      cartProvider.removeItem(widget.itemId);
    } catch (e) {
      print('Error removing item from cart: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}