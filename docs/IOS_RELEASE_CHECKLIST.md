# iOS Release Checklist (#78)

## 基本情報
- **Bundle ID**: `jp.netplan.sitecat` ✅
- **Version**: `1.0.0` ✅
- **Build Number**: `1` ✅
- **App Store Connect**: アカウント確認済み ✅

## 1. 技術的準備

### 1.1 証明書・プロビジョニング
- [ ] Apple Developer Program メンバーシップ確認
- [ ] Distribution Certificate (配布証明書) 作成
- [ ] App Store Provisioning Profile 作成
- [ ] Xcode に証明書インストール

### 1.2 App Store Connect 設定
- [ ] App Store Connect で新規アプリ作成
  - Bundle ID: `jp.netplan.sitecat`
  - アプリ名: `SiteCat`
  - プライマリ言語: English (U.S.)
  - 追加言語: 日本語 (Japanese) ← 作成後すぐに追加
- [ ] SKU 設定: `sitecat-001`
- [ ] アクセス権限設定

### 1.3 Xcode プロジェクト設定
- [ ] Signing & Capabilities 確認
  - Team 選択
  - Automatic Signing 有効化
  - Bundle Identifier 確認
- [ ] Deployment Target 確認 (iOS 13.0+推奨)
- [ ] Info.plist 設定確認
  - CFBundleDisplayName
  - CFBundleShortVersionString
  - Privacy 使用説明 (必要に応じて)

### 1.4 Firebase 設定
- [ ] iOS 本番環境の GoogleService-Info.plist 確認
- [ ] App Store 用の API キー制限設定

### 1.5 ビルド設定
- [ ] Release ビルド確認
  ```bash
  flutter build ios --release
  ```
- [ ] Archive 作成テスト
- [ ] サイズ最適化確認

## 2. アプリアイコン (#126)
- [ ] 1024x1024px App Store 用アイコン作成
- [ ] iOS 各種サイズ自動生成確認
- [ ] アイコン Assets.xcassets に配置
- [ ] デザインガイドライン準拠確認

## 3. マテリアル準備 (#127)

### 3.1 スクリーンショット
- [ ] iPhone 6.9" (iPhone 16 Pro Max) - 必須
- [ ] iPhone 6.7" (iPhone 14 Pro Max) - 必須
- [ ] iPhone 6.5" (iPhone 11 Pro Max) - 推奨
- [ ] iPhone 5.5" (iPhone 8 Plus) - オプション
- [ ] iPad Pro 12.9" (第6世代) - iPadサポート時

### 3.2 アプリ説明
- [ ] アプリ名 (30文字以内) - 英語・日本語
- [ ] サブタイトル (30文字以内) - 英語・日本語
- [ ] プロモーションテキスト (170文字以内) - 英語・日本語
- [ ] 説明文 (4000文字以内)
  - 英語版 (プライマリ)
  - 日本語版
- [ ] キーワード (100文字以内、カンマ区切り) - 英語・日本語
- [ ] サポートURL
- [ ] マーケティングURL (オプション)

### 3.3 レーティング・カテゴリ
- [ ] プライマリカテゴリ選択 (例: ビジネス、ユーティリティ)
- [ ] セカンダリカテゴリ選択 (オプション)
- [ ] 年齢レーティング設定

## 4. 法務関連ドキュメント (#128)
- [ ] プライバシーポリシー作成・公開
- [ ] 利用規約作成・公開
- [ ] サポートページ作成
- [ ] App Privacy 情報入力
  - 収集するデータの種類
  - データの使用目的
  - データの共有先

## 5. 審査準備

### 5.1 テスト
- [ ] 実機テスト (複数デバイス)
- [ ] リリースビルドでの動作確認
- [ ] クラッシュがないことを確認
- [ ] パフォーマンステスト

### 5.2 審査情報
- [ ] デモアカウント準備 (必要な場合)
- [ ] 審査用メモ作成
- [ ] レビュー担当者への注意事項

### 5.3 App Review 対策
- [ ] App Store Review Guidelines 確認
- [ ] 禁止コンテンツ・機能の除外確認
- [ ] メタデータとアプリ内容の一致確認

## 6. 提出

### 6.1 Archive & Upload
- [ ] Xcode で Archive 作成
- [ ] Validate App 実行
- [ ] Distribute App で App Store Connect にアップロード
- [ ] TestFlight で動作確認 (推奨)

### 6.2 App Store Connect 最終確認
- [ ] ビルド選択
- [ ] 価格設定 (無料/有料)
- [ ] 提供国・地域選択
- [ ] 自動リリース/手動リリース選択

### 6.3 審査提出
- [ ] 「審査に提出」ボタンをクリック
- [ ] 確認メール受信確認

## 7. 審査後

### 7.1 承認時
- [ ] リリース通知確認
- [ ] App Store での表示確認
- [ ] ユーザーフィードバック監視開始

### 7.2 リジェクト時
- [ ] リジェクト理由確認
- [ ] 必要な修正実施
- [ ] 再提出

## 注意事項
- 審査期間: 通常 1-2週間
- TestFlight の活用を推奨
- 初回審査は時間がかかる可能性あり
- App Store Review Guidelines を事前に熟読

## 関連Issue
- #78: iOS版リリース準備 (親Issue)
- #126: アプリアイコン
- #127: マテリアル準備
- #128: 法務関連ドキュメント
- #79: Android版リリース準備 (次フェーズ)
