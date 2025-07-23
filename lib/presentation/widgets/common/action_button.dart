// lib/presentation/widgets/common/action_button.dart
enum ActionButtonType { primary, secondary, danger, success }

class ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ActionButtonType type;
  final IconData? icon;
  final bool isExpanded;
  final bool isLoading;
  final double? height;
  
  const ActionButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.type = ActionButtonType.primary,
    this.icon,
    this.isExpanded = false,
    this.isLoading = false,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;
    
    switch (type) {
      case ActionButtonType.primary:
        backgroundColor = const Color(0xFFFFB703);
        foregroundColor = Colors.white;
        break;
      case ActionButtonType.secondary:
        backgroundColor = Colors.grey[200]!;
        foregroundColor = Colors.black87;
        break;
      case ActionButtonType.danger:
        backgroundColor = Colors.red;
        foregroundColor = Colors.white;
        break;
      case ActionButtonType.success:
        backgroundColor = Colors.green;
        foregroundColor = Colors.white;
        break;
    }
    
    Widget button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: onPressed != null ? 3 : 0,
      ),
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
              ),
            )
          : Row(
              mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
    );
    
    if (isExpanded) {
      return SizedBox(
        width: double.infinity,
        height: height ?? 48,
        child: button,
      );
    }
    
    return button;
  }
}