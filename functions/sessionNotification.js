// functions/index.js - Add this to your existing function file

// 🔥 New function: notify users when logged out from another device
exports.notifyUserOnSessionTermination = functions.firestore
  .document('user_sessions/{userId}/history/{historyId}')
  .onCreate(async (snap, context) => {
    const sessionData = snap.data();
    const userId = context.params.userId;
    
    // Only send notification if the logout reason is due to another device login
    if (sessionData.logoutReason === 'Logged in on another device' && sessionData.fcmToken) {
      const fcmToken = sessionData.fcmToken;
      
      // Get user data to personalize the message
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      let userEmail = 'your account';
      if (userDoc.exists) {
        userEmail = userDoc.data().email || 'your account';
      }
      
      const payload = {
        notification: {
          title: 'Logged Out',
          body: `${userEmail} was logged in on another device. You have been logged out for security.`,
        },
        data: {
          type: 'SESSION_TERMINATED',
          userId: userId,
          timestamp: sessionData.logoutTime.toDate().toString(),
        }
      };
      
      // Send the notification
      try {
        await admin.messaging().send({
          token: fcmToken,
          notification: payload.notification,
          data: payload.data
        });
        console.log(`Notification sent to ${fcmToken} for user ${userId}`);
        return null;
      } catch (error) {
        // Token might be invalid
        console.error(`Error sending notification to ${fcmToken}:`, error);
        return null;
      }
    }
    
    return null;
  });