# SiteCat 🐱‍💻

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-orange.svg)](https://firebase.google.com/)

**SiteCat**は、ウェブサイトの死活監視とリンク切れ検出を行うクロスプラットフォームアプリケーションです。

## 🚀 主要機能

### 無料版 🆓
- **手動監視**: ボタンタップでリアルタイム死活チェック
- **基本リンクチェック**: 単一ページのリンク切れ検出
- **Google認証**: アカウント管理とデータ同期
- **履歴保存**: 30日間の監視履歴
- **複数デバイス**: データの自動同期
- **制限**: 10サイトまで、1日10回チェック、手動実行のみ

### 有料版 💎
- **自動監視**: 5分〜24時間間隔での定期ヘルスチェック
- **高度なリンクチェック**: サイト全体の詳細スキャン
- **リアルタイム通知**: プッシュ通知、メール、Slack連携
- **詳細レポート**: アップタイム統計とパフォーマンス分析
- **無制限**: サイト数制限なし、1年間の履歴保持
- **API連携**: 外部システムとの統合機能

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

## � 料金プラン

| 機能 | 無料版 | Personal ($9.99/月) | Business ($29.99/月) |
|------|--------|-------------------|---------------------|
| 監視サイト数 | 10個まで | 無制限 | 無制限 |
| 監視方法 | 手動のみ | 自動+手動 | 自動+手動 |
| チェック頻度 | 1日10回 | 5分〜24時間 | 1分〜24時間 |
| 履歴保持 | 30日 | 1年間 | 1年間 |
| 通知方法 | アプリ内のみ | プッシュ+メール | 全通知+Slack |
| レポート | 基本統計 | 詳細レポート | 高度な分析 |
| API連携 | なし | あり | あり |
| チーム機能 | なし | なし | あり |

## �📚 ドキュメント

- [プロジェクト概要](docs/PROJECT_CONCEPT.md)
- [開発ガイド](docs/DEVELOPMENT_GUIDE.md)
- [料金・機能戦略](docs/PRICING_STRATEGY.md)

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
