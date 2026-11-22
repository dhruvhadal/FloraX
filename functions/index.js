/**
 * FloraX Mobile Backend Cloud Functions (v2)
 *
 * Microservices for real-time epidemiological surge alerts and KVK clinical verification pushes.
 */

const { onDocumentWritten, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

// Configure global deployment options for low cold-start latency
setGlobalOptions({
  region: "asia-south1", // Mumbai datacenter for optimal low latency in Maharashtra
  maxInstances: 10,
  timeoutSeconds: 60,
});

/**
 * 1. Outbreak Cluster Surge Detector
 *
 * Triggers on `outbreak_clusters/{clusterId}` document write.
 * Calculates epidemiological case delta. If caseCount increases by >= 3 within 24 hours,
 * broadcasts an anonymous high-priority FCM topic alert to all subscribed devices
 * in that 5-character GeoHash sector (`outbreak_${geoHash5}`).
 */
exports.onOutbreakClusterSpike = onDocumentWritten(
  "outbreak_clusters/{clusterId}",
  async (event) => {
    const afterSnapshot = event.data?.after;
    if (!afterSnapshot || !afterSnapshot.exists) {
      // Document deleted - ignore
      return null;
    }

    const beforeData = event.data?.before?.exists ? event.data.before.data() : {};
    const afterData = afterSnapshot.data();

    // Support both 'caseCount' and 'confirmedCases' naming
    const beforeCases = Number(beforeData.caseCount || beforeData.confirmedCases || 0);
    const afterCases = Number(afterData.caseCount || afterData.confirmedCases || 0);
    const deltaCases = afterCases - beforeCases;

    const clusterId = event.params.clusterId;
    const geoHash5 = (afterData.geoHash5 || clusterId.split("_")[0] || "te7uc").trim().toLowerCase();
    const primaryDisease = afterData.primaryDisease || "Crop Foliage Pathogen";

    console.log(
      `[FloraX Outbreak] Cluster ${clusterId} updated. Before: ${beforeCases}, After: ${afterCases}, Delta: +${deltaCases}`
    );

    // Check if case count increased by 3 or more cases
    if (deltaCases < 3 && afterCases < 3) {
      console.log(`[FloraX Outbreak] Delta (+${deltaCases}) below surge threshold. No push triggered.`);
      return null;
    }

    // Verify 24-hour window
    const now = Date.now();
    const lastUpdatedMillis = afterData.lastUpdated?.toMillis
      ? afterData.lastUpdated.toMillis()
      : afterData.updatedAt?.toMillis
      ? afterData.updatedAt.toMillis()
      : now;

    const hoursSinceUpdate = (now - lastUpdatedMillis) / (1000 * 60 * 60);
    if (hoursSinceUpdate > 24) {
      console.log(`[FloraX Outbreak] Update outside 24h window (${hoursSinceUpdate.toFixed(1)}h). Skipping alert.`);
      return null;
    }

    // Broadcast anonymous topic alert to nearby farmers in the same GeoHash5 sector
    const topic = `outbreak_${geoHash5}`;
    const formattedDisease = primaryDisease.replace(/_/g, " ").toUpperCase();

    const message = {
      topic: topic,
      notification: {
        title: "⚠️ High Disease Risk Alert",
        body: `Spike detected: +${deltaCases} new cases of ${formattedDisease} in your area. Check preventative spray advisory.`,
      },
      data: {
        type: "OUTBREAK_SPIKE",
        geoHash5: geoHash5,
        diseaseName: String(primaryDisease),
        caseCount: String(afterCases),
        deltaCount: String(deltaCases),
        timestamp: new Date().toISOString(),
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "florax_outbreak_alerts",
          priority: "max",
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

    try {
      console.log(`[FloraX Outbreak] Dispatching FCM topic message to: ${topic}...`);
      const response = await admin.messaging().send(message);
      console.log(`[FloraX Outbreak] FCM message delivered successfully. Message ID: ${response}`);
      return response;
    } catch (fcmError) {
      console.error(`[FloraX Outbreak ERROR] Failed sending FCM topic message to ${topic}:`, fcmError);
      throw fcmError;
    }
  }
);

/**
 * 2. KVK Scientist Diagnostic Verification Trigger
 *
 * Triggers on `scans/{scanId}` update.
 * When a KVK agronomist inspects a pending scan and verifies the diagnosis
 * (`verificationStatus` changes to 'KVK_CONFIRMED'), delivers a targeted push alert
 * to the farmer via topic `kvk_updates_${userId}` unlocking Tier-3 chemical control advisories.
 */
exports.onKvkScanVerified = onDocumentUpdated(
  "scans/{scanId}",
  async (event) => {
    const beforeData = event.data?.before?.data() || {};
    const afterData = event.data?.after?.data() || {};

    const prevStatus = beforeData.verificationStatus;
    const newStatus = afterData.verificationStatus;
    const scanId = event.params.scanId;

    console.log(`[FloraX KVK Trigger] Scan ${scanId} status transition: '${prevStatus}' -> '${newStatus}'`);

    // Only fire when status transitions to KVK_CONFIRMED
    if (prevStatus === "KVK_CONFIRMED" || newStatus !== "KVK_CONFIRMED") {
      return null;
    }

    const userId = afterData.userId;
    if (!userId) {
      console.warn(`[FloraX KVK Trigger WARNING] Scan ${scanId} missing userId. Cannot dispatch user alert.`);
      return null;
    }

    const scientistNote = afterData.kvkScientistNote || "Prescription verified by Senior KVK Agronomist.";
    const topCandidate = afterData.topPredictions?.[0]?.labelId || "Crop Pathology";
    const formattedCandidate = topCandidate.replace(/_/g, " ");

    const topic = `kvk_updates_${userId.trim()}`;

    const message = {
      topic: topic,
      notification: {
        title: "✅ KVK Prescription Unlocked!",
        body: `Your scan for ${formattedCandidate} has been confirmed. CIB&RC chemical control advisories are now active.`,
      },
      data: {
        type: "KVK_VERIFIED",
        scanId: String(scanId),
        userId: String(userId),
        scientistNote: String(scientistNote),
        timestamp: new Date().toISOString(),
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "florax_kvk_alerts",
          priority: "max",
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

    try {
      console.log(`[FloraX KVK Trigger] Dispatching notification to farmer channel: ${topic}...`);
      const response = await admin.messaging().send(message);
      console.log(`[FloraX KVK Trigger] FCM delivery confirmed. Message ID: ${response}`);
      return response;
    } catch (fcmError) {
      console.error(`[FloraX KVK Trigger ERROR] Failed sending notification to ${topic}:`, fcmError);
      throw fcmError;
    }
  }
);
