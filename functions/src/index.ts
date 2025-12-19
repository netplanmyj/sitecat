/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentCreated, onDocumentDeleted} from "firebase-functions/v2/firestore";
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
setGlobalOptions({ maxInstances: 10 });

initializeApp();
const db = getFirestore();

const LIFETIME_PRODUCT_ID = "sitecat.lifetime.basic";
const SUBSCRIPTION_DOC_ID = "lifetime";
const FREE_PLAN_SITE_LIMIT = 3;
const PREMIUM_PLAN_SITE_LIMIT = 30;
const FREE_HISTORY_LIMIT = 10;
const PREMIUM_HISTORY_LIMIT = 50;

async function isPremiumUser(userId: string): Promise<boolean> {
	const subDoc = await db
		.collection("users")
		.doc(userId)
		.collection("subscription")
		.doc(SUBSCRIPTION_DOC_ID)
		.get();
	return subDoc.exists && subDoc.data()?.isActive === true;
}

async function getSiteLimit(userId: string): Promise<number> {
	const premium = await isPremiumUser(userId);
	return premium ? PREMIUM_PLAN_SITE_LIMIT : FREE_PLAN_SITE_LIMIT;
}

async function getHistoryLimit(userId: string): Promise<number> {
	const premium = await isPremiumUser(userId);
	return premium ? PREMIUM_HISTORY_LIMIT : FREE_HISTORY_LIMIT;
}

export const saveLifetimePurchase = onCall({ maxInstances: 10 }, async (request) => {
	const userId = request.auth?.uid;
	if (!userId) {
		throw new HttpsError("unauthenticated", "Authentication required");
	}

	const data = request.data ?? {};
	const { productId, platform, transactionId, verificationData } = data;

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

	await docRef.set(
		{
			productId,
			purchaseDate: FieldValue.serverTimestamp(),
			isActive: true,
			platform,
			transactionId: transactionId ?? null,
			verificationData: verificationData ?? null,
		},
		{ merge: true }
	);

	logger.info("Saved lifetime purchase", { userId, productId, platform });
	return { ok: true };
});

export const onSiteCreated = onDocumentCreated("users/{userId}/sites/{siteId}", async (event) => {
	const userId = event.params.userId as string;
	const sitesCol = db.collection("users").doc(userId).collection("sites");
	const siteCountSnap = await sitesCol.count().get();
	const siteCount = siteCountSnap.data().count ?? 0;
	const limit = await getSiteLimit(userId);

	// Persist the count for rules-side checks
	await db.collection("users").doc(userId).set({ siteCount }, { merge: true });

	if (siteCount > limit) {
		// Over limit: delete the newly created site
		await event.data?.ref.delete();
		logger.warn("Site creation rejected: over limit", { userId, siteCount, limit });
	}
});

export const onSiteDeleted = onDocumentDeleted("users/{userId}/sites/{siteId}", async (event) => {
	const userId = event.params.userId as string;
	const sitesCol = db.collection("users").doc(userId).collection("sites");
	const siteCountSnap = await sitesCol.count().get();
	const siteCount = siteCountSnap.data().count ?? 0;

	await db.collection("users").doc(userId).set({ siteCount }, { merge: true });
});

export const enforceLinkCheckHistoryLimit = onDocumentCreated(
	"users/{userId}/linkCheckResults/{resultId}",
	async (event) => {
		const userId = event.params.userId as string;
		const limit = await getHistoryLimit(userId);
		const resultsCol = db.collection("users").doc(userId).collection("linkCheckResults");

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
