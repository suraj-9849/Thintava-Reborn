import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserHome extends StatelessWidget {
  const UserHome({super.key});

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Home"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
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
              label: const Text("View Menu"),
              onPressed: () {
                Navigator.pushNamed(context, '/menu');
              },
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              icon: const Icon(Icons.track_changes),
              label: const Text("Track Current Order"),
              onPressed: () {
                Navigator.pushNamed(context, '/track');
              },
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text("My Order History"),
              onPressed: () {
                Navigator.pushNamed(context, '/history');
              },
            ),
          ],
        ),
      ),
    );
  }
}
