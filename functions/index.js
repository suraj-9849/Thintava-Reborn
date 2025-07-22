// functions/index.js - COMPLETE WITH RAZORPAY INTEGRATION
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

// NEW: Razorpay imports
const Razorpay = require('razorpay');
const crypto = require('crypto');

// Initialize Firebase Admin SDK without service account key
// Firebase will automatically use the default service account when deployed
admin.initializeApp();

// NEW: Initialize Razorpay instance
const razorpay = new Razorpay({
  key_id: functions.config().razorpay.key_id,
  key_secret: functions.config().razorpay.key_secret,
});

// ============================================================================
// EXISTING FUNCTIONS (KEEP ALL YOUR CURRENT FUNCTIONALITY)
// ============================================================================

// ✅ Your existing function (KEEP IT)
exports.terminateStalePickups = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.FieldValue.serverTimestamp();
    const serverNow = admin.firestore.Timestamp.now();
    const cutoff = admin.firestore.Timestamp.fromMillis(serverNow.toMillis() - 5 * 60 * 1000);

    const stale = await db.collection('orders')
      .where('status', '==', 'Pick Up')
      .where('pickedUpTime', '<=', cutoff)
      .get();

    if (stale.empty) {
      console.log('No stale orders found.');
      return null;
    }

    const batch = db.batch();
    stale.forEach(doc => {
      const data = doc.data();
      const id = doc.id;
      const userId = data.userId;

      batch.update(db.collection('orders').doc(id), {
        status: 'Terminated',
        terminatedTime: now,
      });

      batch.set(
        db.collection('users').doc(userId).collection('orderHistory').doc(id),
        { ...data, status: 'Terminated', terminatedTime: serverNow }
      );

      batch.set(
        db.collection('adminOrderHistory').doc(id),
        { ...data, status: 'Terminated', terminatedTime: serverNow }
      );
    });

    await batch.commit();
    console.log(`Terminated ${stale.size} stale pickups.`);
    return null;
  });

// 🚀 Enhanced function: notify kitchen when a new order is created
exports.notifyKitchenOnNewOrder = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, context) => {
    try {
      const newOrder = snap.data();
      console.log('New order created:', context.params.orderId);

      // 🔥 Fetch kitchen user with role 'kitchen' from users collection
      const kitchenUsers = await admin.firestore().collection('users')
        .where('role', '==', 'kitchen')
        .get();

      if (kitchenUsers.empty) {
        console.log('No kitchen user found!');
        return null;
      }

      const kitchenUser = kitchenUsers.docs[0].data();
      const kitchenFcmToken = kitchenUser.fcmToken;

      if (!kitchenFcmToken) {
        console.log('No FCM token for kitchen user!');
        return null;
      }

      const payload = {
        notification: {
          title: 'New Order Received',
          body: `A new order #${context.params.orderId.substring(0, 6)} has been placed. Check the kitchen panel.`,
        },
        data: {
          type: 'NEW_ORDER',
          orderId: context.params.orderId,
        }
      };

      const result = await admin.messaging().send({
        token: kitchenFcmToken,
        notification: payload.notification,
        data: payload.data
      });

      console.log('Kitchen notification sent successfully:', result);
      return result;
    } catch (error) {
      console.error('Error sending kitchen notification:', error);
      return null;
    }
  });

// 🚀 Enhanced function: notify user when order status changes
exports.notifyUserOnOrderStatusChange = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    try {
      const beforeStatus = change.before.data().status;
      const afterStatus = change.after.data().status;

      // Only send notification if status actually changed
      if (beforeStatus === afterStatus) {
        return null;
      }

      const orderData = change.after.data();
      const userId = orderData.userId;

      console.log(`Order status changed from ${beforeStatus} to ${afterStatus} for user ${userId}`);

      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (!userDoc.exists) {
        console.log('User document not found:', userId);
        return null;
      }

      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;

      if (!fcmToken) {
        console.log('No FCM token found for user:', userId);
        return null;
      }

      // Create status-specific messages
      let notificationBody = `Your order status has been updated to ${afterStatus}.`;
      switch (afterStatus.toLowerCase()) {
        case 'cooking':
          notificationBody = 'Your order is now being prepared! 👨‍🍳';
          break;
        case 'cooked':
          notificationBody = 'Your order is ready! Please come to pick it up. 🍽️';
          break;
        case 'pick up':
          notificationBody = 'Your order is ready for pickup! Please collect it within 5 minutes. ⏰';
          break;
        case 'pickedup':
          notificationBody = 'Thank you! Enjoy your meal! 😊';
          break;
        case 'terminated':
          notificationBody = 'Your order has been cancelled. Please contact support if needed.';
          break;
      }

      const payload = {
        notification: {
          title: 'Order Update',
          body: notificationBody,
        },
        data: {
          type: 'ORDER_STATUS_UPDATE',
          orderId: context.params.orderId,
          newStatus: afterStatus,
          oldStatus: beforeStatus,
        }
      };
      
      const result = await admin.messaging().send({
        token: fcmToken,
        notification: payload.notification,
        data: payload.data
      });

      console.log('User notification sent successfully:', result);
      return result;
    } catch (error) {
      console.error('Error sending user notification:', error);
      return null;
    }
  });

// 🔥 ENHANCED DEVICE MANAGEMENT FUNCTION: notify users when logged out from another device
exports.notifyUserOnSessionTermination = functions.firestore
  .document('user_sessions/{userId}/history/{historyId}')
  .onCreate(async (snap, context) => {
    try {
      const sessionData = snap.data();
      const userId = context.params.userId;
      
      console.log(`📱 Session termination detected for user: ${userId}`);
      console.log(`📱 Session data:`, sessionData);
      
      // Only send notification if the logout reason is due to another device login
      if (sessionData.logoutReason === 'Logged in on another device' && sessionData.fcmToken) {
        const fcmToken = sessionData.fcmToken;
        
        // Get user data to personalize the message
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        let userEmail = 'your account';
        let deviceInfo = '';
        
        if (userDoc.exists) {
          const userData = userDoc.data();
          userEmail = userData.email || 'your account';
        }
        
        // Get device info for more detailed message
        if (sessionData.deviceInfo) {
          const device = sessionData.deviceInfo;
          deviceInfo = ` from ${device.platform || 'unknown'} device`;
          if (device.model) {
            deviceInfo += ` (${device.model})`;
          }
        }
        
        const payload = {
          notification: {
            title: '🔐 Security Alert - Device Login',
            body: `${userEmail} was logged in on another device. You have been logged out${deviceInfo} for security.`,
          },
          data: {
            type: 'SESSION_TERMINATED',
            userId: userId,
            timestamp: sessionData.logoutTime ? sessionData.logoutTime.toDate().toString() : new Date().toString(),
            previousDevice: sessionData.deviceInfo ? JSON.stringify(sessionData.deviceInfo) : '',
            reason: 'another_device_login',
          }
        };
        
        // Send the notification
        try {
          const result = await admin.messaging().send({
            token: fcmToken,
            notification: payload.notification,
            data: payload.data,
            android: {
              notification: {
                channelId: 'thintava_security',
                priority: 'high',
                defaultSound: true,
                defaultVibrateTimings: true,
                color: '#FF5722'
              }
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                  category: 'security'
                }
              }
            }
          });
          console.log(`✅ Session termination notification sent to ${fcmToken.substring(0, 20)}... for user ${userId}:`, result);
          return result;
        } catch (error) {
          // Token might be invalid
          console.error(`❌ Error sending session termination notification to ${fcmToken.substring(0, 20)}...:`, error);
          return null;
        }
      } else {
        console.log(`⚠️ No notification sent - logoutReason: ${sessionData.logoutReason}, fcmToken: ${!!sessionData.fcmToken}`);
      }
      
      return null;
    } catch (error) {
      console.error('❌ Error in notifyUserOnSessionTermination:', error);
      return null;
    }
  });

// 🔥 NEW FUNCTION: Clean up expired sessions periodically
exports.cleanupExpiredSessions = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    console.log('🧹 Starting cleanup of expired sessions');
    
    const db = admin.firestore();
    const cutoffTime = admin.firestore.Timestamp.fromMillis(
      Date.now() - (30 * 24 * 60 * 60 * 1000) // 30 days ago
    );
    
    try {
      // Query for old session history entries
      const expiredSessions = await db.collectionGroup('history')
        .where('logoutTime', '<', cutoffTime)
        .limit(500) // Process in batches
        .get();
      
      if (expiredSessions.empty) {
        console.log('No expired sessions to clean up');
        return null;
      }
      
      const batch = db.batch();
      let deleteCount = 0;
      
      expiredSessions.forEach(doc => {
        batch.delete(doc.ref);
        deleteCount++;
      });
      
      await batch.commit();
      console.log(`✅ Cleaned up ${deleteCount} expired session records`);
      
      return null;
    } catch (error) {
      console.error('❌ Error cleaning up expired sessions:', error);
      return null;
    }
  });

// 🔥 NEW FUNCTION: Monitor and alert on suspicious session activity
exports.monitorSuspiciousActivity = functions.firestore
  .document('user_sessions/{userId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const userId = context.params.userId;
      
      // Check if device changed
      if (before.activeDeviceId !== after.activeDeviceId) {
        console.log(`🔄 Device change detected for user ${userId}`);
        console.log(`Previous device: ${before.activeDeviceId}`);
        console.log(`New device: ${after.activeDeviceId}`);
        
        // Get time difference between sessions
        const previousLogin = before.lastLoginTime;
        const newLogin = after.lastLoginTime;
        
        if (previousLogin && newLogin) {
          const timeDiff = newLogin.toMillis() - previousLogin.toMillis();
          const hoursDiff = timeDiff / (1000 * 60 * 60);
          
          // If login happened within 1 hour of previous login, it might be suspicious
          if (hoursDiff < 1) {
            console.log(`⚠️ Suspicious activity: User ${userId} switched devices within ${hoursDiff.toFixed(2)} hours`);
            
            // Get device info for better logging
            const previousDeviceInfo = before.deviceInfo || {};
            const newDeviceInfo = after.deviceInfo || {};
            
            // Log the suspicious activity with device details
            await admin.firestore().collection('security_logs').add({
              userId: userId,
              type: 'SUSPICIOUS_DEVICE_SWITCH',
              previousDevice: {
                id: before.activeDeviceId,
                info: previousDeviceInfo,
              },
              newDevice: {
                id: after.activeDeviceId,
                info: newDeviceInfo,
              },
              timeDifference: hoursDiff,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              severity: hoursDiff < 0.5 ? 'HIGH' : 'MEDIUM',
            });
            
            console.log(`📝 Suspicious activity logged for user ${userId}`);
          }
        }
      }
      
      return null;
    } catch (error) {
      console.error('❌ Error monitoring suspicious activity:', error);
      return null;
    }
  });

// 🔥 NEW FUNCTION: Get device management statistics (for admin)
exports.getDeviceManagementStats = functions.https.onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    
    // Get active sessions count
    const activeSessions = await db.collection('user_sessions').get();
    
    // Get session terminations in last 24 hours
    const twentyFourHoursAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - 24 * 60 * 60 * 1000);
    const recentTerminations = await db.collectionGroup('history')
      .where('logoutReason', '==', 'Logged in on another device')
      .where('logoutTime', '>', twentyFourHoursAgo)
      .get();
    
    // Get suspicious activities in last 24 hours
    const suspiciousActivities = await db.collection('security_logs')
      .where('type', '==', 'SUSPICIOUS_DEVICE_SWITCH')
      .where('timestamp', '>', twentyFourHoursAgo)
      .get();
    
    // Count by platform
    let platformStats = {
      android: 0,
      ios: 0,
      unknown: 0,
    };
    
    activeSessions.forEach(doc => {
      const data = doc.data();
      const platform = data.deviceInfo?.platform || 'unknown';
      platformStats[platform] = (platformStats[platform] || 0) + 1;
    });
    
    const stats = {
      activeSessions: {
        total: activeSessions.size,
        byPlatform: platformStats,
      },
      last24Hours: {
        deviceSwitches: recentTerminations.size,
        suspiciousActivities: suspiciousActivities.size,
      },
      timestamp: new Date().toISOString(),
    };
    
    res.status(200).json(stats);
    
  } catch (error) {
    console.error('❌ Error getting device management stats:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// 🔥 NEW FUNCTION: Force logout user from all devices (admin function)
exports.forceLogoutUser = functions.https.onRequest(async (req, res) => {
  try {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }
    
    const { userId, reason } = req.body;
    
    if (!userId) {
      res.status(400).json({ error: 'userId is required' });
      return;
    }
    
    const db = admin.firestore();
    
    // Get current session
    const sessionDoc = await db.collection('user_sessions').doc(userId).get();
    
    if (!sessionDoc.exists) {
      res.status(404).json({ error: 'No active session found for user' });
      return;
    }
    
    const sessionData = sessionDoc.data();
    
    // Add to history before clearing
    await db.collection('user_sessions')
      .doc(userId)
      .collection('history')
      .add({
        deviceId: sessionData.activeDeviceId,
        fcmToken: sessionData.activeDeviceFcmToken,
        deviceInfo: sessionData.deviceInfo,
        loginTime: sessionData.lastLoginTime,
        logoutTime: admin.firestore.FieldValue.serverTimestamp(),
        logoutReason: reason || 'Force logout by admin',
        platform: sessionData.deviceInfo?.platform || 'unknown',
      });
    
    // Delete the session
    await db.collection('user_sessions').doc(userId).delete();
    
    // Send notification if FCM token exists
    if (sessionData.activeDeviceFcmToken) {
      try {
        await admin.messaging().send({
          token: sessionData.activeDeviceFcmToken,
          notification: {
            title: '🔐 Account Security',
            body: 'Your session has been terminated by an administrator for security reasons.',
          },
          data: {
            type: 'ADMIN_LOGOUT',
            reason: reason || 'Administrative action',
            timestamp: new Date().toISOString(),
          }
        });
        console.log('Force logout notification sent');
      } catch (notificationError) {
        console.error('Error sending force logout notification:', notificationError);
      }
    }
    
    res.status(200).json({ 
      message: 'User successfully logged out from all devices',
      userId: userId,
      reason: reason || 'Force logout by admin'
    });
    
  } catch (error) {
    console.error('❌ Error forcing user logout:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// 🚀 NEW: Send welcome notification on user registration
exports.sendWelcomeNotification = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    try {
      const userData = snap.data();
      const userId = context.params.userId;
      
      console.log(`New user registered: ${userId}`);
      
      // Wait a bit for FCM token to be set
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      // Get updated user data with FCM token
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      const updatedUserData = userDoc.data();
      
      if (updatedUserData && updatedUserData.fcmToken) {
        const payload = {
          notification: {
            title: 'Welcome to Thintava! 🍽️',
            body: 'Start exploring our delicious menu and place your first order!',
          },
          data: {
            type: 'WELCOME',
            userId: userId,
          }
        };
        
        const result = await admin.messaging().send({
          token: updatedUserData.fcmToken,
          notification: payload.notification,
          data: payload.data
        });
        
        console.log('Welcome notification sent successfully:', result);
        return result;
      } else {
        console.log('No FCM token available for welcome notification');
        return null;
      }
    } catch (error) {
      console.error('Error sending welcome notification:', error);
      return null;
    }
  });

// ============================================================================
// NEW RAZORPAY FUNCTIONS - AUTO-CAPTURE INTEGRATION
// ============================================================================

// 🔥 Create Razorpay order for auto-capture
exports.createRazorpayOrder = functions.https.onCall(async (data, context) => {
  try {
    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { amount, currency = 'INR', receipt, notes = {} } = data;

    // Validate required fields
    if (!amount || amount <= 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Valid amount is required');
    }

    console.log(`🔄 Creating Razorpay order for user ${context.auth.uid}, amount: ${amount}`);

    // Create order with Razorpay
    const orderOptions = {
      amount: amount, // Amount in paise
      currency: currency,
      receipt: receipt || `order_${Date.now()}`,
      payment_capture: 1, // 🔑 AUTO-CAPTURE ENABLED
      notes: {
        ...notes,
        userId: context.auth.uid,
        userEmail: context.auth.token.email || '',
        createdAt: new Date().toISOString(),
        autoCaptureEnabled: 'true',
      }
    };

    const order = await razorpay.orders.create(orderOptions);
    
    console.log(`✅ Razorpay order created with auto-capture: ${order.id}`);

    // Store order details in Firestore for tracking
    await admin.firestore().collection('razorpay_orders').doc(order.id).set({
      razorpayOrderId: order.id,
      userId: context.auth.uid,
      userEmail: context.auth.token.email || '',
      amount: order.amount,
      currency: order.currency,
      status: order.status,
      receipt: order.receipt,
      notes: order.notes,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      autoCaptureEnabled: true,
    });

    return {
      success: true,
      order: {
        id: order.id,
        amount: order.amount,
        currency: order.currency,
        receipt: order.receipt,
        status: order.status,
        autoCaptureEnabled: true,
      }
    };

  } catch (error) {
    console.error('❌ Error creating Razorpay order:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', 'Failed to create payment order');
  }
});

// 🔥 Webhook to handle Razorpay events (for auto-capture tracking)
exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
  try {
    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }

    const signature = req.headers['x-razorpay-signature'];
    const body = JSON.stringify(req.body);
    
    // Verify webhook signature
    const expectedSignature = crypto
      .createHmac('sha256', functions.config().razorpay.webhook_secret)
      .update(body)
      .digest('hex');

    if (signature !== expectedSignature) {
      console.error('❌ Invalid webhook signature');
      return res.status(400).send('Invalid signature');
    }

    const event = req.body;
    console.log(`📨 Razorpay webhook received: ${event.event}`);

    // Handle different events
    switch (event.event) {
      case 'payment.captured':
        await handlePaymentCaptured(event.payload.payment.entity);
        break;
        
      case 'payment.failed':
        await handlePaymentFailed(event.payload.payment.entity);
        break;
        
      case 'payment.authorized':
        await handlePaymentAuthorized(event.payload.payment.entity);
        break;
        
      case 'order.paid':
        await handleOrderPaid(event.payload.order.entity);
        break;
        
      default:
        console.log(`Unhandled event type: ${event.event}`);
    }

    res.status(200).send('OK');

  } catch (error) {
    console.error('❌ Error processing webhook:', error);
    res.status(500).send('Internal Server Error');
  }
});

// Helper function to handle payment authorized event
async function handlePaymentAuthorized(payment) {
  try {
    console.log(`💳 Payment authorized: ${payment.id} for amount ${payment.amount} - waiting for auto-capture`);
    
    // Update payment status in Firestore
    await admin.firestore().collection('razorpay_payments').doc(payment.id).set({
      paymentId: payment.id,
      orderId: payment.order_id,
      amount: payment.amount,
      status: 'authorized',
      authorizedAt: admin.firestore.FieldValue.serverTimestamp(),
      method: payment.method,
      razorpayData: payment,
      awaitingCapture: true,
    }, { merge: true });

    console.log(`✅ Payment ${payment.id} marked as authorized - auto-capture should happen within 12 minutes`);

  } catch (error) {
    console.error('❌ Error handling payment authorized:', error);
  }
}

// Helper function to handle payment captured event
async function handlePaymentCaptured(payment) {
  try {
    console.log(`✅ Payment auto-captured: ${payment.id} for amount ${payment.amount}`);
    
    // Update payment status in Firestore
    await admin.firestore().collection('razorpay_payments').doc(payment.id).set({
      paymentId: payment.id,
      orderId: payment.order_id,
      amount: payment.amount,
      status: 'captured',
      capturedAt: admin.firestore.FieldValue.serverTimestamp(),
      method: payment.method,
      razorpayData: payment,
      awaitingCapture: false,
      autoCaptured: true,
    }, { merge: true });

    // Find and update the corresponding order
    const ordersSnapshot = await admin.firestore()
      .collection('orders')
      .where('paymentId', '==', payment.id)
      .limit(1)
      .get();

    if (!ordersSnapshot.empty) {
      const orderDoc = ordersSnapshot.docs[0];
      await orderDoc.ref.update({
        paymentCaptured: true,
        paymentCapturedAt: admin.firestore.FieldValue.serverTimestamp(),
        paymentMethod: payment.method,
        autoCaptured: true,
      });
      
      console.log(`✅ Order ${orderDoc.id} updated with auto-capture status`);

      // Send notification to kitchen about confirmed payment
      const kitchenUsers = await admin.firestore().collection('users')
        .where('role', '==', 'kitchen')
        .get();

      if (!kitchenUsers.empty) {
        const kitchenUser = kitchenUsers.docs[0].data();
        const kitchenFcmToken = kitchenUser.fcmToken;

        if (kitchenFcmToken) {
          await admin.messaging().send({
            token: kitchenFcmToken,
            notification: {
              title: '💰 Payment Confirmed',
              body: `Order ${orderDoc.id.substring(0, 6)} payment captured automatically. Start preparation!`,
            },
            data: {
              type: 'PAYMENT_CAPTURED',
              orderId: orderDoc.id,
              paymentId: payment.id,
            }
          });
        }
      }
    }

  } catch (error) {
    console.error('❌ Error handling payment captured:', error);
  }
}

// Helper function to handle payment failed event
async function handlePaymentFailed(payment) {
  try {
    console.log(`❌ Payment failed: ${payment.id} - ${payment.error_description}`);
    
    // Update payment status
    await admin.firestore().collection('razorpay_payments').doc(payment.id).set({
      paymentId: payment.id,
      orderId: payment.order_id,
      amount: payment.amount,
      status: 'failed',
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
      errorCode: payment.error_code,
      errorDescription: payment.error_description,
      razorpayData: payment,
    }, { merge: true });

    // Handle order cleanup if needed
    const ordersSnapshot = await admin.firestore()
      .collection('orders')
      .where('paymentId', '==', payment.id)
      .limit(1)
      .get();

    if (!ordersSnapshot.empty) {
      const orderDoc = ordersSnapshot.docs[0];
      await orderDoc.ref.update({
        paymentFailed: true,
        paymentFailedAt: admin.firestore.FieldValue.serverTimestamp(),
        paymentError: payment.error_description,
        status: 'Payment Failed',
      });
      
      console.log(`❌ Order ${orderDoc.id} marked as payment failed`);
    }

  } catch (error) {
    console.error('❌ Error handling payment failed:', error);
  }
}

// Helper function to handle order paid event
async function handleOrderPaid(order) {
  try {
    console.log(`💰 Order paid: ${order.id} for amount ${order.amount_paid}`);
    
    // Update order status
    await admin.firestore().collection('razorpay_orders').doc(order.id).update({
      status: 'paid',
      amountPaid: order.amount_paid,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  } catch (error) {
    console.error('❌ Error handling order paid:', error);
  }
}

// 🔥 Function to get payment analytics (for admin)
exports.getPaymentAnalytics = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    // Check if user is admin
    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    if (!userDoc.exists || userDoc.data().role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }

    const { startDate, endDate } = data;
    const start = startDate ? admin.firestore.Timestamp.fromDate(new Date(startDate)) : 
                  admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000));
    const end = endDate ? admin.firestore.Timestamp.fromDate(new Date(endDate)) : 
                admin.firestore.Timestamp.now();

    // Get payment statistics
    const paymentsSnapshot = await admin.firestore()
      .collection('razorpay_payments')
      .where('capturedAt', '>=', start)
      .where('capturedAt', '<=', end)
      .get();

    let totalAmount = 0;
    let totalCount = 0;
    let autoCapturedCount = 0;
    const methodStats = {};
    
    paymentsSnapshot.forEach(doc => {
      const payment = doc.data();
      if (payment.status === 'captured') {
        totalAmount += payment.amount || 0;
        totalCount++;
        
        if (payment.autoCaptured) {
          autoCapturedCount++;
        }
        
        const method = payment.method || 'unknown';
        methodStats[method] = (methodStats[method] || 0) + 1;
      }
    });

    return {
      success: true,
      analytics: {
        totalAmount: totalAmount,
        totalCount: totalCount,
        autoCapturedCount: autoCapturedCount,
        autoCaptureRate: totalCount > 0 ? (autoCapturedCount / totalCount * 100).toFixed(2) : 0,
        averageAmount: totalCount > 0 ? totalAmount / totalCount : 0,
        methodBreakdown: methodStats,
        period: {
          start: start.toDate().toISOString(),
          end: end.toDate().toISOString(),
        }
      }
    };

  } catch (error) {
    console.error('❌ Error getting payment analytics:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get analytics');
  }
});

// 🔥 Clean up expired reservations for stock management
exports.cleanupExpiredReservations = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    console.log('🧹 Starting cleanup of expired stock reservations');
    
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    
    try {
      // Query for expired reservations
      const expiredReservations = await db.collection('stockReservations')
        .where('status', '==', 'active')
        .where('expiresAt', '<', now)
        .limit(100)
        .get();
      
      if (expiredReservations.empty) {
        console.log('No expired reservations to clean up');
        return null;
      }
      
      const batch = db.batch();
      let cleanupCount = 0;
      
      // Group reservations by item to batch stock updates
      const itemUpdates = {};
      
      expiredReservations.forEach(doc => {
        const reservation = doc.data();
        
        // Update reservation status
        batch.update(doc.ref, {
          status: 'expired',
          expiredAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        // Track stock to release
        if (!itemUpdates[reservation.itemId]) {
          itemUpdates[reservation.itemId] = 0;
        }
        itemUpdates[reservation.itemId] += reservation.quantity;
        cleanupCount++;
      });
      
      // Update menu items to release reserved stock
      for (const [itemId, quantityToRelease] of Object.entries(itemUpdates)) {
        const itemRef = db.collection('menuItems').doc(itemId);
        const itemDoc = await itemRef.get();
        
        if (itemDoc.exists) {
          const itemData = itemDoc.data();
          const currentReserved = itemData.reservedQuantity || 0;
          const newReserved = Math.max(0, currentReserved - quantityToRelease);
          
          batch.update(itemRef, {
            reservedQuantity: newReserved,
            lastReservationUpdate: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
      
      await batch.commit();
      console.log(`✅ Cleaned up ${cleanupCount} expired reservations and released stock for ${Object.keys(itemUpdates).length} items`);
      
      return null;
    } catch (error) {
      console.error('❌ Error cleaning up expired reservations:', error);
      return null;
    }
  });

// 🔥 Initialize reserved quantity field for existing menu items (one-time migration)
exports.initializeReservedQuantityField = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    // Check if user is admin
    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    if (!userDoc.exists || userDoc.data().role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }

    console.log('🔄 Initializing reservedQuantity field for existing menu items');

    const snapshot = await admin.firestore().collection('menuItems').get();
    const batch = admin.firestore().batch();
    let updateCount = 0;

    snapshot.forEach(doc => {
      const data = doc.data();
      if (!data.hasOwnProperty('reservedQuantity')) {
        batch.update(doc.ref, {
          reservedQuantity: 0,
          lastReservationUpdate: admin.firestore.FieldValue.serverTimestamp(),
        });
        updateCount++;
      }
    });

    if (updateCount > 0) {
      await batch.commit();
      console.log(`✅ Initialized reservedQuantity field for ${updateCount} menu items`);
    } else {
      console.log('ℹ️ All menu items already have reservedQuantity field');
    }

    return {
      success: true,
      message: `Initialized reservedQuantity field for ${updateCount} menu items`,
      updatedCount: updateCount,
    };

  } catch (error) {
    console.error('❌ Error initializing reservedQuantity field:', error);
    throw new functions.https.HttpsError('internal', 'Failed to initialize fields');
  }
});