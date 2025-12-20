// Functions entry point. Keeps deployment lint-clean for rules/functions.
import {setGlobalOptions} from "firebase-functions";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentDeleted,
} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

initializeApp();
const db = getFirestore();

const LIFETIME_PRODUCT_ID = "sitecat.lifetime.basic";
const SUBSCRIPTION_DOC_ID = "lifetime";
const FREE_PLAN_SITE_LIMIT = 3;
const PREMIUM_PLAN_SITE_LIMIT = 30;
const FREE_HISTORY_LIMIT = 10;
const PREMIUM_HISTORY_LIMIT = 50;

/**
 * Returns true when the user has an active premium subscription.
 * @param {string} userId Firestore user id.
 * @return {Promise<boolean>} True if user has active premium subscription.
 */
async function isPremiumUser(userId: string): Promise<boolean> {
  try {
    const subDoc = await db
      .collection("users")
      .doc(userId)
      .collection("subscription")
      .doc(SUBSCRIPTION_DOC_ID)
      .get();
    return subDoc.exists && subDoc.data()?.isActive === true;
  } catch (error) {
    logger.error("Treating user as free due to lookup error", {
      userId,
      error,
    });
    return false;
  }
}

/**
 * Site creation limit based on subscription.
 * @param {string} userId Firestore user id.
 * @return {Promise<number>} Maximum number of sites allowed.
 */
async function getSiteLimit(userId: string): Promise<number> {
  const premium = await isPremiumUser(userId);
  return premium ? PREMIUM_PLAN_SITE_LIMIT : FREE_PLAN_SITE_LIMIT;
}

/**
 * Link check history retention limit based on subscription.
 * @param {string} userId Firestore user id.
 * @return {Promise<number>} Maximum number of history records to retain.
 */
async function getHistoryLimit(userId: string): Promise<number> {
  const premium = await isPremiumUser(userId);
  return premium ? PREMIUM_HISTORY_LIMIT : FREE_HISTORY_LIMIT;
}

export const saveLifetimePurchase = onCall(
  {maxInstances: 10},
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const data = request.data ?? {};
    const {productId, platform, transactionId, verificationData} = data;

    if (productId !== LIFETIME_PRODUCT_ID) {
      throw new HttpsError("invalid-argument", "Invalid productId");
    }

    if (!platform) {
      throw new HttpsError("invalid-argument", "platform is required");
    }

    const docRef = db
      .collection("users")
      .doc(userId)
      .collection("subscription")
      .doc(SUBSCRIPTION_DOC_ID);

    const payload = {
      productId,
      purchaseDate: FieldValue.serverTimestamp(),
      isActive: true,
      platform,
      transactionId: transactionId ?? null,
      verificationData: verificationData ?? null,
    };

    await docRef.set(payload, {merge: true});
    await db
      .collection("users")
      .doc(userId)
      .set({plan: "premium"}, {merge: true});

    const saved = await docRef.get();
    logger.info("Saved lifetime purchase", {userId, productId, platform});
    return {ok: true, subscription: saved.data() ?? {}};
  }
);

export const onSiteCreated = onDocumentCreated(
  "users/{userId}/sites/{siteId}",
  async (event) => {
    const userId = event.params.userId as string;
    const sitesCol = db.collection("users").doc(userId).collection("sites");
    const siteCountSnap = await sitesCol.count().get();
    const siteCount = siteCountSnap.data().count ?? 0;
    const limit = await getSiteLimit(userId);

    // Persist the updated count so rules can use it on future requests
    await db.collection("users").doc(userId).set({siteCount}, {merge: true});

    if (siteCount > limit) {
      await event.data?.ref.delete();
      logger.warn("Site creation rejected: over limit", {
        userId,
        siteCount,
        limit,
      });
    }
  }
);

export const onSiteDeleted = onDocumentDeleted(
  "users/{userId}/sites/{siteId}",
  async (event) => {
    const userId = event.params.userId as string;
    const sitesCol = db.collection("users").doc(userId).collection("sites");
    const siteCountSnap = await sitesCol.count().get();
    const siteCount = siteCountSnap.data().count ?? 0;

    await db.collection("users").doc(userId).set({siteCount}, {merge: true});
  }
);

export const enforceLinkCheckHistoryLimit = onDocumentCreated(
  "users/{userId}/linkCheckResults/{resultId}",
  async (event) => {
    const userId = event.params.userId as string;
    const limit = await getHistoryLimit(userId);
    const resultsCol = db
      .collection("users")
      .doc(userId)
      .collection("linkCheckResults");

    const snapshot = await resultsCol
      .orderBy("checkedAt", "desc")
      .offset(limit)
      .get();

    if (!snapshot.empty) {
      const deletions = snapshot.docs.map((doc) => doc.ref.delete());
      await Promise.all(deletions);
      logger.info("Pruned linkCheckResults beyond history limit", {
        userId,
        deleted: snapshot.size,
        limit,
      });
    }
  }
);
/**
 * Callable HTTPS function to clean up subscription and other user-related
 * data from Firestore as part of the account deletion flow.
 *
 * This function is NOT an Auth trigger. It must be explicitly invoked by
 * the client BEFORE deleting the user from Firebase Authentication.
 *
 * Deletes all subcollections (subscription, sites, monitoring results,
 * link check results, etc.) before deleting the user document itself.
 *
 * @param request - Must have authenticated user context
 */
export const onAuthUserDeleted = onCall(
  {maxInstances: 10},
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    try {
      const userDocRef = db.collection("users").doc(userId);
      const collectionNames = [
        "subscription",
        "sites",
        "monitoringResults",
        "linkCheckResults",
      ];

      // Delete all subcollections
      for (const collectionName of collectionNames) {
        const subcollectionRef = userDocRef.collection(collectionName);
        const subcollectionSnapshot = await subcollectionRef.get();

        if (!subcollectionSnapshot.empty) {
          // For linkCheckResults, also delete nested brokenLinks subcollections
          if (collectionName === "linkCheckResults") {
            for (const resultDoc of subcollectionSnapshot.docs) {
              const brokenLinksRef = resultDoc.ref.collection("brokenLinks");
              const brokenLinksSnapshot = await brokenLinksRef.get();
              if (!brokenLinksSnapshot.empty) {
                const BATCH_SIZE = 500;
                const docs = brokenLinksSnapshot.docs;
                for (let i = 0; i < docs.length; i += BATCH_SIZE) {
                  const batch = db.batch();
                  const chunk = docs.slice(i, i + BATCH_SIZE);
                  for (const doc of chunk) {
                    batch.delete(doc.ref);
                  }
                  await batch.commit();
                }
                logger.info(
                  `Deleted brokenLinks for linkCheckResult ${resultDoc.id}`,
                  {userId, count: brokenLinksSnapshot.size}
                );
              }
            }
          }

          // Batch delete documents (max 500 operations per batch)
          const BATCH_SIZE = 500;
          const docs = subcollectionSnapshot.docs;
          for (let i = 0; i < docs.length; i += BATCH_SIZE) {
            const batch = db.batch();
            const chunk = docs.slice(i, i + BATCH_SIZE);
            for (const doc of chunk) {
              batch.delete(doc.ref);
            }
            await batch.commit();
          }
          logger.info(`Deleted ${collectionName} documents for user`, {
            userId,
            count: subcollectionSnapshot.size,
          });
        }
      }

      // Delete user document itself
      await userDocRef.delete();
      logger.info("Cleaned up user data after deletion", {userId});
      return {ok: true};
    } catch (error) {
      logger.error("Error cleaning up user data", {userId, error});
      throw new HttpsError("internal", "Failed to cleanup user data");
    }
  }
);
