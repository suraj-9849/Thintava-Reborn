
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class KitchenNotificationTest extends StatefulWidget {
  const KitchenNotificationTest({super.key});

  @override
  State<KitchenNotificationTest> createState() => _KitchenNotificationTestState();
}

class _KitchenNotificationTestState extends State<KitchenNotificationTest> {
  String _status = 'Ready to test';
  bool _isLoading = false;
  List<String> _logs = [];

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    });
    print(message);
  }

  Future<void> _testAndFixKitchenNotifications() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing and fixing...';
      _logs.clear();
    });

    try {
      _addLog('🚀 Starting kitchen notification test and fix...');

      // Step 1: Check authentication
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _addLog('❌ No authenticated user');
        setState(() {
          _status = 'ERROR: Not logged in';
          _isLoading = false;
        });
        return;
      }
      _addLog('✅ User authenticated: ${currentUser.email}');

      // Step 2: Get current user document
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      Map<String, dynamic>? userData;
      if (userDoc.exists) {
        userData = userDoc.data() as Map<String, dynamic>;
        _addLog('✅ User document exists');
        _addLog('Current role: ${userData['role'] ?? 'not set'}');
      } else {
        _addLog('❌ User document not found, creating...');
        userData = {
          'email': currentUser.email,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        };
      }

      // Step 3: Get FCM token
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        _addLog('❌ Failed to get FCM token');
        setState(() {
          _status = 'ERROR: No FCM token';
          _isLoading = false;
        });
        return;
      }
      _addLog('✅ FCM token obtained: ${fcmToken.substring(0, 20)}...');

      // Step 4: Check if any kitchen user exists
      // FIXED: Correct Firestore query syntax
      QuerySnapshot kitchenUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'kitchen')
          .get();

      _addLog('👨‍🍳 Kitchen users found: ${kitchenUsers.docs.length}');

      // Step 5: Fix kitchen setup
      if (kitchenUsers.docs.isEmpty) {
        _addLog('🔧 No kitchen user found. Converting current user to kitchen...');
        
        // Make current user a kitchen user
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
          'email': currentUser.email,
          'displayName': currentUser.displayName ?? 'Kitchen Staff',
          'role': 'kitchen',
          'fcmToken': fcmToken,
          'createdAt': userData!['createdAt'] ?? FieldValue.serverTimestamp(),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'isActive': true,
          'profileComplete': true,
          'notificationPreferences': {
            'newOrderAlerts': true,
            'orderUpdates': true,
            'promotions': false,
            'marketing': false,
          },
          'deviceInfo': {
            'platform': 'flutter',
            'notificationChannels': ['thintava_orders', 'thintava_urgent'],
          },
        }, SetOptions(merge: true));
        
        _addLog('✅ Current user converted to kitchen staff');
      } else {
        // Check existing kitchen users
        bool foundValidKitchenUser = false;
        
        for (var doc in kitchenUsers.docs) {
          Map<String, dynamic> kitchenData = doc.data() as Map<String, dynamic>;
          String? existingToken = kitchenData['fcmToken'];
          
          _addLog('Kitchen user: ${kitchenData['email']} - Has token: ${existingToken != null}');
          
          if (doc.id == currentUser.uid) {
            // Current user is already a kitchen user, update their token
            await doc.reference.update({
              'fcmToken': fcmToken,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
            _addLog('✅ Updated FCM token for current kitchen user');
            foundValidKitchenUser = true;
          } else if (existingToken != null) {
            foundValidKitchenUser = true;
          }
        }
        
        if (!foundValidKitchenUser) {
          _addLog('🔧 No kitchen user has valid FCM token. Updating current user...');
          
          // Update current user to be kitchen staff
          await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
            'role': 'kitchen',
            'fcmToken': fcmToken,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
            'notificationPreferences': {
              'newOrderAlerts': true,
              'orderUpdates': true,
              'promotions': false,
              'marketing': false,
            },
          });
          _addLog('✅ Current user updated to kitchen staff with FCM token');
        }
      }

      // Step 6: Check notification permissions
      NotificationSettings settings = await FirebaseMessaging.instance.getNotificationSettings();
      _addLog('📱 Notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        _addLog('⚠️ Requesting notification permission...');
        NotificationSettings newSettings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          criticalAlert: false,
          provisional: false,
        );
        _addLog('📱 New permission status: ${newSettings.authorizationStatus}');
      }

      // Step 7: Verify final setup
      // FIXED: Correct Firestore query syntax
      QuerySnapshot finalKitchenCheck = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'kitchen')
          .get();

      bool setupComplete = false;
      for (var doc in finalKitchenCheck.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['fcmToken'] != null && data['fcmToken'].toString().isNotEmpty) {
          setupComplete = true;
          _addLog('✅ Kitchen user ${data['email']} has valid FCM token');
        }
      }

      setState(() {
        _status = setupComplete ? 'Kitchen setup completed! ✅' : 'Setup issues remain ❌';
        _isLoading = false;
      });

      if (setupComplete) {
        _addLog('🎉 Kitchen notification setup is now complete!');
        _addLog('📱 Kitchen should now receive notifications for new orders');
      }

    } catch (e) {
      _addLog('❌ Error during test and fix: $e');
      setState(() {
        _status = 'ERROR: $e';
        _isLoading = false;
      });
    }
  }


Future<void> _createTestOrderWithRealTimeCheck() async {
  setState(() {
    _isLoading = true;
    _status = 'Creating test order with real-time monitoring...';
  });

  try {
    _addLog('🧪 Starting enhanced test with real-time function monitoring...');

    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _addLog('❌ No authenticated user');
      setState(() {
        _status = 'ERROR: Not logged in';
        _isLoading = false;
      });
      return;
    }

    // Create unique test order ID
    final testOrderId = 'enhanced_test_${DateTime.now().millisecondsSinceEpoch}';
    _addLog('📝 Creating test order: $testOrderId');

    // Log all kitchen users before creating order
    _addLog('👨‍🍳 Kitchen users who should receive notifications:');
    QuerySnapshot kitchenUsers = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'kitchen')
        .get();

    for (var doc in kitchenUsers.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String email = data['email'] ?? 'No email';
      bool hasToken = data['fcmToken'] != null && data['fcmToken'].toString().isNotEmpty;
      String tokenPreview = hasToken ? data['fcmToken'].toString().substring(0, 20) + '...' : 'None';
      _addLog('  • $email: ${hasToken ? "✅" : "❌"} Token: $tokenPreview');
    }

    // Create comprehensive test order
    Map<String, dynamic> orderData = {
      'userId': currentUser.uid,
      'userEmail': currentUser.email,
      'status': 'Placed',
      'items': [
        {
          'id': 'test_pizza_001',
          'name': 'Test Margherita Pizza 🍕',
          'quantity': 2,
          'price': 220,
          'category': 'Pizza',
        },
        {
          'id': 'test_burger_001',
          'name': 'Test Chicken Burger 🍔',
          'quantity': 1,
          'price': 150,
          'category': 'Burgers',
        },
        {
          'id': 'test_drink_001',
          'name': 'Test Fresh Juice 🥤',
          'quantity': 2,
          'price': 60,
          'category': 'Beverages',
        }
      ],
      'totalAmount': 690,
      'createdAt': FieldValue.serverTimestamp(),
      'paymentStatus': 'completed',
      'paymentMethod': 'test',
      'paymentId': 'test_payment_${DateTime.now().millisecondsSinceEpoch}',
      'testOrder': true,
      'enhancedTest': true,
      'orderSource': 'notification_test_widget',
      'estimatedTime': 20,
    };

    _addLog('📦 Order details:');
    _addLog('  • Items: 2x Pizza, 1x Burger, 2x Drinks');
    _addLog('  • Total: ₹690');
    _addLog('  • Customer: ${currentUser.email}');

    // Create the order
    await FirebaseFirestore.instance.collection('orders').doc(testOrderId).set(orderData);
    _addLog('✅ Test order created successfully!');
    
    // Start real-time monitoring
    _addLog('⏱️ Monitoring Cloud Function execution...');
    _addLog('🔔 Kitchen notifications should appear within 10 seconds');
    
    // Monitor for 15 seconds
    for (int i = 1; i <= 15; i++) {
      await Future.delayed(Duration(seconds: 1));
      _addLog('⏱️ Monitoring... ${i}/15 seconds');
      
      if (i == 5) {
        _addLog('📱 First check: Kitchen devices should have received notifications by now');
      } else if (i == 10) {
        _addLog('📱 Second check: If no notifications yet, there may be an issue');
      }
    }

    // Final instructions
    _addLog('🎯 TEST COMPLETE! Please check:');
    _addLog('  1. ✅ ALL kitchen devices for push notifications');
    _addLog('  2. ✅ Firebase Console > Functions > Logs');
    _addLog('  3. ✅ Look for "🚀 FIXED: New order created: $testOrderId"');
    _addLog('  4. ✅ Check for success/failure messages');

    setState(() {
      _status = 'Test completed! Check kitchen devices & Firebase logs.';
      _isLoading = false;
    });

  } catch (e) {
    _addLog('❌ Error creating enhanced test order: $e');
    setState(() {
      _status = 'ERROR: $e';
      _isLoading = false;
    });
  }
}

// ============================================================================
// ADD THIS NEW METHOD TO TEST FIREBASE FUNCTION DIRECTLY
// ============================================================================

Future<void> _testFirebaseFunctionDirectly() async {
  setState(() {
    _isLoading = true;
    _status = 'Testing Firebase Function directly...';
  });

  try {
    _addLog('🔥 Testing Firebase Cloud Function directly...');
    
    // Get your project ID (you'll need to replace this)
    String projectId = 'thintava-ee4f4'; // Replace with your actual project ID
    String functionUrl = 'https://$projectId.cloudfunctions.net/testKitchenNotifications';
    
    _addLog('📡 Calling function URL: $functionUrl');
    
    // You can also test this by opening the URL in a browser
    _addLog('🌐 You can also test by opening this URL in a browser:');
    _addLog('   $functionUrl');
    
    _addLog('📋 This will:');
    _addLog('  1. Create a test order in Firebase');
    _addLog('  2. Trigger the notification function');
    _addLog('  3. Send notifications to ALL kitchen users');
    
    _addLog('✅ Manual function test instructions provided');
    _addLog('🔍 Check Firebase Console > Functions > Logs after calling the URL');

    setState(() {
      _status = 'Manual function test ready. Check logs after calling URL.';
      _isLoading = false;
    });

  } catch (e) {
    _addLog('❌ Error in direct function test: $e');
    setState(() {
      _status = 'ERROR: $e';
      _isLoading = false;
    });
  }
}

// ============================================================================
// ADD THIS METHOD TO CHECK CURRENT FUNCTION STATUS
// ============================================================================

Future<void> _checkFunctionDeploymentStatus() async {
  setState(() {
    _isLoading = true;
    _status = 'Checking function deployment...';
  });

  try {
    _addLog('🔍 Checking Cloud Function deployment status...');
    
    // Create a simple test document to see if function triggers
    final testDocId = 'deployment_test_${DateTime.now().millisecondsSinceEpoch}';
    
    _addLog('📝 Creating deployment test document: $testDocId');
    
    await FirebaseFirestore.instance.collection('orders').doc(testDocId).set({
      'userId': 'deployment_test',
      'userEmail': 'deployment@test.com',
      'status': 'Placed',
      'items': [{'name': 'Deployment Test', 'quantity': 1, 'price': 1}],
      'totalAmount': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'deploymentTest': true,
    });
    
    _addLog('✅ Test document created');
    _addLog('⏱️ Waiting 10 seconds for function to trigger...');
    
    await Future.delayed(Duration(seconds: 10));
    
    _addLog('📊 Check Firebase Console > Functions > Logs now');
    _addLog('🔍 Look for logs containing: "🚀 FIXED: New order created: $testDocId"');
    _addLog('');
    _addLog('📋 Expected function behavior:');
    _addLog('  ✅ Function should process the test order');
    _addLog('  ✅ Should find your 3 kitchen users');
    _addLog('  ✅ Should attempt to send 3 notifications');
    _addLog('  ✅ Should log success/failure for each user');
    _addLog('');
    _addLog('🔧 If no logs appear, the function is not deployed correctly');
    _addLog('🔧 If logs appear but no notifications, check FCM tokens');

    setState(() {
      _status = 'Deployment test completed. Check Firebase Console logs.';
      _isLoading = false;
    });

  } catch (e) {
    _addLog('❌ Error checking deployment: $e');
    setState(() {
      _status = 'ERROR: $e';
      _isLoading = false;
    });
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Notification Fix'),
        backgroundColor: const Color(0xFFFFB703),
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Status: $_status',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testAndFixKitchenNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB703),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.all(16),
              ),
              icon: const Icon(Icons.build),
              label: const Text('Test & Fix Kitchen Notifications'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _createTestOrderWithRealTimeCheck,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              icon: const Icon(Icons.shopping_cart),
              label: const Text('Create Test Order'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Debug Logs:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    String log = _logs[index];
                    Color textColor = Colors.black87;
                    
                    if (log.contains('❌')) {
                      textColor = Colors.red;
                    } else if (log.contains('✅')) {
                      textColor = Colors.green;
                    } else if (log.contains('⚠️')) {
                      textColor = Colors.orange;
                    } else if (log.contains('🔧')) {
                      textColor = Colors.blue;
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: textColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}