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

## 開発の優先順位

### Week 1: 基盤整備
- [ ] Firebase プロジェクト作成・設定
- [ ] Flutter アプリにFirebase統合
- [ ] 基本的なルーティング設定
- [ ] テーマ・デザインシステム構築

### Week 2: 認証システム
- [ ] Firebase Authentication 実装
- [ ] ログイン・サインアップUI
- [ ] 認証状態管理
- [ ] ユーザープロファイル

### Week 3: サイト管理
- [ ] サイト追加・編集・削除機能
- [ ] Firestore データ操作
- [ ] サイト一覧UI
- [ ] 入力値バリデーション

### Week 4: 基本的な監視機能
- [ ] HTTP リクエスト機能
- [ ] Cloud Functions 作成
- [ ] 監視結果の保存・表示
- [ ] 基本的な統計表示

## 実装のポイント

### 1. 状態管理
- **Riverpod** を使用して状態管理
- **AsyncValue** でローディング・エラー状態を管理
- **StateNotifier** でビジネスロジックを実装

### 2. エラーハンドリング
- カスタム例外クラスの作成
- ユーザーフレンドリーなエラーメッセージ
- ログ記録とクラッシュレポート

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

- **多言語対応**: 英語・日本語
- **ダークモード**: UI テーマ切り替え
- **API監視**: REST API エンドポイント監視
- **通知カスタマイズ**: 詳細な通知設定
- **レポート機能**: PDF/CSV エクスポート
- **チーム機能**: 複数ユーザーでのサイト共有