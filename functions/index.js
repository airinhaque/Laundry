/* eslint-disable require-jsdoc */
/* eslint-disable spaced-comment */
/* eslint-disable no-multiple-empty-lines */
/* eslint-disable padded-blocks */
/* eslint-disable max-len */
/* eslint-disable quotes */
// eslint-disable-next-line quotes
const functions = require('firebase-functions/v1');
const admin = require("firebase-admin");


const serviceAccount = require("./serviceAccountKey.json");


admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});


exports.sendMachineUpdateNotification = functions.firestore
    .document("machines/{machineId}")
    .onUpdate(async (change, context) => {
      try {
        const machineData = change.after.data();
        //const machineName = machineData.name;
        const energyConsumption = machineData.energy_consumption;
        const machineId = context.params.machineId;


        const subscriptionsSnapshot = await admin
            .firestore()
            .collection("subscriptions")
            // .where("machineId")
            .where("machineId", "==", machineId)
            .get();

        // eslint-disable-next-line max-len
        const tokens = subscriptionsSnapshot.docs.map((doc) => doc.data().token);
        if (tokens.length === 0) {
          console.log("No tokens found. Skipping notification sending.");
          return null;
        }


        // Prepare the data to send to the app
        // eslint-disable-next-line no-unused-vars
        const data = {
          machineId: machineId,
          //machineName: machineName,
          energyConsumption: energyConsumption.toString(),
        };


        const payload = {
          notification: {
            title: "Machine Update",
            // eslint-disable-next-line max-len
            // body: `Machine ${machineName} updated. Energy Consumption: ${energyConsumption}`,
            // body: `Machine ${machineId} updated. Your Laundry Status: ${energyConsumption}`,
            body: `Laundry Machine Status: ${energyConsumption}`,
          },
          data: data, // Include the data in the payload

        };


        const message = {
          tokens: tokens,
          notification: payload.notification,
          data: {
            // eslint-disable-next-line max-len
            click_action: 'FLUTTER_NOTIFICATION_CLICK', // Specify the click action
            // Include the machine update data in the data payload
            machineId: machineId,
            //machineName: machineName,
            energyConsumption: energyConsumption.toString(),


          },
        };


        const response = await admin.messaging().sendMulticast(message);


        console.log("Notification sent successfully:", response);

        // Update the subscriptions document with the machine update data
        if (!subscriptionsSnapshot.empty) {
          const subscriptionDocRef = subscriptionsSnapshot.docs[0].ref;
          await subscriptionDocRef.update({
            machineId: machineId,
            //machineName: machineName,
            energyConsumption: energyConsumption,
          });
        }


        return null;
      } catch (error) {
        console.error("Error sending notification:", error);
        return null;
      }
    });


exports.subscribeToMachine = functions.https.onRequest(async (req, res) => {
  try {
    const {machineId, token} = req.body;

    // Reference to the "subscription" collection
    const subscriptionCollectionRef = admin.firestore().collection('subscriptions');

    console.log('Checking subscription for machineId:', machineId);

    // Check if someone is already subscribed to the machine
    const existingSubscription = await subscriptionCollectionRef.doc(machineId).get();

    if (existingSubscription.exists) {
      // Machine is already being used by someone else
      if (existingSubscription.data().token) {
        console.log('Machine is already in use.');
        return res.status(409).json({message: 'Machine is already in use.'});
      }
    }

    // If not subscribed or token doesn't exist, create or update the document for the provided machineId
    const machineDocRef = subscriptionCollectionRef.doc(machineId);
    await machineDocRef.set({
      machineId,
      token,
      timestamp: admin.firestore.FieldValue.serverTimestamp(), // Add the server timestamp
    }, {merge: true});

    console.log('Device token stored for machineId:', machineId);

    return res.status(200).json({message: 'Device token stored for machineId.'});
  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({error: 'An error occurred.'});
  }
});


exports.deleteOldTokens = functions.pubsub.schedule('every 12 hours').timeZone('Asia/Dubai').onRun(async (context) => {
  try {
    const subscriptionCollectionRef = admin.firestore().collection('subscriptions');

    // Calculate the timestamp for 12 hours ago
    const twelveHoursAgo = new Date();
    twelveHoursAgo.setHours(twelveHoursAgo.getHours() - 12);

    // Query documents older than 12 hours
    const oldTokensQuery = await subscriptionCollectionRef.where('timestamp', '<=', twelveHoursAgo).get();

    // Delete old documents
    const deletePromises = [];
    oldTokensQuery.forEach((doc) => {
      deletePromises.push(doc.ref.delete());
    });

    await Promise.all(deletePromises);

    console.log('Old tokens deleted successfully.');
    return null;
  } catch (error) {
    console.error('Error:', error);
    return null;
  }
});



exports.storeSharingCode = functions.https.onRequest(async (req, res) => {
  try {
    const {machineId, token, sharingCode} = req.body;

    // Store the sharing code along with the machineId and token
    const sharingCodeDocRef = admin.firestore().collection('sharingCodes').doc(sharingCode);
    await sharingCodeDocRef.set({machineId, token});

    return res.status(200).json({message: 'Sharing code stored successfully.'});
  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({error: 'An error occurred.'});
  }
});




const db = admin.firestore();


exports.updateMachineStatus = functions.https.onRequest(async (req, res) => {
  try {
    const { machineId, energyConsumption, timestamp, cycleType } = req.body;

    // Update machine status and energy consumption
    await db.collection('machines').doc(machineId).set({
      energy_consumption: energyConsumption,
      timestamp: timestamp,
      cycle_type: cycleType,  // Add cycle type to the machine document
    }, { merge: true });

    // Add entry to machine history subcollection
    const historyRef = db.collection('machines').doc(machineId).collection('history');
    await historyRef.add({
      energy_consumption: energyConsumption,
      timestamp: timestamp,
      cycle_type: cycleType,  // Add cycle type to the history entry
    });

    return res.status(200).json({ message: 'Machine status updated.' });
  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({ error: 'An error occurred.' });
  }
});



exports.unsubscribeFromMachine = functions.https.onRequest(async (req, res) => {
  try {
    const {machineId} = req.body;

    // Reference to the "subscriptions" collection
    const subscriptionCollectionRef = admin.firestore().collection('subscriptions');

    // Find and delete the document for the provided machineId
    const machineDocRef = subscriptionCollectionRef.doc(machineId);
    const snapshot = await machineDocRef.get();

    if (snapshot.exists) {
      await machineDocRef.delete();
      return res.status(200).json({message: 'Unsubscribed successfully.'});
    } else {
      return res.status(404).json({error: 'Document not found.'});
    }
  } catch (error) {
    console.error('Error unsubscribing:', error);
    return res.status(500).json({error: 'An error occurred.'});
  }
});



exports.acceptInvitationAndSubscribe = functions.https.onRequest(async (req, res) => {
  try {
    const {sharingCode, token} = req.body;

    // Reference to the "subscription" collection
    const subscriptionCollectionRef = admin.firestore().collection('subscriptions');

    // Check if someone is already subscribed to the sharing code
    const existingSubscription = await subscriptionCollectionRef.where('sharingCode', '==', sharingCode).get();

    if (!existingSubscription.empty) {
      // Already subscribed, update the document with device token
      const machineDocRef = subscriptionCollectionRef.doc(existingSubscription.docs[0].id);
      await machineDocRef.update({token: token});
    } else {
      // Sharing code not found, show appropriate message to user
      console.log('Sharing code not found');
      return res.status(404).json({message: 'Invalid or expired laundry code.'});
    }

    return res.status(200).json({message: 'Device token stored for sharing code.'});
  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({error: 'An error occurred.'});
  }
});



