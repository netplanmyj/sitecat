# SiteCat - 価格戦略

**最終更新: 2025年12月3日**  
**現在のバージョン: v1.0.3 (Build 41) - App Store配信中**

## 概要

このドキュメントは、SiteCat iOS版の段階的な有料化戦略を定義します。v1.0.3のリリース後、以下の2段階で有料機能を展開します。

---

## 📊 価格プラン

### 無料版（現行）
- **サイト登録**: 1個
- **Quick Check**: 手動実行のみ
- **Full Scan**: 手動実行のみ
- **除外パス設定**: 不可
- **履歴表示**: Quick Check 10件 + Full Scan 10件

### 買い切り版 - ¥1,220（Phase 3a）
- **サイト登録**: 無制限
- **Quick Check**: 手動実行のみ
- **Full Scan**: 手動実行のみ + **中断・再開機能**
- **除外パス設定**: 可能
- **履歴表示**: Quick Check 50件 + Full Scan 50件

### サブスクリプション - ¥490/月（Phase 3b）
買い切り版のすべての機能 +
- **自動監視**: 1日4回（6時間ごと）Cloud Run実行
- **プッシュ通知**: リンク切れ検出時の即時通知
- **レポート機能**: 詳細な統計・推移グラフ
- **履歴表示**: Quick Check 50件 + Full Scan 50件（買い切りと同じ）

---

## 🎯 実装ロードマップ

### Phase 1: 無料版リリース ✅ 完了
**期間**: 2025年10月～11月  
**バージョン**: v1.0.0 - v1.0.3

#### 実装済み機能
- Firebase Authentication（Google, Apple Sign-In）
- サイト登録・管理（1サイト制限）
- Quick Check（手動実行）
- Full Scan（手動実行、サイトマップベース）
- 履歴表示（各10件）
- グラフ表示（fl_chart）
- App Store審査・配信（175カ国）

#### 技術スタック
- Flutter 3.27.3 / Dart 3.10.1
- Firebase: Auth, Firestore, Functions
- CI/CD: Xcode Cloud
- 現在のビルド番号: 41

### Phase 2: バックエンド基盤整備 ✅ 完了
**期間**: 2025年11月～12月  
**バージョン**: v1.0.3 - v1.0.4

#### 実装済み機能
- 除外パス設定（バックエンド）
  - `Site`モデルに`excludedPaths`フィールド追加
  - `LinkCheckerService`でパス除外ロジック実装
  - 単体テスト追加（168テスト成功）
  - PR #195でマージ完了

### Phase 3a: 買い切り有料版 🔄 次のフェーズ
**予定**: 2025年12月～  
**価格**: ¥1,220（一度の購入）

#### 実装予定機能
1. **In-App Purchase 統合**
   - StoreKit 2対応
   - 課金状態管理（Firestore `users/{userId}/subscription`）
   - リストア機能

2. **サイト数制限解除**（#196）
   - 定数変更のみ（`lib/constants/limits.dart`）
   - UI側で課金状態チェック

3. **除外パス設定UI**（#197）
   - 設定画面実装
   - パス入力・検証UI
   - プレビュー機能

4. **Full Scan中断・再開機能**（#193）
   - Isolate管理の改善
   - 一時停止・再開ロジック
   - 進捗状態の永続化

5. **履歴表示拡張**
   - 取得件数を10→50に変更（Quick Check/Full Scan各50件）
   - クリーンアップロジック更新（`link_checker_service.dart`）

#### 技術的な実装ポイント
```dart
// 課金状態管理
class SubscriptionService {
  static const String LIFETIME_PRODUCT_ID = 'sitecat.lifetime.basic';
  
  Future<bool> hasLifetimeAccess() async {
    // StoreKit 2で購入状態確認
    // Firestoreに状態キャッシュ
  }
}

// 履歴件数制御
class HistoryService {
  static const int FREE_HISTORY_LIMIT = 10;
  static const int PAID_HISTORY_LIMIT = 50;
  
  Future<List<CheckResult>> getHistory(String siteId, bool isPaid) async {
    final limit = isPaid ? PAID_HISTORY_LIMIT : FREE_HISTORY_LIMIT;
    return FirebaseFirestore.instance
        .collection('check_results')
        .where('siteId', isEqualTo: siteId)
        .orderBy('checkedAt', descending: true)
        .limit(limit)
        .get();
  }
  
  // クリーンアップ: Quick Check/Full Scan別々に50件保持
  Future<void> cleanupOldResults(String siteId) async {
    await _cleanupByType(siteId, 'quick_check', PAID_HISTORY_LIMIT);
    await _cleanupByType(siteId, 'full_scan', PAID_HISTORY_LIMIT);
  }
}
```

### Phase 3b: サブスクリプション版 📅 将来計画
**予定**: Phase 3a完了後  
**価格**: ¥490/月（すべてのPhase 3a機能を含む）

#### 実装予定機能
1. **Cloud Run定期実行**
   - Cloud Scheduler設定
   - 1日4回（6時間ごと）の自動監視
   - 課金状態の確認と実行制御

2. **プッシュ通知**
   - Firebase Cloud Messaging統合
   - リンク切れ検出時の通知
   - 通知設定UI

3. **詳細レポート機能**
   - 推移グラフの強化
   - 統計サマリー
   - エクスポート機能（将来検討）

#### サブスクリプション管理
```dart
class SubscriptionService {
  static const String MONTHLY_PRODUCT_ID = 'sitecat.subscription.monthly';
  
  Future<bool> hasActiveSubscription() async {
    // StoreKit 2でサブスク状態確認
    // 自動更新のステータス管理
    // Firestoreに同期
  }
  
  Future<void> enableAutoMonitoring(String userId) async {
    // Cloud Run Jobの有効化
    // FCMトークン登録
  }
}
```

---

## 💰 価格設定の根拠

### 買い切り版: ¥1,220
- **ターゲット**: 個人開発者、小規模サイト運営者
- **競合比較**: 類似ツールの月額料金の2-3ヶ月分相当
- **提供価値**: 
  - サイト数無制限（複数サイト管理）
  - 除外パス設定（柔軟な監視）
  - 中断・再開機能（大規模サイト対応）
  - 履歴50件表示（十分な振り返り期間）

### サブスクリプション: ¥490/月
- **ターゲット**: アクティブな運営者、ビジネス利用
- **競合比較**: 他のモニタリングサービス（月額$10-30）より低価格
- **提供価値**:
  - 自動監視（手間削減）
  - 即時プッシュ通知（問題の早期発見）
  - 詳細レポート（データドリブンな改善）

### 価格戦略のポイント
1. **買い切り優先**: 初期ユーザーの獲得と収益化
2. **サブスク誘導**: 継続的な価値提供でアップグレード促進
3. **柔軟な選択肢**: ユーザーの利用状況に応じた選択
4. **シンプルな履歴管理**: 買い切り・サブスク共通仕様で実装負担削減

---

## 📈 成功指標（KPI）

### Phase 3a: 買い切り版
- 無料→有料 コンバージョン率: 3-5%目標
- 購入単価: ¥1,220
- 初月収益目標: ¥50,000-100,000

### Phase 3b: サブスクリプション
- 買い切り→サブスク アップグレード率: 10-15%目標
- 月次継続率（リテンション）: 80%以上
- MRR（月次経常収益）成長

### ビジネス目標
- Phase 3a完了後3ヶ月で累計100万円収益
- サブスク開始後6ヶ月でMRR 20万円達成
- 1年後にサブスク収益が買い切りを上回る

---

## 🔄 将来の拡張可能性

### 機能拡張の候補
- **レポート強化**: CSVエクスポート、詳細分析
- **通知拡張**: Slack/Discord連携、カスタムWebhook
- **チーム機能**: 複数ユーザーでのサイト共有
- **API提供**: 外部システムとの連携

### 価格プラン拡張
- Enterprise プラン（大規模サイト向け）
- チームプラン（複数ユーザー共有）

### サブスク機能の差別化（将来検討）
現在は買い切り・サブスクで履歴50件に統一。  
運用後のフィードバックに応じて、サブスクの価値をさらに高める施策を検討：
- 履歴の無制限化または長期保存（例: 6ヶ月～1年）
- より高頻度な自動監視（1時間ごとなど）
- 高度なアラートルール設定

---

## ⚠️ リスクと対策

### 課金システムのリスク
- **リスク**: StoreKit統合の不具合、リストア失敗
- **対策**: 徹底したテスト、段階的ロールアウト、Firestore状態管理

### コスト管理
- **リスク**: Cloud Run実行コストの増加
- **対策**: サブスク数に応じた実行制御、コスト監視アラート

### ユーザー離脱
- **リスク**: 有料化後のユーザー離脱
- **対策**: 無料版の継続提供、明確な価値提案、段階的な移行

---

## 📝 ドキュメント管理

### 関連ドキュメント
- `BUSINESS_MODEL.md` - ビジネスモデルの詳細
- `PROJECT_CONCEPT.md` - プロジェクト全体のコンセプト
- `DEVELOPMENT_GUIDE.md` - 技術的な実装ガイド

### 更新履歴
- 2025年11月: v1.0.3リリース
  - Phase 1/2完了を反映
  - 買い切り・サブスクの2段階戦略を明確化
  - 履歴表示を買い切り・サブスク共通仕様に統一（各50件）
- 2025-12-03: v1.0.3リリース後の実態に合わせて全面改訂
  - ドキュメント全体を最新仕様に更新
- （以前の履歴は古い設計のため省略）