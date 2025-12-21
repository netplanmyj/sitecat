# v1.0.9 Release Plan

> **リリース予定**: 2025年12月下旬  
> **目的**: コード品質向上とテストカバレッジ拡大  
> **対象**: TestFlight → App Store

> 注記: バージョン番号の更新（pubspec.yaml）を実行しました。
> 現在のバージョンは v1.0.9+78 です（審査提出用）。

---

## 概要

v1.0.9では、Phase 3bに向けた基盤整備として、コードの保守性向上とテストカバレッジの改善を行います。

---

## リリース目標

### 主要目標
1. ✅ TestFlightビルド101で課金機能の実機確認完了
2. 🔲 テストカバレッジ: 32% → 50%以上
3. 🔲 コード重複: 8% → 6%以下
4. 🔲 重要なバグ修正とパフォーマンス改善

### 副次目標
- CI/CDパイプラインの安定化
- ドキュメント整備
- 開発者体験の向上

---

## 実施タスク（優先順位順）

### Phase 1: サーバー側セキュリティ強化 🔴 CRITICAL

**期間**: 1.5-2週間  
**複雑度**: ⭐⭐⭐⭐（高）

#### Task 1.1: Apple レシート検証 - Issue #300 **MUST**
**優先度**: P0 🔴  
**工数**: 3-5日  
**判断**: **MUST** - セキュリティ上必須

**理由:**
- クライアント側で `isPremium` フラグを信頼している危険性
- 不正な課金状態遷移を防止
- App Store 審査要件

**実装内容:**
```typescript
// functions/src/verifyReceipt.ts
exports.verifyReceipt = onCall(async (request) => {
  const receipt = request.data.receipt;
  
  // Apple App Store Server API で検証
  const isValid = await callAppleReceiptValidation(receipt);
  
  if (!isValid) {
    throw new HttpsError('invalid-argument', 'Invalid receipt');
  }
  
  // 結果を永続化
  await saveVerificationResult(userId, true);
  return { verified: true };
});
```

**成果物:**
- Apple レシート検証実装
- 検証結果の Firestore 永続化
- エラーハンドリング

---

#### Task 1.2: トランザクション的なサイト作成 - Issue #299 **MUST**
**優先度**: P0 🔴  
**工数**: 2-3日  
**判断**: **MUST** - UX 改善 + 不具合防止

**理由:**
- クライアント側の競合条件で「作成→削除」の混乱 UX
- 制限超過時の不正なサイト追加を防止
- 必須エラーメッセージ表示

**実装内容:**
```typescript
// functions/src/createSiteWithLimit.ts
exports.createSiteWithLimit = onCall(async (request) => {
  const userId = request.auth.uid;
  
  // 原子的な制限チェック
  const siteCount = await getSiteCount(userId);
  const limit = isPremium(userId) ? 30 : 3;
  
  if (siteCount >= limit) {
    throw new HttpsError('resource-exhausted', 'Site limit reached');
  }
  
  // 作成 + カウント更新（1ステップで実行）
  return createSite(userId, data);
});
```

**成果物:**
- Callable Function 実装
- UI エラーメッセージ表示
- ロギング機能

---

#### Task 1.3: Cloud Functions テスト - Issue #301 **SHOULD**
**優先度**: P1 ⚠️  
**工数**: 2日  
**判断**: **SHOULD** - テスト駆動で信頼性向上

**理由:**
- Task 1.1, 1.2 の正確性検証に必須
- CI/CD での自動テスト化
- 複雑度は低い（⭐⭐）

**実装内容:**
```typescript
// functions/test/limit.test.ts
describe('Site Limit Enforcement', () => {
  test('free user: max 3 sites', async () => { ... });
  test('premium user: max 30 sites', async () => { ... });
  test('reject over-limit create', async () => { ... });
});

// functions/test/verify.test.ts
describe('Receipt Verification', () => {
  test('valid receipt accepted', async () => { ... });
  test('invalid receipt rejected', async () => { ... });
});
```

**成果物:**
- Cloud Functions の単体テスト
- エラーケースのカバレッジ

---

### Phase 2: テストカバレッジ向上 ⚠️ HIGH

**期間**: 1.5週間  
**複雑度**: ⭐⭐（低）

#### Task 2.1: ポーリングテスト実装 - Issue #311 **SHOULD**
**優先度**: P1 ⚠️  
**工数**: 1日  
**判断**: **SHOULD** - Issue #312 と組み合わせると効果大

**理由:**
- 購入完了ポーリングのテストカバレッジ欠落
- Issue #312 で追加するエラーハンドリング検証に必須
- 実装が簡単（⭐⭐）

**実装内容:**
```dart
// test/providers/subscription_provider_test.dart に追加
testWidgets('polling returns immediately when purchase confirmed', (tester) async {
  // Mock: _hasLifetimeAccess が 2回目で true に
  // 検証: 2秒以内に完了
});

testWidgets('polling times out after 10 seconds', (tester) async {
  // Mock: _hasLifetimeAccess が常に false
  // 検証: 約10秒後に完了
});

testWidgets('polls at 1 second intervals', (tester) async {
  // 検証: 正確に 1 秒間隔
});
```

**成果物:**
- 4つのテストケース
- ポーリング機能の完全カバレッジ

---

#### Task 2.2: タイムアウト処理と UI - Issue #312 **SHOULD**
**優先度**: P1 ⚠️  
**工数**: 1-2日  
**判断**: **SHOULD** - UX 改善、Issue #311 と同時実装推奨

**理由:**
- 購入完了タイムアウト時のユーザーフィードバック欠落
- シンプルな実装（エラーメッセージ表示のみ）
- Issue #311 とセット実装で効果高

**実装内容:**
```dart
// lib/providers/subscription_provider.dart
Future<void> _waitForPurchaseCompletion() async {
  // ... ポーリング処理 ...
  
  if (タイムアウト) {
    _error = '購入確認がタイムアウトしました。'
             'しばらくしてからご確認ください。';
    notifyListeners();
  }
}

// lib/screens/purchase_screen.dart
if (provider.error != null) {
  showErrorDialog(provider.error!);
}
```

**成果物:**
- Issue #311 のテスト追加（同時）
- UI エラーメッセージ表示

---

### Phase 3: アーキテクチャ改善 🟡 MEDIUM

**期間**: 2-3日  
**複雑度**: ⭐⭐⭐（中）

#### Task 3.1: Build method アンチパターン修正 - Issue #313 **COMPLETED** ✅
**優先度**: P2  
**工数**: 2日  
**ステータス**: ✅ **完了** - Provider同期を `initState()` に移動

**実装完了内容:**
- ✅ `sites_screen.dart`: Provider同期を `build()` → `initState()` に移動
- ✅ `site_form_screen.dart`: Provider同期を `build()` → `initState()` に移動
- ✅ `purchase_screen.dart`: Provider同期を `build()` → `initState()` に移動（race condition 修正含む）
- ✅ `site_provider.dart`: `initializeFromSubscription()` メソッド追加

**削除予定:**
- 🔲 `purchase_provider.dart`: 不要なファイルを削除（次のコミットで対応）

**次のステップ:**
1. `purchase_provider.dart` 削除
2. 全409テスト実行・確認
3. 実機動作確認

---

### Phase 4: ドキュメント・テストファイナライズ 📝

**期間**: 2-3日  
**担当**: 開発チーム

#### Task 4.1: Release Notes 作成
**優先度**: P1  
**工数**: 1時間

**記載内容:**
```markdown
## [1.0.9] - 2025-01-15

### 🔐 Security
- ✅ Apple receipt server-side verification (Issue #300)
- ✅ Transactional site creation to prevent duplicates (Issue #299)

### 🧪 Testing
- ✅ Cloud Functions comprehensive tests (Issue #301)
- ✅ Purchase polling tests (Issue #311)

### 🏗 Architecture
- ✅ Build method anti-pattern fixed (Issue #313)
- ✅ Purchase timeout error handling (Issue #312)

### 📊 Metrics
- Test coverage: 32% → 48%
- New test cases: +20 tests
- Zero known security gaps
```

---

#### Task 4.2: CHANGELOG.md 更新
**優先度**: P1  
**工数**: 30分

#### Task 4.3: TestFlight 配布準備
**優先度**: P1  
**工数**: 1-2時間  
**ステータス**: ✅ Testing Guide 完了

**成果物:**
- Build 108 配布準備
- テスター通知文作成
- フィードバック収集フォーム

---

## リリース成功基準 ✅

### MUST（必須条件）
- ✅ Issue #300 実装完了（Apple receipt verification）
- ✅ Issue #299 実装完了（Transactional creation）
- ✅ Issue #301 テスト完了（CF tests ≥80% coverage）
- 🔲 全429テスト通過（現在409テスト、+20追加予定）
- 🔲 `flutter analyze` 成功
- 🔲 `dart format --check` 成功
- 🔲 CI/CDパイプライン成功

### SHOULD（推奨）
- 🔲 Issue #311 実装完了（ポーリングテスト）
- 🔲 Issue #312 実装完了（タイムアウト処理）
- 🔲 Issue #313 実装完了（Build method 修正）
- 🔲 TestFlight Build 108 配布完了

### 削除・スキップ（非対象）
- ❌ Issue #210（リクエストレベル検証）→ v1.1 に延期
  - **理由:** 複雑度 ⭐⭐⭐⭐⭐、Issue #300 で基本セキュリティ解決済み
- ❌ 汎用 CooldownService/ValidationUtils 統一
  - **理由:** Issue #299-#313 の実装で自動的に改善される

---

## 実装スケジュール

### Week 1: セキュリティ基盤（目標: 7日）

**Days 1-5: Issue #300 実装（Apple Receipt Verification）**
```
Day 1-2: Apple API ドキュメント確認、環境設定
Day 2-3: Apple receipt 検証ロジック実装
Day 3-4: エラーハンドリング、エッジケース対応
Day 4: ユニットテスト追加
Day 5: 統合テスト、実機確認
```

**Days 2-4: Issue #299 実装（Transactional Creation - 並行）**
```
Day 2: Firestore Transaction 設計検討
Day 3: URL 重複チェック + createSite アトミック化
Day 4: ロールバック機構実装、テスト追加
```

### Week 2: テスト完成（目標: 6-7日）

**Days 5-6: Issue #301（Cloud Functions テスト）**
```
Day 5: Jest テストスイート作成
Day 6: 15+ テストケース実装（80%+ coverage）
```

**Days 6-7: Issue #311 + #312（ポーリング完成）**
```
Day 6: ポーリングテスト実装（#311）
Day 7: タイムアウト UI 実装（#312）
```

**Days 7-8: Issue #313（アーキテクチャ改善）**
```
Day 7-8: Build method 修正（3ファイル）
         パフォーマンス確認
```

### Week 3: 統合テスト・ベータ（目標: 3-4日）

**Days 9-10: 統合テスト**
```
Day 9: 全機能エンドツーエンドテスト
Day 10: リグレッションテスト、準本番確認
```

**Days 10-11: TestFlight 配布**
```
Day 10: Build 108 Xcode Cloud でビルド
Day 11: TestFlight 配布、ベータテスター通知
```

**Day 12: App Store 審査準備**
```
バージョン番号確定（1.0.9）
リリースノート最終確認
審査提出準備
```
  ├─ Day 5: 最終テスト・レビュー
  └─ Day 6-7: バッファ

Week 3 (1/2-1/8):
  ├─ Day 1: TestFlightリリース
  ├─ Day 2-3: 実機テスト・フィードバック対応
  ├─ Day 4: App Store提出
  └─ Day 5-7: 審査待ち
```

**リリース予定日**: 2025年1月中旬

---

## リスク管理・対応策

### 主要リスク分析

| リスク | 発生確率 | 影響度 | 対策 |
|--------|---------|--------|------|
| **Apple API 連携の複雑性** (Issue #300) | Medium | 🔴 Critical | 事前に sandbox 環境で検証、エラーログ詳細化 |
| **Firestore Transaction 競合** (Issue #299) | Low | 🔴 Critical | 単体テスト + Cloud Functions テストで検証 |
| **TestFlight 配布遅延** | Low | 🟠 High | Xcode Cloud での自動ビルド活用 |
| **iOS 実機テスト環境** | Low | 🟠 High | TestFlight ベータテスター 10+ 名確保 |
| **App Store 審査拒否** | Very Low | 🔴 Critical | Privacy Policy 再確認、ガイドライン確認 |

### リスク軽減戦略

**Issue #300（Apple Receipt）の複雑性軽減:**
1. **段階的テスト** - sandbox → production receipt 検証順
2. **エラーハンドリング詳細化** - Apple エラーコード を適切にマップ
3. **フェイルセーフ** - 検証失敗時は `auth_error` で不正な購入を reject

**Issue #299（Transactional Creation）の競合軽減:**
1. **Transaction タイムアウト設定** - 30秒以下
2. **リトライ機構** - 失敗時は自動リトライ（最大3回）
3. **重複検出** - 既存レコード存在時は `already-exists` エラー返却

**スケジュール遅延対応:**
- **Week 1 (MUST)**: Issue #300, #299, #301 → これら完了が必須
- **Week 2 (SHOULD)**: Issue #311, #312, #313 → 時間許せば含める、無理なら v1.0.10 へ
- **Week 3 (DEFER)**: 新たなテスト/リファクタリング → v1.1 以降

### ロールバック計画

**段階的ロールバック:**
1. **Issue #300 に問題** → #299 のみで リリース可能
2. **Issue #299 に問題** → #300 のみで リリース可能
3. **Cloud Functions テスト失敗** → サーバー側修正で対応（クライアント non-blocking）

**ホットフィックス計画:**
- v1.0.8 ブランチ維持 → 緊急ホットフィックス対応可能
- Git tag でバージョン追跡

---

## 判断フレームワーク: MUST / SHOULD / DON'T

### MUST 実装（v1.0.9 必須）🔴
```
優先度: P0（Critical)
理由: セキュリティまたはUX に直結するバグ/機能
複雑度: ⭐⭐⭐ ～ ⭐⭐⭐⭐（受け入れ可能）

対象:
  ✅ Issue #300 - Apple receipt verification (⭐⭐⭐⭐, 必須)
  ✅ Issue #299 - Transactional creation (⭐⭐⭐, 必須)
  ✅ Issue #301 - Cloud Functions tests (⭐⭐, テスト)
```

### SHOULD 実装（v1.0.9 推奨）🟡
```
優先度: P1（High）
理由: メンテナンス性向上 or UX 改善
複雑度: ⭐⭐ ～ ⭐⭐⭐（リスク低い）

対象:
  ✅ Issue #311 - ポーリングテスト (⭐⭐, 既実装コードテスト)
  ✅ Issue #312 - タイムアウト処理 (⭐⭐, UI 追加)
  ✅ Issue #313 - Build method 修正 (⭐⭐⭐, 高メンテナンス性)
```

### DON'T 実装（v1.1 以降へ延期）❌
```
優先度: P2+（Low）
理由: 複雑度 > 効果 または 基本機能で代替可能
複雑度: ⭐⭐⭐⭐⭐（受け入れ不可）

対象:
  ❌ Issue #210 - Request-level validation (⭐⭐⭐⭐⭐)
     → 理由: Issue #300 で基本セキュリティ解決済み
     →       システム全体に波及する複雑度
     →       v1.0.9 時点では必要性薄い
```

### 決定基準
```
┌─────────────────────────────────────────────────────┐
│ Issue の複雑度は? → ⭐⭐⭐⭐⭐ (極度に高い)    │
├─────────────────────────────────────────────────────┤
│ YES → DON'T (v1.1 以降)                              │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ セキュリティに直結? or UX バグ?                      │
├─────────────────────────────────────────────────────┤
│ YES (セキュリティ) → MUST (v1.0.9 必須)              │
│ YES (UX バグ) → MUST or SHOULD (優先度で判定)        │
│ NO → SHOULD or DON'T (メンテナンス/複雑度で判定)    │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ メンテナンス性が大幅向上? + 複雑度低い?              │
├─────────────────────────────────────────────────────┤
│ YES → SHOULD (v1.0.9 推奨)                           │
│ NO → DON'T (v1.1 以降)                               │
└─────────────────────────────────────────────────────┘
```

---

## 成功定義

### v1.0.9 リリース成功 = 以下すべてを満たす

1. **セキュリティ** ✅
   - Apple receipt 検証が 100% 機能
   - 不正な購入は 100% reject
   - サーバー側・クライアント側の検証が一貫

2. **安定性** ✅
   - 全429テスト通過（新規テスト含む）
   - `flutter analyze` エラー 0 件
   - `dart format --check` 成功

3. **パフォーマンス** ✅
   - TestFlight ビルド 108 安定配布
   - ベータテスター フィードバック 問題なし
   - クラッシュレート < 0.1%

4. **保守性** ✅
   - Issue #313 修正で architecture 改善
   - Issue #301 テストで信頼性向上
   - コード重複削減（自動）

## 成功指標

### テクニカル指標
- ✅ テストカバレッジ: 32% → 50%+
- ✅ テスト数: 409 → 477+
- ✅ コード重複: 8% → 6%
- ✅ CI/CD成功率: 100%

### ビジネス指標
- App Store審査通過
- クラッシュ率: <0.1%
- ユーザーからの不具合報告: 0件
- TestFlight満足度: 高評価

---

## 次のステップ

### v1.0.9リリース後
1. Phase 3実施検討（複雑度削減）
2. Phase 3b準備開始（サブスクリプション機能）
3. Android版開発検討

### 長期計画
- Phase 4: ドキュメント完全整備
- Android版リリース
- Phase 3b: サブスクリプション＋自動監視

---

## 関連ドキュメント

- [REFACTORING_PLAN.md](./REFACTORING_PLAN.md) - 全体リファクタリング計画
- [TESTFLIGHT_TESTING_GUIDE.md](./TESTFLIGHT_TESTING_GUIDE.md) - TestFlightテスト手順
- [DEVELOPMENT_GUIDE.md](./DEVELOPMENT_GUIDE.md) - 開発ガイド
- [ROADMAP.md](./ROADMAP.md) - 開発ロードマップ

---

**計画策定**: 2025年12月19日  
**最終更新**: 2025年12月19日  
**次回レビュー**: 2025年12月26日
