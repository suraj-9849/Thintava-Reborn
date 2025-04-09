const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// ✅ Your existing function (KEEP IT)
exports.terminateStalePickups = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.FieldValue.serverTimestamp();
    const serverNow = admin.firestore.Timestamp.now(); // for calculations
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

      // Update the main orders collection
      batch.update(db.collection('orders').doc(id), {
        status: 'Terminated',
        terminatedTime: now,
      });

      // Save to user's order history
      batch.set(
        db.collection('users').doc(userId).collection('orderHistory').doc(id),
        { ...data, status: 'Terminated', terminatedTime: serverNow }
      );

      // Save to admin order history
      batch.set(
        db.collection('adminOrderHistory').doc(id),
        { ...data, status: 'Terminated', terminatedTime: serverNow }
      );
    });

    await batch.commit();
    console.log(`Terminated ${stale.size} stale pickups.`);
    return null;
  });

// ✅ New function to send notification automatically
exports.sendNotificationOnNewNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();

    if (!notification) {
      console.log("No notification data");
      return null;
    }

    const payload = {
      notification: {
        title: notification.title || "New Update",
        body: notification.body || "",
      },
      data: notification.data || {},
    };

    if (notification.token) {
      console.log(`Sending notification to token: ${notification.token}`);
      await admin.messaging().sendToDevice(notification.token, payload);
    } else {
      console.log("No token found, skipping send.");
    }

    return null;
  });
