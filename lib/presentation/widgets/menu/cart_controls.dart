// lib/presentation/widgets/menu/cart_controls.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/cart_provider.dart';

class CartControls extends StatelessWidget {
  final String itemId;
  final int cartQuantity;
  final bool canAdd;
  final bool isReserved;
  final VoidCallback? onStockError;
  
  const CartControls({
    Key? key,
    required this.itemId,
    required this.cartQuantity,
    required this.canAdd,
    this.isReserved = false,
    this.onStockError,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        if (cartQuantity > 0) {
          return _buildQuantityControls(cartProvider);
        } else {
          return _buildAddToCartButton(cartProvider);
        }
      },
    );
  }

  Widget _buildQuantityControls(CartProvider cartProvider) {
    return Container(
      decoration: BoxDecoration(
        color: isReserved 
          ? Colors.blue.withOpacity(0.1) 
          : const Color(0xFFFFB703).withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isReserved 
            ? Colors.blue.withOpacity(0.3) 
            : const Color(0xFFFFB703).withOpacity(0.3)
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCartButton(
            icon: Icons.remove_rounded,
            onTap: isReserved ? null : () => cartProvider.removeItem(itemId),
            color: isReserved ? Colors.grey : const Color(0xFFFFB703),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isReserved ? Colors.blue : const Color(0xFFFFB703),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              cartQuantity.toString(),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          _buildCartButton(
            icon: Icons.add_rounded,
            onTap: (isReserved || !canAdd) ? null : () async {
              // FIXED: Better error handling for active orders
              final success = await cartProvider.addItem(itemId);
              if (!success) {
                if (cartProvider.hasActiveOrder) {
                  // Trigger the onStockError callback which will re-check active order
                  if (onStockError != null) {
                    onStockError!();
                  }
                } else if (onStockError != null) {
                  onStockError!();
                }
              }
            },
            color: (isReserved || !canAdd) ? Colors.grey : const Color(0xFFFFB703),
          ),
        ],
      ),
    );
  }

  Widget _buildAddToCartButton(CartProvider cartProvider) {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canAdd ? () async {
          // FIXED: Better error handling for active orders
          final success = await cartProvider.addItem(itemId);
          if (!success) {
            if (cartProvider.hasActiveOrder) {
              // Trigger the onStockError callback which will re-check active order
              if (onStockError != null) {
                onStockError!();
              }
            } else if (onStockError != null) {
              onStockError!();
            }
          }
        } : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canAdd ? const Color(0xFFFFB703) : Colors.grey[400],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
        label: Text(
          "Add to Cart",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCartButton({required IconData icon, required VoidCallback? onTap, required Color color}) {
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
}