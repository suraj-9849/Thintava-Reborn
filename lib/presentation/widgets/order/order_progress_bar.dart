// lib/presentation/widgets/order/order_progress_bar.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/enums/user_enums.dart';
import '../../../core/utils/user_utils.dart';

class OrderProgressBar extends StatelessWidget {
  final OrderStatusType currentStatus;
  
  const OrderProgressBar({
    Key? key,
    required this.currentStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatusStep(OrderStatusType.placed, Icons.receipt_long),
        Expanded(
          child: Container(
            height: 3,
            color: _isStatusActive(OrderStatusType.pickUp) 
              ? const Color(0xFFFFB703) 
              : Colors.grey[300],
          ),
        ),
        _buildStatusStep(OrderStatusType.pickUp, Icons.delivery_dining),
      ],
    );
  }

  Widget _buildStatusStep(OrderStatusType status, IconData icon) {
    final isActive = _isStatusActive(status);
    final title = _getStepTitle(status);
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFB703) : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : Colors.grey[600],
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isActive ? const Color(0xFF023047) : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  bool _isStatusActive(OrderStatusType checkStatus) {
    final statusOrder = [
      OrderStatusType.placed,
      OrderStatusType.pickUp,
      OrderStatusType.pickedUp
    ];
    
    final currentIndex = statusOrder.indexOf(currentStatus);
    final checkIndex = statusOrder.indexOf(checkStatus);
    
    return currentIndex >= checkIndex && checkIndex != -1;
  }

  String _getStepTitle(OrderStatusType status) {
    switch (status) {
      case OrderStatusType.placed:
        return 'Placed';
      case OrderStatusType.pickUp:
        return 'Pick Up';
      default:
        return '';
    }
  }
}
