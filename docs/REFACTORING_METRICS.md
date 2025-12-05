# リファクタリングメトリクス - Issue #212

## 測定日時
2025年12月5日

## 対象ファイル
`lib/services/link_checker_service.dart`

## 現在の状態（リファクタリング前）

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

### Phase 5: ファイル分割（重要 🔴）
**現状**: 1139行（Phase 3完了時点）

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
