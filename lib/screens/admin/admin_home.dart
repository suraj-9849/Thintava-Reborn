import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.restaurant_menu),
              label: const Text("Manage Menu"),
              onPressed: () {
                Navigator.pushNamed(context, '/admin/menu');
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.kitchen),
              label: const Text("Kitchen Dashboard"),
              onPressed: () {
                Navigator.pushNamed(context, '/kitchen');
              },
            ),
            // You can add more here (like user analytics, all orders, etc.)
          ],
        ),
      ),
    );
  }
}
