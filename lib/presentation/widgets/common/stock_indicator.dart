// lib/presentation/widgets/common/stock_indicator.dart - NEW FILE
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/enums/user_enums.dart';
import '../../../core/utils/user_utils.dart';

class StockIndicator extends StatelessWidget {
  final StockStatusType status;
  final int availableStock;
  final bool isCompact;
  final bool isLoading;
  
  const StockIndicator({
    Key? key,
    required this.status,
    required this.availableStock,
    this.isCompact = false,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingIndicator();
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
        border: Border.all(
          color: _getBorderColor(),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(),
            size: isCompact ? 12 : 16,
            color: _getIconColor(),
          ),
          const SizedBox(width: 4),
          Text(
            _getText(),
            style: GoogleFonts.poppins(
              fontSize: isCompact ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: _getTextColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: isCompact ? 12 : 16,
            height: isCompact ? 12 : 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Checking...',
            style: GoogleFonts.poppins(
              fontSize: isCompact ? 10 : 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    return UserUtils.getStockStatusColor(status).withOpacity(0.1);
  }

  Color _getBorderColor() {
    return UserUtils.getStockStatusColor(status).withOpacity(0.3);
  }

  Color _getIconColor() {
    return UserUtils.getStockStatusColor(status);
  }

  Color _getTextColor() {
    return UserUtils.getStockStatusColor(status);
  }

  IconData _getIcon() {
    switch (status) {
      case StockStatusType.unlimited:
        return Icons.all_inclusive;
      case StockStatusType.inStock:
        return Icons.check_circle_outline;
      case StockStatusType.lowStock:
        return Icons.warning_amber_outlined;
      case StockStatusType.outOfStock:
        return Icons.cancel_outlined;
      case StockStatusType.unavailable:
        return Icons.block_outlined;
    }
  }

  String _getText() {
    return UserUtils.getStockStatusText(status, availableStock);
  }
}