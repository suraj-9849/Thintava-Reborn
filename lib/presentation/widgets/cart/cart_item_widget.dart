// lib/presentation/widgets/cart/cart_item_widget.dart
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
    final isVeg = item['isVeg'] ?? false;

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
                _buildFoodImage(),
                const SizedBox(width: 12),
                
                // Dish details
                Expanded(
                  child: _buildItemDetails(price),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodImage() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: item['imageUrl'] != null
              ? Image.network(
                  item['imageUrl'],
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
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
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[200],
      child: Icon(
        Icons.restaurant,
        size: 40,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildItemDetails(double price) {
    return Column(
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
        
        // Quantity controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildQuantityControls(),
            _buildDeleteButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildQuantityControls() {
    return Container(
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
    );
  }

  Widget _buildDeleteButton() {
    return IconButton(
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
    );
  }
}