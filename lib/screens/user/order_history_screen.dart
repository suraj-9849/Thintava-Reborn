import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in.")),
      );
    }

    final ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text("My Orders")),
      body: StreamBuilder(
        stream: ordersStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            return const Center(child: Text("You have no orders yet."));
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;
              final items = (data['items'] as Map<String, dynamic>).entries.map((e) => "${e.key} x${e.value}").join(', ');
              final status = data['status'] ?? 'unknown';
              final timestamp = (data['timestamp'] as Timestamp).toDate();
              final total = data['total'];

              return ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text("₹$total - $status"),
                subtitle: Text("Items: $items\nDate: $timestamp"),
              );
            },
          );
        },
      ),
    );
  }
}
