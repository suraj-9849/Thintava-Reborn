import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Capitalize helper
String capitalize(String s) =>
    s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';

class KitchenDashboard extends StatelessWidget {
  const KitchenDashboard({Key? key}) : super(key: key);

  Stream<QuerySnapshot> getOrdersStream() {
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
  final db = FirebaseFirestore.instance;
  final orderRef = db.collection('orders').doc(orderId);

  final updates = <String, Object>{'status': newStatus};
  if (newStatus == 'Cooked') {
    updates['cookedTime'] = FieldValue.serverTimestamp();
  }
  if (newStatus == 'Pick Up') {
    updates['pickedUpTime'] = FieldValue.serverTimestamp();
  }

  // ✅ Update order status
  await orderRef.update(updates);

  // ✅ Send notification to User when status becomes Pick Up
  if (newStatus == 'Pick Up') {
    final orderDoc = await orderRef.get();
    final userId = orderDoc.data()?['userId'];

    if (userId != null) {
      final userDoc = await db.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'];

      if (fcmToken != null) {
        await db.collection('notifications').add({
          'title': 'Order Ready!',
          'body': 'Your order is ready for pickup 🍽️',
          'token': fcmToken,
        });
      }
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Kitchen Dashboard"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/kitchen-menu'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/auth');
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF004D40), Color(0xFF1B5E20)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: getOrdersStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text("Error loading orders.", style: TextStyle(color: Colors.white)),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // Filter to remove Terminated and PickedUp orders
            final docs = snapshot.data!.docs.where((d) {
              final s = d['status'];
              return s != 'Terminated' && s != 'PickedUp';
            }).toList();

            if (docs.isEmpty) {
              return const Center(
                child: Text("No active orders.", style: TextStyle(color: Colors.white)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 24, 16, 16),
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final doc = docs[i];
                final data = doc.data()! as Map<String, dynamic>;
                return OrderCard(
                  key: ValueKey(doc.id),
                  orderId: doc.id,
                  data: data,
                  onUpdate: updateOrderStatus,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class OrderCard extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final Future<void> Function(String, String) onUpdate;

  const OrderCard({
    Key? key,
    required this.orderId,
    required this.data,
    required this.onUpdate,
  }) : super(key: key);

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  Timestamp? _lastPickedTs;

  @override
  void initState() {
    super.initState();
    _maybeStartTimer(widget.data);
  }

  @override
  void didUpdateWidget(covariant OrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTs = widget.data['pickedUpTime'] as Timestamp?;
    if (widget.data['status'] == 'Pick Up' && newTs != null && newTs != _lastPickedTs) {
      _maybeStartTimer(widget.data);
    }
  }

  void _maybeStartTimer(Map<String, dynamic> data) {
    _timer?.cancel();
    final status = data['status'];
    final ts = data['pickedUpTime'] as Timestamp?;
    if (status == 'Pick Up' && ts != null) {
      _lastPickedTs = ts;
      final expiry = ts.toDate().add(const Duration(minutes: 5));
      _remaining = expiry.difference(DateTime.now());
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final diff = expiry.difference(DateTime.now());
        setState(() => _remaining = diff);
        if (diff.isNegative) {
          _timer?.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = capitalize(widget.data['status'] ?? '');
    final shortId = widget.orderId.substring(0, 6);
    final items = (widget.data['items'] as Map<String, dynamic>?)
        ?.entries
        .map((e) => '${e.key} (${e.value})')
        .join(', ') ?? 'N/A';

    Widget timerWidget = const SizedBox();
    if (status == 'Pick Up') {
      if (_remaining.isNegative) {
        timerWidget = const Text("⏰ Expired", style: TextStyle(color: Colors.red, fontSize: 16));
      } else {
        final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
        final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
        timerWidget = Text("⏱ $m:$s", style: const TextStyle(color: Colors.green, fontSize: 16));
      }
    }

    return Card(
      color: Colors.white.withOpacity(0.95),
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Order ID: $shortId",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Items: $items", style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Row(children: [
            const Text("Status: ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            DropdownButton<String>(
              value: status,
              underline: Container(),
              onChanged: (newStatus) {
                if (newStatus != null) {
                  widget.onUpdate(widget.orderId, newStatus);
                }
              },
              items: ['Placed', 'Cooking', 'Cooked', 'Pick Up']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
            ),
            const Spacer(),
            timerWidget,
          ]),
        ]),
      ),
    );
  }
}
