import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final cart = <String, int>{};

  void toggleCart(String itemId) {
    setState(() {
      cart[itemId] = (cart[itemId] ?? 0) + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final menuStream = FirebaseFirestore.instance.collection('menuItems').snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Menu"),
        actions: [
          IconButton(
            icon: const Icon(Icons.track_changes),
            tooltip: "Track Order",
            onPressed: () {
              Navigator.pushNamed(context, '/track');
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: menuStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final items = snapshot.data!.docs;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index].data();
              final id = items[index].id;
              return ListTile(
                leading: item['imageUrl'] != null
                    ? Image.network(item['imageUrl'], width: 50)
                    : const Icon(Icons.fastfood),
                title: Text(item['name'] ?? 'Item'),
                subtitle: Text("₹${item['price']}"),
                trailing: IconButton(
                  icon: const Icon(Icons.add_shopping_cart),
                  onPressed: () => toggleCart(id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: "Go to Cart",
        onPressed: () {
          Navigator.pushNamed(context, '/cart', arguments: cart);
        },
        child: const Icon(Icons.shopping_cart),
      ),
    );
  }
}
