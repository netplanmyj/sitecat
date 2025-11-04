# SiteCat 🐱‍💻

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-orange.svg)](https://firebase.google.com/)

**SiteCat**は、ウェブサイトの死活監視とリンク切れ検出を行うモバイルアプリケーションです。

## 🚀 現在の機能（MVP完成）

- **手動監視**: ボタンタップでウェブサイトの死活チェック
- **基本統計**: 稼働率、平均応答時間の表示
- **監視履歴**: 過去の監視結果を保存・表示
- **Google認証**: アカウント管理とデータ同期
- **マルチサイト管理**: 複数サイトの一元管理
- **リアルタイム同期**: Firestore経由でデバイス間同期
- **ダッシュボード**: Recent Activity表示

## � 開発中・計画中の機能

- **リンク切れチェック**: サイト内のリンク切れを検出（Phase 2 進行中）
- **自動監視**: Cloud Functionsによる定期監視（Phase 4 検討中）
- **プッシュ通知**: ダウンタイム検出時の通知（Phase 4 検討中）
- **詳細レポート**: 時系列グラフ、高度な分析（Phase 4 検討中）

> フリーミアムモデル（無料版/有料版）は将来的に検討予定です。詳細は [PRICING_STRATEGY.md](docs/PRICING_STRATEGY.md) を参照。

## 📱 対応プラットフォーム

- **iOS** 📱
- **Android** 🤖

> **Note**: モバイル専用アプリです。プッシュ通知などモバイル特有の機能を重視した設計です。

## 🛠 技術スタック

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase
  - Authentication (Google Sign-In)
  - Cloud Firestore (データベース)
  - Cloud Functions (将来の自動監視用)
- **状態管理**: Provider Pattern

## 📋 前提条件

- Flutter SDK 3.0+
- Dart SDK 3.0+
- Firebase CLI
- Android Studio / Xcode

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
   # Firebase CLI インストール・ログイン
   npm install -g firebase-tools
   firebase login
   
   # プロジェクト初期化
   firebase use sitecat-dev  # 開発環境
   firebase init
   ```

   > **Note**: Firebase プロジェクト設定の詳細は [FIREBASE_SETUP.md](FIREBASE_SETUP.md) を参照

4. **アプリ実行**
   ```bash
   flutter run
   ```

## 📚 ドキュメント

- [プロジェクト概要](docs/PROJECT_CONCEPT.md): SiteCatの目的と主要機能
- [開発ガイド](docs/DEVELOPMENT_GUIDE.md): アーキテクチャ、セットアップ、開発ロードマップ
- [Firebase認証](docs/FIREBASE_AUTH_SPEC.md): 認証システムの実装概要
- [料金・機能戦略](docs/PRICING_STRATEGY.md): 将来の収益化計画（検討中）

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
