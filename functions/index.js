// functions/index.js - COMPLETE WITH RESERVATION SYSTEM
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

exports.notifyKitchenOnNewOrder = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, context) => {
    try {
      const newOrder = snap.data();
      const orderId = context.params.orderId;

      console.log('🚀 FIXED: New order created:', orderId);
      console.log('📦 Order details:', JSON.stringify(newOrder, null, 2));

      // Step 1: Find ALL kitchen users (not just the first one)
      console.log('🔍 Looking for ALL kitchen users...');
      const kitchenUsersQuery = await admin.firestore().collection('users')
        .where('role', '==', 'kitchen')
        .get();

      if (kitchenUsersQuery.empty) {
        console.error('❌ CRITICAL: No kitchen users found!');
        return null;
      }

      console.log(`✅ Found ${kitchenUsersQuery.docs.length} kitchen user(s)`);

      // Step 2: Calculate order details
      let itemCount = 0;
      if (newOrder.items && Array.isArray(newOrder.items)) {
        itemCount = newOrder.items.reduce((total, item) => {
          return total + (item.quantity || 1);
        }, 0);
      }

      console.log(`📦 Order contains ${itemCount} items`);

      // Step 3: Send notifications to ALL kitchen users
      let successCount = 0;
      let failureCount = 0;
      const notificationPromises = [];

      for (const kitchenUserDoc of kitchenUsersQuery.docs) {
        const kitchenUserData = kitchenUserDoc.data();
        const kitchenUserId = kitchenUserDoc.id;
        const kitchenFcmToken = kitchenUserData.fcmToken;
        const kitchenEmail = kitchenUserData.email || 'Unknown';

        console.log(`👨‍🍳 Processing kitchen user: ${kitchenEmail}`);

        if (!kitchenFcmToken || kitchenFcmToken.trim() === '') {
          console.warn(`⚠️ Kitchen user ${kitchenEmail} has no FCM token`);
          failureCount++;
          continue;
        }

        console.log(`✅ Sending notification to ${kitchenEmail}`);

        // Create notification payload with better formatting
        const payload = {
          notification: {
            title: '🔔 New Order Alert!',
            body: `Order #${orderId.substring(0, 6)} • ${itemCount} items • Customer: ${newOrder.userEmail || 'Unknown'}`,
          },
          data: {
            type: 'NEW_ORDER',
            orderId: orderId,
            itemCount: itemCount.toString(),
            customerEmail: newOrder.userEmail || 'Unknown',
            action: 'view_kitchen_dashboard',
            timestamp: new Date().toISOString(),
          },
          // Enhanced Android settings for better delivery
          android: {
            priority: 'high',
            notification: {
              channelId: 'thintava_orders',
              priority: 'high',
              defaultSound: true,
              defaultVibrateTimings: true,
              icon: '@mipmap/ic_launcher',
              color: '#FFB703',
              tag: `order_${orderId}`, // Prevent duplicate notifications
            }
          },
          // Enhanced iOS settings
          apns: {
            payload: {
              aps: {
                alert: {
                  title: '🔔 New Order Alert!',
                  body: `Order #${orderId.substring(0, 6)} • ${itemCount} items`,
                },
                sound: 'default',
                badge: 1,
                'content-available': 1, // Enable background processing
              }
            }
          }
        };

        // Create individual notification promise
        const notificationPromise = admin.messaging().send({
          token: kitchenFcmToken,
          ...payload
        }).then(result => {
          console.log(`✅ SUCCESS: Notification sent to ${kitchenEmail} - Result: ${result}`);
          successCount++;

          // Update kitchen user stats
          return kitchenUserDoc.ref.update({
            lastNotificationSent: admin.firestore.FieldValue.serverTimestamp(),
            lastOrderNotified: orderId,
            notificationCount: admin.firestore.FieldValue.increment(1),
          });

        }).catch(error => {
          console.error(`❌ FAILED: Could not send notification to ${kitchenEmail}:`, error);
          failureCount++;

          // Handle invalid tokens
          if (error.code === 'messaging/registration-token-not-registered' ||
            error.code === 'messaging/invalid-registration-token') {
            console.log(`🔧 Clearing invalid FCM token for ${kitchenEmail}`);
            return kitchenUserDoc.ref.update({
              fcmToken: admin.firestore.FieldValue.delete(),
              tokenClearedAt: admin.firestore.FieldValue.serverTimestamp(),
              tokenClearReason: error.code,
            });
          }

          return null;
        });

        notificationPromises.push(notificationPromise);
      }

      // Wait for all notifications to complete
      console.log(`📤 Sending notifications to ${notificationPromises.length} kitchen users...`);
      await Promise.allSettled(notificationPromises);

      console.log(`📊 FINAL RESULT: ${successCount} notifications sent successfully, ${failureCount} failed`);

      if (successCount > 0) {
        console.log(`🎉 SUCCESS: Notifications sent to ${successCount} kitchen users for order ${orderId}`);
        return {
          success: true,
          orderId: orderId,
          sent: successCount,
          failed: failureCount,
          kitchenUsersTotal: kitchenUsersQuery.docs.length
        };
      } else {
        console.error(`💥 COMPLETE FAILURE: No notifications were sent for order ${orderId}`);
        return {
          success: false,
          orderId: orderId,
          sent: 0,
          failed: failureCount,
          error: 'No valid FCM tokens found'
        };
      }

    } catch (error) {
      console.error(`💥 CRITICAL ERROR in kitchen notification function for order ${context.params.orderId}:`, error);
      console.error('Full error details:', error.stack);
      return {
        success: false,
        orderId: context.params.orderId,
        error: error.message
      };
    }
  });

// 🧪 Test function to manually trigger kitchen notifications
exports.testKitchenNotifications = functions.https.onRequest(async (req, res) => {
  try {
    console.log('🧪 Manual kitchen notification test started');

    // Create a test order document
    const testOrderId = `manual_test_${Date.now()}`;
    const testOrderData = {
      userId: 'test_user_manual',
      userEmail: 'test@manualtest.com',
      status: 'Placed',
      items: [
        { name: 'Test Pizza 🍕', quantity: 2, price: 200 },
        { name: 'Test Drink 🥤', quantity: 1, price: 50 }
      ],
      totalAmount: 450,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentStatus: 'completed',
      testOrder: true,
      manualTest: true,
    };

    // Create the test order (this will trigger the notification function)
    await admin.firestore().collection('orders').doc(testOrderId).set(testOrderData);

    console.log(`✅ Test order created: ${testOrderId}`);

    // Wait a moment for the trigger to process
    await new Promise(resolve => setTimeout(resolve, 3000));

    res.status(200).json({
      success: true,
      message: 'Test order created successfully',
      testOrderId: testOrderId,
      instruction: 'Check Firebase Console logs and kitchen devices for notifications'
    });

  } catch (error) {
    console.error('❌ Error in manual test:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
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

      // Calculate item count from order data
      let itemCount = 0;
      if (orderData.items && Array.isArray(orderData.items)) {
        itemCount = orderData.items.reduce((total, item) => {
          return total + (item.quantity || 1);
        }, 0);
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
          itemCount: itemCount.toString(),
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
            timestamp: sessionData.logoutTime ? sessionData.logoutTime.toString() : new Date().toISOString(),
            device: deviceInfo,
          }
        };

        const result = await admin.messaging().send({
          token: fcmToken,
          notification: payload.notification,
          data: payload.data
        });

        console.log('Session termination notification sent successfully:', result);
        return result;
      } else {
        console.log('Not sending session notification - no logout reason or FCM token');
        return null;
      }
    } catch (error) {
      console.error('Error sending session termination notification:', error);
      return null;
    }
  });

// 🔥 Enhanced welcome notification function for new user registrations
exports.sendWelcomeNotification = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    try {
      const newUserData = snap.data();
      const userId = context.params.userId;

      console.log(`🎉 New user registered: ${userId}`);

      // Wait 5 seconds to ensure FCM token is saved
      await new Promise(resolve => setTimeout(resolve, 5000));

      // Get updated user data with FCM token
      const updatedUserDoc = await admin.firestore().collection('users').doc(userId).get();
      const updatedUserData = updatedUserDoc.data();

      if (updatedUserData && updatedUserData.fcmToken) {
        console.log(`📱 Sending welcome notification to: ${updatedUserData.email}`);

        const payload = {
          notification: {
            title: '🎉 Welcome to Thintava! 🍽️',
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
// RAZORPAY FUNCTIONS - AUTO-CAPTURE INTEGRATION WITH RESERVATION SYSTEM
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
      }
    };

    const razorpayOrder = await razorpay.orders.create(orderOptions);

    console.log(`✅ Razorpay order created: ${razorpayOrder.id}`);

    // Store order info in Firestore for tracking
    await admin.firestore().collection('razorpay_orders').doc(razorpayOrder.id).set({
      razorpayOrderId: razorpayOrder.id,
      userId: context.auth.uid,
      amount: amount,
      currency: currency,
      status: razorpayOrder.status,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      notes: orderOptions.notes,
      autoCaptureEnabled: true,
    });

    // Return order details to client
    return {
      success: true,
      orderId: razorpayOrder.id,
      amount: razorpayOrder.amount,
      currency: razorpayOrder.currency,
      status: razorpayOrder.status,
      autoCaptureEnabled: true,
    };

  } catch (error) {
    console.error('❌ Error creating Razorpay order:', error);
    throw new functions.https.HttpsError('internal', 'Failed to create order', error.message);
  }
});

// 🔥 Verify Razorpay payment WITH RESERVATION SYSTEM
exports.verifyRazorpayPayment = functions.https.onCall(async (data, context) => {
  try {
    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { razorpay_payment_id, razorpay_order_id, razorpay_signature } = data;

    // Validate required fields
    if (!razorpay_payment_id || !razorpay_order_id || !razorpay_signature) {
      throw new functions.https.HttpsError('invalid-argument', 'Payment ID, Order ID, and Signature are required');
    }

    console.log(`🔍 Verifying payment with reservation: ${razorpay_payment_id} for order: ${razorpay_order_id}`);

    // Create signature verification string
    const generated_signature = crypto
      .createHmac('sha256', functions.config().razorpay.key_secret)
      .update(`${razorpay_order_id}|${razorpay_payment_id}`)
      .digest('hex');

    // Verify signature
    const isSignatureValid = generated_signature === razorpay_signature;

    if (!isSignatureValid) {
      console.log('❌ Invalid payment signature - failing reservation');
      
      // Fail any associated reservation
      await failReservationByPaymentId(razorpay_order_id);
      
      throw new functions.https.HttpsError('permission-denied', 'Invalid payment signature');
    }

    console.log('✅ Payment signature verified successfully');

    // Get payment details from Razorpay
    const payment = await razorpay.payments.fetch(razorpay_payment_id);

    // Complete the reservation
    await completeReservationByPaymentId(razorpay_order_id);

    // Store payment info in Firestore
    await admin.firestore().collection('razorpay_payments').doc(razorpay_payment_id).set({
      paymentId: razorpay_payment_id,
      orderId: razorpay_order_id,
      signature: razorpay_signature,
      amount: payment.amount,
      status: payment.status,
      method: payment.method,
      userId: context.auth.uid,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      razorpayData: payment,
      autoCaptured: payment.captured || false,
      reservationCompleted: true,
    });

    // Update order status
    await admin.firestore().collection('razorpay_orders').doc(razorpay_order_id).update({
      paymentId: razorpay_payment_id,
      paymentStatus: payment.status,
      paymentVerified: true,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      autoCaptured: payment.captured || false,
      reservationCompleted: true,
    });

    console.log(`✅ Payment verification and reservation completion done for: ${razorpay_payment_id}`);

    return {
      success: true,
      paymentId: razorpay_payment_id,
      status: payment.status,
      amount: payment.amount,
      method: payment.method,
      captured: payment.captured || false,
      verified: true,
      reservationCompleted: true,
    };

  } catch (error) {
    console.error('❌ Error verifying payment with reservation:', error);
    
    // Try to fail reservation on any error
    if (data.razorpay_order_id) {
      await failReservationByPaymentId(data.razorpay_order_id);
    }
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Payment verification failed', error.message);
  }
});

// 🔥 Razorpay webhook handler WITH RESERVATION SYSTEM
exports.handleRazorpayWebhook = functions.https.onRequest(async (req, res) => {
  try {
    console.log('📨 Razorpay webhook received (with reservations)');

    // Verify webhook signature
    const webhookSignature = req.headers['x-razorpay-signature'];
    const webhookSecret = functions.config().razorpay.webhook_secret;

    if (webhookSecret && webhookSignature) {
      const expectedSignature = crypto
        .createHmac('sha256', webhookSecret)
        .update(JSON.stringify(req.body))
        .digest('hex');

      if (expectedSignature !== webhookSignature) {
        console.log('❌ Invalid webhook signature');
        return res.status(400).send('Invalid signature');
      }
    }

    const event = req.body;
    console.log(`📨 Webhook event: ${event.event}`);

    // Handle different webhook events
    switch (event.event) {
      case 'payment.captured':
        await handlePaymentCaptured(event.payload.payment.entity);
        break;

      case 'payment.failed':
        await handlePaymentFailed(event.payload.payment.entity);
        break;

      case 'order.paid':
        await handleOrderPaid(event.payload.order.entity);
        break;

      default:
        console.log(`🔄 Unhandled webhook event: ${event.event}`);
    }

    res.status(200).send('OK');
  } catch (error) {
    console.error('❌ Error handling webhook with reservations:', error);
    res.status(500).send('Internal server error');
  }
});

// Helper function to handle payment captured event WITH RESERVATION
async function handlePaymentCaptured(payment) {
  try {
    console.log(`✅ Payment auto-captured with reservation: ${payment.id} for amount ${payment.amount}`);

    // Complete the reservation
    await completeReservationByPaymentId(payment.order_id);

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
      reservationCompleted: true,
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
        reservationCompleted: true,
      });

      console.log(`✅ Order ${orderDoc.id} updated with auto-capture and reservation completion status`);

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
    console.error('❌ Error handling payment captured with reservation:', error);
  }
}

// Helper function to handle payment failed event WITH RESERVATION
async function handlePaymentFailed(payment) {
  try {
    console.log(`❌ Payment failed with reservation: ${payment.id} - ${payment.error_description}`);

    // Fail the reservation to release items
    await failReservationByPaymentId(payment.order_id);

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
      reservationFailed: true,
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
        reservationFailed: true,
      });

      console.log(`❌ Order ${orderDoc.id} marked as payment failed with reservation release`);
    }

  } catch (error) {
    console.error('❌ Error handling payment failed with reservation:', error);
  }
}

// Helper function to handle order paid event
async function handleOrderPaid(order) {
  try {
    console.log(`💰 Order paid with reservation: ${order.id} for amount ${order.amount_paid}`);

    // Update order status
    await admin.firestore().collection('razorpay_orders').doc(order.id).update({
      status: 'paid',
      amountPaid: order.amount_paid,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      reservationHandled: true,
    });

  } catch (error) {
    console.error('❌ Error handling order paid with reservation:', error);
  }
}

// ============================================================================
// RESERVATION SYSTEM FUNCTIONS - NEW
// ============================================================================

// IMMEDIATE FIX: Replace your cleanupExpiredReservations function with this version
// This version doesn't require a composite index

exports.cleanupExpiredReservations = functions.pubsub
  .schedule('every 1 minutes')
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      const db = admin.firestore();
      const now = admin.firestore.Timestamp.now();
      
      console.log('🔄 Starting reservation cleanup at:', now.toDate().toISOString());

      // ✅ FIX: Get ALL active reservations first (no composite index needed)
      const activeReservationsQuery = await db.collection('reservations')
        .where('status', '==', 'active')
        .get();

      console.log('📋 Found active reservations:', activeReservationsQuery.size);

      if (activeReservationsQuery.empty) {
        console.log('✅ No active reservations found');
        return { success: true, expiredReservations: 0 };
      }

      // ✅ FIX: Filter expired ones in code instead of Firestore query
      const batch = db.batch();
      let expiredCount = 0;
      const expiredReservations = [];

      activeReservationsQuery.forEach(doc => {
        const data = doc.data();
        const expiresAt = data.expiresAt;
        
        // Check if expired in JavaScript instead of Firestore query
        if (expiresAt.toMillis() <= now.toMillis()) {
          console.log(`⏰ Expiring reservation: ${doc.id} (Payment: ${data.paymentId})`);
          console.log(`   Expired by: ${Math.round((now.toMillis() - expiresAt.toMillis()) / (1000 * 60))} minutes`);
          
          batch.update(doc.ref, {
            status: 'expired',
            expiredAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          expiredReservations.push({
            id: doc.id,
            paymentId: data.paymentId,
            expiredBy: Math.round((now.toMillis() - expiresAt.toMillis()) / (1000 * 60))
          });
          
          expiredCount++;
        } else {
          const minutesLeft = Math.round((expiresAt.toMillis() - now.toMillis()) / (1000 * 60));
          console.log(`⏳ Reservation ${doc.id} expires in ${minutesLeft} minutes`);
        }
      });

      // Commit expired reservations
      if (expiredCount > 0) {
        await batch.commit();
        console.log(`✅ Successfully expired ${expiredCount} reservations:`, expiredReservations);
      } else {
        console.log('✅ No reservations need to be expired yet');
      }

      // Optional: Clean up old expired/failed reservations (older than 24 hours)
      // This uses a simple single-field query (no index needed)
      const twentyFourHoursAgo = admin.firestore.Timestamp.fromMillis(
        now.toMillis() - (24 * 60 * 60 * 1000)
      );

      const oldExpiredQuery = await db.collection('reservations')
        .where('status', '==', 'expired')
        .get();

      const oldFailedQuery = await db.collection('reservations')
        .where('status', '==', 'failed')
        .get();

      // Filter old ones in code
      const deleteBatch = db.batch();
      let deletedCount = 0;

      [...oldExpiredQuery.docs, ...oldFailedQuery.docs].forEach(doc => {
        const data = doc.data();
        const expiresAt = data.expiresAt;
        
        if (expiresAt.toMillis() <= twentyFourHoursAgo.toMillis()) {
          deleteBatch.delete(doc.ref);
          deletedCount++;
        }
      });

      if (deletedCount > 0) {
        await deleteBatch.commit();
        console.log(`🗑️ Cleaned up ${deletedCount} old reservations`);
      }

      return {
        success: true,
        expiredReservations: expiredCount,
        cleanedUpOld: deletedCount,
        totalActiveChecked: activeReservationsQuery.size,
        timestamp: now.toDate().toISOString(),
      };

    } catch (error) {
      console.error('❌ Error in reservation cleanup:', error);
      return {
        success: false,
        error: error.message,
        timestamp: new Date().toISOString(),
      };
    }
  });

// 🧪 IMMEDIATE TEST FUNCTION (works without index)
exports.testReservationExpiry = functions.https.onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    
    console.log('🧪 Testing reservation expiry logic');

    // Get all active reservations (no index needed)
    const activeReservations = await db.collection('reservations')
      .where('status', '==', 'active')
      .get();

    const results = [];
    let shouldExpireCount = 0;

    activeReservations.forEach(doc => {
      const data = doc.data();
      const expiresAt = data.expiresAt;
      const isExpired = expiresAt.toMillis() <= now.toMillis();
      const minutesDiff = Math.round((now.toMillis() - expiresAt.toMillis()) / (1000 * 60));

      const result = {
        id: doc.id,
        paymentId: data.paymentId,
        status: data.status,
        createdAt: data.createdAt.toDate().toISOString(),
        expiresAt: expiresAt.toDate().toISOString(),
        currentTime: now.toDate().toISOString(),
        isExpired: isExpired,
        minutesSinceExpiry: minutesDiff,
        shouldExpire: isExpired
      };

      if (isExpired) {
        shouldExpireCount++;
      }

      results.push(result);
    });

    res.status(200).json({
      success: true,
      currentTime: now.toDate().toISOString(),
      totalActiveReservations: activeReservations.size,
      shouldExpireCount: shouldExpireCount,
      reservations: results,
      message: shouldExpireCount > 0 
        ? `${shouldExpireCount} reservations should be expired` 
        : 'No reservations need expiring yet'
    });

  } catch (error) {
    console.error('❌ Test error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// 🔧 MANUAL CLEANUP (works without index)
exports.manualCleanupExpiredReservations = functions.https.onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    
    console.log('🔧 Manual cleanup starting');

    // Get all active reservations
    const activeReservations = await db.collection('reservations')
      .where('status', '==', 'active')
      .get();

    const batch = db.batch();
    let expiredCount = 0;
    const processedReservations = [];

    activeReservations.forEach(doc => {
      const data = doc.data();
      const expiresAt = data.expiresAt;
      const isExpired = expiresAt.toMillis() <= now.toMillis();
      const minutesDiff = Math.round((now.toMillis() - expiresAt.toMillis()) / (1000 * 60));

      processedReservations.push({
        id: doc.id,
        paymentId: data.paymentId,
        isExpired: isExpired,
        minutesSinceExpiry: minutesDiff
      });

      if (isExpired) {
        console.log(`🔧 Manually expiring: ${doc.id} (expired ${minutesDiff} minutes ago)`);
        batch.update(doc.ref, {
          status: 'expired',
          expiredAt: admin.firestore.FieldValue.serverTimestamp(),
          manuallyExpired: true,
        });
        expiredCount++;
      }
    });

    if (expiredCount > 0) {
      await batch.commit();
      console.log(`🔧 Manually expired ${expiredCount} reservations`);
    }

    res.status(200).json({
      success: true,
      message: `Manual cleanup completed - expired ${expiredCount} reservations`,
      totalActive: activeReservations.size,
      expiredCount: expiredCount,
      processedReservations: processedReservations
    });

  } catch (error) {
    console.error('❌ Manual cleanup error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// 🆕 Manual reservation cleanup trigger for testing
exports.manualReservationCleanup = functions.https.onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    
    // Find all expired active reservations
    const expiredQuery = await db.collection('reservations')
      .where('status', '==', 'active')
      .where('expiresAt', '<=', now)
      .get();

    const batch = db.batch();
    let count = 0;

    expiredQuery.forEach(doc => {
      batch.update(doc.ref, {
        status: 'expired',
        expiredAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      count++;
    });

    await batch.commit();

    res.status(200).json({
      success: true,
      expiredReservations: count,
      message: `Manually expired ${count} reservations`,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    console.error('Error in manual cleanup:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

// 🆕 Get reservation statistics (for admin monitoring)
exports.getReservationStats = functions.https.onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    
    const reservationsSnapshot = await db.collection('reservations').get();
    
    let stats = {
      total: 0,
      active: 0,
      completed: 0,
      failed: 0,
      expired: 0,
      totalValue: 0,
    };

    reservationsSnapshot.forEach(doc => {
      const data = doc.data();
      const status = data.status || 'active';
      const amount = data.totalAmount || 0;
      
      stats.total++;
      stats[status] = (stats[status] || 0) + 1;
      
      if (status === 'active') {
        stats.totalValue += amount;
      }
    });

    res.status(200).json({
      success: true,
      stats: stats,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    console.error('Error getting reservation stats:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

// 🆕 Get active reservations (for admin monitoring)
exports.getActiveReservations = functions.https.onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    
    const activeReservations = await db.collection('reservations')
      .where('status', '==', 'active')
      .orderBy('createdAt', 'desc')
      .get();

    const reservations = [];
    
    activeReservations.forEach(doc => {
      const data = doc.data();
      reservations.push({
        id: doc.id,
        paymentId: data.paymentId,
        items: data.items || [],
        totalAmount: data.totalAmount || 0,
        createdAt: data.createdAt.toDate().toISOString(),
        expiresAt: data.expiresAt.toDate().toISOString(),
        timeRemaining: Math.max(0, data.expiresAt.toMillis() - Date.now()),
      });
    });

    res.status(200).json({
      success: true,
      activeReservations: reservations,
      count: reservations.length,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    console.error('Error getting active reservations:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

// 🆕 Force expire a specific reservation (admin function)
exports.forceExpireReservation = functions.https.onRequest(async (req, res) => {
  try {
    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }

    const { reservationId } = req.body;

    if (!reservationId) {
      return res.status(400).json({ error: 'reservationId is required' });
    }

    const db = admin.firestore();
    const reservationRef = db.collection('reservations').doc(reservationId);
    const reservationDoc = await reservationRef.get();

    if (!reservationDoc.exists) {
      return res.status(404).json({ error: 'Reservation not found' });
    }

    const reservationData = reservationDoc.data();

    if (reservationData.status !== 'active') {
      return res.status(400).json({ 
        error: `Reservation is not active. Current status: ${reservationData.status}` 
      });
    }

    // Force expire the reservation
    await reservationRef.update({
      status: 'expired',
      expiredAt: admin.firestore.FieldValue.serverTimestamp(),
      forceExpired: true,
    });

    res.status(200).json({
      success: true,
      message: `Reservation ${reservationId} has been force expired`,
      paymentId: reservationData.paymentId,
    });

  } catch (error) {
    console.error('Error force expiring reservation:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

// ============================================================================
// RESERVATION HELPER FUNCTIONS
// ============================================================================

// Helper function to complete reservation by payment ID
async function completeReservationByPaymentId(paymentId) {
  try {
    const db = admin.firestore();
    
    const reservationQuery = await db.collection('reservations')
      .where('paymentId', '==', paymentId)
      .where('status', '==', 'active')
      .limit(1)
      .get();

    if (!reservationQuery.empty) {
      const reservationDoc = reservationQuery.docs[0];
      const reservationData = reservationDoc.data();
      
      // Update reservation status
      await reservationDoc.ref.update({
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Decrease actual stock
      const batch = db.batch();
      
      for (const item of reservationData.items) {
        const itemRef = db.collection('menuItems').doc(item.itemId);
        const itemDoc = await itemRef.get();
        
        if (itemDoc.exists) {
          const itemData = itemDoc.data();
          const hasUnlimitedStock = itemData.hasUnlimitedStock || false;
          
          if (!hasUnlimitedStock) {
            const currentStock = itemData.quantity || 0;
            const newStock = Math.max(0, currentStock - item.quantity);
            
            batch.update(itemRef, {
              quantity: newStock,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }
      }
      
      await batch.commit();
      
      console.log(`✅ Completed reservation: ${reservationDoc.id} for payment: ${paymentId}`);
      return true;
    }
    
    console.log(`⚠️ No active reservation found for payment: ${paymentId}`);
    return false;
  } catch (error) {
    console.error(`❌ Error completing reservation for payment ${paymentId}:`, error);
    return false;
  }
}

// Helper function to fail reservation by payment ID
async function failReservationByPaymentId(paymentId) {
  try {
    const db = admin.firestore();
    
    const reservationQuery = await db.collection('reservations')
      .where('paymentId', '==', paymentId)
      .where('status', '==', 'active')
      .limit(1)
      .get();

    if (!reservationQuery.empty) {
      const reservationDoc = reservationQuery.docs[0];
      
      await reservationDoc.ref.update({
        status: 'failed',
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      console.log(`✅ Failed reservation: ${reservationDoc.id} for payment: ${paymentId}`);
      return true;
    }
    
    console.log(`⚠️ No active reservation found to fail for payment: ${paymentId}`);
    return false;
  } catch (error) {
    console.error(`❌ Error failing reservation for payment ${paymentId}:`, error);
    return false;
  }
}

// ============================================================================
// EXISTING PAYMENT ANALYTICS AND ADMIN FUNCTIONS
// ============================================================================

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

    // Get payment data
    const paymentsSnapshot = await admin.firestore()
      .collection('razorpay_payments')
      .where('verifiedAt', '>=', start)
      .where('verifiedAt', '<=', end)
      .orderBy('verifiedAt', 'desc')
      .get();

    let totalAmount = 0;
    let successfulPayments = 0;
    let failedPayments = 0;
    const paymentMethods = {};

    paymentsSnapshot.forEach(doc => {
      const payment = doc.data();

      if (payment.status === 'captured') {
        totalAmount += payment.amount || 0;
        successfulPayments++;
      } else if (payment.status === 'failed') {
        failedPayments++;
      }

      const method = payment.method || 'unknown';
      paymentMethods[method] = (paymentMethods[method] || 0) + 1;
    });

    return {
      success: true,
      analytics: {
        totalAmount: totalAmount,
        successfulPayments: successfulPayments,
        failedPayments: failedPayments,
        totalTransactions: successfulPayments + failedPayments,
        successRate: successfulPayments > 0 ? (successfulPayments / (successfulPayments + failedPayments)) * 100 : 0,
        paymentMethods: paymentMethods,
        period: {
          start: start.toDate().toISOString(),
          end: end.toDate().toISOString(),
        }
      }
    };

  } catch (error) {
    console.error('❌ Error getting payment analytics:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get payment analytics', error.message);
  }
});

// 🔥 Function to refund a payment (for admin)
exports.refundPayment = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    // Check if user is admin
    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    if (!userDoc.exists || userDoc.data().role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }

    const { paymentId, amount, notes } = data;

    if (!paymentId) {
      throw new functions.https.HttpsError('invalid-argument', 'Payment ID is required');
    }

    console.log(`🔄 Processing refund for payment: ${paymentId}`);

    // Create refund with Razorpay
    const refundOptions = {
      payment_id: paymentId,
      notes: notes || { reason: 'Admin refund' }
    };

    if (amount) {
      refundOptions.amount = amount;
    }

    const refund = await razorpay.payments.refund(paymentId, refundOptions);

    // Store refund info in Firestore
    await admin.firestore().collection('razorpay_refunds').doc(refund.id).set({
      refundId: refund.id,
      paymentId: paymentId,
      amount: refund.amount,
      status: refund.status,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      processedBy: context.auth.uid,
      notes: refundOptions.notes,
      razorpayData: refund,
    });

    // Update payment record
    await admin.firestore().collection('razorpay_payments').doc(paymentId).update({
      refunded: true,
      refundId: refund.id,
      refundAmount: refund.amount,
      refundedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Refund processed: ${refund.id}`);

    return {
      success: true,
      refundId: refund.id,
      amount: refund.amount,
      status: refund.status,
    };

  } catch (error) {
    console.error('❌ Error processing refund:', error);
    throw new functions.https.HttpsError('internal', 'Failed to process refund', error.message);
  }
});

// 🔥 Function to get order status with payment info
exports.getOrderWithPaymentStatus = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { orderId } = data;

    if (!orderId) {
      throw new functions.https.HttpsError('invalid-argument', 'Order ID is required');
    }

    // Get order from either active orders or user's order history
    let orderDoc = await admin.firestore().collection('orders').doc(orderId).get();

    if (!orderDoc.exists) {
      // Try user's order history
      orderDoc = await admin.firestore()
        .collection('users')
        .doc(context.auth.uid)
        .collection('orderHistory')
        .doc(orderId)
        .get();
    }

    if (!orderDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Order not found');
    }

    const orderData = orderDoc.data();

    // Verify user owns this order
    if (orderData.userId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Access denied');
    }

    // Get payment information if available
    let paymentInfo = null;
    if (orderData.paymentId) {
      const paymentDoc = await admin.firestore()
        .collection('razorpay_payments')
        .doc(orderData.paymentId)
        .get();

      if (paymentDoc.exists) {
        const paymentData = paymentDoc.data();
        paymentInfo = {
          paymentId: paymentData.paymentId,
          status: paymentData.status,
          method: paymentData.method,
          amount: paymentData.amount,
          captured: paymentData.autoCaptured || false,
          verifiedAt: paymentData.verifiedAt,
          refunded: paymentData.refunded || false,
          reservationCompleted: paymentData.reservationCompleted || false,
        };
      }
    }

    return {
      success: true,
      order: {
        id: orderId,
        ...orderData,
        payment: paymentInfo,
      }
    };

  } catch (error) {
    console.error('❌ Error getting order with payment status:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to get order status', error.message);
  }
});

// ============================================================================
// DEVICE MANAGEMENT AND SESSION CLEANUP FUNCTIONS (KEEP)
// ============================================================================

// 🔥 Clean up expired session history
exports.cleanupExpiredSessions = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    try {
      const db = admin.firestore();
      const now = admin.firestore.Timestamp.now();

      // Clean up session history older than 30 days
      const thirtyDaysAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - 30 * 24 * 60 * 60 * 1000);

      // Get all session history documents older than 30 days
      const expiredSessions = await db.collectionGroup('history')
        .where('logoutTime', '<', thirtyDaysAgo)
        .limit(500) // Process in batches
        .get();

      if (expiredSessions.empty) {
        console.log('No expired session records to clean up');
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

// 🔥 Monitor and alert on suspicious session activity
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

// 🔥 Get device management statistics (for admin)
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

// 🔥 Force logout user from all devices (admin function)
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

    // Get user's current session
    const sessionDoc = await db.collection('user_sessions').doc(userId).get();

    if (sessionDoc.exists) {
      const sessionData = sessionDoc.data();

      // Store logout history
      if (sessionData.fcmToken) {
        await db.collection('user_sessions')
          .doc(userId)
          .collection('history')
          .add({
            sessionId: sessionData.sessionId || 'unknown',
            deviceId: sessionData.activeDeviceId || 'unknown',
            fcmToken: sessionData.fcmToken,
            logoutTime: admin.firestore.FieldValue.serverTimestamp(),
            logoutReason: reason || 'Admin forced logout',
            deviceInfo: sessionData.deviceInfo || {},
            adminForced: true,
          });
      }

      // Delete the active session
      await sessionDoc.ref.delete();

      // Revoke Firebase Auth tokens (optional)
      try {
        await admin.auth().revokeRefreshTokens(userId);
        console.log(`✅ Revoked refresh tokens for user ${userId}`);
      } catch (authError) {
        console.log(`⚠️ Could not revoke tokens for user ${userId}:`, authError);
      }

      console.log(`✅ Forced logout completed for user ${userId}`);
      res.status(200).json({
        success: true,
        message: `User ${userId} has been logged out from all devices`
      });
    } else {
      res.status(404).json({ error: 'No active session found for user' });
    }

  } catch (error) {
    console.error('❌ Error forcing user logout:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

console.log('🚀 Firebase Functions loaded successfully with RESERVATION SYSTEM enabled!');