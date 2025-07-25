// lib/screens/role_router.dart - UPDATED TO USE KITCHEN HOME DIRECTLY
import 'package:canteen_app/screens/admin/admin_home.dart';
import 'package:canteen_app/screens/kitchen/kitchen_home.dart'; // Now serves as the main dashboard
import 'package:canteen_app/screens/user/user_home.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:flutter/material.dart';

class RoleRouter extends StatelessWidget {
  final String uid;
  const RoleRouter({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return FutureBuilder<String?>(
      future: auth.getUserRole(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
              ),
            ),
          );
        }
        
        switch (snapshot.data) {
          case 'admin':
            return const AdminHome();
          case 'kitchen':
            return const KitchenHome(); // Now directly shows the dashboard
          default:
            return const UserHome();
        }
      },
    );
  }
}