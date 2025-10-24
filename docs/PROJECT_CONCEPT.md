# SiteCat - ウェブサイト監視アプリ

## プロジェクト概要

SiteCatは、指定されたウェブサイトの死活監視とリンク切れ検出を行うFlutterアプリケーションです。複数のデバイスからアクセス可能なクラウドベースのソリューションを提供します。

## 主要機能

### 1. ウェブサイト死活監視
- 指定したウェブサイトのHTTPステータスチェック
- 定期的な監視（1時間おき、カスタマイズ可能）
- レスポンス時間の測定
- アップタイム/ダウンタイムの統計
- 障害時の通知機能

### 2. リンク切れ検出
- サイト内のリンクをクロールして404エラーを検出
- 外部リンクの有効性チェック
- 壊れたリンクのレポート生成
- 定期スキャンのスケジューリング

### 3. マルチデバイス対応
- Firebase Authenticationによるユーザー認証
- Cloud Firestoreでのデータ同期
- iOS、Android、Web対応
- リアルタイムデータ同期

### 4. 通知機能
- プッシュ通知（Firebase Cloud Messaging）
- メール通知
- Slack/Discord連携（将来的に）

## 技術スタック

### フロントエンド
- **Flutter**: クロスプラットフォーム開発
- **Dart**: プログラミング言語

### バックエンド・インフラ
- **Firebase Authentication**: ユーザー認証
- **Cloud Firestore**: データベース
- **Firebase Cloud Functions**: サーバーサイド処理
- **Firebase Cloud Messaging**: プッシュ通知
- **Firebase Hosting**: Webアプリホスティング

### 監視・スケジューリング
- **Cloud Scheduler**: 定期実行
- **HTTP Client**: ウェブサイトアクセス
- **HTML Parser**: リンク抽出

## アーキテクチャ

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │   Firebase      │    │  Cloud Functions│
│  (iOS/Android)  │◄──►│  Authentication │◄──►│  (Monitoring)   │
│                 │    │  Firestore      │    │                 │
└─────────────────┘    │  FCM            │    └─────────────────┘
                       └─────────────────┘            │
┌─────────────────┐             │                     │
│   Web App       │◄────────────┘                     ▼
│   (Flutter Web) │                          ┌─────────────────┐
└─────────────────┘                          │  Target Websites│
                                             │  (Monitoring)   │
                                             └─────────────────┘
```

## データ構造

### Users Collection
```
users/{userId}
├── email: string
├── displayName: string
├── createdAt: timestamp
└── settings: object
```

### Sites Collection
```
sites/{siteId}
├── userId: string
├── url: string
├── name: string
├── monitoringEnabled: boolean
├── checkInterval: number (minutes)
├── createdAt: timestamp
└── lastChecked: timestamp
```

### MonitoringResults Collection
```
monitoringResults/{resultId}
├── siteId: string
├── timestamp: timestamp
├── status: number (HTTP status)
├── responseTime: number (ms)
├── isUp: boolean
└── error: string (optional)
```

### LinkChecks Collection
```
linkChecks/{checkId}
├── siteId: string
├── url: string
├── status: number
├── isBroken: boolean
├── checkedAt: timestamp
└── parentPage: string
```

## 開発フェーズ

### Phase 1: 基本設計・Firebase設定
- [x] プロジェクト初期化
- [x] Git リポジトリ設定
- [x] ライセンス設定
- [ ] Firebase プロジェクト作成
- [ ] Flutter Firebase 設定
- [ ] 基本的なUI/UX設計

### Phase 2: 認証システム
- [ ] Firebase Authentication 実装
- [ ] ログイン/ログアウト機能
- [ ] ユーザープロファイル管理
- [ ] 認証状態管理

### Phase 3: サイト管理機能
- [ ] サイト登録・編集・削除
- [ ] サイト一覧表示
- [ ] 監視設定（間隔、通知設定など）

### Phase 4: 死活監視機能
- [ ] HTTP ステータスチェック機能
- [ ] Cloud Functions での定期実行
- [ ] 監視結果の保存・表示
- [ ] 統計・グラフ機能

### Phase 5: リンク切れ検出
- [ ] HTML パーシング機能
- [ ] リンク抽出・検証
- [ ] 壊れたリンクのレポート
- [ ] 定期スキャン機能

### Phase 6: 通知機能
- [ ] プッシュ通知実装
- [ ] メール通知機能
- [ ] 通知設定管理

### Phase 7: 最適化・拡張
- [ ] パフォーマンス最適化
- [ ] エラーハンドリング強化
- [ ] 外部サービス連携
- [ ] ダークモード対応

## 次のステップ

1. **Firebase プロジェクト作成**: Google Cloud Console でプロジェクト設定
2. **Flutter Firebase 設定**: 必要なパッケージの追加とConfig設定
3. **基本的なUI構造**: ナビゲーション、認証画面、メイン画面の骨組み作成
4. **認証システム実装**: ログイン・登録・ログアウト機能

## 想定される課題と対策

### 技術的課題
- **Rate Limiting**: 監視対象サイトへの過度なアクセス防止
- **スケーラビリティ**: 大量のサイト監視に対応
- **リアルタイム性**: 即座な障害通知

### ビジネス課題
- **コスト管理**: Firebase 使用量の最適化
- **ユーザビリティ**: 直感的で使いやすいUI/UX

### 対策
- Cloud Functions のリソース制限設定
- 効率的なデータベース設計
- ユーザーテストによるUI改善