// lib/widgets/reservation_timer.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:canteen_app/models/reservation_model.dart';

class ReservationTimer extends StatefulWidget {
  final DateTime expiryTime;
  final VoidCallback? onExpired;
  final VoidCallback? onWarning;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final Color? borderColor;
  final Duration warningThreshold;
  final bool showIcon;
  final bool showBackground;

  const ReservationTimer({
    Key? key,
    required this.expiryTime,
    this.onExpired,
    this.onWarning,
    this.textStyle,
    this.backgroundColor,
    this.borderColor,
    this.warningThreshold = const Duration(minutes: 2),
    this.showIcon = true,
    this.showBackground = true,
  }) : super(key: key);

  @override
  State<ReservationTimer> createState() => _ReservationTimerState();
}

class _ReservationTimerState extends State<ReservationTimer>
    with TickerProviderStateMixin {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _hasExpired = false;
  bool _hasWarned = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _initializeTimer();
  }

  @override
  void didUpdateWidget(ReservationTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiryTime != widget.expiryTime) {
      _disposeTimer();
      _hasExpired = false;
      _hasWarned = false;
      _initializeTimer();
    }
  }

  @override
  void dispose() {
    _disposeTimer();
    _pulseController.dispose();
    super.dispose();
  }

  void _initializeTimer() {
    _updateRemaining();
    
    if (_remaining.isNegative) {
      _hasExpired = true;
      _callExpiryCallback();
      return;
    }
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      _updateRemaining();
      
      // Check for expiry
      if (_remaining.isNegative && !_hasExpired) {
        _hasExpired = true;
        _pulseController.stop();
        timer.cancel();
        _callExpiryCallback();
      }
      
      // Check for warning threshold
      if (!_hasWarned && _remaining <= widget.warningThreshold) {
        _hasWarned = true;
        _pulseController.repeat(reverse: true);
        _callWarningCallback();
      }
      
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _updateRemaining() {
    _remaining = widget.expiryTime.difference(DateTime.now());
  }

  void _disposeTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _callExpiryCallback() {
    if (widget.onExpired != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onExpired!();
        }
      });
    }
  }

  void _callWarningCallback() {
    if (widget.onWarning != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onWarning!();
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

  Color _getStatusColor() {
    if (_hasExpired) return Colors.red;
    if (_remaining <= widget.warningThreshold) return Colors.orange;
    return Colors.green;
  }

  IconData _getStatusIcon() {
    if (_hasExpired) return Icons.timer_off;
    if (_remaining <= widget.warningThreshold) return Icons.warning;
    return Icons.schedule;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();
    final timeText = _hasExpired ? "EXPIRED" : _formatTime(_remaining);

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showIcon) ...[
          Icon(
            statusIcon,
            color: statusColor,
            size: 16,
          ),
          const SizedBox(width: 6),
        ],
        Text(
          _hasExpired ? timeText : "Reserved: $timeText",
          style: widget.textStyle?.copyWith(
            color: statusColor,
            fontWeight: FontWeight.bold,
          ) ?? GoogleFonts.poppins(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );

    if (!widget.showBackground) {
      return _hasWarned && !_hasExpired
          ? AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: content,
              ),
            )
          : content;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.borderColor ?? statusColor,
          width: 1,
        ),
      ),
      child: _hasWarned && !_hasExpired
          ? AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: content,
              ),
            )
          : content,
    );
  }
}

class ReservationStatusBanner extends StatelessWidget {
  final CartReservationState reservationState;
  final VoidCallback? onViewDetails;
  final VoidCallback? onExtendTime;

  const ReservationStatusBanner({
    Key? key,
    required this.reservationState,
    this.onViewDetails,
    this.onExtendTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!reservationState.hasActiveReservations) {
      return const SizedBox.shrink();
    }

    final timeUntilExpiry = reservationState.timeUntilExpiry;
    final isUrgent = timeUntilExpiry != null && timeUntilExpiry.inMinutes < 2;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent ? Colors.orange : Colors.blue,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUrgent ? Icons.warning_amber : Icons.schedule,
                color: isUrgent ? Colors.orange : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isUrgent 
                    ? "⚠️ Items Reserved - Time Running Out!"
                    : "🛒 Items Reserved for You",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: isUrgent ? Colors.orange.shade700 : Colors.blue.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (timeUntilExpiry != null)
                ReservationTimer(
                  expiryTime: DateTime.now().add(timeUntilExpiry),
                  showBackground: false,
                  textStyle: GoogleFonts.poppins(fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "${reservationState.reservations.length} item${reservationState.reservations.length > 1 ? 's' : ''} reserved in your cart. Complete payment before time expires.",
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          if (onViewDetails != null || onExtendTime != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onViewDetails != null)
                  TextButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.visibility, size: 16),
                    label: Text(
                      "View Details",
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                if (onExtendTime != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onExtendTime,
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text(
                      "Extend Time",
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class CompactReservationIndicator extends StatelessWidget {
  final List<StockReservation> reservations;
  final VoidCallback? onTap;

  const CompactReservationIndicator({
    Key? key,
    required this.reservations,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeReservations = reservations.where((r) => r.isActive).toList();
    if (activeReservations.isEmpty) {
      return const SizedBox.shrink();
    }

    final earliestExpiry = activeReservations
        .map((r) => r.expiresAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule,
              color: Colors.blue,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              "${activeReservations.length} reserved",
              style: GoogleFonts.poppins(
                color: Colors.blue,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            ReservationTimer(
              expiryTime: earliestExpiry,
              showBackground: false,
              showIcon: false,
              textStyle: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}