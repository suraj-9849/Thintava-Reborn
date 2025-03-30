import 'package:flutter/material.dart';

class UserHome extends StatelessWidget {
  const UserHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Home"),
      ),
      body: const Center(
        child: Text(
          "Welcome, User!",
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
