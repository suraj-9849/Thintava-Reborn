// lib/widgets/order_expiry_timer.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderExpiryTimer extends StatefulWidget {
  final DateTime pickedUpTime;
  final VoidCallback? onExpired;
  final Duration expiryDuration;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final Color? borderColor;

  const OrderExpiryTimer({
    Key? key,
    required this.pickedUpTime,
    this.onExpired,
    this.expiryDuration = const Duration(minutes: 5),
    this.textStyle,
    this.backgroundColor,
    this.borderColor,
  }) : super(key: key);

  @override
  State<OrderExpiryTimer> createState() => _OrderExpiryTimerState();
}

class _OrderExpiryTimerState extends State<OrderExpiryTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  DateTime? _expiry;
  bool _hasExpired = false;

  @override
  void initState() {
    super.initState();
    _initializeTimer();
  }

  @override
  void didUpdateWidget(OrderExpiryTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only restart timer if pickup time actually changed
    if (oldWidget.pickedUpTime != widget.pickedUpTime) {
      _disposeTimer();
      _initializeTimer();
    }
  }

  @override
  void dispose() {
    _disposeTimer();
    super.dispose();
  }

  void _initializeTimer() {
    // Calculate expiry time
    _expiry = widget.pickedUpTime.add(widget.expiryDuration);
    _updateRemaining();
    
    // Check if already expired
    if (_remaining.isNegative) {
      _hasExpired = true;
      _callExpiryCallback();
      return;
    }
    
    // Start the timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      _updateRemaining();
      
      if (_remaining.isNegative && !_hasExpired) {
        _hasExpired = true;
        timer.cancel();
        _callExpiryCallback();
      }
      
      // Update UI
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _updateRemaining() {
    if (_expiry != null) {
      _remaining = _expiry!.difference(DateTime.now());
    }
  }

  void _disposeTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _callExpiryCallback() {
    if (widget.onExpired != null) {
      // Use addPostFrameCallback to avoid calling callback during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onExpired!();
        }
      });
    }
  }

  String _formatTime(Duration duration) {
    if (duration.isNegative) return "00:00";
    
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    // Determine display state
    final bool isExpired = _remaining.isNegative;
    final bool isUrgent = !isExpired && _remaining.inMinutes < 2;
    
    // Choose colors based on state
    Color displayBackgroundColor;
    Color displayBorderColor;
    Color textColor;
    IconData displayIcon;
    String displayText;
    
    if (isExpired) {
      displayBackgroundColor = widget.backgroundColor ?? Colors.red.withOpacity(0.1);
      displayBorderColor = widget.borderColor ?? Colors.red;
      textColor = Colors.red;
      displayIcon = Icons.timer_off;
      displayText = "EXPIRED";
    } else if (isUrgent) {
      displayBackgroundColor = widget.backgroundColor ?? Colors.orange.withOpacity(0.1);
      displayBorderColor = widget.borderColor ?? Colors.orange;
      textColor = Colors.orange;
      displayIcon = Icons.warning;
      displayText = _formatTime(_remaining);
    } else {
      displayBackgroundColor = widget.backgroundColor ?? Colors.green.withOpacity(0.1);
      displayBorderColor = widget.borderColor ?? Colors.green;
      textColor = Colors.green;
      displayIcon = Icons.timer;
      displayText = _formatTime(_remaining);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: displayBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: displayBorderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            displayIcon,
            color: textColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            isExpired ? displayText : "Time remaining: $displayText",
            style: widget.textStyle?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ) ?? GoogleFonts.poppins(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Simple countdown timer for kitchen dashboard (simpler version)
class SimpleCountdownTimer extends StatefulWidget {
  final DateTime startTime;
  final Duration duration;
  final TextStyle? textStyle;
  final Color? color;

  const SimpleCountdownTimer({
    Key? key,
    required this.startTime,
    required this.duration,
    this.textStyle,
    this.color,
  }) : super(key: key);

  @override
  State<SimpleCountdownTimer> createState() => _SimpleCountdownTimerState();
}

class _SimpleCountdownTimerState extends State<SimpleCountdownTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(SimpleCountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime) {
      _timer?.cancel();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    final expiry = widget.startTime.add(widget.duration);
    _remaining = expiry.difference(DateTime.now());
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final newRemaining = expiry.difference(DateTime.now());
      
      if (mounted) {
        setState(() {
          _remaining = newRemaining;
        });
      }
      
      if (newRemaining.isNegative) {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.timer_off, color: Colors.red, size: 10),
            SizedBox(width: 2),
            Text(
              "EXP",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ],
        ),
      );
    }

    final minutes = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: (widget.color ?? const Color(0xFFFFB703)).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: (widget.color ?? const Color(0xFFFFB703)).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            color: widget.color ?? const Color(0xFFFFB703),
            size: 10,
          ),
          const SizedBox(width: 2),
          Text(
            "$minutes:$seconds",
            style: widget.textStyle ?? TextStyle(
              color: widget.color ?? const Color(0xFFFFB703),
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}