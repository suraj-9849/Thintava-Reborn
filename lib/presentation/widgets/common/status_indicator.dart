// lib/presentation/widgets/common/status_indicator.dart - FIXED OVERFLOW VERSION
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/enums/user_enums.dart';
import '../../../core/utils/user_utils.dart';

class StatusIndicator extends StatelessWidget {
  final OrderStatusType status;
  final bool showIcon;
  final bool isCompact;
  
  const StatusIndicator({
    Key? key,
    required this.status,
    this.showIcon = true,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = UserUtils.getStatusColor(status);
    final icon = UserUtils.getStatusIcon(status);
    final text = status.displayName;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 4 : 8,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isCompact ? 6 : 12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              icon,
              color: color,
              size: isCompact ? 10 : 16,
            ),
            SizedBox(width: isCompact ? 2 : 6),
          ],
          // FIXED: Use Flexible to prevent overflow
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: isCompact ? 9 : 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}