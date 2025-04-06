const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.terminateStalePickups = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const cutoff = admin.firestore.Timestamp.fromMillis(now.toMillis() - 5*60*1000);

    const stale = await db.collection('orders')
      .where('status','==','Pick Up')
      .where('pickedUpTime','<=',cutoff)
      .get();

    const batch = db.batch();
    stale.forEach(doc => {
      const data = doc.data();
      const id = doc.id;
      batch.update(doc.ref, { status:'Terminated', terminatedTime: now });
      batch.set(
        db.collection('users').doc(data.userId)
          .collection('orderHistory').doc(id),
        { ...data, status:'Terminated', terminatedTime: now }
      );
      batch.set(
        db.collection('adminOrderHistory').doc(id),
        { ...data, status:'Terminated', terminatedTime: now }
      );
    });

    await batch.commit();
    console.log(`Terminated ${stale.size} stale pickups.`);
    return null;
  });
