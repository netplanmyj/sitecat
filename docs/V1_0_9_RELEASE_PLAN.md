# v1.0.9 Release Plan

> **リリース予定**: 2025年12月下旬  
> **目的**: コード品質向上とテストカバレッジ拡大  
> **対象**: TestFlight → App Store

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

### Phase 1: テストカバレッジ拡大 🚨 CRITICAL

**期間**: 1-2週間  
**担当**: 開発チーム

#### Task 1.1: SiteProvider Tests (#264)
**優先度**: P0 🚨  
**工数**: 4-6時間

**実装内容:**
```dart
// test/providers/site_provider_test.dart
group('SiteProvider', () {
  test('loadSites() fetches from Firestore', () async { ... });
  test('addSite() validates URL', () async { ... });
  test('updateSite() detects excluded paths change', () async { ... });
  test('deleteSite() cascades delete', () async { ... });
  test('site limit enforcement (free: 3, premium: 30)', () async { ... });
});
```

**成果物:**
- 20+テストケース
- SiteProviderの全パブリックメソッドカバレッジ
- エッジケーステスト（空データ、ネットワークエラー）

---

#### Task 1.2: MonitoringProvider Tests (#265)
**優先度**: P0 🚨  
**工数**: 5-7時間

**実装内容:**
```dart
// test/providers/monitoring_provider_test.dart
group('MonitoringProvider', () {
  test('checkSite() performs quick scan', () async { ... });
  test('listenToSiteResults() streams updates', () async { ... });
  test('cooldown enforcement works', () async { ... });
  test('result caching is effective', () async { ... });
  test('getCachedSitemapStatus() returns correct data', () async { ... });
});
```

**成果物:**
- 25+テストケース
- 非同期処理の適切なテスト
- クールダウンロジックの検証

---

#### Task 1.3: Model Tests (#267)
**優先度**: P1 ⚠️  
**工数**: 3-5時間

**実装内容:**
```dart
// test/models/site_test.dart
group('Site', () {
  test('fromFirestore() deserializes correctly', () { ... });
  test('toFirestore() serializes correctly', () { ... });
  test('copyWith() updates fields', () { ... });
});

// test/models/broken_link_test.dart
group('BrokenLink', () {
  test('validation works', () { ... });
  test('serialization round-trip', () { ... });
});
```

**成果物:**
- 15+テストケース
- シリアライゼーションの往復検証
- バリデーションロジックカバレッジ

---

### Phase 2: コード重複削除 ⚠️ HIGH

**期間**: 1週間  
**担当**: 開発チーム

#### Task 2.1: CooldownService 統一 (#256)
**優先度**: P1 ⚠️  
**工数**: 4-6時間  
**ステータス**: ✅ v1.0.8で計画済み

**実装内容:**
```dart
// lib/services/cooldown_service.dart
class CooldownService {
  final Map<String, DateTime> _cooldownUntil = {};
  
  void startCooldown(String id, Duration duration) {
    _cooldownUntil[id] = DateTime.now().add(duration);
  }
  
  Duration? getTimeUntilNextCheck(String id) {
    final cooldownEnd = _cooldownUntil[id];
    if (cooldownEnd == null) return null;
    
    final now = DateTime.now();
    if (now.isAfter(cooldownEnd)) {
      _cooldownUntil.remove(id);
      return null;
    }
    
    return cooldownEnd.difference(now);
  }
  
  bool canPerformAction(String id) {
    return getTimeUntilNextCheck(id) == null;
  }
  
  void clearCooldown(String id) {
    _cooldownUntil.remove(id);
  }
}
```

**変更箇所:**
```dart
// lib/providers/link_checker_provider.dart (Before)
final Map<String, DateTime> _cooldownUntil = {};
Duration? getTimeUntilNextCheck(String siteId) { ... }

// lib/providers/link_checker_provider.dart (After)
final _cooldownService = CooldownService();
Duration? getTimeUntilNextCheck(String siteId) {
  return _cooldownService.getTimeUntilNextCheck(siteId);
}
```

**成果物:**
- 新規 `CooldownService` クラス
- LinkCheckerProviderで使用
- MonitoringProviderで使用
- ~30行のコード削減
- ユニットテスト追加

---

#### Task 2.2: Validation Utils 抽出 (#268)
**優先度**: P1  
**工数**: 2-3時間

**実装内容:**
```dart
// lib/utils/validation_utils.dart
class ValidationUtils {
  // URL validation
  static String? validateSiteUrl(String url) {
    if (url.isEmpty) return 'URL cannot be empty';
    
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'URL must start with http:// or https://';
    }
    
    try {
      Uri.parse(url);
    } catch (e) {
      return 'Invalid URL format';
    }
    
    return null; // Valid
  }
  
  // Sitemap URL validation
  static String? validateSitemapUrl(String? url) {
    if (url == null || url.isEmpty) return null; // Optional
    
    if (!url.endsWith('.xml') && !url.endsWith('/sitemap.xml')) {
      return 'Sitemap URL should end with .xml';
    }
    
    return validateSiteUrl(url);
  }
  
  // Excluded path validation
  static String? validateExcludedPath(String path) {
    if (path.isEmpty) return 'Path cannot be empty';
    
    if (!path.startsWith('/')) {
      return 'Path must start with /';
    }
    
    return null;
  }
}
```

**変更箇所:**
```dart
// lib/screens/site_form_screen.dart (Before)
validator: (value) {
  if (value == null || value.isEmpty) {
    return 'URLを入力してください';
  }
  if (!value.startsWith('http://') && !value.startsWith('https://')) {
    return 'URLはhttp://またはhttps://で始まる必要があります';
  }
  return null;
}

// lib/screens/site_form_screen.dart (After)
validator: (value) {
  final error = ValidationUtils.validateSiteUrl(value ?? '');
  return error;
}
```

**成果物:**
- 新規 `ValidationUtils` クラス
- 3箇所以上で重複削除
- ~15行のコード削減
- ユニットテスト追加

---

### Phase 3: ドキュメント整備 📝

**期間**: 2-3日  
**担当**: 開発チーム

#### Task 3.1: TestFlight Testing Guide
**優先度**: P1  
**工数**: 1-2時間  
**ステータス**: ✅ 完了

**成果物:**
- [TESTFLIGHT_TESTING_GUIDE.md](./TESTFLIGHT_TESTING_GUIDE.md)
- 未購入状態テスト手順
- Lifetime購入後テスト手順
- トラブルシューティング

---

#### Task 3.2: Development Guide 更新
**優先度**: P2  
**工数**: 1-2時間

**更新内容:**
- テスト戦略の追加
- CooldownServiceの使用例
- ValidationUtilsの使用例
- v1.0.9の変更履歴

---

#### Task 3.3: CHANGELOG.md 更新
**優先度**: P1  
**工数**: 30分

**記載内容:**
```markdown
## [1.0.9] - 2025-12-XX

### Added
- CooldownService for unified cooldown management
- ValidationUtils for consistent validation
- Comprehensive test coverage for providers and models

### Changed
- Test coverage improved: 32% → 50%+
- Code duplication reduced: 8% → 6%

### Fixed
- [List any bugs fixed]

### Internal
- 68+ new tests added
- Better code organization
- Improved developer experience
```

---

## リリース基準

### 必須条件（Must Have）
- ✅ TestFlightビルド101で実機確認完了
- 🔲 全409テスト通過（現在409テスト）
- 🔲 新規68+テスト追加
- 🔲 CI/CDパイプライン成功
- 🔲 テストカバレッジ50%以上

### 推奨条件（Should Have）
- 🔲 CooldownService統一完了
- 🔲 ValidationUtils抽出完了
- 🔲 コード重複6%以下
- 🔲 ドキュメント更新完了

### オプション（Nice to Have）
- LinkCheckerService リファクタリング（Phase 3に延期可）
- 複雑度削減（Phase 3に延期可）

---

## タイムライン

```
Week 1 (12/19-12/25):
  ├─ Day 1-2: Task 1.1 (SiteProvider Tests)
  ├─ Day 3-4: Task 1.2 (MonitoringProvider Tests)
  └─ Day 5-6: Task 1.3 (Model Tests)

Week 2 (12/26-1/1):
  ├─ Day 1-2: Task 2.1 (CooldownService)
  ├─ Day 3: Task 2.2 (ValidationUtils)
  ├─ Day 4: ドキュメント更新
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

## リスク管理

### 主要リスク

| リスク | 発生確率 | 影響度 | 対策 |
|--------|---------|--------|------|
| テスト作成が遅延 | Medium | High | バッファ期間を設定、段階的リリース |
| 新しいバグ発見 | Low | High | テストファースト、段階的リファクタリング |
| スケジュール遅延 | Medium | Medium | 優先度に基づいて一部を延期 |

### ロールバック計画
- 各タスクは独立しているため、個別にロールバック可能
- Gitタグでバージョン管理
- TestFlightで段階的配信

---

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
