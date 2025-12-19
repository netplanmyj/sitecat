/**
 * Script to fix siteCount for all users
 * Run with: node scripts/fix_site_count.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'sitecat-prod'
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
