# Firebase コスト制御設定

## 概要
無料版ユーザーのFirebase使用量を制限し、予期しないコスト発生を防ぐための設定ファイルです。

## Firestore セキュリティルール

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ユーザーデータアクセス制御
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // 無料版ユーザーのサイト数制限
      allow create: if request.auth != null 
        && request.auth.uid == userId
        && resource == null
        && get(/databases/$(database)/documents/users/$(userId)).data.plan == 'free'
        && get(/databases/$(database)/documents/users/$(userId)).data.siteCount < 1;
    }
    
    // サイト設定アクセス制御
    match /sites/{siteId} {
      allow read, write: if request.auth != null 
        && resource.data.userId == request.auth.uid;
      
      // 無料版ユーザーの新規サイト作成制限
      allow create: if request.auth != null 
        && request.auth.uid == resource.data.userId
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.plan == 'free'
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.siteCount < 1;
    }
    
    // 監視履歴アクセス制御
    match /check_history/{checkId} {
      allow read: if request.auth != null 
        && resource.data.userId == request.auth.uid;
      
      allow write: if request.auth != null 
        && request.auth.uid == resource.data.userId;
      
      // 無料版ユーザーの1日あたりチェック回数制限
      allow create: if request.auth != null 
        && request.auth.uid == resource.data.userId
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.plan == 'free'
        && dailyCheckCount() < 10;
    }
    
    // 1日のチェック回数を計算する関数
    function dailyCheckCount() {
      let today = timestamp.date(request.time);
      return get(/databases/$(database)/documents/usage_stats/$(request.auth.uid + '_' + today)).data.checkCount;
    }
  }
}
```

## Cloud Functions コスト制御

```javascript
// functions/src/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

// 使用量制限チェック関数
async function checkUsageLimits(userId, action) {
  const userDoc = await db.collection('users').doc(userId).get();
  const userData = userDoc.data();
  
  if (!userData) {
    throw new functions.https.HttpsError('not-found', 'User not found');
  }
  
  const plan = userData.plan || 'free';
  const limits = {
    free: {
      dailyChecks: 10,
      maxSites: 1,
      historyDays: 30
    },
    personal: {
      dailyChecks: 1000,
      maxSites: 999,
      historyDays: 365
    }
  };
  
  const userLimits = limits[plan];
  
  if (action === 'check') {
    const today = new Date().toISOString().split('T')[0];
    const usageDoc = await db
      .collection('usage_stats')
      .doc(`${userId}_${today}`)
      .get();
    
    const todayChecks = usageDoc.exists ? usageDoc.data().checkCount : 0;
    
    if (todayChecks >= userLimits.dailyChecks) {
      throw new functions.https.HttpsError(
        'resource-exhausted', 
        `Daily check limit (${userLimits.dailyChecks}) exceeded`
      );
    }
  }
  
  if (action === 'addSite') {
    const sitesSnapshot = await db
      .collection('sites')
      .where('userId', '==', userId)
      .get();
    
    if (sitesSnapshot.size >= userLimits.maxSites) {
      throw new functions.https.HttpsError(
        'resource-exhausted', 
        `Site limit (${userLimits.maxSites}) exceeded`
      );
    }
  }
  
  return userLimits;
}

// 手動サイトチェック関数
exports.checkSiteManual = functions.https.onCall(async (data, context) => {
  // 認証チェック
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const userId = context.auth.uid;
  const { siteId } = data;
  
  try {
    // 使用量制限チェック
    await checkUsageLimits(userId, 'check');
    
    // サイト情報取得
    const siteDoc = await db.collection('sites').doc(siteId).get();
    if (!siteDoc.exists || siteDoc.data().userId !== userId) {
      throw new functions.https.HttpsError('permission-denied', 'Site not found or access denied');
    }
    
    const siteData = siteDoc.data();
    
    // HTTP チェック実行
    const axios = require('axios');
    const startTime = Date.now();
    
    let checkResult;
    try {
      const response = await axios.get(siteData.url, {
        timeout: 30000,
        validateStatus: () => true // すべてのステータスコードを受け入れ
      });
      
      const responseTime = Date.now() - startTime;
      
      checkResult = {
        siteId,
        userId,
        url: siteData.url,
        status: response.status,
        responseTime,
        isSuccess: response.status >= 200 && response.status < 400,
        checkedAt: admin.firestore.FieldValue.serverTimestamp(),
        error: null
      };
    } catch (error) {
      const responseTime = Date.now() - startTime;
      
      checkResult = {
        siteId,
        userId,
        url: siteData.url,
        status: 0,
        responseTime,
        isSuccess: false,
        checkedAt: admin.firestore.FieldValue.serverTimestamp(),
        error: error.message
      };
    }
    
    // 結果をFirestoreに保存
    await db.collection('check_history').add(checkResult);
    
    // 使用量統計更新
    const today = new Date().toISOString().split('T')[0];
    const usageRef = db.collection('usage_stats').doc(`${userId}_${today}`);
    
    await db.runTransaction(async (transaction) => {
      const usageDoc = await transaction.get(usageRef);
      const currentCount = usageDoc.exists ? usageDoc.data().checkCount : 0;
      
      transaction.set(usageRef, {
        userId,
        date: today,
        checkCount: currentCount + 1,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    });
    
    return checkResult;
    
  } catch (error) {
    console.error('Error in checkSiteManual:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', 'Internal server error');
  }
});

// 新規サイト追加制限
exports.addSite = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const userId = context.auth.uid;
  
  try {
    // 使用量制限チェック
    await checkUsageLimits(userId, 'addSite');
    
    const { name, url } = data;
    
    // サイトデータ作成
    const siteData = {
      userId,
      name,
      url,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true
    };
    
    // Firestoreに保存
    const siteRef = await db.collection('sites').add(siteData);
    
    // ユーザーのサイト数を更新
    await db.runTransaction(async (transaction) => {
      const userRef = db.collection('users').doc(userId);
      const userDoc = await transaction.get(userRef);
      const userData = userDoc.data() || {};
      const currentSiteCount = userData.siteCount || 0;
      
      transaction.set(userRef, {
        siteCount: currentSiteCount + 1,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    });
    
    return { siteId: siteRef.id, ...siteData };
    
  } catch (error) {
    console.error('Error in addSite:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', 'Internal server error');
  }
});
```

## Firebase予算アラート設定

```bash
# gcloud CLIでの予算設定
# プロジェクトIDを設定
export PROJECT_ID="your-project-id"

# 予算作成（月$10制限）
gcloud billing budgets create \
  --billing-account=YOUR_BILLING_ACCOUNT_ID \
  --display-name="SiteCat Monthly Budget" \
  --budget-amount=10 \
  --threshold-rule=percent=50,basis=CURRENT_SPEND \
  --threshold-rule=percent=90,basis=CURRENT_SPEND \
  --threshold-rule=percent=100,basis=CURRENT_SPEND \
  --notifications-rule=monitoring-notification-channels=NOTIFICATION_CHANNEL_ID
```

## 監視・アラート設定

```yaml
# monitoring.yaml - Cloud Monitoring設定
resources:
  - name: firebase-usage-alert
    type: monitoring.v1.alertPolicy
    properties:
      displayName: "Firebase Usage Alert"
      conditions:
        - displayName: "High Firestore Operations"
          conditionThreshold:
            filter: 'resource.type="firestore_database"'
            comparison: COMPARISON_GREATER_THAN
            thresholdValue: 50000  # 1日50,000操作で警告
            duration: 300s
      notificationChannels:
        - "projects/PROJECT_ID/notificationChannels/CHANNEL_ID"
```

## 使用量監視ダッシュボード

```javascript
// 管理者用の使用量監視ダッシュボード
exports.getUsageStats = functions.https.onCall(async (data, context) => {
  // 管理者権限チェック
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }
  
  const { startDate, endDate } = data;
  
  try {
    // 期間内の使用量統計取得
    const usageSnapshot = await db
      .collection('usage_stats')
      .where('date', '>=', startDate)
      .where('date', '<=', endDate)
      .get();
    
    let totalChecks = 0;
    let totalUsers = new Set();
    let dailyStats = {};
    
    usageSnapshot.forEach(doc => {
      const data = doc.data();
      totalChecks += data.checkCount;
      totalUsers.add(data.userId);
      
      if (!dailyStats[data.date]) {
        dailyStats[data.date] = { checks: 0, users: new Set() };
      }
      
      dailyStats[data.date].checks += data.checkCount;
      dailyStats[data.date].users.add(data.userId);
    });
    
    // レスポンス用にSetをArrayに変換
    Object.keys(dailyStats).forEach(date => {
      dailyStats[date].users = dailyStats[date].users.size;
    });
    
    return {
      totalChecks,
      totalUsers: totalUsers.size,
      dailyStats,
      period: { startDate, endDate }
    };
    
  } catch (error) {
    console.error('Error getting usage stats:', error);
    throw new functions.https.HttpsError('internal', 'Failed to retrieve usage stats');
  }
});
```

## 実装チェックリスト

### 1. Firestore設定
- [ ] セキュリティルールの適用
- [ ] インデックス作成
- [ ] 無料版制限の実装

### 2. Cloud Functions設定
- [ ] 使用量制限チェック関数
- [ ] 手動監視関数
- [ ] エラーハンドリング

### 3. 監視・アラート
- [ ] 予算アラート設定
- [ ] 使用量監視ダッシュボード
- [ ] 異常使用パターン検知

### 4. テスト
- [ ] 制限超過時の動作テスト
- [ ] パフォーマンステスト
- [ ] コスト計算の検証

この設定により、無料版ユーザーのFirebase使用量を確実に制限し、予期しないコスト発生を防ぐことができます。