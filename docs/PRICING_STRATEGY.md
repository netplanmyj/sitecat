# SiteCat - 無料版・有料版機能設計書

## 概要

Firebaseのコストを抑制しつつ、ユーザーに価値を提供する無料版・有料版の機能差別化設計です。

## 無料版 A案：完全オフライン版

### 🎯 基本方針
- Google認証なし
- Firebase利用なし
- 完全にローカル実行
- シンプルで軽量

### ✅ 提供機能

#### 1. 手動サイト監視
- **即座チェック**: ボタンタップでリアルタイム監視
- **レスポンス時間計測**: 応答速度表示
- **ステータス確認**: HTTP ステータスコード表示
- **履歴保存**: ローカルデータベース（SQLite）に保存

#### 2. 基本リンクチェック
- **単一ページ**: 指定URLのリンク切れをその場でチェック
- **浅い階層**: 1階層のみの簡易チェック
- **結果表示**: 壊れたリンク一覧をその場で表示

#### 3. ローカルデータ管理
- **サイト登録**: 最大5サイトまで
- **履歴表示**: 過去24時間分の監視履歴
- **簡易統計**: 成功/失敗回数の表示

#### 4. 基本UI/UX
- **ダークモード対応**
- **タブレット対応**
- **基本設定画面**

### ❌ 制限事項
- 定期監視なし（手動実行のみ）
- クラウド同期なし
- プッシュ通知なし
- データバックアップなし
- 詳細レポートなし

### 💰 コスト
- **Firebase**: $0（使用なし）
- **開発・維持**: 最小限

### 📱 実装方針
```dart
// ローカルデータベース
class LocalDatabase {
  late Database _database;
  
  // サイト管理
  Future<void> addSite(Site site) async { /* SQLite操作 */ }
  Future<List<Site>> getSites() async { /* 最大5件 */ }
  
  // 監視履歴
  Future<void> saveCheckResult(CheckResult result) async { /* */ }
  Future<List<CheckResult>> getHistory(String siteId) async { /* 24h分 */ }
}

// 手動監視
class ManualMonitor {
  Future<CheckResult> checkSite(Site site) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.get(Uri.parse(site.url));
      stopwatch.stop();
      
      return CheckResult(
        siteId: site.id,
        status: response.statusCode,
        responseTime: stopwatch.elapsedMilliseconds,
        checkedAt: DateTime.now(),
        isSuccess: response.statusCode == 200,
      );
    } catch (e) {
      stopwatch.stop();
      return CheckResult.error(site.id, e.toString());
    }
  }
}
```

---

## 無料版 B案：制限付きFirebase版

### 🎯 基本方針
- Google認証あり（無料）
- Firebase最小限利用
- 手動実行のみ
- クラウド同期対応

### ✅ 提供機能

#### 1. 認証・同期機能
- **Google認証**: Firebase Auth（無料範囲内）
- **データ同期**: 複数デバイス間でのサイト設定同期
- **バックアップ**: 設定データのクラウドバックアップ

#### 2. 手動監視（Cloud Functions）
- **手動実行**: ボタンタップでCloud Function呼び出し
- **詳細レポート**: より詳細な監視結果
- **履歴保存**: Firestoreに30日分保存
- **統計表示**: 月次統計レポート

#### 3. 強化されたリンクチェック
- **詳細スキャン**: より深い階層のリンクチェック
- **並列処理**: Cloud Functions での高速処理
- **レポート**: 詳細なリンク切れレポート

#### 4. 制限付き通知
- **即座通知**: 手動チェック時の結果通知のみ
- **アプリ内通知**: プッシュ通知なし、アプリ内のみ

### ❌ 制限事項
- **定期監視なし**: Cloud Schedulerは有料版のみ
- **プッシュ通知制限**: FCM使用量制限
- **サイト数制限**: 10サイトまで
- **履歴制限**: 30日間のみ
- **レポート制限**: 基本統計のみ

### 💰 コスト見積もり
```
月間想定コスト（1000ユーザー）:
- Firebase Auth: $0（無料枠内）
- Firestore: ~$1-3（読み書き制限）
- Cloud Functions: ~$2-5（手動実行のみ）
- Firebase Hosting: $0（無料枠内）
合計: $3-8/月
```

### 📱 実装方針
```dart
// Firebase認証
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Future<User?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    final GoogleSignInAuthentication googleAuth = 
        await googleUser!.authentication;
    
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    
    final UserCredential result = 
        await _auth.signInWithCredential(credential);
    return result.user;
  }
}

// 手動監視サービス
class ManualMonitoringService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  Future<Map<String, dynamic>> checkSite(String siteId) async {
    // 1日の実行回数制限チェック
    if (await _hasExceededDailyLimit(siteId)) {
      throw Exception('Daily check limit exceeded');
    }
    
    final callable = _functions.httpsCallable('checkSiteManual');
    final result = await callable.call({
      'siteId': siteId,
      'userId': FirebaseAuth.instance.currentUser!.uid,
    });
    
    return result.data;
  }
  
  Future<bool> _hasExceededDailyLimit(String siteId) async {
    // Firestoreで今日の実行回数をチェック（例：10回/日）
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    
    final query = await FirebaseFirestore.instance
        .collection('check_history')
        .where('siteId', isEqualTo: siteId)
        .where('checkedAt', isGreaterThanOrEqualTo: todayStart)
        .count()
        .get();
        
    return query.count >= 10; // 1日10回制限
  }
}
```

---

## 有料版機能

### 💎 Premium機能（両案共通）

#### 1. 自動監視
- **定期実行**: Cloud Scheduler使用
- **柔軟な間隔**: 5分～24時間で設定可能
- **複数パターン**: 平日/休日で異なる間隔設定

#### 2. 高度な通知
- **プッシュ通知**: Firebase Cloud Messaging
- **メール通知**: SendGrid/Gmail API連携
- **Slack/Discord**: Webhook連携
- **通知ルール**: 詳細な条件設定

#### 3. 詳細レポート・分析
- **アップタイム統計**: 月次/年次レポート
- **パフォーマンス分析**: レスポンス時間トレンド
- **SLA監視**: 可用性目標管理
- **CSVエクスポート**: データ出力機能

#### 4. 拡張機能
- **無制限サイト**: サイト数制限なし
- **長期履歴**: 1年間のデータ保持
- **API連携**: 外部システム連携
- **チーム機能**: 複数ユーザーでの共有

### 💰 料金設定案
```
月額料金:
- Personal: $9.99/月（個人利用）
- Business: $29.99/月（チーム利用）
- Enterprise: $99.99/月（大規模利用）
```

---

## 推奨案：B案の採用理由

### ✅ B案の優位性

1. **段階的アップグレード**
   - 無料版でFirebaseの利便性を体験
   - 自然な有料版への移行

2. **開発効率**
   - 統一されたアーキテクチャ
   - コードベースの共通化

3. **ユーザー体験**
   - クラウド同期による利便性
   - より信頼性の高い監視

4. **コスト管理**
   - 実行回数制限による予測可能なコスト
   - スケールしやすい設計

### ⚠️ リスク対策

1. **コスト超過防止**
```dart
// 利用制限クラス
class UsageLimiter {
  static const int DAILY_FREE_CHECKS = 10;
  static const int MAX_FREE_SITES = 10;
  
  Future<bool> canExecuteCheck(String userId) async {
    final todayChecks = await _getTodayCheckCount(userId);
    return todayChecks < DAILY_FREE_CHECKS;
  }
  
  Future<bool> canAddSite(String userId) async {
    final siteCount = await _getUserSiteCount(userId);
    return siteCount < MAX_FREE_SITES;
  }
}
```

2. **フリーミアム戦略**
```dart
// 機能制限管理
class FeatureGate {
  final String userId;
  final bool isPremium;
  
  bool get canUseAutoMonitoring => isPremium;
  bool get canUsePushNotifications => isPremium;
  bool get canExportData => isPremium;
  int get maxSites => isPremium ? 999 : 10;
  int get historyDays => isPremium ? 365 : 30;
}
```

---

## 実装ロードマップ

### Phase 1: 無料版B案の実装
1. Firebase プロジェクト設定
2. Google認証実装
3. 手動監視機能
4. 基本UI/UX

### Phase 2: 利用制限・コスト管理
1. 使用量制限機能
2. コスト監視ダッシュボード
3. エラーハンドリング強化

### Phase 3: 有料版機能開発
1. 決済システム（Stripe/Google Pay）
2. 定期監視機能
3. 高度な通知システム

### Phase 4: 最適化・拡張
1. パフォーマンス最適化
2. ユーザーフィードバック反映
3. 新機能追加

この設計により、無料版でFirebaseのコストを最小限に抑えながら、有料版への自然な移行を促進できます。