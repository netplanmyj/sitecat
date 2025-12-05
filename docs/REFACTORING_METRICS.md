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

### Phase 2: 補助メソッドの抽出（次のステップ）
1. `_loadSitemapUrls()` - Step 1を抽出
2. `_loadPreviousScanData()` - Step 1bを抽出
3. `_calculateScanRange()` - Step 1cを抽出
4. `_scanPagesAndExtractLinks()` - Step 2を抽出
5. `_checkInternalLinks()` - Step 3を抽出
6. `_checkExternalLinks()` - Step 4を抽出
7. `_mergeBrokenLinks()` - Step 5を抽出
8. `_createAndSaveResult()` - Step 6を抽出

### Phase 3: データクラスの導入
```dart
class _ScanContext {
  final Site site;
  final Uri originalBaseUrl;
  final Uri baseUrl;
  final Map<String, List<String>> linkSourceMap;
  final int startIndex;
  final int endIndex;
  final bool scanCompleted;
}

class _LinkExtractionResult {
  final Set<Uri> internalLinks;
  final Set<Uri> externalLinks;
  final Map<String, List<String>> linkSourceMap;
  final int totalInternalLinksCount;
  final int totalExternalLinksCount;
  final int pagesScanned;
}
```

### Phase 4: テストの追加
- 各抽出メソッドの単体テスト
- エッジケースのテスト
- エラーハンドリングのテスト

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
