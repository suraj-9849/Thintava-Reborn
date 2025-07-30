// lib/presentation/widgets/menu/cart_controls.dart - IMPROVED WITH BETTER ERROR HANDLING
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/cart_provider.dart';

class CartControls extends StatefulWidget {
  final String itemId;
  final int cartQuantity;
  final bool canAdd;
  final VoidCallback? onStockError;
  
  const CartControls({
    Key? key,
    required this.itemId,
    required this.cartQuantity,
    required this.canAdd,
    this.onStockError,
  }) : super(key: key);

  @override
  State<CartControls> createState() => _CartControlsState();
}

class _CartControlsState extends State<CartControls> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        if (widget.cartQuantity > 0) {
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
        color: const Color(0xFFFFB703).withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB703),
              borderRadius: BorderRadius.circular(15),
            ),
            child: _isLoading 
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.cartQuantity.toString(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
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

  Widget _buildAddToCartButton(CartProvider cartProvider) {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_isLoading || !widget.canAdd) ? null : () => _handleAdd(cartProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.canAdd ? const Color(0xFFFFB703) : Colors.grey[400],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        icon: _isLoading 
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.add_shopping_cart_rounded, size: 20),
        label: Text(
          _isLoading ? "Adding..." : "Add to Cart",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
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
          size: 20,
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