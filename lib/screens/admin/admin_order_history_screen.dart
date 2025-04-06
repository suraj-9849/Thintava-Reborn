import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminOrderHistoryScreen extends StatelessWidget {
  const AdminOrderHistoryScreen({Key? key}) : super(key: key);

  Future<String> fetchUserName(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['username'] ?? 'Unknown User';
      }
    } catch (e) {
      // ignore
    }
    return 'Unknown User';
  }

  @override
  Widget build(BuildContext context) {
    final adminOrdersStream = FirebaseFirestore.instance
        .collection('adminOrderHistory')
        .orderBy('timestamp', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Orders History'),
      ),
      body: StreamBuilder(
        stream: adminOrdersStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            return const Center(child: Text("No orders found."));
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;

              final items = (data['items'] as Map<String, dynamic>)
                  .entries
                  .map((e) => "${e.key} x${e.value}")
                  .join(', ');

              final status = data['status'] ?? 'Unknown';
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              final total = data['total'] ?? 0.0;
              final userId = data['userId'] ?? 'Unknown';

              return FutureBuilder<String>(
                future: fetchUserName(userId),
                builder: (context, userSnapshot) {
                  final username = userSnapshot.data ?? 'Loading...';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 4,
                    child: ListTile(
                      leading: const Icon(Icons.fastfood),
                      title: Text("₹$total - $status"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "User: $username ($userId)",
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Items: $items",
                            style: GoogleFonts.poppins(color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Date: ${timestamp != null ? timestamp.toString() : ''}",
                            style: GoogleFonts.poppins(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
