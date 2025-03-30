import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class KitchenDashboard extends StatelessWidget {
  const KitchenDashboard({super.key});

  Future<void> updateStatus(String docId, String currentStatus) async {
    String nextStatus = switch (currentStatus) {
      'placed' => 'preparing',
      'preparing' => 'ready',
      'ready' => 'collected',
      _ => 'collected',
    };

    await FirebaseFirestore.instance.collection('orders').doc(docId).update({
      'status': nextStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text("Kitchen Dashboard")),
      body: StreamBuilder(
        stream: ordersStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            return const Center(child: Text("No orders yet."));
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final data = order.data() as Map<String, dynamic>;
              final items = (data['items'] as Map<String, dynamic>).entries
                  .map((e) => "${e.key} x${e.value}")
                  .join(', ');

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text("Order by ${data['userId']}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Items: $items"),
                      Text("Status: ${data['status']}"),
                      Text("Total: ₹${data['total']}"),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => updateStatus(order.id, data['status']),
                    child: const Text("Next Stage"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
