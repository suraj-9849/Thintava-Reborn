

// 🔧 FILE: lib/screens/kitchen/kitchen_home.dart

import 'package:flutter/material.dart';
import 'kitchen_dashboard.dart';

class KitchenHome extends StatelessWidget {
  const KitchenHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kitchen Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.kitchen_rounded, size: 100, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              "Welcome Kitchen Staff",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.green[800],
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.dashboard_customize),
              label: const Text("Go to Live Dashboard"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                backgroundColor: Colors.green,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const KitchenDashboard()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
