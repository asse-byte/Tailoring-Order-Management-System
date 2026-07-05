// =============================================================================
// Tailoring Studio — Cloud Function for FCM heads-up delivery
// =============================================================================
//
// In-app notifications work out of the box (the app reads the /notifications
// collection directly). This function listens to new /notifications docs and
// delivers a heads-up push to the recipient's registered device(s).
//
// HOW TO DEPLOY
// -------------
// 1. From the project root, install the Firebase CLI (one-time):
//      npm install -g firebase-tools
// 2. Initialize Cloud Functions in this folder:
//      cd functions
//      npm init -y
//      npm install firebase-admin firebase-functions
// 3. Login & deploy:
//      firebase login
//      firebase deploy --only functions
//
// REQUIREMENTS
// ------------
// • Each user document at /users/{uid} should have an `fcmToken` string
//   (the Flutter app writes this automatically after sign-in via FcmService).
// • Each notification document at /notifications/{id} must include:
//      recipientId : string  (the target user's uid)
//      title       : string
//      body        : string
//      orderId     : string  (optional — used for deep-link)
//
// BILLING NOTE
// ------------
// Cloud Functions require the Firebase Blaze (pay-as-you-go) plan. The free
// tier covers a generous monthly allotment, but be aware.
// =============================================================================

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.deliverNotification = onDocumentCreated(
  "notifications/{id}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const recipientId = data.recipientId;
    if (!recipientId) return;

    // Load the recipient's FCM token.
    const userDoc = await getFirestore()
      .collection("users")
      .doc(recipientId)
      .get();
    const token = userDoc.data()?.fcmToken;
    if (!token) {
      console.log(`No FCM token for user ${recipientId}; skipping push.`);
      return;
    }

    const message = {
      token,
      notification: {
        title: data.title || "Tailoring Studio",
        body: data.body || "",
      },
      data: {
        // Stringify everything — FCM data values must be strings.
        notificationId: event.params.id,
        ...(data.orderId ? { orderId: String(data.orderId) } : {}),
      },
      android: {
        priority: "high",
        notification: {
          channelId: "tailoring_orders_channel",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            "content-available": 1,
          },
        },
      },
    };

    try {
      await getMessaging().send(message);
    } catch (err) {
      console.error(`Failed to send push to ${recipientId}:`, err);
      // If the token is no longer valid, clear it so we don't keep trying.
      if (
        err.code === "messaging/registration-token-not-registered" ||
        err.code === "messaging/invalid-registration-token"
      ) {
        await userDoc.ref.update({ fcmToken: null });
      }
    }
  }
);
