// lib/presentation/widgets/cart/cart_item_widget.dart - COMPLETE FIXED VERSION
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:canteen_app/widgets/reservation_timer.dart';

class CartItemWidget extends StatelessWidget {
  final String itemId;
  final int quantity;
  final Map<String, dynamic> item;
  final bool isReserved;
  final CartProvider cartProvider;

  const CartItemWidget({
    Key? key,
    required this.itemId,
    required this.quantity,
    required this.item,
    required this.isReserved,
    required this.cartProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final price = item['price'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isReserved 
          ? Border.all(color: Colors.blue, width: 2)
          : Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: isReserved 
              ? Colors.blue.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
            blurRadius: isReserved ? 8 : 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Status indicator
            if (isReserved)
              _buildReservationIndicator()
            else
              _buildEditableIndicator(),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Food image
                _buildFoodImage(),
                const SizedBox(width: 12),
                
                // Dish details
                Expanded(
                  child: _buildItemDetails(price, context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Reservation indicator
  Widget _buildReservationIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, color: Colors.blue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Reserved - Cannot modify during reservation",
              style: GoogleFonts.poppins(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (cartProvider.reservationState.earliestExpiry != null)
            ReservationTimer(
              expiryTime: cartProvider.reservationState.earliestExpiry!,
              showBackground: false,
              showIcon: false,
              textStyle: GoogleFonts.poppins(fontSize: 10),
            ),
        ],
      ),
    );
  }

  // Editable indicator for non-reserved items
  Widget _buildEditableIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit, color: Colors.green, size: 14),
          const SizedBox(width: 6),
          Text(
            "Editable - Click +/- to modify quantity",
            style: GoogleFonts.poppins(
              color: Colors.green,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodImage() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: item['imageUrl'] != null
              ? ColorFiltered(
                  colorFilter: isReserved
                    ? ColorFilter.mode(Colors.blue.withOpacity(0.2), BlendMode.srcOver)
                    : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                  child: Image.network(
                    item['imageUrl'],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                  ),
                )
              : _buildImagePlaceholder(),
        ),
        // Veg/Non-veg indicator
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: (item['isVeg'] ?? false) ? Colors.green : Colors.red,
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
        // Reservation overlay
        if (isReserved)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Center(
                child: Icon(
                  Icons.lock,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: isReserved ? Colors.blue.shade50 : Colors.grey[200],
      child: Icon(
        Icons.restaurant,
        size: 40,
        color: isReserved ? Colors.blue : Colors.grey[400],
      ),
    );
  }

  Widget _buildItemDetails(double price, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item['name'] ?? 'Item',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isReserved ? Colors.blue.shade700 : const Color(0xFF023047),
          ),
        ),
        const SizedBox(height: 4),
        if (item['description'] != null)
          Text(
            item['description'],
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isReserved ? Colors.blue.shade600 : Colors.grey[600],
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
                color: isReserved ? Colors.blue.shade600 : Colors.grey[700],
              ),
            ),
            Text(
              "₹${(price * quantity).toStringAsFixed(2)}",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isReserved ? Colors.blue.shade700 : const Color(0xFFFFB703),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Quantity controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildQuantityControls(context),
            _buildDeleteButton(context),
          ],
        ),
      ],
    );
  }

  Widget _buildQuantityControls(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isReserved 
          ? Colors.blue.withOpacity(0.1)
          : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isReserved 
            ? Colors.blue.withOpacity(0.3)
            : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          _buildCartButton(
            icon: Icons.remove_circle_outline,
            onTap: isReserved ? null : () {
              cartProvider.removeItem(itemId);
              _showFeedback(context, "Item quantity decreased");
            },
            color: isReserved ? Colors.grey : const Color(0xFF023047),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: isReserved ? Colors.blue : const Color(0xFFFFB703),
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
          _buildCartButton(
            icon: Icons.add_circle_outline,
            onTap: isReserved ? null : () async {
              final success = await cartProvider.addItem(itemId);
              if (success) {
                _showFeedback(context, "Item added to cart");
              } else {
                _showFeedback(context, "Cannot add more - insufficient stock", isError: true);
              }
            },
            color: isReserved ? Colors.grey : const Color(0xFF023047),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return IconButton(
      icon: Icon(
        isReserved ? Icons.lock : Icons.delete_outline,
        color: isReserved ? Colors.grey : Colors.red,
        size: 20,
      ),
      onPressed: isReserved ? () {
        _showFeedback(context, "Cannot remove reserved item", isError: true);
      } : () {
        cartProvider.removeItemCompletely(itemId);
        _showFeedback(context, "Item removed from cart");
      },
      constraints: const BoxConstraints(
        minWidth: 32,
        minHeight: 32,
      ),
      padding: EdgeInsets.zero,
      tooltip: isReserved ? "Cannot remove reserved item" : "Remove item",
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
          size: 20,
        ),
      ),
    );
  }

  // Show feedback to user
  void _showFeedback(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.warning : Icons.check,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}