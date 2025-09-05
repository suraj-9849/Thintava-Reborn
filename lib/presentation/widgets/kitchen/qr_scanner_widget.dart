// lib/presentation/widgets/kitchen/qr_scanner_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/notification_service.dart';

class QRScannerWidget extends StatefulWidget {
  final Function() onOrderCompleted;
  
  const QRScannerWidget({
    Key? key,
    required this.onOrderCompleted,
  }) : super(key: key);

  @override
  State<QRScannerWidget> createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget> {
  MobileScannerController controller = MobileScannerController();
  bool isProcessing = false;
  bool hasScanned = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Scan QR Code',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFFFB703),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: _onQRCodeDetected,
                ),
                // Custom overlay
                _buildScannerOverlay(),
                if (isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Processing order...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 40,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Point camera at the QR code',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF023047),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The order will be automatically marked as picked up',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onQRCodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && !hasScanned && !isProcessing) {
      final String? code = barcodes.first.rawValue;
      _handleQRCodeScanned(code);
    }
  }

  Widget _buildScannerOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFFFB703),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // Corner brackets
                  Positioned(
                    top: -2,
                    left: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: const Color(0xFFFFB703), width: 4),
                          left: BorderSide(color: const Color(0xFFFFB703), width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: const Color(0xFFFFB703), width: 4),
                          right: BorderSide(color: const Color(0xFFFFB703), width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    left: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: const Color(0xFFFFB703), width: 4),
                          left: BorderSide(color: const Color(0xFFFFB703), width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: const Color(0xFFFFB703), width: 4),
                          right: BorderSide(color: const Color(0xFFFFB703), width: 4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleQRCodeScanned(String? qrCode) async {
    if (qrCode == null || qrCode.isEmpty || isProcessing || hasScanned) return;

    setState(() {
      isProcessing = true;
      hasScanned = true;
    });

    try {
      // Pause camera
      await controller.stop();

      // Find the order in Firestore
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(qrCode)
          .get();

      if (!orderDoc.exists) {
        _showErrorDialog('Invalid QR Code', 'Order not found. Please check the QR code.');
        return;
      }

      final orderData = orderDoc.data()!;
      final currentStatus = orderData['status'];

      if (currentStatus != 'Pick Up') {
        _showErrorDialog(
          'Invalid Order Status',
          'This order is not ready for pickup. Current status: $currentStatus',
        );
        return;
      }

      // Update order status to PickedUp
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(qrCode)
          .update({
        'status': 'PickedUp',
        'pickedUpTime': FieldValue.serverTimestamp(),
        'pickedUpBy': 'kitchen_qr_scan',
      });

      // Add to order history
      final updatedOrderData = {...orderData, 'status': 'PickedUp'};
      
      // Add to user's order history
      final userId = orderData['userId'];
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('orderHistory')
            .doc(qrCode)
            .set(updatedOrderData);
      }

      // Add to admin order history
      await FirebaseFirestore.instance
          .collection('adminOrderHistory')
          .doc(qrCode)
          .set(updatedOrderData);

      // Send notification to user
      await _sendCompletionNotification(orderData);

      // Show success message
      _showSuccessDialog(qrCode);

    } catch (e) {
      print('Error processing QR scan: $e');
      _showErrorDialog('Error', 'Failed to process order: $e');
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> _sendCompletionNotification(Map<String, dynamic> orderData) async {
    try {
      final userId = orderData['userId'];
      final total = orderData['total']?.toString() ?? '0';
      final orderId = orderData['orderId'] ?? '';
      
      if (userId == null) return;

      // Use the existing notification service to send completion notification
      await NotificationService.sendOrderCompletionNotification(
        userId: userId,
        orderId: orderId,
        orderTotal: total,
      );

    } catch (e) {
      print('Error sending completion notification: $e');
    }
  }

  void _showSuccessDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 48,
        ),
        title: Text(
          'Order Completed!',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF023047),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Order successfully marked as picked up.',
              style: GoogleFonts.poppins(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Order ID: ${orderId.length > 10 ? '${orderId.substring(0, 10)}...' : orderId}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close scanner
              widget.onOrderCompleted(); // Refresh kitchen dashboard
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB703),
              foregroundColor: Colors.white,
            ),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.error,
          color: Colors.red,
          size: 48,
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(),
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                hasScanned = false;
                isProcessing = false;
              });
              controller.start();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Try Again',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}