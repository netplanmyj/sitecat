# PR Draft: SiteCat 無料版・有料版機能設計とFirebaseコスト制御戦略

## 概要
SiteCatプロジェクトにおいて、Firebaseコストを抑制しつつユーザーに価値を提供するフリーミアムモデルの詳細設計を行いました。

## 変更内容

### 📋 新規作成ドキュメント
- **料金・機能戦略** (`docs/PRICING_STRATEGY.md`)
  - 無料版A案（完全オフライン）vs B案（制限付きFirebase）の比較
  - 推奨案（B案）の詳細設計
  - 有料版機能とロードマップ
  
- **Firebaseコスト制御** (`docs/FIREBASE_COST_CONTROL.md`)
  - Firestoreセキュリティルールによる使用量制限
  - Cloud Functions実装例
  - 予算アラート・監視設定
  - 管理者用ダッシュボード

- **使用量制御サービス** (`lib/services/usage_control_service.dart`)
  - プラン別制限管理クラス
  - Flutter アプリ側での制限チェック実装例
  - UI連携サンプルコード

### 📝 更新ドキュメント
- **README.md**
  - 無料版・有料版機能比較表追加
  - 料金プラン詳細
  - ドキュメントリンク追加

- **PROJECT_CONCEPT.md**
  - フリーミアムビジネスモデルの説明追加

### 🔧 GitHub設定
- **Issue テンプレート**
  - Firebase認証実装用テンプレート追加
  - バグレポート・機能リクエストテンプレート
  
- **PR テンプレート・CODEOWNERS・CI設定**
  - 開発フロー整備

## 主要な設計決定

### 💰 料金戦略
| プラン | 料金 | 主要制限 |
|--------|------|----------|
| 無料版 | $0 | 手動監視のみ、10サイト、1日10回チェック |
| Personal | $9.99/月 | 自動監視、無制限サイト、プッシュ通知 |
| Business | $29.99/月 | チーム機能、高度な分析、外部連携 |

### 🛡️ コスト制御
- **無料版予想コスト**: 月$3-8（1000ユーザー想定）
- **制限メカニズム**: Firestoreルール + Cloud Functions + アプリ側チェック
- **予算アラート**: 月$10制限で自動通知

### 🎯 推奨アプローチ
**無料版B案**を採用：
- Google認証あり
- Firebase最小限利用
- 手動実行のみ
- 段階的アップグレード促進

## 技術的ハイライト

### セキュリティルール例
```javascript
// 無料版ユーザーのサイト数制限
allow create: if request.auth != null 
  && get(/databases/$(database)/documents/users/$(userId)).data.plan == 'free'
  && get(/databases/$(database)/documents/users/$(userId)).data.siteCount < 10;
```

### 使用量制限チェック
```dart
Future<UsageCheckResult> canExecuteCheck() async {
  final plan = await getCurrentPlan();
  final limits = PlanLimits.getLimits(plan);
  final todayUsage = await getTodayUsage();

  if (todayUsage >= limits.dailyChecks) {
    return UsageCheckResult.limitExceeded('Daily limit exceeded');
  }
  return UsageCheckResult.allowed(limits.dailyChecks - todayUsage);
}
```

## 次のステップ

### 即座に実施
1. ✅ このPRをマージ
2. 🎯 Firebase認証実装のIssue作成
3. 🚀 Firebase プロジェクト設定開始

### フェーズ別実装計画
1. **Phase 1**: Firebase認証（2-3週間）
2. **Phase 2**: 手動監視機能（2-3週間）
3. **Phase 3**: 使用量制限・UI（1-2週間）
4. **Phase 4**: 有料版機能・決済（3-4週間）

## テスト
- [ ] ドキュメントの整合性確認
- [ ] リンク切れチェック
- [ ] CI/CDパイプライン動作確認

## チェックリスト
- [x] コードが適切にフォーマットされている
- [x] 静的解析にパスしている
- [x] 必要なドキュメントを更新している
- [x] Breaking changes はない
- [x] セキュリティ考慮事項を検討している

## レビュー観点
- 設計の妥当性
- コスト試算の妥当性
- 実装可能性
- ドキュメントの分かりやすさ

---

この設計により、無料版でFirebaseコストを月$10以下に抑えながら、有料版への自然な移行を促進できる基盤が整いました。