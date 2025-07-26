// lib/widgets/debug_lifecycle_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:canteen_app/services/enhanced_app_lifecycle_handler.dart';

class DebugLifecycleWidget extends StatefulWidget {
  const DebugLifecycleWidget({Key? key}) : super(key: key);

  @override
  State<DebugLifecycleWidget> createState() => _DebugLifecycleWidgetState();
}

class _DebugLifecycleWidgetState extends State<DebugLifecycleWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "🐛 DEBUG: Lifecycle Handler",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 12),
              
              // Cart Status
              _buildDebugRow("Cart Items", "${cartProvider.itemCount}"),
              _buildDebugRow("Active Reservations", "${cartProvider.hasActiveReservations}"),
              _buildDebugRow("Reservation Count", "${cartProvider.activeReservations.length}"),
              
              // App State Info
              _buildDebugRow("App State", "${WidgetsBinding.instance.lifecycleState}"),
              
              const SizedBox(height: 12),
              
              // Test Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        EnhancedAppLifecycleHandler.instance.debugCurrentState();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Check console for debug info"),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        "Debug State",
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        EnhancedAppLifecycleHandler.instance.markPaymentProcessStarted();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Payment process marked as started"),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        "Start Payment",
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        EnhancedAppLifecycleHandler.instance.manuallyTriggerReservationRelease();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Manual reservation release triggered"),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        "Release Reservations",
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        EnhancedAppLifecycleHandler.instance.markPaymentProcessCompleted();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Payment process marked as completed"),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        "End Payment",
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Test: 1) Add items to cart 2) Click 'Start Payment' 3) Close app 4) Reopen app and check if reservations were released",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.yellow.shade800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }
}