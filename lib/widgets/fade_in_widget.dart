import 'package:flutter/material.dart';

/// FADE IN WIDGET FOR ANIMATIONS
class FadeInWidget extends StatelessWidget {
  final Widget child;
  final int delay;
  const FadeInWidget({Key? key, required this.child, this.delay = 0})
      : super(key: key);
      
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// Extension to get day of year for date
extension DateTimeExtensions on DateTime {
  int get dayOfYear {
    return difference(DateTime(year, 1, 1)).inDays;
  }
}