# 開発ガイド - SiteCat

> **対象読者**: 開発者  
> **目的**: SiteCatの技術詳細、開発環境構築、アーキテクチャ、実装ガイド  
> **ドキュメントバージョン**: v2.1  
> **最終更新**: 2025年12月  
> **現在のアプリバージョン**: v1.0.3+ - App Store配信中

---

## 開発環境セットアップ

### 前提条件
- **Flutter SDK**: 3.27以上
- **Dart SDK**: 3.10以上
- **Xcode**: 15以上（iOS開発用、現在iOS専用アプリ）
- **Firebase CLI**: 最新版
- **Git**: バージョン管理
- **CocoaPods**: iOS依存関係管理

### 初期セットアップ手順

1. **リポジトリクローン**
   ```bash
   git clone https://github.com/netplanmyj/sitecat.git
   cd sitecat
   ```

2. **依存関係インストール**
   ```bash
   flutter pub get
   ```

3. **Firebase設定**
   ```bash
   firebase login
   firebase init
   ```

## 開発ワークフロー

### 1. Gitフロー
- **main**: 本番用ブランチ
- **develop**: 開発用ブランチ
- **feature/***: 機能開発ブランチ
- **hotfix/***: 緊急修正ブランチ

### 1.1 PR作成前チェックリスト

**PR作成前に必ず以下を実行してください。これにより CIエラーを事前に防ぐことができます。**

```bash
# 1. 静的解析（コード品質チェック）
flutter analyze

# 2. フォーマット（コードスタイル統一）
dart format --set-exit-if-changed .

# 3. テスト実行（機能動作確認）
flutter test

# 4. すべてOKなら、修正をコミット・プッシュ
git add -A
git commit -m "fix: Changes based on analyze and format results"
git push origin <branch-name>
```

**各チェックの詳細:**
- `flutter analyze`: Lintエラー、型チェック、その他の潜在的な問題を検出
- `dart format --set-exit-if-changed .`: コード自動フォーマット。変更がある場合は終了コード1を返す
- `flutter test`: 全ユニット・ウィジェットテストを実行

**一括実行:**
```bash
flutter analyze && dart format --set-exit-if-changed . && flutter test
```

⚠️ **注意**:  
これらをスキップして PR を作成すると、CI/CD パイプラインで失敗し、マージが遅延します。

### 1.2 Full Scan カウントダウン仕様

- 対象: Site Detail > Full Scan タブの Start / Stop / Continue
- トリガー: Start/Continue 押下時、Stop 押下時、バッチ完了時（例: 100ページ終了）
- 挙動: 30秒間 Start/Continue を無効化（Stop は常に有効、緊急停止用）
- UI: 残り時間を CountdownTimer で表示（Start/Continue 共通で表示）
- 設定: 30秒に固定。将来は設定画面で変更可能にする（別Issueで対応）

### 2. コード規約
- Dart公式のlintルールに従う
- `analysis_options.yaml`の設定を遵守
- コメントは日本語でOK、変数名・関数名は英語

**コード削除のポリシー:**
- 不要になったコード・ファイルは**即座に削除**する
- リファクタリング時に古い実装を残さない
- 「後で削除」は禁止 - 削除タイミングを逃すと永久に残る
- 大きな変更の場合は、以下を1つのコミットで実施：
  1. 新しい実装の追加
  2. 古い実装の削除
  3. インポート文の整理
- 削除理由をコミットメッセージに明記

**例：機能移行時の削除フロー**
```bash
# ❌ 悪い例：新機能だけ追加して古いファイルを放置
git add new_feature.dart
git commit -m "Add new feature"

# ✅ 良い例：新機能追加と同時に古いファイルを削除
git add new_feature.dart
git rm old_feature.dart
git commit -m "Replace old feature with new implementation

- Add: new_feature.dart with improved architecture
- Remove: old_feature.dart (deprecated)
- Update: Remove unused imports from 3 files"
```

### 3. テスト戦略
- **Unit Tests**: ビジネスロジックのテスト
- **Widget Tests**: UI コンポーネントのテスト
- **Integration Tests**: エンドツーエンドテスト

### 4. リファクタリング戦略

**目的**: コードベースをコンパクトに保ち、保守性・拡張性を維持する

#### 基本方針

**1. 日常的なリファクタリング（常時実施）**
- 新機能追加時は必ず既存コードの重複をチェック
- 200行を超えるファイルは分割を検討
- 50行を超えるメソッドは分割を検討
- 3レベルを超えるネストは改善を検討

**2. 定期的な大規模リファクタリング（月次）**
- 最大ファイルTOP5を特定
- リファクタリング計画を立案
- 段階的に実施（Phase分け）

**3. ファイル分割の基準**

| ファイルサイズ | 優先度 | 対応 |
|---------------|--------|------|
| 1000行以上 | 🔴 緊急 | 即座にファイル分割 |
| 500-999行 | 🟡 警告 | 次のバージョンで対応 |
| 200-499行 | 🟢 正常 | 必要に応じてメソッド抽出 |
| 200行未満 | ✅ 理想 | 維持 |

#### リファクタリングの3ステップ

**Step 1: メソッド抽出**
- 巨大メソッドを小さなメソッドに分割
- 単一責任原則を適用
- テストを追加して動作保証

**Step 2: クラス・ウィジェット分割**
- 責務ごとに独立したクラス/ウィジェットを作成
- `lib/services/[feature]/` や `lib/widgets/[feature]/` に配置
- ファイル間で再利用可能にする

**Step 3: 重複コードの共通化**
- 類似処理を抽出してユーティリティ化
- `lib/utils/` や `lib/core/` に配置
- プロジェクト全体で共有

#### 現在の優先リファクタリング対象

**🔴 緊急対応（1000行以上）**

（現在該当なし）

**🟡 警告レベル（500-999行）**

（現在該当なし）

**🟢 経過観察（200-499行）**

1. **lib/screens/site_form_screen.dart** (246行 → 最適化済み)
   - Phase 1完了（ウィジェット分割済み）
   - 5ウィジェットに分割: SiteLimitCard, SiteFormBody, ActionButtons, UrlChangeWarningDialog, WarningItem
   - 旧: 780行 → 新: 246行 + 408行 (5ウィジェット) = 654行（126行削減、16%削減）

2. **lib/providers/link_checker_provider.dart** (414行)
3. **lib/screens/profile_screen.dart** (426行)
4. **lib/widgets/site_detail/full_scan_section.dart** (405行)

**✅ 完了済み（最適化済み）**
- ✅ **lib/services/link_checker_service.dart** (722行 → 最適化済み)
  - Phase 5完了（ファイル分割・主要ロジック整理済み）
  - 4ファイルに分割: models.dart, http_client.dart, sitemap_parser.dart, result_repository.dart
  - 旧: 1142行 → 新: 722行（420行削減、37%削減）

- ✅ **lib/screens/site_form_screen.dart** (246行 → 最適化済み)
  - Phase 1完了（ウィジェット分割済み）
  - 5ウィジェットに分割: SiteLimitCard, SiteFormBody, ActionButtons, UrlChangeWarningDialog, WarningItem
  - 旧: 780行 → 新: 246行 + 408行 (5ウィジェット) = 654行（126行削減、16%削減）

#### リファクタリング実施の流れ

```bash
# 1. リファクタリングブランチ作成
git checkout -b refactor/[対象ファイル名]-[issue番号]

# 2. Phase 1: メソッド抽出
# - セクションコメント追加
# - 補助メソッド作成
# - テスト実行

# 3. Phase 2: データクラス導入（必要に応じて）
# - レコード型 → クラス化
# - 型安全性向上

# 4. Phase 3: ファイル分割
# - 責務ごとに別ファイル作成
# - import文更新
# - テスト実行

# 5. Phase 4: 重複コード共通化
# - 類似処理を検索
# - ユーティリティ関数作成
# - プロジェクト全体で適用

# 6. PR作成・レビュー・マージ
git push -u origin refactor/[対象ファイル名]-[issue番号]
```

#### リファクタリングのメトリクス測定

**各Phase完了時に記録**:
- ファイル行数（Before → After）
- Cyclomatic Complexity（制御構造の数）
- ネスト深さ（最大レベル数）
- テスト通過率

**記録場所**: `docs/REFACTORING_METRICS.md`（ファイルごとに詳細記録）

#### ベストプラクティス

**✅ DO（推奨）**
- リファクタリング前に必ずテストを追加
- 段階的に実施（1つのPRで1つのPhase）
- コミットメッセージに`refactor:`プレフィックス
- Before/Afterメトリクスを記録

**❌ DON'T（非推奨）**
- 機能追加とリファクタリングを同時に実施
- テストなしでリファクタリング
- 一度に大量のファイルを変更
- メトリクス測定をスキップ

#### 参考資料
- [Clean Code by Robert C. Martin](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)
- [Refactoring by Martin Fowler](https://refactoring.com/)
- [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)

## 依存関係

プロジェクトで使用しているパッケージの詳細は `pubspec.yaml` を参照してください。

### 主要な依存関係

**Firebase関連:**
- `firebase_core`: Firebase初期化
- `firebase_auth`: ユーザー認証
- `cloud_firestore`: NoSQLデータベース
- `cloud_functions`: サーバーレス関数（将来使用予定）

**認証:**
- `google_sign_in`: Google認証
- `sign_in_with_apple`: Apple Sign-In

**状態管理:**
- `provider`: UI状態管理（Provider Pattern）

**HTTP通信:**
- `http`: REST API通信、サイト監視

**HTML/XML解析:**
- `html`: HTMLパース（リンクチェック用）
- `xml`: XMLパース（Sitemap解析用）

**UI/可視化:**
- `fl_chart`: グラフ・チャート表示

**その他:**
- `intl`: 国際化・日時フォーマット
- `url_launcher`: 外部URL起動

> **注意**: 正確なバージョン番号は `pubspec.yaml` で確認してください。

## プロジェクト構造

```
lib/
├── main.dart                 # アプリエントリーポイント
├── app.dart                  # アプリルートウィジェット
├── core/                     # コア機能
│   ├── constants/            # 定数
│   ├── errors/               # エラー処理
│   ├── utils/                # ユーティリティ
│   └── services/             # サービス層
├── features/                 # 機能別フォルダ
│   ├── auth/                 # 認証機能
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── site_management/      # サイト管理
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── monitoring/           # 死活監視
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   └── link_checker/         # リンクチェック
│       ├── data/
│       ├── domain/
│       └── presentation/
├── shared/                   # 共通コンポーネント
│   ├── widgets/              # 共通ウィジェット
│   ├── themes/               # テーマ設定
│   └── extensions/           # 拡張機能
└── l10n/                     # 国際化対応
```

## データ構造

SiteCatはFirestore（NoSQLデータベース）を使用しています。以下は主要なコレクションとフィールドの構造です。

### Users Collection

**パス**: `/users/{userId}`

```typescript
{
  email: string           // ユーザーのメールアドレス
  displayName: string     // 表示名
  createdAt: Timestamp    // アカウント作成日時
  settings: {             // ユーザー設定
    notificationsEnabled: boolean
    defaultCheckInterval: number  // デフォルト監視間隔（分）
  }
}
```

### Sites Collection

**パス**: `/sites/{siteId}`

```typescript
{
  userId: string          // サイト所有者のユーザーID
  url: string             // 監視対象URL
  name: string            // サイト名
  monitoringEnabled: boolean  // 監視有効/無効
  checkInterval: number   // 監視間隔（分）
  excludedPaths: string[] // 除外パス（Phase 2で追加、Phase 3aでUI実装予定）
  createdAt: Timestamp    // 登録日時
  lastChecked: Timestamp  // 最終チェック日時
}
```

### MonitoringResults Collection

**パス**: `/monitoring_results/{resultId}`

```typescript
{
  siteId: string          // 対象サイトID
  timestamp: Timestamp    // チェック実行日時
  status: number          // HTTPステータスコード（200, 404, 500等）
  responseTime: number    // レスポンス時間（ミリ秒）
  isUp: boolean           // サイトが稼働中か
  errorMessage: string?   // エラーメッセージ（エラー時のみ）
}
```

### LinkCheckResults Collection

**パス**: `/link_check_results/{checkId}`

```typescript
{
  siteId: string          // 対象サイトID
  checkedAt: Timestamp    // チェック実行日時
  totalLinks: number      // 総リンク数
  brokenLinks: number     // 壊れたリンク数
  status: string          // チェック状況（"completed", "in_progress", "failed"）
}
```

### BrokenLinks SubCollection

**パス**: `/link_check_results/{checkId}/broken_links/{linkId}`

```typescript
{
  url: string             // リンクURL
  sourceUrl: string       // リンクが含まれるページURL
  status: number          // HTTPステータスコード
  isBroken: boolean       // リンク切れか
  errorMessage: string?   // エラーメッセージ
  checkedAt: Timestamp    // チェック日時
}
```

### データ設計のポイント

1. **正規化**: ユーザーとサイトは別コレクションで管理（1:N関係）
2. **サブコレクション**: リンク切れ詳細は`broken_links`サブコレクションで管理
3. **インデックス**: `userId`, `siteId`, `timestamp`等でクエリ最適化
4. **タイムスタンプ**: 全てのレコードに作成/更新日時を記録

## アーキテクチャ

### 概要

SiteCatは**Provider パターン**による状態管理と、**レイヤードアーキテクチャ**を採用しています。
各レイヤーは明確な責務を持ち、疎結合で保守性・テスタビリティの高い設計を実現しています。

### アーキテクチャ図

```
┌─────────────────────────────────────────────────────────────┐
│                    Screens (UI層)                           │
│  - ユーザーインターフェースの実装                              │
│  - レイアウト構築、ユーザー入力の受付                           │
│  - Providerからデータを取得して表示                           │
└─────────────────────┬───────────────────────────────────────┘
                      │ Consumer<Provider>
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Providers (状態管理層)                          │
│  - UIの状態管理（loading, error, data）                      │
│  - Serviceを呼び出してデータ取得                              │
│  - notifyListeners()でUI更新を通知                          │
│  - 複数のServiceを組み合わせた処理の調整                      │
└─────────────────────┬───────────────────────────────────────┘
                      │ 呼び出し
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Services (ビジネスロジック層)                    │
│  - Firebase/Firestoreとの通信                               │
│  - データの取得・保存・更新・削除（CRUD）                      │
│  - HTTP通信（リンクチェック、サイト監視）                      │
│  - データ変換・バリデーション                                 │
│  - UIから独立、再利用可能                                    │
└─────────────────────┬───────────────────────────────────────┘
                      │ 使用
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                 Models (データ層)                            │
│  - データ構造の定義                                          │
│  - Firestore ⇔ Dart オブジェクト変換                        │
│  - バリデーションロジック                                    │
└─────────────────────────────────────────────────────────────┘
```

### 各レイヤーの詳細

#### 1. Screens (UI層) 🖼️

**場所**: `lib/screens/`

**役割**: ユーザーインターフェースの実装

**責務**:
- レイアウト構築（Scaffold, Column, Row等）
- ユーザー入力の受付（TextFieldからの入力、ボタンタップ等）
- `Consumer<Provider>`でProviderからデータを取得
- データを画面に表示

**主なファイル**:
- `dashboard_screen.dart` - ダッシュボード画面
- `sites_screen.dart` - サイト一覧画面
- `site_detail_screen.dart` - サイト詳細画面
- `site_form_screen.dart` - サイト登録・編集フォーム

---

#### 2. Providers (状態管理層) 🔄

**場所**: `lib/providers/`

**役割**: UI用の状態管理 + ビジネスロジックの調整

**責務**:
- UI用の状態を保持（`_sites`, `_isLoading`, `_error`等）
- Serviceを呼び出してデータ取得
- `notifyListeners()`でUIに変更を通知
- 複数のServiceを組み合わせた処理の調整
- エラーハンドリングとUI向けエラーメッセージ生成

**パターン**: Provider Pattern (ChangeNotifier)

**主なファイル**:
- `site_provider.dart` - サイト管理の状態
- `auth_provider.dart` - 認証状態
- `monitoring_provider.dart` - 監視機能の状態
- `link_checker_provider.dart` - リンクチェック機能の状態

**重要なポイント**:
- ❌ Providerに複雑なビジネスロジックを書かない
- ✅ ビジネスロジックはServiceに委譲する
- ✅ ProviderはServiceとUIの「橋渡し」役

---

#### 3. Services (ビジネスロジック層) ⚙️

**場所**: `lib/services/`

**役割**: 実際のビジネスロジック実装

**責務**:
- Firebase/Firestoreとの通信
- データのCRUD操作（Create, Read, Update, Delete）
- HTTP通信（`http`パッケージでリンクチェック、サイト監視）
- データ変換（Firestore ⇔ Dartオブジェクト）
- バリデーション（URL形式チェック等）

**特徴**:
- UIから完全に独立
- 他のProviderからも再利用可能
- テストが容易

**主なファイル**:
- `site_service.dart` - サイト管理のビジネスロジック
- `auth_service.dart` - 認証処理
- `monitoring_service.dart` - サイト監視（HTTP通信）
- `link_checker_service.dart` - リンクチェック（HTML解析、リンク検証）

---

#### 4. Models (データ層) 📦

**場所**: `lib/models/`

**役割**: データ構造の定義

**責務**:
- データクラスの定義
- Firestore ⇔ Dart オブジェクト変換（`fromFirestore`, `toFirestore`）
- 簡易的なバリデーション・計算ロジック（getter等）

**主なファイル**:
- `site.dart` - サイトデータ
- `monitoring_result.dart` - 監視結果
- `broken_link.dart` - リンクチェック結果（壊れたリンク情報）

---

#### 5. Widgets (再利用可能なUI部品) 🧩

**場所**: `lib/widgets/`

**役割**: 複数の画面で使い回すUI部品

**責務**:
- 汎用的なUIコンポーネント
- 特定の機能に依存しない再利用可能なウィジェット

**主なファイル**:
- `link_check_section.dart` - リンクチェック結果表示セクション
- `monitoring_result_card.dart` - 監視結果カード
- `site_card.dart` - サイト情報カード

---

### 実際のデータフロー例: サイト一覧表示

```
1. ユーザーが「My Sites」画面を開く
   ↓
2. SitesScreen が表示される
   ↓
3. initState() で SiteProvider.initialize() を呼び出し
   ↓
4. SiteProvider が SiteService.getUserSites() を呼び出し
   ↓
5. SiteService が Firestore からデータを Stream で受信
   ↓
6. データが更新されるたびに SiteProvider.notifyListeners() が呼ばれる
   ↓
7. Consumer<SiteProvider> が再ビルドされる
   ↓
8. 画面に最新のサイト一覧が表示される
```

### 実際のデータフロー例: サイト作成

```
1. ユーザーがフォームに入力して「保存」ボタンをタップ
   ↓
2. SiteFormScreen が SiteProvider.createSite() を呼び出し
   ↓
3. SiteProvider が SiteService.validateUrl() でバリデーション
   ↓
4. バリデーションOKなら SiteService.createSite() を呼び出し
   ↓
5. SiteService が Firestore にデータを保存
   ↓
6. Firestore の変更が自動的に Stream に通知される（リアルタイム同期）
   ↓
7. SiteProvider の Stream リスナーが発火
   ↓
8. SiteProvider.notifyListeners() が呼ばれる
   ↓
9. Consumer<SiteProvider> が再ビルドされる
   ↓
10. 画面に新しいサイトが追加表示される
```

### アーキテクチャの利点

#### 1. 保守性 🔧
- 各レイヤーが明確な責務を持つ
- 変更の影響範囲が限定される
- コードの可読性が高い

#### 2. テスタビリティ 🧪
- ServiceはUIから独立しているため単体テスト容易
- Providerのモック化が簡単
- レイヤー単位でのテストが可能

#### 3. 再利用性 ♻️
- Serviceは複数のProviderから呼び出し可能
- Widgetは複数のScreenで再利用可能
- ビジネスロジックの重複を防げる

#### 4. 拡張性 📈
- 新機能追加時も既存コードへの影響が少ない
- レイヤーごとに独立して拡張可能
- チーム開発での分業が容易

### ベストプラクティス

#### ✅ DO（推奨）

- **Providerは状態管理に専念**
  ```dart
  // ✅ Good: Serviceに処理を委譲
  Future<bool> createSite({...}) async {
    if (!await _siteService.validateUrl(url)) {
      _error = 'Invalid URL';
      return false;
    }
    await _siteService.createSite(...);
    return true;
  }
  ```

- **Serviceはステートレスに保つ**
  ```dart
  // ✅ Good: 引数で必要な情報を受け取る
  Future<void> createSite({required String url, required String name}) async {
    // ...
  }
  ```

- **リアルタイム同期を活用**
  ```dart
  // ✅ Good: Stream でリアルタイム更新
  Stream<List<Site>> getUserSites() {
    return _firestore.collection('sites').snapshots().map(...);
  }
  ```

#### ❌ DON'T（非推奨）

- **ProviderにFirestore操作を直接書かない**
  ```dart
  // ❌ Bad: Providerに直接Firestore操作
  Future<void> createSite() async {
    await FirebaseFirestore.instance.collection('sites').add({...});
  }
  ```

- **Screenに複雑なロジックを書かない**
  ```dart
  // ❌ Bad: ScreenにHTTP通信
  Future<void> checkSite() async {
    final response = await http.get(Uri.parse(url));
    // ...
  }
  ```

- **Modelに複雑なビジネスロジックを書かない**
  ```dart
  // ❌ Bad: ModelにFirestore保存ロジック
  class Site {
    Future<void> save() async {
      await FirebaseFirestore.instance.collection('sites').add(toFirestore());
    }
  }
  ```

### まとめ

SiteCatのアーキテクチャは以下のように整理されています：

- **Screens**: UIの実装
- **Providers**: 状態管理 + UI⇔Serviceの橋渡し
- **Services**: ビジネスロジック（Firebase通信、HTTP通信、データ変換）
- **Models**: データ構造の定義
- **Widgets**: 再利用可能なUI部品

この構成により、コードの可読性、保守性、テスタビリティが高く保たれ、チーム開発やアプリの拡張が容易になっています。

---

## 開発ロードマップ

### Phase 1: MVP完成・App Storeリリース ✅ (完了)
**期間**: 2025年Q4  
**バージョン**: v1.0.x

**目標**: iOS版アプリとして最小限の機能を実装し、App Storeでリリース

**完了した機能:**
- ✅ Firebase プロジェクト作成・設定
- ✅ Flutter アプリにFirebase統合
- ✅ Firebase Authentication 実装
- ✅ ログイン・サインアップUI（Google Sign-In + Apple Sign-In）
- ✅ サイト管理機能（追加・編集・削除、1サイト制限）
- ✅ Firestore データ操作
- ✅ サイト一覧UI
- ✅ Quick Check（手動監視、HTTP リクエスト）
- ✅ 監視結果の保存・表示
- ✅ 基本統計（稼働率、平均応答時間）
- ✅ グラフ表示（fl_chart）
- ✅ 監視頻度制限（5分間隔）
- ✅ タイムアウト最適化（30秒→10秒）
- ✅ 統計情報キャッシュ（5分間有効）
- ✅ **App Store審査通過・配信開始（175カ国）**
- ✅ **Xcode Cloud CI/CD設定**

**成果物:**
- iOS専用アプリとしてApp Store配信中
- 死活監視の基本機能が動作
- 手動チェックで即座に結果確認可能
- 負荷軽減機能により対象サイトへの影響を最小化

---

### Phase 2: リンク切れチェック強化 ✅ (完了)
**期間**: 2025年Q4  
**バージョン**: v1.0.x

**目標**: サイト内のリンク切れを検出する機能を追加し、バックエンド基盤を整備

**完了した機能:**
- ✅ HTML/XMLサイトマップ解析機能
- ✅ リンクの有効性チェック（HTTP HEAD/GET リクエスト）
- ✅ 壊れたリンクのリスト表示（内部/外部リンク別）
- ✅ リンクチェック結果の保存（Firestore）
- ✅ チェック進捗表示（リアルタイム更新）
- ✅ Full Scan機能（サイトマップベース、中断・再開UI）
- ✅ Quick CheckとFull Scanのタブ分離
- ✅ 独立したカウントダウンタイマー（各5分間隔）
- ✅ UI大規模リファクタリング（13個の再利用可能ウィジェット作成）
- ✅ **除外パス設定（バックエンド実装完了、PR #195マージ）**
- ✅ **Flutter 3.38.3へのアップグレード（PR #196マージ）**
- ✅ **168テスト成功**
- ✅ **Quick Scan廃止してSite Scanに統合（Issue #215、PR #230マージ）**
  - ✅ MonitoringResultにsitemapStatusCodeフィールド追加
  - ✅ MonitoringProviderにセッション別キャッシュ機能実装
  - ✅ Site Scanタブにサイトマップ状態セクション追加
  - ✅ 画面オープン時に自動でquick scanを実行
  - ✅ Quick Scanタブ削除（UIシンプル化）

**実装された技術要素:**
- `html`/`xml` パッケージでサイトマップ解析
- Isolateでのバックグラウンド処理
- Firestoreへの結果保存とキャッシュ機能
- Provider Patternによる状態管理
- TabController/TabViewによるUI分離
- 除外パス機能（`Site`モデル、`LinkCheckerService`）

**達成された効果:**
- ウェブサイトのメンテナンス効率向上
- SEO対策の支援
- コードの可読性・保守性が大幅に向上（1,163行削減）
- 有料化の技術基盤完成

---

### Phase 3a: 買い切り有料版 ✅ (完了)
**期間**: 2025年Q4  
**価格**: ¥1,220（一度の購入）  
**バージョン**: v1.0.x～v1.1.x

**目標**: 買い切り型有料機能を実装し、収益化を開始

**完了した機能:**
- ✅ **In-App Purchase統合**
  - ✅ StoreKit 2対応
  - ✅ 課金状態管理（Firestore `users/{userId}/subscription`）
  - ✅ リストア機能
  - ✅ 購入フロー実装
  - ✅ **App Storeリリース完了**

- ✅ **サイト数制限解除**
  - ✅ 定数変更（1サイト → 無制限）
  - ✅ UI側で課金状態チェック
  - ✅ 無料版での制限表示

- ✅ **除外パス設定UI** (#197)
  - ✅ バックエンド実装完了（PR #195マージ済み）
  - ✅ 設定画面UI実装
  - ✅ パス入力・検証UI

- ✅ **Full Scan中断・再開機能** (#193)
  - ✅ Isolate管理の改善
  - ✅ 一時停止・再開ロジック
  - ✅ UI実装

- ✅ **履歴表示拡張**
  - ✅ Site Scan: 10件 → 50件
  - ✅ Full Scan: 10件 → 50件
  - ✅ クリーンアップロジック更新

**技術的な実装（完了済み）:**
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
  
  Future<void> cleanupOldResults(String siteId) async {
    await _cleanupByType(siteId, 'site_scan', PAID_HISTORY_LIMIT);
    await _cleanupByType(siteId, 'full_scan', PAID_HISTORY_LIMIT);
  }
}
```

**成果物:**
- 買い切り型課金システム実装完了
- App Storeで販売開始（¥1,220）
- サイト数無制限機能リリース
- 除外パス設定機能完全実装（バックエンド + UI）
- Full Scan中断・再開機能実装
- 履歴表示を50件に拡張（有料版）
- Phase 3a の全機能リリース完了

---

### Phase 3b: サブスクリプション版 📅 (将来計画)
**予定**: 2026年Q1～  
**価格**: ¥490/月（買い切り機能すべて含む）  
**バージョン**: v1.2.x予定

**目標**: サブスクリプションで継続的収益を実現

**実装予定機能:**
- [ ] **Cloud Run定期実行**
  - [ ] Cloud Scheduler設定
  - [ ] 1日4回（6時間ごと）の自動監視
  - [ ] 課金状態確認と実行制御
  - [ ] エラーハンドリング

- [ ] **プッシュ通知**
  - [ ] Firebase Cloud Messaging統合
  - [ ] リンク切れ検出時の通知
  - [ ] ダウンタイム検出時の通知
  - [ ] 通知設定UI

- [ ] **詳細レポート機能**
  - [ ] 推移グラフの強化
  - [ ] 統計サマリー
  - [ ] エクスポート機能（将来検討）

**技術的な実装:**
```dart
class SubscriptionService {
  static const String MONTHLY_PRODUCT_ID = 'sitecat.subscription.monthly';
  
  Future<bool> hasActiveSubscription() async {
    // StoreKit 2でサブスク状態確認
    // 自動更新のステータス管理
  }
  
  Future<void> enableAutoMonitoring(String userId) async {
    // Cloud Run Jobの有効化
    // FCMトークン登録
  }
}
```

### Phase 4: 将来的な拡張 🚀 (2026年Q2～)
**目標**: プラットフォーム拡張と高度な機能追加

**検討中の機能:**
- [ ] **Android版の開発**
  - [ ] Flutterマルチプラットフォーム化
  - [ ] Google Play Store配信

- [ ] **高度な機能**
  - [ ] チーム機能（複数ユーザーでのサイト共有）
  - [ ] Slack/Discord連携
  - [ ] API連携機能
  - [ ] Enterprise プラン

- [ ] **多言語対応**
  - [ ] 英語対応
  - [ ] l10nファイル整備

---

### Phase 2実装の詳細（完了済み）

#### ✅ HTML解析とリンク抽出
- ✅ `html` パッケージの統合
- ✅ HTML取得機能
- ✅ リンク抽出ロジック（a要素、href属性）
- ✅ 内部/外部リンクの判定（ドメインベース）

#### ✅ リンク検証機能
- ✅ HTTP HEAD/GET リクエスト実装
- ✅ 並列処理（効率的なリンクチェック）
- ✅ 結果の集計（成功/失敗カウント）
- ✅ エラーハンドリング（タイムアウト、404等）

#### ✅ データ保存とUI
- ✅ Firestore スキーマ設計（link_check_results コレクション）
- ✅ リンクチェック結果の保存
- ✅ リンク切れリスト画面（BrokenLinksScreen）
- ✅ 進捗表示UI（リアルタイム更新）
- ✅ タブUI（Quick Check / Full Scan分離）

#### ✅ テストとリファクタリング
- ✅ 全117ユニットテスト通過
- ✅ UI大規模リファクタリング（4画面、1,163行削減）
- ✅ 13個の再利用可能ウィジェット作成
- ✅ コード可読性・保守性の向上
- ✅ **App Store審査通過・配信開始（175カ国）**
- ✅ **実機テスト、セキュリティチェック完了**

## 実装のポイント

### 1. 状態管理
- **Provider** を使用して状態管理（採用済み）
- **ChangeNotifier** でビジネスロジックを実装
- リアルタイムデータ更新に対応

### 2. エラーハンドリング
- カスタム例外クラスの作成
- ユーザーフレンドリーなエラーメッセージ
- ログ記録とクラッシュレポート
- Firebase Crashlytics 統合（将来）

### 3. パフォーマンス
- 画像の最適化
- 無限スクロール実装
- キャッシュ戦略

### 4. セキュリティ
- Firebase Security Rules の設定
- 入力値のサニタイゼーション
- Rate Limiting の実装

## テスト戦略

### Unit Tests
```dart
// example: test/features/auth/domain/usecases/login_usecase_test.dart
void main() {
  group('LoginUsecase', () {
    test('should return User when login is successful', () async {
      // テストコード
    });
  });
}
```

### Widget Tests
```dart
// example: test/features/auth/presentation/pages/login_page_test.dart
void main() {
  testWidgets('LoginPage should display login form', (tester) async {
    // テストコード
  });
}
```

## デプロイメント

### Development
- Firebase Hosting (Web)
- Firebase App Distribution (Mobile)

### Production
- Google Play Store (Android)
- Apple App Store (iOS)
- Firebase Hosting (Web)

## モニタリング・分析

- **Firebase Analytics**: ユーザー行動分析
- **Firebase Crashlytics**: クラッシュレポート
- **Firebase Performance Monitoring**: パフォーマンス監視

## 関連ドキュメント

- **[PROJECT_CONCEPT.md](./PROJECT_CONCEPT.md)**: プロジェクト全体の概要、ビジネスモデル、開発状況
- **[BUSINESS_MODEL.md](./BUSINESS_MODEL.md)**: ビジネスモデル、価格プラン、App Store審査対応
- **[PRICING_STRATEGY.md](./PRICING_STRATEGY.md)**: 有料化戦略の詳細、実装ロードマップ

---

**ドキュメントバージョン**: v2.1