# SiteCat 🐱‍💻

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-orange.svg)](https://firebase.google.com/)

**SiteCat**は、ウェブサイトの死活監視とリンク切れ検出を行うクロスプラットフォームアプリケーションです。

## 🚀 主要機能

- **死活監視**: 指定したウェブサイトの定期的なヘルスチェック
- **リンク切れ検出**: サイト内の壊れたリンクを自動検出
- **マルチデバイス対応**: iOS、Android、Web で利用可能
- **リアルタイム通知**: 障害発生時の即座な通知
- **統計・レポート**: アップタイム統計とパフォーマンス分析

## 📱 対応プラットフォーム

- iOS
- Android  
- Web (Progressive Web App)

## 🛠 技術スタック

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase
  - Authentication (認証)
  - Cloud Firestore (データベース)
  - Cloud Functions (サーバーサイド処理)
  - Cloud Messaging (プッシュ通知)
- **Hosting**: Firebase Hosting

## 📋 前提条件

- Flutter SDK 3.0+
- Dart SDK 3.0+
- Firebase CLI
- Android Studio / Xcode (モバイル開発の場合)

## 🚦 セットアップ

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

4. **アプリ実行**
   ```bash
   flutter run
   ```

## 📚 ドキュメント

- [プロジェクト概要](docs/PROJECT_CONCEPT.md)
- [開発ガイド](docs/DEVELOPMENT_GUIDE.md)

## 🤝 コントリビューション

プルリクエストや Issue の報告を歓迎します！

1. フォークする
2. フィーチャーブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add some amazing feature'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. プルリクエストを作成

## 📄 ライセンス

このプロジェクトは [MIT License](LICENSE) の下で公開されています。

## 🙋‍♂️ サポート

質問や問題がある場合は、[Issues](https://github.com/netplanmyj/sitecat/issues) を作成してください。

---

Made with ❤️ using Flutter
