import 'package:flutter/material.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
      ),
      body: const Center(
        child: Text(
          "Welcome, Admin!",
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
