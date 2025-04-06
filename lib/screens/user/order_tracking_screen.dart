import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({Key? key}) : super(key: key);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  DateTime? _expiry;

  Stream<DocumentSnapshot?> getLatestOrderStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty ? snap.docs.first : null);
  }

  void _startCountdown(DateTime pickedAt) {
    _expiry = pickedAt.add(const Duration(minutes: 5));
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final diff = _expiry!.difference(DateTime.now());
      setState(() => _remaining = diff);
      if (diff.isNegative) _timer!.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Track Your Order")),
      body: StreamBuilder<DocumentSnapshot?>(
        stream: getLatestOrderStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snap.data;
          if (doc == null) {
            return const Center(child: Text("No current orders."));
          }
          final data = doc.data()! as Map<String, dynamic>;
          final status = data['status'] ?? 'Unknown';
          final total = data['total'] ?? 0.0;
          final items = (data['items'] as Map<String, dynamic>?)
                  ?.entries
                  .map((e) => "${e.key}: ${e.value}")
                  .join('\n') ??
              'No items';

          // Countdown or expired
          Widget countdown = const SizedBox();
          if (status == 'Pick Up' && data['pickedUpTime'] != null) {
            final pickedAt = (data['pickedUpTime'] as Timestamp).toDate();
            if (_expiry == null ||
                _expiry!.difference(pickedAt).inMinutes < 5) {
              _startCountdown(pickedAt);
            }
            if (_remaining.isNegative) {
              countdown = const Text("⏰ Order expired",
                  style: TextStyle(color: Colors.red, fontSize: 16));
            } else {
              final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
              final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
              countdown = Text("⏱ $m:$s",
                  style: const TextStyle(color: Colors.green, fontSize: 16));
            }
          }

          // If terminated, redirect to history
          if (status == 'Terminated') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(context, '/history');
            });
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Status: $status", style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 8),
              countdown,
              const SizedBox(height: 16),
              Text("Total: ₹$total", style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              Text("Items:\n$items", style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              if (status == 'Pick Up')
                ElevatedButton(
                  onPressed: () async {
                    final id = doc.id;
                    // 1) Mark as PickedUp
                    await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(id)
                        .update({
                      'status': 'PickedUp',
                      'pickedUpByUserTime': FieldValue.serverTimestamp(),
                    });
                    // 2) Archive to histories
                    final userId = data['userId'];
                    final orderData = {...data, 'status': 'PickedUp'};
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('orderHistory')
                        .doc(id)
                        .set(orderData);
                    await FirebaseFirestore.instance
                        .collection('adminOrderHistory')
                        .doc(id)
                        .set(orderData);
                    // 3) Navigate to history
                    Navigator.pushReplacementNamed(context, '/history');
                  },
                  child: const Text("I Have Picked Up"),
                ),
            ]),
          );
        },
      ),
    );
  }
}
