// lib/services/notification_service.dart - FIXED VERSION FOR MISSING PRICE DATA
import 'dart:async';
import 'dart:typed_data'; // Add this import for Int64List
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📱 Background notification received: ${message.messageId}');
  print('📱 Data: ${message.data}');
  
  // Only process order-related notifications
  if (message.data['type'] != null && 
      (message.data['type'].toString().contains('ORDER') || 
       message.data['type'].toString().contains('NEW_ORDER'))) {
    print('📱 Processing order notification in background: ${message.data['type']}');
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();

  // Navigation callback for handling notification taps
  static Function(String)? onNotificationTap;

  static Future<void> initializeNotifications() async {
    print('🔔 Initializing enhanced order notifications...');
    
    // Initialize Firebase Messaging
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    
    // Request permission with detailed settings
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    print('🔔 Notification permission granted: ${settings.authorizationStatus}');

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize local notifications with detailed channels
    await _initializeLocalNotifications();

    // Create notification channels for different types of order notifications
    await _createNotificationChannels();

    // Set up foreground message handler with detailed processing
    await _setupForegroundMessageHandler();
    
    // Set up notification opened app handler
    await _setupNotificationOpenedHandler();
    
    print('✅ Enhanced order notifications initialized successfully');
  }

  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('🔔 Local notification tapped: ${response.payload}');
        _handleNotificationTap(response.payload);
      },
    );
  }

  static Future<void> _createNotificationChannels() async {
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      // Channel for regular order updates
      final AndroidNotificationChannel orderChannel = AndroidNotificationChannel(
        'thintava_orders',
        'Order Updates',
        description: 'Notifications for order status updates and new orders',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 1000, 500]),
      );

      // Channel for urgent notifications (expiring orders)
      final AndroidNotificationChannel urgentChannel = AndroidNotificationChannel(
        'thintava_urgent',
        'Urgent Order Alerts',
        description: 'Critical alerts for order expiration and urgent updates',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 300, 100, 300, 100, 300]),
      );

      await androidImplementation.createNotificationChannel(orderChannel);
      await androidImplementation.createNotificationChannel(urgentChannel);
      
      print('📱 Notification channels created successfully');
    }
  }

  static Future<void> _setupForegroundMessageHandler() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 Foreground notification received: ${message.messageId}');
      print('📱 Data: ${message.data}');

      // Only process order-related notifications
      if (!_isOrderRelatedNotification(message)) {
        print('📱 Ignoring non-order notification');
        return;
      }

      RemoteNotification? notification = message.notification;
      
      if (notification != null) {
        _showEnhancedLocalNotification(message, notification);
      }
    });
  }

  static Future<void> _setupNotificationOpenedHandler() async {
    // Handle notification that opened the app from terminated state
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null && _isOrderRelatedNotification(initialMessage)) {
      print('📱 App opened from terminated state by order notification');
      _handleNotificationNavigation(initialMessage.data);
    }

    // Handle notification that opened the app from background state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 App opened from background by order notification');
      if (_isOrderRelatedNotification(message)) {
        _handleNotificationNavigation(message.data);
      }
    });
  }

  static bool _isOrderRelatedNotification(RemoteMessage message) {
    final type = message.data['type']?.toString() ?? '';
    return type.contains('ORDER') || type.contains('NEW_ORDER');
  }

  static Future<void> _showEnhancedLocalNotification(
      RemoteMessage message, RemoteNotification notification) async {
    
    final type = message.data['type']?.toString() ?? '';
    
    // Determine channel and styling based on notification type
    String channelId = 'thintava_orders';
    String channelName = 'Order Updates';
    Importance importance = Importance.high;
    Priority priority = Priority.high;
    List<int> vibrationPattern = [0, 500, 1000, 500];
    Color color = const Color(0xFFFFB703);
    
    if (type == 'ORDER_EXPIRING') {
      channelId = 'thintava_urgent';
      channelName = 'Urgent Order Alerts';
      importance = Importance.max;
      priority = Priority.max;
      vibrationPattern = [0, 300, 100, 300, 100, 300];
      color = const Color(0xFFFF5722);
    }

    // Create rich notification content - FIXED FOR MISSING PRICE DATA
    String expandedText = _createExpandedNotificationText(message.data);
    
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: _getChannelDescription(type),
      importance: importance,
      priority: priority,
      icon: '@mipmap/ic_launcher',
      color: color,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(vibrationPattern),
      styleInformation: BigTextStyleInformation(
        expandedText,
        htmlFormatBigText: true,
        contentTitle: notification.title,
        htmlFormatContentTitle: true,
        summaryText: 'Thintava Order Update',
        htmlFormatSummaryText: true,
      ),
      fullScreenIntent: type == 'ORDER_EXPIRING',
      category: AndroidNotificationCategory.message,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Create unique notification ID based on order ID or use timestamp
    int notificationId = _generateNotificationId(message.data);

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      notification.title,
      notification.body,
      details,
      payload: _createNotificationPayload(message.data),
    );

    print('📱 Enhanced local notification shown for type: $type');
  }

  // FIXED: Remove pricing information from notification text
  static String _createExpandedNotificationText(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final orderId = data['orderId']?.toString() ?? '';
    final shortOrderId = orderId.isNotEmpty ? orderId.substring(0, 6) : 'Unknown';
    
    switch (type) {
      case 'NEW_ORDER':
        final itemCount = data['itemCount']?.toString() ?? '0';
        final customerEmail = data['customerEmail']?.toString() ?? 'Unknown';
        // REMOVED: orderTotal/pricing information
        return '<b>New Order #$shortOrderId</b><br/>'
               '📦 $itemCount items<br/>'
               '👤 $customerEmail<br/>'
               '<i>Tap to view in kitchen dashboard</i>';
               
      case 'ORDER_STATUS_UPDATE':
        final oldStatus = data['oldStatus']?.toString() ?? '';
        final newStatus = data['newStatus']?.toString() ?? '';
        final itemCount = data['itemCount']?.toString() ?? '0';
        // REMOVED: orderTotal/pricing information
        return '<b>Order #$shortOrderId Updated</b><br/>'
               '📋 Status: $oldStatus → $newStatus<br/>'
               '📦 $itemCount items<br/>'
               '<i>Tap to track your order</i>';
               
      case 'ORDER_EXPIRING':
        // REMOVED: orderTotal/pricing information
        return '<b>⚠ Order #$shortOrderId Expiring!</b><br/>'
               '⏰ Expires in 1 minute<br/>'
               '<b><i>COLLECT NOW!</i></b>';
               
      case 'PAYMENT_CAPTURED':
        return '<b>💰 Payment Confirmed</b><br/>'
               'Order #$shortOrderId payment processed<br/>'
               '<i>Order is being prepared</i>';
               
      case 'WELCOME':
        return '<b>🎉 Welcome to Thintava!</b><br/>'
               'Explore our delicious menu<br/>'
               '<i>Tap to start ordering</i>';
               
      default:
        return 'Tap to view order details';
    }
  }

  static String _getChannelDescription(String type) {
    switch (type) {
      case 'NEW_ORDER':
        return 'Notifications when new orders are received';
      case 'ORDER_STATUS_UPDATE':
        return 'Updates when your order status changes';
      case 'ORDER_EXPIRING':
        return 'Critical alerts when orders are about to expire';
      case 'PAYMENT_CAPTURED':
        return 'Payment confirmation notifications';
      case 'WELCOME':
        return 'Welcome messages for new users';
      default:
        return 'General order notifications';
    }
  }

  static int _generateNotificationId(Map<String, dynamic> data) {
    final orderId = data['orderId']?.toString() ?? '';
    final type = data['type']?.toString() ?? '';
    
    if (orderId.isNotEmpty) {
      // Use order ID hash for consistent ID per order
      return orderId.hashCode.abs();
    } else {
      // Fallback to timestamp-based ID
      return DateTime.now().millisecondsSinceEpoch.remainder(100000);
    }
  }

  static String _createNotificationPayload(Map<String, dynamic> data) {
    return '${data['type']}|${data['orderId']}|${data['action']}';
  }

  static void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    
    final parts = payload.split('|');
    if (parts.length >= 3) {
      final type = parts[0];
      final orderId = parts[1];
      final action = parts[2];
      
      print('📱 Notification tapped - Type: $type, OrderID: $orderId, Action: $action');
      _handleNotificationNavigation({'type': type, 'orderId': orderId, 'action': action});
    }
  }

  static void _handleNotificationNavigation(Map<String, dynamic> data) {
    final action = data['action']?.toString() ?? '';
    final type = data['type']?.toString() ?? '';
    
    // Only handle order-related navigation
    if (onNotificationTap != null) {
      switch (action) {
        case 'view_kitchen_dashboard':
          onNotificationTap!('/kitchen-dashboard');
          break;
        case 'view_order_tracking':
        case 'track_order':
        case 'collect_order_now':
          onNotificationTap!('/track');
          break;
        default:
          // Default navigation based on type
          if (type.contains('ORDER') || type == 'PAYMENT_CAPTURED') {
            onNotificationTap!('/track');
          } else if (type == 'WELCOME') {
            onNotificationTap!('/home');
          }
      }
    }
  }

  // Call this method when logging out to clean up notification resources
  static Future<void> cleanupNotifications() async {
    try {
      // Clear all displayed notifications
      await flutterLocalNotificationsPlugin.cancelAll();
      print('🔔 All notifications cleared');
    } catch (e) {
      print("❌ Error cleaning up notifications: $e");
    }
  }

  // Method to cancel specific order notifications
  static Future<void> cancelOrderNotification(String orderId) async {
    try {
      final notificationId = orderId.hashCode.abs();
      await flutterLocalNotificationsPlugin.cancel(notificationId);
      print('🔔 Cancelled notification for order: $orderId');
    } catch (e) {
      print("❌ Error cancelling order notification: $e");
    }
  }

  // Method to show a test notification (for debugging)
  static Future<void> showTestOrderNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'thintava_orders',
      'Order Updates',
      channelDescription: 'Test notification for order updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFFFB703),
      styleInformation: BigTextStyleInformation(
        'This is a test notification to verify that order notifications are working correctly.',
        htmlFormatBigText: true,
        contentTitle: '🧪 Test Order Notification',
        htmlFormatContentTitle: true,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      999999,
      '🧪 Test Order Notification',
      'Testing enhanced order notification system',
      details,
      payload: 'test|test_order|view_order_tracking',
    );
  }
}