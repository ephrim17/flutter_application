import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

admin.initializeApp();

/**
 * Sends a topic notification through FCM.
 */
async function sendTopicNotification({
  title,
  body,
  topic,
}: {
  title: string;
  body: string;
  topic: string;
}) {
  await admin.messaging().send({
    notification: {
      title,
      body,
    },
    topic,
  });
}

export const processQueuedChurchNotification = onDocumentCreated(
  "churches/{churchId}/notification_requests/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    const data = snapshot?.data();

    if (!data) return;

    const title = String(data.title ?? "");
    const body = String(data.body ?? "");
    const topic = String(data.topic ?? "");

    if (!title || !body || !topic) {
      if (snapshot) {
        await snapshot.ref.update({
          status: "failed",
          error: "Missing required notification fields",
        });
      }
      return;
    }

    try {
      await sendTopicNotification({
        title,
        body,
        topic,
      });

      if (snapshot) {
        await snapshot.ref.update({
          status: "sent",
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      console.log("Notification sent");
    } catch (error) {
      console.error("Error sending notification", error);

      if (snapshot) {
        await snapshot.ref.update({
          status: "failed",
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
  }
);

export const notifyOnFeedPostCreated = onDocumentCreated(
  "churches/{churchId}/feeds/{feedId}",
  async (event) => {
    const snapshot = event.data;
    const data = snapshot?.data();
    const churchId = event.params.churchId;

    if (!data || !churchId) {
      return;
    }

    const userName = String(data.userName ?? "").trim() || "Someone";

    await sendTopicNotification({
      title: "New Feed Post",
      body: `User ${userName} has posted a new feed`,
      topic: `church_${churchId}`,
    });
  }
);
