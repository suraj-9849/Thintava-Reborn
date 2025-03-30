import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final imageController = TextEditingController();

  Future<void> addMenuItem() async {
    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text.trim()) ?? 0;
    final imageUrl = imageController.text.trim();

    if (name.isEmpty || price <= 0) return;

    await FirebaseFirestore.instance.collection('menuItems').add({
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'available': true,
    });

    nameController.clear();
    priceController.clear();
    imageController.clear();
  }

  Future<void> deleteItem(String docId) async {
    await FirebaseFirestore.instance.collection('menuItems').doc(docId).delete();
  }

  Future<void> toggleAvailability(String docId, bool current) async {
    await FirebaseFirestore.instance
        .collection('menuItems')
        .doc(docId)
        .update({'available': !current});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Menu")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "Item name")),
                TextField(controller: priceController, decoration: const InputDecoration(labelText: "Price")),
                TextField(controller: imageController, decoration: const InputDecoration(labelText: "Image URL")),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: addMenuItem, child: const Text("Add Item")),
              ],
            ),
          ),
          const Divider(),
          const Text("Existing Items", style: TextStyle(fontSize: 18)),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('menuItems').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final items = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final data = item.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text("${data['name']} (₹${data['price']})"),
                      subtitle: Text(data['available'] ? "Available" : "Unavailable"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => deleteItem(item.id),
                          ),
                          IconButton(
                            icon: Icon(data['available'] ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => toggleAvailability(item.id, data['available']),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

