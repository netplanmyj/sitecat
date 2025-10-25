# Mobile-First Architecture Decision

## 決定内容

SiteCatをモバイル専用アプリケーション（Android/iOS）として開発し、Webプラットフォームのサポートを除外しました。

## 理由

### 1. モバイルファーストな体験
- Webサイト監視はモバイルでの確認が主要なユースケース
- プッシュ通知による即座のアラート機能
- モバイル特有のUIパターンでより直感的な操作性

### 2. 開発・運用コストの削減
- 単一プラットフォーム対応により開発速度向上
- テスト対象の削減
- Firebase Hostingのコスト削減
- CI/CDパイプラインの簡素化

### 3. 技術的な利点
- ネイティブモバイル機能の活用（カメラ、位置情報、バイオメトリクス等）
- プラットフォーム固有の最適化
- より安定したパフォーマンス

## 影響範囲

### 削除された要素
- `web/` ディレクトリ
- Firebase Hosting設定
- Web関連のGitHub Actionsワークフロー
- CI/CDでのWebビルドプロセス

### 保持された要素
- Android/iOSのサポート
- Firebase Authentication, Firestore, Functions
- モバイル向けのCI/CDパイプライン

## 今後の拡張性

将来的にWebサポートが必要になった場合は、以下の手順で復元可能：

1. `flutter create --platforms web .` でWeb設定を再生成
2. Firebase Hostingの再設定
3. GitHub ActionsワークフローにWebビルドを追加
4. `firebase_options.dart` にWeb設定を追加

## メリット

✅ **開発効率の向上**: 単一プラットフォーム対応により開発速度アップ
✅ **コスト削減**: Firebase Hostingやその他Web関連コストの削減
✅ **保守性の向上**: テスト対象とデプロイ対象の簡素化
✅ **モバイル体験の最適化**: ネイティブ機能を活用した最適なUX
✅ **セキュリティ向上**: 攻撃面の縮小