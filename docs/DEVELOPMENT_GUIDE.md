# 開発ガイド - SiteCat

## 開発環境セットアップ

### 前提条件
- Flutter SDK (最新安定版)
- Dart SDK
- Android Studio / Xcode (モバイル開発用)
- Firebase CLI
- Git

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

### 2. コード規約
- Dart公式のlintルールに従う
- `analysis_options.yaml`の設定を遵守
- コメントは日本語でOK、変数名・関数名は英語

### 3. テスト戦略
- **Unit Tests**: ビジネスロジックのテスト
- **Widget Tests**: UI コンポーネントのテスト
- **Integration Tests**: エンドツーエンドテスト

## 必要なFirebaseパッケージ

以下のパッケージを`pubspec.yaml`に追加予定：

```yaml
dependencies:
  # Firebase Core
  firebase_core: ^2.24.2
  
  # Authentication
  firebase_auth: ^4.15.3
  
  # Database
  cloud_firestore: ^4.13.6
  
  # Functions
  cloud_functions: ^4.5.4
  
  # Messaging
  firebase_messaging: ^14.7.10
  
  # Analytics
  firebase_analytics: ^10.7.4
  
  # HTTP requests
  http: ^1.1.0
  dio: ^5.4.0
  
  # HTML parsing
  html: ^0.15.4
  
  # State management
  provider: ^6.1.1
  riverpod: ^2.4.9
  
  # UI
  flutter_local_notifications: ^16.3.0
  url_launcher: ^6.2.2
  
  # Utilities
  intl: ^0.19.0
  shared_preferences: ^2.2.2
```

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

## 開発ロードマップ

### Phase 1: MVP完成 ✅ (完了)

**目標**: 簡易ツールとして最小限の機能を実装

**完了した機能:**
- ✅ Firebase プロジェクト作成・設定
- ✅ Flutter アプリにFirebase統合
- ✅ Firebase Authentication 実装
- ✅ ログイン・サインアップUI (Google認証)
- ✅ サイト管理機能（追加・編集・削除）
- ✅ Firestore データ操作
- ✅ サイト一覧UI
- ✅ 手動監視機能（HTTP リクエスト）
- ✅ 監視結果の保存・表示
- ✅ 基本統計（稼働率、平均応答時間）
- ✅ 監視頻度制限（5分間隔）
- ✅ タイムアウト最適化（30秒→10秒）
- ✅ 統計情報キャッシュ（5分間有効）

**成果物:**
- 死活監視の基本機能が動作
- 手動チェックで即座に結果確認可能
- 負荷軽減機能により対象サイトへの影響を最小化

---

### Phase 2: リンク切れチェック実装 🎯 (進行中)

**目標**: サイト内のリンク切れを検出する機能を追加

**実装予定:**
- [ ] HTML解析機能（サイト内リンク抽出）
- [ ] リンクの有効性チェック（HTTP HEAD リクエスト）
- [ ] 壊れたリンクのリスト表示
- [ ] リンクチェック結果の保存
- [ ] チェック進捗表示
- [ ] 外部リンク/内部リンクの区別

**技術要素:**
- `html` パッケージでHTMLパース
- 並列リクエスト処理
- 結果のFirestore保存
- UI: リンク切れリスト画面

**期待される効果:**
- ウェブサイトのメンテナンス効率向上
- SEO対策の支援
- ユーザー体験の改善

---

### Phase 3: リリース準備 (未着手)

**目標**: アプリストアへの公開準備

**タスク:**
- [ ] UI/UX 最終調整
  - [ ] アイコン・スプラッシュ画面
  - [ ] 各画面の操作性確認
  - [ ] エラーメッセージの改善
- [ ] テスト
  - [ ] 全機能の統合テスト
  - [ ] 実機テスト（複数デバイス）
  - [ ] パフォーマンステスト
- [ ] ドキュメント整備
  - [ ] ユーザーマニュアル
  - [ ] プライバシーポリシー
  - [ ] 利用規約
- [ ] ストア申請
  - [ ] Google Play Store
  - [ ] Apple App Store
  - [ ] アプリ説明文・スクリーンショット

**品質基準:**
- クラッシュ率 < 0.1%
- 主要機能のテストカバレッジ > 80%
- 全プラットフォームで動作確認

---

### Phase 4: 有料機能実装 (リリース後)

**目標**: フリーミアムモデルで収益化

**無料版（現在の機能）:**
- 手動監視
- 基本統計
- リンク切れチェック（手動）

**有料版追加機能:**
- [ ] 詳細な監視履歴UI
  - [ ] 時系列グラフ（レスポンス時間、稼働率）
  - [ ] 詳細な統計レポート
  - [ ] データエクスポート（CSV/PDF）
- [ ] 自動監視（Cloud Functions）
  - [ ] Cloud Scheduler で定期実行
  - [ ] checkInterval 設定の活用
  - [ ] バックグラウンド監視
- [ ] プッシュ通知
  - [ ] ダウンタイム検出時の通知
  - [ ] リンク切れ検出時の通知
  - [ ] 通知設定のカスタマイズ
- [ ] 高度な機能
  - [ ] 複数サイトの一括監視
  - [ ] チーム共有機能
  - [ ] Slack/Discord 連携
  - [ ] API エンドポイント監視

**価格戦略:**
- 無料版: 基本機能
- 有料版: 月額 ¥500-1,000 程度

---

### 開発の優先順位（Phase 2の詳細）

#### Week 1: HTML解析とリンク抽出
- [ ] `html` パッケージの統合
- [ ] HTML取得機能
- [ ] リンク抽出ロジック
- [ ] 内部/外部リンクの判定

#### Week 2: リンク検証機能
- [ ] HTTP HEAD リクエスト実装
- [ ] 並列処理（効率化）
- [ ] 結果の集計
- [ ] エラーハンドリング

#### Week 3: データ保存とUI
- [ ] Firestore スキーマ設計
- [ ] リンクチェック結果の保存
- [ ] リンク切れリスト画面
- [ ] 進捗表示UI

#### Week 4: テストと調整
- [ ] ユニットテスト
- [ ] 統合テスト
- [ ] パフォーマンス最適化
- [ ] UI/UX 改善

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

## 今後の拡張予定

### 短期（Phase 2-3）
- リンク切れチェック機能
- UI/UX 改善
- パフォーマンス最適化
- アプリストアリリース

### 中期（Phase 4 - 有料版）
- 詳細な監視履歴UI（グラフ、レポート）
- 自動監視（Cloud Functions + Cloud Scheduler）
- プッシュ通知
- データエクスポート（CSV/PDF）

### 長期（将来バージョン）
- **多言語対応**: 英語・日本語
- **ダークモード**: UI テーマ切り替え
- **API監視**: REST API エンドポイント監視
- **通知カスタマイズ**: 詳細な通知設定
- **チーム機能**: 複数ユーザーでのサイト共有
- **Slack/Discord連携**: 外部サービス統合