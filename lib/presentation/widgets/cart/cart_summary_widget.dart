// lib/presentation/widgets/cart/cart_summary_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/providers/cart_provider.dart';

class CartSummaryWidget extends StatelessWidget {
  final double total;
  final bool isReserving;
  final bool hasActiveReservations;
  final VoidCallback onReserveAndPay;
  final VoidCallback onPayNow;

  const CartSummaryWidget({
    Key? key,
    required this.total,
    required this.isReserving,
    required this.hasActiveReservations,
    required this.onReserveAndPay,
    required this.onPayNow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
          // Bill details
          _buildBillDetails(),
          const SizedBox(height: 16),
          
          // Auto-capture info banner
          _buildAutoCaptureInfo(),
          
          // Place order button
          _buildOrderButton(),
          
          // Info text
          const SizedBox(height: 8),
          _buildInfoText(),
        ],
      ),
    );
  }

  Widget _buildBillDetails() {
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
              "₹${total.toStringAsFixed(2)}",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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

  Widget _buildAutoCaptureInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Auto-capture enabled - Payment will be captured automatically after authorization",
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isReserving 
          ? null 
          : (hasActiveReservations 
              ? onPayNow
              : onReserveAndPay),
        style: ElevatedButton.styleFrom(
          backgroundColor: isReserving
            ? Colors.grey[400] 
            : const Color(0xFFFFB703),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isReserving
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
                  "Reserving Items...",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasActiveReservations 
                    ? Icons.payment 
                    : Icons.schedule,
                ),
                const SizedBox(width: 8),
                Text(
                  hasActiveReservations
                    ? "Pay Now • ₹${total.toStringAsFixed(2)}"
                    : "Reserve & Pay • ₹${total.toStringAsFixed(2)}",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildInfoText() {
    return Center(
      child: Text(
        hasActiveReservations 
          ? "Items are reserved for you. Complete payment to confirm order."
          : "Items will be reserved while you complete payment",
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}