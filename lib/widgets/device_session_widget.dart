// lib/widgets/device_session_widget.dart - DEVICE SESSION STATUS WIDGET
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:canteen_app/services/session_manager.dart';

class DeviceSessionStatus extends StatefulWidget {
  final AuthService authService;
  final bool showDetails;

  const DeviceSessionStatus({
    Key? key,
    required this.authService,
    this.showDetails = false,
  }) : super(key: key);

  @override
  State<DeviceSessionStatus> createState() => _DeviceSessionStatusState();
}

class _DeviceSessionStatusState extends State<DeviceSessionStatus> {
  bool _isCheckingSession = false;
  bool _isSessionActive = true;
  Map<String, dynamic>? _sessionInfo;

  @override
  void initState() {
    super.initState();
    if (widget.showDetails) {
      _loadSessionInfo();
    }
  }

  Future<void> _loadSessionInfo() async {
    if (!mounted) return;
    
    setState(() {
      _isCheckingSession = true;
    });

    try {
      final user = widget.authService.currentUser;
      if (user != null) {
        final sessionManager = SessionManager();
        final sessionInfo = await sessionManager.getActiveSessionInfo(user.uid);
        final isActive = await widget.authService.checkActiveSession();
        
        if (mounted) {
          setState(() {
            _sessionInfo = sessionInfo;
            _isSessionActive = isActive;
            _isCheckingSession = false;
          });
        }
      }
    } catch (e) {
      print('Error loading session info: $e');
      if (mounted) {
        setState(() {
          _isCheckingSession = false;
        });
      }
    }
  }

  Future<void> _refreshSession() async {
    await _loadSessionInfo();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showDetails) {
      // Simple status indicator
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _isSessionActive 
            ? Colors.green.withOpacity(0.1) 
            : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isSessionActive ? Colors.green : Colors.red,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isSessionActive ? Icons.security : Icons.warning,
              color: _isSessionActive ? Colors.green : Colors.red,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              _isSessionActive ? 'Secure' : 'Inactive',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _isSessionActive ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      );
    }

    // Detailed session info card
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.security,
                      color: _isSessionActive ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Device Session',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (!_isCheckingSession)
                  IconButton(
                    onPressed: _refreshSession,
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh session info',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (_isCheckingSession)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              _buildStatusRow(
                'Status',
                _isSessionActive ? 'Active' : 'Inactive',
                _isSessionActive ? Colors.green : Colors.red,
              ),
              
              if (_sessionInfo != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow('Device ID', _sessionInfo!['activeDeviceId'] ?? 'Unknown'),
                
                if (_sessionInfo!['deviceInfo'] != null) ...[
                  const SizedBox(height: 8),
                  _buildDeviceInfo(_sessionInfo!['deviceInfo']),
                ],
                
                if (_sessionInfo!['lastActivity'] != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Last Activity',
                    _formatTimestamp(_sessionInfo!['lastActivity']),
                  ),
                ],
                
                if (_sessionInfo!['lastLoginTime'] != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Login Time',
                    _formatTimestamp(_sessionInfo!['lastLoginTime']),
                  ),
                ],
              ],
              
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Only one device can be logged in at a time for security.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceInfo(Map<String, dynamic> deviceInfo) {
    final platform = deviceInfo['platform'] ?? 'Unknown';
    final model = deviceInfo['model'] ?? deviceInfo['name'] ?? 'Unknown';
    final version = deviceInfo['version'] ?? 
                   deviceInfo['systemVersion'] ?? 
                   deviceInfo['systemName'] ?? '';

    return Column(
      children: [
        _buildInfoRow('Platform', platform.toUpperCase()),
        const SizedBox(height: 4),
        _buildInfoRow('Device', model),
        if (version.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildInfoRow('Version', version),
        ],
      ],
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return 'Unknown';
      
      DateTime dateTime;
      if (timestamp is DateTime) {
        dateTime = timestamp;
      } else if (timestamp.toDate != null) {
        dateTime = timestamp.toDate();
      } else {
        return 'Unknown';
      }
      
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}

class SessionHistoryWidget extends StatefulWidget {
  final String userId;

  const SessionHistoryWidget({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<SessionHistoryWidget> createState() => _SessionHistoryWidgetState();
}

class _SessionHistoryWidgetState extends State<SessionHistoryWidget> {
  List<Map<String, dynamic>> _sessionHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessionHistory();
  }

  Future<void> _loadSessionHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sessionManager = SessionManager();
      final history = await sessionManager.getSessionHistory(widget.userId);
      
      if (mounted) {
        setState(() {
          _sessionHistory = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading session history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Session History',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (!_isLoading)
                  IconButton(
                    onPressed: _loadSessionHistory,
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh history',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_sessionHistory.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No session history available',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sessionHistory.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final session = _sessionHistory[index];
                  return _buildSessionHistoryItem(session);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionHistoryItem(Map<String, dynamic> session) {
    final deviceInfo = session['deviceInfo'] as Map<String, dynamic>?;
    final platform = deviceInfo?['platform'] ?? 'Unknown';
    final model = deviceInfo?['model'] ?? deviceInfo?['name'] ?? 'Unknown Device';
    final logoutReason = session['logoutReason'] ?? 'Unknown';
    final logoutTime = session['logoutTime'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getReasonColor(logoutReason).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getReasonColor(logoutReason).withOpacity(0.3),
              ),
            ),
            child: Icon(
              _getReasonIcon(logoutReason),
              color: _getReasonColor(logoutReason),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$platform • $model',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  logoutReason,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _getReasonColor(logoutReason),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTimestamp(logoutTime),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getReasonColor(String reason) {
    switch (reason.toLowerCase()) {
      case 'logged in on another device':
        return Colors.orange;
      case 'manual logout':
        return Colors.green;
      case 'force logout by admin':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getReasonIcon(String reason) {
    switch (reason.toLowerCase()) {
      case 'logged in on another device':
        return Icons.devices_other;
      case 'manual logout':
        return Icons.logout;
      case 'force logout by admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.circle;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return 'Unknown time';
      
      DateTime dateTime;
      if (timestamp is DateTime) {
        dateTime = timestamp;
      } else if (timestamp.toDate != null) {
        dateTime = timestamp.toDate();
      } else {
        return 'Unknown time';
      }
      
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes} minutes ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours} hours ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return 'Unknown time';
    }
  }
}