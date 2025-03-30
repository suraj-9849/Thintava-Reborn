import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class CartScreen extends StatefulWidget {
  final Map<String, int> cart;

  const CartScreen({super.key, required this.cart});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  double total = 0;
  Map<String, dynamic> menuMap = {};
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    fetchItems();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> fetchItems() async {
    final snapshot = await FirebaseFirestore.instance.collection('menuItems').get();
    setState(() {
      for (var doc in snapshot.docs) {
        menuMap[doc.id] = doc.data();
      }

      total = widget.cart.entries.fold(0, (sum, entry) {
        final price = menuMap[entry.key]?['price'] ?? 0;
        return sum + price * entry.value;
      });
    });
  }

  void startPayment() {
    var options = {
      'key': 'rzp_live_FBnjPJmPGZ9JHo', // Replace with your Razorpay test key
      'amount': (total * 100).toInt(), // In paise
      'name': 'Canteen Order',
      'description': 'Food Order Payment',
      'prefill': {
        'contact': '',
        'email': FirebaseAuth.instance.currentUser?.email ?? '',
      },
      'currency': 'INR',
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final order = {
      'userId': user.uid,
      'items': widget.cart,
      'status': 'placed',
      'timestamp': Timestamp.now(),
      'total': total,
      'paymentId': response.paymentId,
      'paymentStatus': 'success',
    };

    await FirebaseFirestore.instance.collection('orders').add(order);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Order placed successfully!")),
    );
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Payment failed!")),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("External Wallet selected.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Your Cart")),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: widget.cart.entries.map((entry) {
                final item = menuMap[entry.key];
                return ListTile(
                  title: Text(item?['name'] ?? 'Item'),
                  subtitle: Text("${entry.value} x ₹${item?['price']}"),
                );
              }).toList(),
            ),
          ),
          Text("Total: ₹$total", style: const TextStyle(fontSize: 18)),
          ElevatedButton(
            onPressed: startPayment,
            child: const Text("Pay & Place Order"),
          ),
        ],
      ),
    );
  }
}
