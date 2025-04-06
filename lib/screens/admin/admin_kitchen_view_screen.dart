import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Helper
String capitalize(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';

class AdminKitchenViewScreen extends StatelessWidget {
  const AdminKitchenViewScreen({super.key});

  Stream<QuerySnapshot> getOrdersStream() {
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Dashboard (Admin View)'),
        backgroundColor: const Color(0xFF004D40),
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
              return const Center(child: Text('Error loading orders', style: TextStyle(color: Colors.white)));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Center(child: Text('No orders yet.', style: TextStyle(color: Colors.white)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data()! as Map<String, dynamic>;
                return _AdminOrderCard(data: data);
              },
            );
          },
        ),
      ),
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AdminOrderCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final status = capitalize(data['status'] ?? '');
    final items = (data['items'] as Map<String, dynamic>?)
            ?.entries
            .map((e) => '${e.key} (${e.value})')
            .join(', ') ??
        'No items';

    return Card(
      color: Colors.white.withOpacity(0.9),
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(
          "Items: $items",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            "Status: $status",
            style: const TextStyle(fontSize: 14),
          ),
        ),
        trailing: const Icon(Icons.visibility, color: Colors.grey),
      ),
    );
  }
}
