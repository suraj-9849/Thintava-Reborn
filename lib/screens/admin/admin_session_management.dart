// lib/screens/admin/admin_session_management.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminSessionManagement extends StatefulWidget {
  const AdminSessionManagement({Key? key}) : super(key: key);

  @override
  State<AdminSessionManagement> createState() => _AdminSessionManagementState();
}

class _AdminSessionManagementState extends State<AdminSessionManagement> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> getActiveSessionsStream() {
    return FirebaseFirestore.instance
        .collection('user_sessions')
        .snapshots();
  }

  Future<String> getUserEmail(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['email'] ?? 'Unknown Email';
      }
    } catch (e) {
      print('Error fetching user email: $e');
    }
    return 'Unknown Email';
  }

  Future<void> forceLogoutUser(String userId, String userEmail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Force Logout User',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to force logout $userEmail? This will terminate their current session.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Force Logout', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete the user's session document to force logout
        await FirebaseFirestore.instance.collection('user_sessions').doc(userId).delete();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User $userEmail has been logged out'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Session Management',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFFFB703),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Text(
                'Active Sessions',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
            Tab(
              child: Text(
                'Session History',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveSessionsList(),
          _buildSessionHistoryList(),
        ],
      ),
    );
  }

  Widget _buildActiveSessionsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: getActiveSessionsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading sessions: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFB703)),
          );
        }

        final sessions = snapshot.data!.docs;

        if (sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.devices_other, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No active sessions',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            final sessionData = session.data() as Map<String, dynamic>;
            final userId = session.id;
            final deviceId = sessionData['activeDeviceId'] ?? 'Unknown Device';
            final lastLoginTime = sessionData['lastLoginTime'] as Timestamp?;
            final email = sessionData['email'] ?? 'Unknown Email';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFFFB703),
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  email,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Device: ${deviceId.substring(0, deviceId.length > 12 ? 12 : deviceId.length)}...',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    Text(
                      'Login: ${lastLoginTime != null ? _formatDateTime(lastLoginTime.toDate()) : 'Unknown'}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ],
                ),
                trailing: PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Row(
                        children: [
                          const Icon(Icons.logout, color: Colors.red),
                          const SizedBox(width: 8),
                          Text('Force Logout', style: GoogleFonts.poppins()),
                        ],
                      ),
                      onTap: () => Future.delayed(
                        Duration.zero,
                        () => forceLogoutUser(userId, email),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSessionHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('history')
          .orderBy('logoutTime', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading session history: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFB703)),
          );
        }

        final historyEntries = snapshot.data!.docs;

        if (historyEntries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No session history',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: historyEntries.length,
          itemBuilder: (context, index) {
            final historyEntry = historyEntries[index];
            final historyData = historyEntry.data() as Map<String, dynamic>;
            
            final deviceId = historyData['deviceId'] ?? 'Unknown Device';
            final loginTime = historyData['loginTime'] as Timestamp?;
            final logoutTime = historyData['logoutTime'] as Timestamp?;
            final logoutReason = historyData['logoutReason'] ?? 'Unknown';
            
            // Extract user ID from the document path
            final userId = historyEntry.reference.parent.parent?.id ?? 'Unknown';

            return FutureBuilder<String>(
              future: getUserEmail(userId),
              builder: (context, emailSnapshot) {
                final email = emailSnapshot.data ?? 'Loading...';
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: _getLogoutReasonColor(logoutReason),
                      child: Icon(
                        _getLogoutReasonIcon(logoutReason),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      email,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      logoutReason,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _getLogoutReasonColor(logoutReason),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Device ID', deviceId),
                            _buildInfoRow(
                              'Login Time',
                              loginTime != null ? _formatDateTime(loginTime.toDate()) : 'Unknown',
                            ),
                            _buildInfoRow(
                              'Logout Time',
                              logoutTime != null ? _formatDateTime(logoutTime.toDate()) : 'Unknown',
                            ),
                            _buildInfoRow('Logout Reason', logoutReason),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Color _getLogoutReasonColor(String reason) {
    switch (reason.toLowerCase()) {
      case 'manual logout':
        return Colors.blue;
      case 'logged in on another device':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getLogoutReasonIcon(String reason) {
    switch (reason.toLowerCase()) {
      case 'manual logout':
        return Icons.logout;
      case 'logged in on another device':
        return Icons.devices_other;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final date = '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    final time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$date at $time';
  }
}