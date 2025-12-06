# リファクタリングメトリクス

> **概要**: プロジェクト内の大規模ファイルのリファクタリング詳細記録  
> **目的**: リファクタリング前後のメトリクス測定、計画管理、進捗追跡  
> **更新方針**: ファイルごとにセクションを追加、完了後も記録を保持  
> **参照**: 全体戦略は [DEVELOPMENT_GUIDE.md](./DEVELOPMENT_GUIDE.md) 参照

---

## リファクタリング対象ファイル一覧

**優先度順（2025年12月6日時点）**:

| 優先度 | ファイル | 行数 | ステータス | Issue |
|--------|---------|------|-----------|-------|
| 🔴 | lib/services/link_checker_service.dart | 1142 | Phase 3完了 | #212 |
| 🟡 | lib/screens/site_form_screen.dart | 780 | 未着手 | #220予定 |
| 🟢 | lib/screens/profile_screen.dart | 426 | 未着手 | - |
| 🟢 | lib/providers/link_checker_provider.dart | 414 | 未着手 | - |
| 🟢 | lib/widgets/site_detail/full_scan_section.dart | 405 | 未着手 | - |

---

## 1. lib/services/link_checker_service.dart

### 基本情報
- **Issue**: #212
- **PR**: #219（Phase 1-3完了、マージ済み）
- **測定日**: 2025年12月5日
- **担当者**: GitHub Copilot + 開発者

### リファクタリング前の状態

### ファイル規模
- **総行数**: 965行
- **ランキング**: 第1位（プロジェクト内最大）

### メソッド規模
- **checkSiteLinksメソッド**: 約355行（行65〜420）
  - Step 1: sitemap読み込み（60行）
  - Step 2: ページスキャン・リンク抽出（90行）
  - Step 3: 内部リンクチェック（50行）
  - Step 4: 外部リンクチェック（50行）
  - Step 5: 結果マージ（5行）
  - Step 6: 結果保存（100行）

### 複雑度指標
- **ファイル全体の制御構造**: 73個（if/for/while/switch/catch）
- **checkSiteLinksメソッド内の制御構造**: 28個
- **推定Cyclomatic Complexity**: 29（非常に高い）
  - 推奨値: 10以下
  - 警告レベル: 15以上
  - 危険レベル: 20以上

### ネストの深さ
- **最大ネスト**: 5〜6レベル
  ```dart
  for (page in pages) {           // Level 1
    if (condition) {              // Level 2
      for (link in links) {       // Level 3
        if (condition) {          // Level 4
          try {                   // Level 5
            if (condition) {      // Level 6
  ```

## 問題点

### 1. 単一責任原則の違反
- 1つのメソッドが7つの異なる責務を持つ
- テストが困難
- 部分的な変更がリスクを伴う

### 2. 可読性の低下
- メソッドが長すぎてスクロールが必要
- 処理の流れが追いにくい
- 変数スコープが広すぎる

### 3. 保守性の問題
- バグ修正時の影響範囲が不明確
- 新機能追加が困難
- コードレビューが大変

## リファクタリング計画

### Phase 1: ドキュメント改善（完了✅）
- [x] セクションコメント追加
- [x] 処理フローの明確化
- [x] コミット: ffaa0cd

### Phase 2: 補助メソッドの抽出（完了✅）
**達成メトリクス**:
- `checkSiteLinks`メソッド: **355行 → 68行** (81%削減)
- Cyclomatic Complexity: **29 → 8推定** (72%削減)
- ネスト深さ: **6レベル → 3レベル** (50%削減)
- テスト結果: **19/19通過** (機能変更なし)

**抽出されたメソッド** (7個):
1. [x] `_loadSitemapUrls()` - sitemap読み込み、60行（コミット: f511500）
2. [x] `_loadPreviousScanData()` - 前回データ取得、17行（コミット: f511500）
3. [x] `_calculateScanRange()` - スキャン範囲計算、23行（コミット: f511500）
4. [x] `_scanPagesAndExtractLinks()` - リンク抽出、90行（コミット: 6e35ea0）
5. [x] `_checkAllLinks()` - リンクチェック、110行（コミット: dfc33e0）
6. [x] `_mergeBrokenLinks()` - 結果マージ、8行（コミット: dfc33e0）
7. [x] `_createAndSaveResult()` - 結果保存、87行（コミット: 202e7ce）

### Phase 3: データクラスの導入（完了✅）
**達成内容**:
- レコード型からデータクラスへの移行完了
- 型安全性とコード明瞭性の向上
- テスト結果: **19/19通過** (機能変更なし)

**導入されたデータクラス** (4個):
1. [x] `_SitemapLoadResult` - sitemap読み込み結果（コミット: 2e844e1）
2. [x] `_PreviousScanData` - 前回スキャンデータ（コミット: 2e844e1）
3. [x] `_ScanRange` - スキャン範囲情報（コミット: 2e844e1）
4. [x] `_LinkExtractionResult` - リンク抽出結果（コミット: 2e844e1）

**改善ポイント**:
```dart
// Before: レコード型（型名なし）
Future<({List<Uri> urls, int totalPages, int? statusCode})> _loadSitemapUrls(...)

// After: データクラス（明示的な型）
Future<_SitemapLoadResult> _loadSitemapUrls(...)
```

### Phase 4: テストの追加（次のステップ）
- 各抽出メソッドの単体テスト
- エッジケースのテスト
- エラーハンドリングのテスト

### Phase 5: ファイル分割（進行中🔄）
**現状**: 1086行（Phase 5-1完了時点）

**Phase 5-1完了✅ - データクラス抽出**:
- lib/services/link_checker/models.dart作成（54行）
- 4つのデータクラスを分離
- link_checker_service.dart: 1142行 → 1086行（56行削減）
- テスト結果: 19/19通過
- コミット: 438fcaa

**Phase 5-2完了✅ - HTTP/Sitemap処理の抽出**:
- lib/services/link_checker/http_client.dart作成（117行）
  - LinkCheckerHttpClient: HTTP/HTML処理
  - checkUrlHead, fetchHtmlContent, extractLinks, checkLink
- lib/services/link_checker/sitemap_parser.dart作成（165行）
  - SitemapParser: XML解析
  - fetchSitemapUrls, parseSitemapXml, normalizeSitemapUrl
- link_checker_service.dart: 1086行 → 840行（246行削減）
- テスト結果: 19/19通過
- コミット: 501703a

**Phase 5総削減量**:
- 開始: 1142行
- Phase 5-1後: 1086行（56行削減）
- Phase 5-2後: 840行（246行削減）
- **合計削減: 302行（26%削減）** ✅
- **🎉 1000行以下を達成！**

**分割後のファイル構成**:
```
lib/services/
  link_checker_service.dart (840行) - メインロジック
  link_checker/
    models.dart (54行) - データクラス4個
    http_client.dart (117行) - HTTP/HTML処理
    sitemap_parser.dart (165行) - Sitemap XML解析
```

**Phase 5-3完了✅ - Firestore操作の抽出**:

**実施日**: 2025-01-XX  
**削減**: 722行（Phase 5-2: 840行 → Phase 5-3: 722行、118行削減）

**作業内容**:

1. **LinkCheckResultRepositoryクラス作成**（180行、新規）
   - パス: `lib/services/link_checker/result_repository.dart`
   - 責務: Firestore CRUD操作の完全カプセル化
   - メソッド数: 10個
     * `getBrokenLinks`: 指定結果IDの壊れたリンク取得
     * `deleteResultBrokenLinks`: 壊れたリンクの削除
     * `getLatestCheckResult`: 最新チェック結果取得
     * `getCheckResults`: チェック結果履歴取得（limit指定可）
     * `getAllCheckResults`: 全サイトのチェック結果取得
     * `deleteAllCheckResults`: 特定サイトの全結果削除
     * `deleteLinkCheckResult`: 単一結果削除
     * `saveResult`: チェック結果の保存
     * `saveBrokenLinks`: 壊れたリンクの一括保存（バッチ処理）
     * `cleanupOldResults`: 古い結果の自動クリーンアップ（30日以上前）

2. **公開メソッドのリポジトリ委譲**（6メソッド、72行削減）
   - `getBrokenLinks`: 13行 → 4行
   - `getLatestCheckResult`: 13行 → 3行
   - `getCheckResults`: 14行 → 3行
   - `getAllCheckResults`: 10行 → 3行
   - `deleteAllCheckResults`: 13行 → 3行
   - `deleteLinkCheckResult`: 9行 → 3行

3. **プライベートメソッド削除**（77行削減）
   - `_saveBrokenLinks`: 14行削除（リポジトリのsaveBrokenLinksに置き換え）
   - `_deleteResultBrokenLinks`: 18行削除（リポジトリのdeleteResultBrokenLinksに置き換え）
   - `_cleanupOldResults`: 45行削除（リポジトリのcleanupOldResultsに置き換え）

4. **未使用コレクション参照削除**（8行削減）
   - `_resultsCollection`: 3行削除
   - `_brokenLinksCollection`: 5行削除

5. **メインロジック更新**
   - `_createAndSaveResult`メソッド: Firestoreへの直接書き込みをリポジトリ経由に変更
     ```dart
     // Before
     final docRef = await _resultsCollection(_currentUserId!).add(result.toFirestore());
     final resultId = docRef.id;
     await _saveBrokenLinks(resultId, allBrokenLinks);
     
     // After
     final resultId = await _repo.saveResult(result);
     await _repo.saveBrokenLinks(resultId, allBrokenLinks);
     ```

**Phase 5総削減量**:
- 開始: 1142行
- Phase 5-1後: 1086行（56行削減）
- Phase 5-2後: 840行（246行削減）
- Phase 5-3後: **722行**（118行削減）
- **合計削減: 420行（37%削減）** ✅

**分割後のファイル構成**:
```
lib/services/
  link_checker_service.dart (722行) - メインロジック・公開API
  link_checker/
    models.dart (54行) - データクラス4個
    http_client.dart (117行) - HTTP/HTML処理
    sitemap_parser.dart (165行) - Sitemap XML解析
    result_repository.dart (180行) - Firestore CRUD操作
```

**Repository Pattern採用の効果**:
- データアクセス層の完全分離
- 単体テスト容易性の向上（モック・スタブ化が可能）
- Firestore実装の変更時の影響範囲局所化
- コード重複の削減（コレクション参照の一元管理）

**テスト結果**:
- 実施テスト: `test/link_check_models_test.dart`, `test/link_checker_provider_test.dart`
- 結果: **19テスト全て通過** ✅
- コンパイルエラー: なし

**次のフェーズ候補**:
- Phase 6: エラーハンドリング・リトライロジックの共通化（検討中）
- Phase 7: ログ出力の整理・構造化（検討中）

---

**Phase 5-3予定 - Firestore操作の抽出**:

**問題点**:
- 1ファイル1000行超えは保守性・可読性の観点で問題
- エディタ上で全体を見渡すのにスクロールが必要
- 責務が混在（HTTP通信、Sitemap解析、リンク検証、Firestore操作）
- コードの冗長性発見が困難

**分割案**:
```
lib/services/
  link_checker_service.dart (250行)
    - メインロジック・公開API
    - 7つの補助メソッド
  
  link_checker/
    http_client.dart (150行)
      - _checkUrlHead, _fetchHtmlContent
      - _extractLinks (HTML解析)
    
    sitemap_parser.dart (200行)
      - _fetchSitemapUrls, _parseSitemapXml
      - _extractUrlsFromSitemapDocument
    
    link_validator.dart (200行)
      - _checkLink (リンク検証)
      - バッチチェック処理
    
    result_repository.dart (200行)
      - Firestore CRUD操作
      - _createAndSaveResult
    
    models.dart (60行)
      - _SitemapLoadResult
      - _PreviousScanData
      - _ScanRange
      - _LinkExtractionResult
```

**期待効果**:
- ✅ 各ファイル200-250行（スクロールで見渡せる）
- ✅ 単一責任原則の徹底
- ✅ コードの重複発見・共通化の促進
- ✅ テスト容易性の向上
- ✅ 並行開発が可能

**実施タイミング**: Phase 1-3マージ後の次のPR（Issue #212-2として）

## 期待される改善効果

### メソッド規模
- checkSiteLinksメソッド: 355行 → 50行（85%削減）
- 平均メソッド長: 20行以下

### 複雑度
- checkSiteLinks Cyclomatic Complexity: 29 → 8（72%削減）
- 各補助メソッド: 5以下

### ネストの深さ
- 最大ネスト: 6レベル → 3レベル（50%削減）

### テスト容易性
- 単体テスト可能なメソッド数: 1個 → 9個
- テストカバレッジ向上の見込み

## 参考資料
- [Clean Code by Robert C. Martin](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)
- [Refactoring by Martin Fowler](https://refactoring.com/)
- [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)

---

## 2. lib/screens/site_form_screen.dart

### 基本情報
- **Issue**: #220（予定）
- **PR**: 未作成
- **測定日**: 2025年12月6日
- **優先度**: 🟡 警告レベル

### リファクタリング前の状態

#### ファイル規模
- **総行数**: 780行
- **ランキング**: 第2位（プロジェクト内）

#### 主要なメソッド
- `build()`: 約530行（UI構築）
  - AppBarセクション（20行）
  - Formセクション（400行）
    - サイト名入力（50行）
    - URL入力（80行）
    - Sitemap URL入力（80行）
    - 除外パス設定（190行）
  - 保存ボタン（30行）
- `_saveSite()`: 約70行（保存処理）
- `_showUrlChangeWarningDialog()`: 約60行（警告ダイアログ）

#### 問題点
1. **巨大なbuildメソッド**: 530行でスクロール必須
2. **UI責務の混在**: 入力、検証、警告、リスト管理が1ファイルに
3. **ウィジェットの再利用不可**: 他のフォームで使えない
4. **保守性の低下**: 変更時の影響範囲が不明確

### リファクタリング計画

#### Phase 1: FormSectionウィジェットの抽出
**目標**: buildメソッドを100行以下に削減

**抽出予定ウィジェット**:
```
lib/widgets/site_form/
  site_name_field.dart (60行)
    - サイト名入力フィールド
    - バリデーション
  
  site_url_field.dart (100行)
    - URL入力フィールド
    - バリデーション
    - プレビュー機能
  
  sitemap_url_field.dart (100行)
    - Sitemap URL入力
    - バリデーション
    - ヘルプテキスト
  
  excluded_paths_section.dart (250行)
    - 除外パス管理UI
    - リスト表示
    - 追加・削除機能
  
  form_actions.dart (80行)
    - 保存ボタン
    - キャンセルボタン
    - ローディング表示
```

**期待効果**:
- site_form_screen.dart: 780行 → 200行（74%削減）
- 再利用可能なウィジェット: 5個作成
- buildメソッド: 530行 → 80行（85%削減）

#### Phase 2: バリデーションロジックの共通化
**目標**: フォーム検証を再利用可能に

**作成予定クラス**:
```dart
lib/utils/validators/
  site_validator.dart (100行)
    - validateSiteName()
    - validateUrl()
    - validateSitemapUrl()
    - validateExcludedPath()
```

**期待効果**:
- 他のフォームでも使用可能
- テストが容易
- 検証ロジックの一貫性向上

#### Phase 3: ダイアログウィジェットの分離
**目標**: 警告ダイアログを再利用可能に

**作成予定ウィジェット**:
```dart
lib/widgets/dialogs/
  url_change_warning_dialog.dart (80行)
    - URL変更警告ダイアログ
    - 警告項目リスト
    - 確認ボタン
```

### 実施予定
- **開始**: Phase 1-3完了後
- **期間**: 2-3日
- **ブランチ**: refactor/issue-220-site-form-screen

---

## 3. 今後の対象ファイル（経過観察）

### lib/screens/profile_screen.dart (426行)
- Premium機能UI
- アカウント情報表示
- サブスクリプション管理

**対応方針**: Premium UIをウィジェット分離

### lib/providers/link_checker_provider.dart (414行)
- リンクチェック状態管理
- プログレス管理

**対応方針**: 状態クラスの導入、メソッド抽出

### lib/widgets/site_detail/full_scan_section.dart (405行)
- Full Scan UI
- 進捗表示
- 結果表示

**対応方針**: サブウィジェットへの分割

---

## リファクタリング実施ガイドライン

### 開始前のチェックリスト
- [ ] Issue作成（リファクタリング計画記載）
- [ ] ブランチ作成（`refactor/issue-[番号]-[対象ファイル]`）
- [ ] メトリクス測定（行数、Cyclomatic Complexity、ネスト深さ）
- [ ] 既存テストの確認

### 各Phase完了時のチェックリスト
- [ ] テスト実行（全テスト通過）
- [ ] コンパイルエラー確認
- [ ] メトリクス再測定
- [ ] コミット（`refactor: [Phase名] - [達成内容]`）

### PR作成時のチェックリスト
- [ ] Before/Afterメトリクスをコミット
- [ ] 本ドキュメント更新（完了記録）
- [ ] PRテンプレート記入
- [ ] レビュー依頼

### 完了後の記録
- [ ] 最終メトリクスを本ドキュメントに記録
- [ ] 学んだ教訓を記載
- [ ] 次の対象ファイルの優先度更新

---

## 参考資料
- [Clean Code by Robert C. Martin](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)
- [Refactoring by Martin Fowler](https://refactoring.com/)
- [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
