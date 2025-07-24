// lib/presentation/widgets/order/pickup_button.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../screens/user/user_home.dart';

class PickupButton extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  
  const PickupButton({
    Key? key,
    required this.orderId,
    required this.orderData,
  }) : super(key: key);

  @override
  State<PickupButton> createState() => _PickupButtonState();
}

class _PickupButtonState extends State<PickupButton> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : () => _handlePickup(context),
        icon: _isProcessing 
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.check_circle),
        label: Text(
          _isProcessing ? "PROCESSING..." : "CONFIRM ORDER PICK UP",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isProcessing ? Colors.grey : const Color(0xFFFFB703),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: _isProcessing ? 0 : 3,
        ),
      ),
    );
  }

  Future<void> _handlePickup(BuildContext context) async {
    if (_isProcessing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Confirm Pick Up",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Have you picked up your order? This action cannot be undone.",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              "CANCEL",
              style: GoogleFonts.poppins(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB703),
            ),
            child: Text(
              "CONFIRM",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirm) return;
    
    // Set processing state
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final updatedOrderData = {...widget.orderData, 'status': 'PickedUp'};

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': 'PickedUp',
        'pickedUpByUserTime': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('orderHistory')
          .doc(widget.orderId)
          .set(updatedOrderData);

      await FirebaseFirestore.instance
          .collection('adminOrderHistory')
          .doc(widget.orderId)
          .set(updatedOrderData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Order marked as picked up!",
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const UserHome(initialIndex: 2),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error updating order: $e",
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}