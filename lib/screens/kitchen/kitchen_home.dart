import 'package:flutter/material.dart';

class KitchenHome extends StatelessWidget {
  const KitchenHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kitchen Dashboard"),
      ),
      body: const Center(
        child: Text(
          "Welcome, Kitchen Staff!",
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
