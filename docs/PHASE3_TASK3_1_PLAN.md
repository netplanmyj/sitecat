# Phase 3 Task 3.1: LinkCheckerProvider 分割計画

**Issue**: #271  
**Status**: 実装開始  
**Current File Size**: 557行  
**Target**: 3ファイルに分割して各ファイルを ~200行以下に

---

## 現在の LinkCheckerProvider 構成

### 1. 状態管理用フィールド (28個のMap/変数)
```dart
Map<String, LinkCheckState> _checkStates
Map<String, LinkCheckResult?> _resultCache
Map<String, List<BrokenLink>> _brokenLinksCache
Map<String, String> _errors
Map<String, int> _checkedCounts
Map<String, int> _totalCounts
Map<String, List<LinkCheckResult>> _checkHistory
Map<String, bool> _isProcessingExternalLinks
Map<String, int> _externalLinksChecked
Map<String, int> _externalLinksTotal
Map<String, int?> _currentSitemapStatusCode
Map<String, bool> _cancelRequested
Map<String, int?> _precalculatedPageCounts
List<...> _allCheckHistory
```

### 2. 主要メソッドカテゴリ

**キャッシュ管理**:
- `getCachedResult()`
- `getCachedBrokenLinks()`
- `getCheckHistory()`
- `loadCheckHistory()`

**進捗追跡**:
- `setCheckedCounts()`
- `getCheckedCount()` (取得用)
- `getTotalCount()` (取得用)
- `isProcessingExternalLinks()`
- `saveProgressOnInterruption()`
- `precalculatePageCount()`
- `getPrecalculatedPageCount()`
- `clearPrecalculatedPageCount()`

**チェック制御**:
- `checkSiteLinks()` (メインロジック - 180行)
- `cancelScan()`
- `isCancelRequested()`
- `loadLatestResult()`
- `deleteLinkCheckResult()`

**冷却制御**:
- `_startCooldown()`
- `isInCooldown()`
- `canCheckSite()`

---

## 提案された分割戦略

### ファイル 1: `link_checker_provider.dart` (200行)
**責務**: Core Provider + UI State Management

**含まれるもの**:
- Provider クラス本体
- 状態初期化 (`__init__`, `initialize()`)
- UI状態フラグ (`_checkStates`, `_errors`, `_isDemoMode`, `_hasLifetimeAccess`)
- Cache参照用getter: `getCachedResult()`, `getCachedBrokenLinks()`
- チェック制御: `checkSiteLinks()`, `cancelScan()`, `isCancelRequested()`
- 冷却制御: `_startCooldown()`, `isInCooldown()`, `canCheckSite()`
- プレミアム設定: `setHasLifetimeAccess()`
- 状態リセット: `resetState()`

**行数目安**: 180-200行

---

### ファイル 2: `link_checker_cache.dart` (150行)
**責務**: チェック結果キャッシング + 履歴管理

**クラス名**: `LinkCheckerCache`

**含まれるもの**:
- `_resultCache` (最新結果)
- `_brokenLinksCache` (壊れたリンク一覧)
- `_checkHistory` (site別の履歴)
- `_allCheckHistory` (全サイト履歴)
- `_currentSitemapStatusCode` (Sitemap状態)

**メソッド**:
- `saveResult(siteId, result)` - 結果を保存
- `saveBrokenLinks(siteId, links)` - リンクを保存
- `addToHistory(siteId, result)` - 履歴に追加
- `getResult(siteId)` - 結果取得
- `getBrokenLinks(siteId)` - リンク取得
- `getHistory(siteId)` - 履歴取得
- `loadHistory(siteId)` - Firestore から履歴ロード
- `deleteResult(siteId, resultId)` - 結果削除
- `setSitemapStatusCode(siteId, code)` - Sitemap状態保存
- `clearCache(siteId)` - キャッシュクリア

**行数目安**: 140-160行

---

### ファイル 3: `link_checker_progress.dart` (150行)
**責務**: チェック進捗追跡 + ページカウント管理

**クラス名**: `LinkCheckerProgress`

**含まれるもの**:
- `_checkedCounts` (チェック済みカウント)
- `_totalCounts` (総数)
- `_externalLinksChecked` (外部リンク済み)
- `_externalLinksTotal` (外部リンク総数)
- `_isProcessingExternalLinks` (処理中フラグ)
- `_precalculatedPageCounts` (ページ数キャッシュ)
- `_cancelRequested` (キャンセル要求フラグ)

**メソッド**:
- `setCheckedCount(siteId, count)` - 進捗更新
- `getCheckedCount(siteId)` - 進捗取得
- `setTotalCount(siteId, count)` - 総数設定
- `getTotalCount(siteId)` - 総数取得
- `getProgress(siteId)` - 進捗率 (0.0-1.0)
- `getProgressPercentage(siteId)` - 進捗率 (%)
- `setExternalLinksProgress(siteId, checked, total)`
- `getExternalProgress(siteId)` - 外部リンク進捗
- `precalculatePageCount(site)` - ページ数事前計算
- `getPrecalculatedPageCount(siteId)`
- `clearPrecalculatedPageCount(siteId)`
- `setCancelRequested(siteId, requested)`
- `isCancelRequested(siteId)`
- `saveProgressOnInterruption(siteId, result)` - 中断時に進捗を保存
- `resetProgress(siteId)` - 進捗リセット

**行数目安**: 140-160行

---

## 実装ステップ

### ステップ 1: ファイル作成 (1時間)
1. `link_checker_cache.dart` 作成
   - `LinkCheckerCache` クラス実装
   - `_resultCache`, `_brokenLinksCache` など属性移行
   - `get/set` メソッド実装

2. `link_checker_progress.dart` 作成
   - `LinkCheckerProgress` クラス実装
   - `_checkedCounts`, `_totalCounts` など属性移行
   - 進捗管理メソッド実装

### ステップ 2: Provider 更新 (1.5時間)
1. 新しいクラスをインスタンス化
   ```dart
   class LinkCheckerProvider extends ChangeNotifier {
     late LinkCheckerCache _cache;
     late LinkCheckerProgress _progress;
     
     LinkCheckerProvider({...}) {
       _cache = LinkCheckerCache();
       _progress = LinkCheckerProgress();
     }
   }
   ```

2. 既存メソッドを新クラスへ委譲
   ```dart
   // Before
   LinkCheckResult? getCachedResult(siteId) => _resultCache[siteId];
   
   // After
   LinkCheckResult? getCachedResult(siteId) => _cache.getResult(siteId);
   ```

3. 状態の一貫性確保
   - キャッシュ更新時に自動的に `notifyListeners()` 呼び出し

### ステップ 3: テスト追加 (1.5時間)
1. `LinkCheckerCache` ユニットテスト
2. `LinkCheckerProgress` ユニットテスト
3. Provider 統合テスト (キャッシュ + 進捗の相互作用)

### ステップ 4: 動作確認 (1時間)
1. `flutter analyze` - Lint チェック
2. `dart format` - フォーマット
3. `flutter test` - 全テスト実行

---

## 分割メリット

✅ **責務の明確化**
- Provider: 状態管理の中心
- Cache: 結果の永続化・取得
- Progress: 進捗情報の追跡

✅ **テスタビリティ向上**
- 各クラスを独立してテスト可能
- モック化が容易

✅ **再利用性**
- `LinkCheckerCache` を他の Provider から利用可能
- `LinkCheckerProgress` を統計機能で再利用可能

✅ **保守性**
- ファイルサイズが適切範囲 (150-200行)
- コード量が減ることで可読性向上

---

## 進捗追跡

- [x] ステップ 1: ファイル作成
- [x] ステップ 2: Provider 更新
- [x] ステップ 3: テスト追加
- [x] ステップ 4: 動作確認
- [x] PR 作成・レビュー

**予定時間**: 4-5時間  
**実際の時間**: (実装中に記録)

---

**作成日**: 2025年12月14日  
**予定完了日**: 2025年12月15日
