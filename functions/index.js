// index.js
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

/**
 * Cloud Function to send FCM notifications
 * This function should be triggered when an emergency document is created
 */
exports.sendEmergencyNotification = functions.firestore
    .document("emergencies/{emergencyId}")
    .onCreate(async (snapshot, context) => {
      try {
        const emergencyData = snapshot.data();

        // Check if the emergency is active
        if (!emergencyData.active) {
          console.log("Emergency not active, skipping notification");
          return null;
        }

        const seniorId = emergencyData.seniorId;
        const seniorName = emergencyData.seniorName;

        // Get location string if available
        let locationStr = "unknown";
        if (emergencyData.location) {
          locationStr = `${emergencyData.location.latitude},` +
                        `${emergencyData.location.longitude}`;
        }

        // Query for family members connected to this senior
        const familySnapshot = await admin.firestore()
            .collection("users")
            .where("connectedSeniorIds", "array-contains", seniorId)
            .get();

        if (familySnapshot.empty) {
          console.log("No family members found for senior", seniorId);
          return null;
        }

        // Send notification to each family member
        const notificationPromises = [];

        familySnapshot.forEach((doc) => {
          const familyData = doc.data();
          const fcmToken = familyData.fcmToken;

          if (fcmToken) {
            const message = {
              token: fcmToken,
              notification: {
                title: "Emergency Alert!",
                body: `${seniorName} needs help! Tap to view location.`,
              },
              data: {
                payload: `emergency:${seniorId}:${locationStr}`,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
              android: {
                priority: "high",
                notification: {
                  sound: "default",
                  priority: "high",
                  channel_id: "high_importance_channel",
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    badge: 1,
                  },
                },
              },
            };

            notificationPromises.push(admin.messaging().send(message));
          }
        });

        if (notificationPromises.length === 0) {
          console.log("No valid FCM tokens found");
          return null;
        }

        return Promise.all(notificationPromises);
      } catch (error) {
        console.error("Error sending notifications:", error);
        return null;
      }
    });

/**
 * Cloud Function to send FCM cancellation notifications
 */
exports.sendCancellationNotification = functions.firestore
    .document("emergencies/{emergencyId}")
    .onUpdate(async (change, context) => {
      try {
        const newData = change.after.data();
        const previousData = change.before.data();

        // Only proceed if emergency was active and is now inactive
        if (previousData.active && !newData.active) {
          const seniorId = newData.seniorId;

          // Get senior name
          const seniorDoc = await admin.firestore()
              .collection("users")
              .doc(seniorId)
              .get();

          if (!seniorDoc.exists) {
            console.log("Senior document not found");
            return null;
          }

          const seniorData = seniorDoc.data();
          const seniorName = seniorData.name || "Senior";

          // Find connected family members
          const familySnapshot = await admin.firestore()
              .collection("users")
              .where("connectedSeniorIds", "array-contains", seniorId)
              .get();

          if (familySnapshot.empty) {
            console.log("No family members found");
            return null;
          }

          // Send cancellation notification to each family member
          const notificationPromises = [];

          familySnapshot.forEach((doc) => {
            const familyData = doc.data();
            const fcmToken = familyData.fcmToken;

            if (fcmToken) {
              const message = {
                token: fcmToken,
                notification: {
                  title: "Emergency Cancelled",
                  body: `${seniorName} is now safe. ` +
                        `Emergency has been cancelled.`,
                },
                data: {
                  payload: `emergency_cancelled:${seniorId}`,
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
                android: {
                  priority: "high",
                  notification: {
                    sound: "default",
                    channel_id: "high_importance_channel",
                  },
                },
                apns: {
                  payload: {
                    aps: {
                      sound: "default",
                      badge: 1,
                    },
                  },
                },
              };

              notificationPromises.push(admin.messaging().send(message));
            }
          });

          if (notificationPromises.length === 0) {
            console.log("No valid FCM tokens found");
            return null;
          }

          return Promise.all(notificationPromises);
        }

        return null;
      } catch (error) {
        console.error("Error sending cancellation notifications:", error);
        return null;
      }
    });
