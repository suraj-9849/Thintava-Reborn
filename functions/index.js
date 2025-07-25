// functions/index.js - COMPLETE WITH RAZORPAY INTEGRATION - FIXED PRICING ISSUE
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

// 🚀 Enhanced function: notify kitchen when a new order is created - FIXED PRICING
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

      // Calculate item count from order data
      let itemCount = 0;
      if (newOrder.items && Array.isArray(newOrder.items)) {
        itemCount = newOrder.items.reduce((total, item) => {
          return total + (item.quantity || 1);
        }, 0);
      }

      const payload = {
        notification: {
          title: 'New Order Received',
          body: `A new order #${context.params.orderId.substring(0, 6)} has been placed. ${itemCount} items total.`,
        },
        data: {
          type: 'NEW_ORDER',
          orderId: context.params.orderId,
          itemCount: itemCount.toString(),
          customerEmail: newOrder.userEmail || 'Unknown',
          // REMOVED: orderTotal to hide pricing
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

// 🚀 Enhanced function: notify user when order status changes - FIXED PRICING
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
          // REMOVED: orderTotal to hide pricing
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

// 🔥 Verify Razorpay payment
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

    console.log(`🔍 Verifying payment: ${razorpay_payment_id} for order: ${razorpay_order_id}`);

    // Create signature verification string
    const generated_signature = crypto
      .createHmac('sha256', functions.config().razorpay.key_secret)
      .update(`${razorpay_order_id}|${razorpay_payment_id}`)
      .digest('hex');

    // Verify signature
    const isSignatureValid = generated_signature === razorpay_signature;

    if (!isSignatureValid) {
      console.log('❌ Invalid payment signature');
      throw new functions.https.HttpsError('permission-denied', 'Invalid payment signature');
    }

    console.log('✅ Payment signature verified successfully');

    // Get payment details from Razorpay
    const payment = await razorpay.payments.fetch(razorpay_payment_id);
    
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
    });

    // Update order status
    await admin.firestore().collection('razorpay_orders').doc(razorpay_order_id).update({
      paymentId: razorpay_payment_id,
      paymentStatus: payment.status,
      paymentVerified: true,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      autoCaptured: payment.captured || false,
    });

    console.log(`✅ Payment verification completed for: ${razorpay_payment_id}`);

    return {
      success: true,
      paymentId: razorpay_payment_id,
      status: payment.status,
      amount: payment.amount,
      method: payment.method,
      captured: payment.captured || false,
      verified: true,
    };

  } catch (error) {
    console.error('❌ Error verifying payment:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Payment verification failed', error.message);
  }
});

// 🔥 Razorpay webhook handler for auto-capture events
exports.handleRazorpayWebhook = functions.https.onRequest(async (req, res) => {
  try {
    console.log('📨 Razorpay webhook received');
    
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
    console.error('❌ Error handling webhook:', error);
    res.status(500).send('Internal server error');
  }
});

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

      // Send notification to kitchen about confirmed payment - NO PRICING
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
              // REMOVED: amount to hide pricing
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

// 🔥 NEW FUNCTION: Clean up expired session history
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

// 🔥 Razorpay webhook handler for auto-capture events (COMPLETE VERSION)
exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
  try {
    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }

    const signature = req.headers['x-razorpay-signature'];
    const body = JSON.stringify(req.body);
    
    // Verify webhook signature if webhook secret is configured
    const webhookSecret = functions.config().razorpay?.webhook_secret;
    if (webhookSecret && signature) {
      const expectedSignature = crypto
        .createHmac('sha256', webhookSecret)
        .update(body)
        .digest('hex');

      if (signature !== expectedSignature) {
        console.log('❌ Invalid webhook signature');
        return res.status(400).send('Invalid signature');
      }
    }

    const event = req.body;
    console.log(`📨 Razorpay webhook received: ${event.event}`);

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
    console.error('❌ Error handling Razorpay webhook:', error);
    res.status(500).send('Internal server error');
  }
});

// 🔥 Function to create Razorpay order with auto-capture (COMPLETE VERSION)
exports.createRazorpayOrder = functions.https.onCall(async (data, context) => {
  try {
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { amount, currency = 'INR', receipt, notes = {} } = data;

    // Validate amount
    if (!amount || amount <= 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Valid amount is required');
    }

    console.log(`🔄 Creating Razorpay order for user ${context.auth.uid}, amount: ${amount}`);

    // Create order options with auto-capture enabled
    const orderOptions = {
      amount: amount, // Amount in paise
      currency: currency,
      receipt: receipt || `order_${Date.now()}`,
      payment_capture: 1, // Enable auto-capture
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

console.log('🚀 Firebase Functions loaded successfully with ALL features: Razorpay integration, device management, session monitoring, and fixed pricing notifications!');