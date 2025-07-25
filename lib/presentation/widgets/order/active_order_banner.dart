// lib/presentation/widgets/order/active_order_banner.dart - EMPTY VERSION (CAN BE DELETED)
import 'package:flutter/material.dart';

class ActiveOrderBanner extends StatelessWidget {
  final VoidCallback? onTap;
  
  const ActiveOrderBanner({
    Key? key,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Always return empty widget since active order feature is removed
    return const SizedBox.shrink();
  }
}