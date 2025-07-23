// lib/presentation/widgets/common/stock_indicator.dart
class StockIndicator extends StatelessWidget {
  final StockStatusType status;
  final int? availableStock;
  final bool isCompact;
  
  const StockIndicator({
    Key? key,
    required this.status,
    this.availableStock,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = UserUtils.getStockStatusColor(status);
    final text = UserUtils.getStockStatusText(status, availableStock);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: isCompact ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}