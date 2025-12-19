/**
 * Script to fix siteCount for all users
 *
 * Usage:
 *   node scripts/fix_site_count.js [projectId]
 *
 * Project resolution order:
 *   1) CLI arg:           node scripts/fix_site_count.js my-project-id
 *   2) Env vars:          FIREBASE_PROJECT_ID / GCLOUD_PROJECT / GOOGLE_CLOUD_PROJECT
 *   3) Safe default dev:  sitecat-dev
 *
 * Safety for production:
 *   To allow running against sitecat-prod, you MUST set:
 *     CONFIRM_PROD_MIGRATION=true
 */

const admin = require('firebase-admin');

// Resolve Firebase project ID with safe defaults
const DEFAULT_PROJECT_ID = 'sitecat-dev';
const cliProjectId = process.argv[2];
const envProjectId =
  process.env.FIREBASE_PROJECT_ID ||
  process.env.GCLOUD_PROJECT ||
  process.env.GOOGLE_CLOUD_PROJECT;

const projectId = cliProjectId || envProjectId || DEFAULT_PROJECT_ID;

// Prevent accidental writes to production without explicit confirmation
if (projectId === 'sitecat-prod' && process.env.CONFIRM_PROD_MIGRATION !== 'true') {
  console.error(
    'Refusing to run fix_site_count.js against production project "sitecat-prod" without confirmation.\n' +
      'If you really intend to run this against production, set CONFIRM_PROD_MIGRATION=true explicitly.\n' +
      'Example:\n' +
      '  CONFIRM_PROD_MIGRATION=true node scripts/fix_site_count.js sitecat-prod'
  );
  process.exit(1);
}

console.log(`Using Firebase project: ${projectId}`);

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId
});

const db = admin.firestore();

async function fixSiteCount() {
  console.log('Starting siteCount fix...');
  
  const usersSnapshot = await db.collection('users').get();
  
  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    console.log(`\nProcessing user: ${userId}`);
    
    // Count actual sites
    const sitesSnapshot = await db
      .collection('users')
      .doc(userId)
      .collection('sites')
      .get();
    
    const actualCount = sitesSnapshot.size;
    const currentCount = userDoc.data()?.siteCount || 0;
    
    console.log(`  Current siteCount: ${currentCount}`);
    console.log(`  Actual sites: ${actualCount}`);
    
    if (currentCount !== actualCount) {
      console.log(`  ❌ Mismatch detected! Updating...`);
      await db.collection('users').doc(userId).set(
        { siteCount: actualCount },
        { merge: true }
      );
      console.log(`  ✅ Updated siteCount to ${actualCount}`);
    } else {
      console.log(`  ✅ Already correct`);
    }
  }
  
  console.log('\n✅ Done!');
}

fixSiteCount()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error);
    process.exit(1);
  });
