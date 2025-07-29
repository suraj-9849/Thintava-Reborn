// lib/presentation/widgets/menu/menu_item_card.dart - FIXED WITH RESERVATION SYSTEM
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/enums/user_enums.dart';
import '../../../core/utils/user_utils.dart';
import '../../../providers/cart_provider.dart';
import '../common/stock_indicator.dart';
import 'cart_controls.dart';

class MenuItemCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final name = data['name'] ?? 'Unknown Item';
    final price = (data['price'] ?? 0.0) is double 
      ? (data['price'] ?? 0.0) 
      : double.parse((data['price'] ?? '0').toString());
    final description = data['description'] ?? '';
    final imageUrl = data['imageUrl'] as String?;
    final isVeg = data['isVeg'] ?? false;
    final available = data['available'] ?? true;
    
    // ✅ FIXED: Use sync versions for immediate display, async versions for real data
    final actualStock = UserUtils.getAvailableStockSync(data);
    final stockStatusSync = UserUtils.getStockStatusSync(data);
    final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
    
    // For immediate display - will be updated by FutureBuilder
    final isOutOfStock = !available || (!hasUnlimitedStock && actualStock <= 0);

    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final cartQuantity = cartProvider.getQuantity(id);
        
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 100)),
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
                                available, cartProvider, cartQuantity,
                                hasUnlimitedStock, context
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOutOfStock && !hasUnlimitedStock) _buildOutOfStockOverlay(),
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
      bool available, CartProvider cartProvider, int cartQuantity, 
      bool hasUnlimitedStock, BuildContext context) {
    
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
        
        // ✅ FIXED: Real-time stock status with FutureBuilder
        _buildAsyncStockIndicator(),
        
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
        
        // ✅ FIXED: Real-time cart controls with FutureBuilder
        _buildAsyncCartControls(cartProvider, cartQuantity, context),
      ],
    );
  }

  // ✅ NEW: Real-time stock indicator with reservation awareness
  Widget _buildAsyncStockIndicator() {
    return FutureBuilder<StockStatusType>(
      future: UserUtils.getStockStatus(data, id),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return FutureBuilder<int>(
            future: UserUtils.getAvailableStock(data, id),
            builder: (context, stockSnapshot) {
              final availableStock = stockSnapshot.data ?? 0;
              return StockIndicator(
                status: snapshot.data!,
                availableStock: availableStock,
                isCompact: true,
              );
            },
          );
        } else {
          // Show sync version while loading
          return StockIndicator(
            status: UserUtils.getStockStatusSync(data),
            availableStock: UserUtils.getAvailableStockSync(data),
            isCompact: true,
          );
        }
      },
    );
  }

  // ✅ NEW: Real-time cart controls with reservation awareness
  Widget _buildAsyncCartControls(CartProvider cartProvider, int cartQuantity, BuildContext context) {
    final available = data['available'] ?? true;
    final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
    
    if (!available) {
      return _buildUnavailableButton('Currently Unavailable');
    }

    return FutureBuilder<bool>(
      future: UserUtils.canAddToCart(data, id, cartQuantity),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final canAdd = snapshot.data!;
          
          if (hasUnlimitedStock || canAdd) {
            return CartControls(
              itemId: id,
              cartQuantity: cartQuantity,
              canAdd: canAdd,
              onStockError: () => _showStockError(context),
            );
          } else {
            return FutureBuilder<int>(
              future: UserUtils.getAvailableStock(data, id),
              builder: (context, stockSnapshot) {
                final availableStock = stockSnapshot.data ?? 0;
                if (availableStock <= 0) {
                  return _buildUnavailableButton('Out of Stock');
                } else {
                  return CartControls(
                    itemId: id,
                    cartQuantity: cartQuantity,
                    canAdd: false,
                    onStockError: () => _showStockError(context, availableStock),
                  );
                }
              },
            );
          }
        } else {
          // Show loading or sync version
          final canAddSync = UserUtils.canAddToCartSync(data, cartQuantity);
          return CartControls(
            itemId: id,
            cartQuantity: cartQuantity,
            canAdd: canAddSync,
            onStockError: () => _showStockError(context),
          );
        }
      },
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
    FutureBuilder<int>(
      future: availableStock != null 
        ? Future.value(availableStock) 
        : UserUtils.getAvailableStock(data, id),
      builder: (context, snapshot) {
        final stock = snapshot.data ?? 0;
        
        String message;
        if (stock <= 0) {
          message = '${data['name']} is out of stock';
        } else {
          message = 'Only $stock ${data['name']} available';
        }
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
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
        });
        
        return SizedBox.shrink();
      },
    );
  }
}