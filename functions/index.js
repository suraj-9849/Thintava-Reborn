const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

// Initialize admin SDK - Firebase will automatically use project credentials
admin.initializeApp();

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

// 🚀 Enhanced function: Detailed notification to kitchen when new order is created
exports.notifyKitchenOnNewOrder = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, context) => {
    const orderId = context.params.orderId;
    const orderData = snap.data();

    try {
      console.log(`📦 New order created: ${orderId}`);
      
      // 🔥 Fetch kitchen user with role 'kitchen' from users collection
      const kitchenUsers = await admin.firestore().collection('users')
        .where('role', '==', 'kitchen')
        .get();

      if (kitchenUsers.empty) {
        console.log('❌ No kitchen user found!');
        return null;
      }

      const kitchenFcmToken = kitchenUsers.docs[0].data().fcmToken;

      if (!kitchenFcmToken) {
        console.log('❌ No FCM token for kitchen user!');
        return null;
      }

      // Extract order details for detailed notification
      const orderTotal = orderData.total || 0;
      const orderItems = orderData.items || {};
      const shortOrderId = orderId.substring(0, 6);
      
      // Count total items
      let totalItemCount = 0;
      const itemsList = [];
      
      if (typeof orderItems === 'object') {
        for (const [itemName, itemData] of Object.entries(orderItems)) {
          if (typeof itemData === 'object' && itemData.quantity) {
            totalItemCount += itemData.quantity;
            itemsList.push(`${itemName} x${itemData.quantity}`);
          } else if (typeof itemData === 'number') {
            totalItemCount += itemData;
            itemsList.push(`${itemName} x${itemData}`);
          }
        }
      }

      const itemsText = itemsList.length > 0 ? itemsList.join(', ') : 'Items not specified';
      
      // Get customer email for kitchen reference
      const customerEmail = orderData.userEmail || 'Unknown customer';

      const payload = {
        notification: {
          title: `🍽️ New Order #${shortOrderId}`,
          body: `${totalItemCount} items • ₹${orderTotal.toFixed(2)} • ${customerEmail}`,
        },
        data: {
          type: 'NEW_ORDER',
          orderId: orderId,
          orderTotal: orderTotal.toString(),
          itemCount: totalItemCount.toString(),
          items: itemsText,
          customerEmail: customerEmail,
          timestamp: new Date().toISOString(),
          action: 'view_kitchen_dashboard'
        }
      };

      // Send notification to kitchen
      const response = await admin.messaging().send({
        token: kitchenFcmToken,
        notification: payload.notification,
        data: payload.data,
        android: {
          notification: {
            channelId: 'thintava_orders',
            priority: 'high',
            defaultSound: true,
            defaultVibrateTimings: true,
            color: '#FFB703'
          }
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1
            }
          }
        }
      });

      console.log(`✅ Kitchen notification sent successfully for order ${orderId}:`, response);
      return null;

    } catch (error) {
      console.error(`❌ Error sending kitchen notification for order ${orderId}:`, error);
      return null;
    }
  });

// 🚀 Enhanced function: Detailed notification to user when order status changes
exports.notifyUserOnOrderStatusChange = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const orderId = context.params.orderId;
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const beforeStatus = beforeData.status;
    const afterStatus = afterData.status;

    // Only proceed if status actually changed
    if (beforeStatus === afterStatus) {
      return null;
    }

    try {
      console.log(`📱 Order status changed: ${orderId} - ${beforeStatus} → ${afterStatus}`);
      
      const userId = afterData.userId;
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        console.log(`❌ No user found for userId: ${userId}`);
        return null;
      }

      const fcmToken = userDoc.data().fcmToken;
      if (!fcmToken) {
        console.log(`❌ No FCM token found for user: ${userId}`);
        return null;
      }

      // Extract order details
      const orderTotal = afterData.total || 0;
      const orderItems = afterData.items || {};
      const shortOrderId = orderId.substring(0, 6);
      
      // Count total items
      let totalItemCount = 0;
      const itemsList = [];
      
      if (typeof orderItems === 'object') {
        for (const [itemName, itemData] of Object.entries(orderItems)) {
          if (typeof itemData === 'object' && itemData.quantity) {
            totalItemCount += itemData.quantity;
            itemsList.push(`${itemName} x${itemData.quantity}`);
          } else if (typeof itemData === 'number') {
            totalItemCount += itemData;
            itemsList.push(`${itemName} x${itemData}`);
          }
        }
      }

      // Create status-specific messages
      let title, body, statusEmoji;
      
      switch (afterStatus) {
        case 'Placed':
          statusEmoji = '📝';
          title = `${statusEmoji} Order Confirmed #${shortOrderId}`;
          body = `Your order for ${totalItemCount} items (₹${orderTotal.toFixed(2)}) has been placed successfully!`;
          break;
        case 'Cooking':
          statusEmoji = '👨‍🍳';
          title = `${statusEmoji} Cooking Started #${shortOrderId}`;
          body = `Great! Our chef has started preparing your ${totalItemCount} items. Estimated time: 15-20 mins`;
          break;
        case 'Cooked':
          statusEmoji = '✅';
          title = `${statusEmoji} Order Ready #${shortOrderId}`;
          body = `Your delicious meal is ready! Please come to collect your ${totalItemCount} items worth ₹${orderTotal.toFixed(2)}`;
          break;
        case 'Pick Up':
          statusEmoji = '🎒';
          title = `${statusEmoji} Ready for Pickup #${shortOrderId}`;
          body = `Your order is ready for pickup! You have 5 minutes to collect. Total: ₹${orderTotal.toFixed(2)}`;
          break;
        case 'PickedUp':
          statusEmoji = '🎉';
          title = `${statusEmoji} Order Completed #${shortOrderId}`;
          body = `Thank you! Your order has been marked as picked up. Enjoy your meal!`;
          break;
        case 'Terminated':
          statusEmoji = '❌';
          title = `${statusEmoji} Order Cancelled #${shortOrderId}`;
          body = `Your order worth ₹${orderTotal.toFixed(2)} has been cancelled. Please contact us if you have questions.`;
          break;
        default:
          statusEmoji = '📱';
          title = `${statusEmoji} Order Update #${shortOrderId}`;
          body = `Your order status has been updated to: ${afterStatus}`;
      }

      const payload = {
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: 'ORDER_STATUS_UPDATE',
          orderId: orderId,
          oldStatus: beforeStatus,
          newStatus: afterStatus,
          orderTotal: orderTotal.toString(),
          itemCount: totalItemCount.toString(),
          timestamp: new Date().toISOString(),
          action: 'view_order_tracking'
        }
      };

      // Send notification to user
      const response = await admin.messaging().send({
        token: fcmToken,
        notification: payload.notification,
        data: payload.data,
        android: {
          notification: {
            channelId: 'thintava_orders',
            priority: 'high',
            defaultSound: true,
            defaultVibrateTimings: true,
            color: '#FFB703'
          }
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1
            }
          }
        }
      });

      console.log(`✅ User notification sent successfully for order ${orderId} status change: ${beforeStatus} → ${afterStatus}`);
      return null;

    } catch (error) {
      console.error(`❌ Error sending user notification for order ${orderId} status change:`, error);
      return null;
    }
  });

// 🚀 Enhanced function: Notify user when order is about to expire (1 minute warning)
exports.notifyUserOrderExpiring = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    
    // Find orders that will expire in 1 minute (4 minutes since pickup time)
    const fourMinutesAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - 4 * 60 * 1000);
    const fiveMinutesAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - 5 * 60 * 1000);

    try {
      const expiringOrders = await db.collection('orders')
        .where('status', '==', 'Pick Up')
        .where('pickedUpTime', '>', fiveMinutesAgo)
        .where('pickedUpTime', '<=', fourMinutesAgo)
        .get();

      if (expiringOrders.empty) {
        console.log('⏰ No orders expiring in 1 minute found.');
        return null;
      }

      console.log(`⏰ Found ${expiringOrders.size} orders expiring in 1 minute`);

      const promises = expiringOrders.docs.map(async (doc) => {
        const orderData = doc.data();
        const orderId = doc.id;
        const userId = orderData.userId;

        try {
          const userDoc = await db.collection('users').doc(userId).get();
          if (!userDoc.exists) return;

          const fcmToken = userDoc.data().fcmToken;
          if (!fcmToken) return;

          const shortOrderId = orderId.substring(0, 6);
          const orderTotal = orderData.total || 0;

          const payload = {
            notification: {
              title: `⏰ Urgent: Order Expiring #${shortOrderId}`,
              body: `Your order worth ₹${orderTotal.toFixed(2)} will expire in 1 minute! Please collect it now.`,
            },
            data: {
              type: 'ORDER_EXPIRING',
              orderId: orderId,
              orderTotal: orderTotal.toString(),
              expiresIn: '60',
              timestamp: new Date().toISOString(),
              action: 'collect_order_now'
            }
          };

          return admin.messaging().send({
            token: fcmToken,
            notification: payload.notification,
            data: payload.data,
            android: {
              notification: {
                channelId: 'thintava_urgent',
                priority: 'max',
                defaultSound: true,
                defaultVibrateTimings: true,
                color: '#FF5722'
              }
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1
                }
              }
            }
          });

        } catch (error) {
          console.error(`❌ Error sending expiring notification for order ${orderId}:`, error);
        }
      });

      await Promise.all(promises);
      console.log(`✅ Sent expiring notifications for ${expiringOrders.size} orders.`);
      return null;

    } catch (error) {
      console.error('❌ Error in notifyUserOrderExpiring:', error);
      return null;
    }
  });