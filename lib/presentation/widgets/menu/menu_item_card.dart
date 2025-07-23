// lib/presentation/widgets/menu/menu_item_card.dart
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
    
    final availableStock = UserUtils.getAvailableStock(data);
    final stockStatus = UserUtils.getStockStatus(data);
    final isOutOfStock = !available || availableStock <= 0;
    final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;

    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final cartQuantity = cartProvider.getQuantity(id);
        final isReserved = cartProvider.isItemReserved(id);
        final canAdd = available && UserUtils.canAddToCart(data, cartQuantity) && !hasActiveOrder;
        
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
                    border: isReserved 
                      ? Border.all(color: Colors.blue, width: 2)
                      : isOutOfStock
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
                        child: Column(
                          children: [
                            if (isReserved) _buildReservationBanner(cartProvider),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFoodImage(imageUrl, isVeg, isOutOfStock, hasActiveOrder),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildFoodDetails(
                                    name, price, description, stockStatus,
                                    available, isOutOfStock, cartProvider, cartQuantity,
                                    hasActiveOrder, canAdd, availableStock, isReserved,
                                    hasUnlimitedStock, context
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isOutOfStock && !hasUnlimitedStock) _buildOutOfStockOverlay(),
                      if (hasActiveOrder) _buildActiveOrderOverlay(),
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

  Widget _buildReservationBanner(CartProvider cartProvider) {
    return Container(
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
            "Reserved for you (${cartProvider.getReservedQuantity(id)} item${cartProvider.getReservedQuantity(id) > 1 ? 's' : ''})",
            style: GoogleFonts.poppins(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodImage(String? imageUrl, bool isVeg, bool isOutOfStock, bool hasActiveOrder) {
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
                  colorFilter: (isOutOfStock || hasActiveOrder)
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
      StockStatusType stockStatus, bool available, bool isOutOfStock, 
      CartProvider cartProvider, int cartQuantity, bool hasActiveOrder, 
      bool canAdd, int availableStock, bool isReserved, bool hasUnlimitedStock,
      BuildContext context) {
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name
        Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: (isOutOfStock || hasActiveOrder) ? Colors.grey[600] : Colors.black87,
            decoration: (isOutOfStock || hasActiveOrder) ? TextDecoration.lineThrough : null,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 4),
        
        // Status indicators
        _buildStatusIndicators(stockStatus, availableStock, hasActiveOrder),
        
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: (isOutOfStock || hasActiveOrder) ? Colors.grey[500] : Colors.grey[600],
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
            color: (isOutOfStock || hasActiveOrder) ? Colors.grey[500] : const Color(0xFFFFB703),
            decoration: (isOutOfStock || hasActiveOrder) ? TextDecoration.lineThrough : null,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Cart controls
        _buildCartSection(hasActiveOrder, isOutOfStock, available, hasUnlimitedStock,
            cartProvider, cartQuantity, canAdd, availableStock, isReserved, context),
      ],
    );
  }

  Widget _buildStatusIndicators(StockStatusType stockStatus, int availableStock, bool hasActiveOrder) {
    return Row(
      children: [
        StockIndicator(
          status: stockStatus,
          availableStock: availableStock,
          isCompact: true,
        ),
        if (hasActiveOrder) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Text(
              'Order Active',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCartSection(bool hasActiveOrder, bool isOutOfStock, bool available,
      bool hasUnlimitedStock, CartProvider cartProvider, int cartQuantity, 
      bool canAdd, int availableStock, bool isReserved, BuildContext context) {
    
    if (hasActiveOrder) {
      return _buildActiveOrderButton();
    } else if (!isOutOfStock) {
      return CartControls(
        itemId: id,
        cartQuantity: cartQuantity,
        canAdd: canAdd,
        isReserved: isReserved,
        onStockError: () => _showStockError(context, availableStock),
      );
    } else {
      return _buildUnavailableButton(!available, hasUnlimitedStock);
    }
  }

  Widget _buildActiveOrderButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            color: Colors.orange[700],
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Complete Active Order First',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.orange[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableButton(bool isUnavailable, bool hasUnlimitedStock) {
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
            isUnavailable ? Icons.block_rounded : Icons.hourglass_empty_rounded,
            color: Colors.grey[600],
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isUnavailable ? 'Currently Unavailable' : 'Out of Stock',
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

  Widget _buildActiveOrderOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.restaurant_menu,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'ACTIVE ORDER',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStockError(BuildContext context, int availableStock) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                availableStock <= 0 
                  ? '${data['name']} is out of stock'
                  : 'Only $availableStock ${data['name']} available',
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