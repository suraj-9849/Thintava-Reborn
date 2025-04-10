const functions = require('firebase-functions/v1');   // ✅ THIS
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');  // 👈 Add this line
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
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

// 🚀 New function: notify user when order status changes
exports.notifyKitchenOnNewOrder = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, context) => {
    const newOrder = snap.data();

    // 🔥 Fetch kitchen user with role 'kitchen' from users collection
    const kitchenUsers = await admin.firestore().collection('users')
      .where('role', '==', 'kitchen')
      .get();

    if (kitchenUsers.empty) {
      console.log('No kitchen user found!');
      return null;
    }

    const kitchenFcmToken = kitchenUsers.docs[0].data().fcmToken;  // 🔥 Use fcmToken

    if (!kitchenFcmToken) {
      console.log('No FCM token for kitchen!');
      return null;
    }

    const payload = {
      notification: {
        title: 'New Order Received',
        body: `A new order has been placed. Check the kitchen panel.`,
      },
    };

    // Fixed: Using send() instead of sendToDevice()
    return admin.messaging().send({
      token: kitchenFcmToken,
      notification: payload.notification
    });
  });

// 🚀 New function: notify kitchen when a new order is created
exports.notifyUserOnOrderStatusChange = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const beforeStatus = change.before.data().status;
    const afterStatus = change.after.data().status;

    if (beforeStatus !== afterStatus) {
      const orderData = change.after.data();
      const userId = orderData.userId;

      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (!userDoc.exists) {
        console.log('No such user!');
        return null;
      }

      const fcmToken = userDoc.data().fcmToken;

      if (!fcmToken) {
        console.log('No FCM token found for user!');
        return null;
      }

      const payload = {
        notification: {
          title: 'Order Update',
          body: `Your order status changed!`,
        },
      };
      
      // ✅ FIXED: Use send() method instead of sendToDevice()
      return admin.messaging().send({
        token: fcmToken,
        notification: payload.notification
      });
    }

    return null;
  });