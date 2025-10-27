# Firebase Configuration Setup

このプロジェクトではFirebaseの設定ファイルがセキュリティ上の理由で`.gitignore`に含まれています。

## セットアップ手順

### 1. FlutterFire CLIを使用（推奨）

```bash
# Firebase CLIとFlutterFire CLIをインストール
npm install -g firebase-tools
dart pub global activate flutterfire_cli

# Firebaseにログイン
firebase login

# Firebase設定ファイルを生成
flutterfire configure
```

### 2. 手動セットアップ

1. `lib/firebase_options.dart.example` を `lib/firebase_options.dart` にコピー
2. Firebase Consoleから各プラットフォームのAPIキーと設定を取得
3. `lib/firebase_options.dart` の `YOUR_*` プレースホルダーを実際の値に置き換え

同様に以下のファイルも設定が必要です：
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

## セキュリティ注意事項

⚠️ これらのファイルは**絶対にコミットしないでください**：
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

これらは既に`.gitignore`に追加されています。
