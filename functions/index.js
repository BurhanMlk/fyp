/**
 * Blood Bridge - Firebase Cloud Functions
 *
 * Scheduled functions for donation reminders and other background tasks.
 */

const {setGlobalOptions} = require("firebase-functions");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ maxInstances: 10 });

/**
 * Scheduled function: Check for due donation reminders every hour.
 * When a donor's 90-day cooldown expires:
 * 1. Sends an in-app message: "You can donate now!"  
 * 2. Clears the cooldown on the donor's user profile
 * 3. Marks the reminder as sent
 */
exports.checkDonationReminders = onSchedule(
  {
    schedule: "every hour",
    timeZone: "Asia/Karachi",
    maxInstances: 3,
  },
  async (event) => {
    const now = admin.firestore.Timestamp.now();
    let sentCount = 0;

    try {
      const dueSnap = await db
        .collection("donation_reminders")
        .where("sent", "==", false)
        .where("sendAt", "<=", now)
        .get();

      logger.info(`Found ${dueSnap.size} due reminder(s) to process`);

      for (const doc of dueSnap.docs) {
        const data = doc.data();
        const donorEmail = data.donorEmail || "";
        const donorName = data.donorName || donorEmail.split("@")[0];
        const message =
          "🎉 *You Can Donate Blood Again!* 🎉\n\n" +
          `Dear ${donorName},\n\n` +
          "Your 3-month waiting period is now complete. You are eligible to donate blood again and help save more lives!\n\n" +
          "🩸 Please visit Blood Bridge to find recipients who need your blood type.\n\n" +
          "With gratitude,\n" +
          "*Quaidian Society of Blood Donors / Blood Bridge* ❤️";

        if (!donorEmail) {
          logger.warn(`Reminder ${doc.id} has no donorEmail, skipping`);
          continue;
        }

        try {
          const conversationId = `conv_${donorEmail.replace(/\./g, "_").replace(/@/g, "_at_")}_admin`;
          const timestamp = admin.firestore.Timestamp.now();

          // Send in-app message to the donor
          await db.collection("messages").add({
            conversationId: conversationId,
            from: "Admin",
            to: donorEmail,
            message: message,
            sentAt: timestamp,
            type: "reminder",
            read: false,
          });

          // Update/create chat conversation
          await db
            .collection("chats")
            .doc(conversationId)
            .set(
              {
                conversationId: conversationId,
                participants: [donorEmail, "Admin"],
                participantNames: [donorName, "Admin"],
                lastMessage: message,
                lastMessageAt: timestamp,
                lastMessageFrom: "Admin",
                status: "active",
                unreadCount: 0,
                updatedAt: timestamp,
              },
              { merge: true }
            );

          // Mark reminder as sent
          await doc.ref.update({
            sent: true,
            sentAt: timestamp,
          });

          // Clear cooldown on the donor's user document
          try {
            const userSnap = await db
              .collection("users")
              .where("email", "==", donorEmail)
              .limit(1)
              .get();

            for (const userDoc of userSnap.docs) {
              await userDoc.ref.update({
                cooldownUntil: admin.firestore.FieldValue.delete(),
              });
              logger.info(`Cleared cooldown for ${donorEmail}`);
            }
          } catch (userErr) {
            logger.warn(`Could not clear cooldown for ${donorEmail}: ${userErr.message}`);
          }

          sentCount++;
          logger.info(`✅ Eligibility reminder sent to ${donorEmail}`);
        } catch (err) {
          logger.error(`Failed to send reminder to ${donorEmail}: ${err.message}`);
        }
      }

      logger.info(`checkDonationReminders completed: ${sentCount} reminder(s) sent`);
    } catch (err) {
      logger.error(`checkDonationReminders error: ${err.message}`);
    }

    return null;
  }
);

/**
 * Optional: Manual HTTP trigger to force-run the reminder check.
 * GET https://<region>-<project>.cloudfunctions.net/forceCheckReminders
 */
exports.forceCheckReminders = onRequest(
  { maxInstances: 3 },
  async (request, response) => {
    const now = admin.firestore.Timestamp.now();
    let sentCount = 0;

    try {
      const dueSnap = await db
        .collection("donation_reminders")
        .where("sent", "==", false)
        .where("sendAt", "<=", now)
        .get();

      for (const doc of dueSnap.docs) {
        const data = doc.data();
        const donorEmail = data.donorEmail || "";
        const message =
          data.message ||
          "You are now eligible to donate blood again! Your 3-month waiting period is complete. ❤️";

        if (!donorEmail) continue;

        try {
          const conversationId = `conv_${donorEmail.replace(/\./g, "_").replace(/@/g, "_at_")}_admin`;
          const timestamp = admin.firestore.Timestamp.now();

          await db.collection("messages").add({
            conversationId: conversationId,
            from: "Admin",
            to: donorEmail,
            message: message,
            sentAt: timestamp,
            type: "reminder",
            read: false,
          });

          const donorName = donorEmail.split("@")[0];
          await db
            .collection("chats")
            .doc(conversationId)
            .set(
              {
                conversationId: conversationId,
                participants: [donorEmail, "Admin"],
                participantNames: [donorName, "Admin"],
                lastMessage: message,
                lastMessageAt: timestamp,
                lastMessageFrom: "Admin",
                status: "active",
                unreadCount: 0,
                updatedAt: timestamp,
              },
              { merge: true }
            );

          await doc.ref.update({
            sent: true,
            sentAt: timestamp,
          });

          try {
            const userSnap = await db
              .collection("users")
              .where("email", "==", donorEmail)
              .limit(1)
              .get();

            for (const userDoc of userSnap.docs) {
              await userDoc.ref.update({
                cooldownUntil: admin.firestore.FieldValue.delete(),
              });
            }
          } catch (_) {}

          sentCount++;
        } catch (err) {
          logger.error(`Failed to send to ${donorEmail}: ${err.message}`);
        }
      }
    } catch (err) {
      logger.error(`Force check error: ${err.message}`);
      response.status(500).send(`Error: ${err.message}`);
      return;
    }

    response.status(200).send(`Done: ${sentCount} reminder(s) sent`);
  }
);
