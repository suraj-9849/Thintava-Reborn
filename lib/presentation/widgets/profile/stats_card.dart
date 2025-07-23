// lib/presentation/widgets/profile/stats_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatsCard extends StatelessWidget {
  final int totalOrders;
  final double totalSpent;
  final bool isLoading;
  
  const StatsCard({
    Key? key,
    required this.totalOrders,
    required this.totalSpent,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isLoading 
        ? const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFFB703),
            ),
          )
        : Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.shopping_bag_outlined,
                  value: totalOrders.toString(),
                  label: "Orders",
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.grey[300],
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.currency_rupee,
                  value: "₹${totalSpent.toStringAsFixed(0)}",
                  label: "Spent",
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB703).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFFB703),
            size: 18,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFFB703),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}