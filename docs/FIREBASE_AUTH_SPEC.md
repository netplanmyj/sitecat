# Firebase認証 - 実装概要

> **Status**: ✅ 実装完了  
> **最終更新**: 2025年11月

---

## 概要

SiteCatはFirebase Authenticationを使用したGoogle Sign-In認証を実装しています。

## 認証システム構成

### 使用している認証方法
- **Google Sign-In**: 主要な認証プロバイダー
- **Firebase Authentication**: バックエンド認証システム

### 環境構成
```
開発環境: sitecat-dev
本番環境: sitecat-prod (予定)
```

## 主要ファイル

### サービス層
- `lib/services/auth_service.dart`
  - Firebase認証の実装
  - Google Sign-In処理
  - ユーザードキュメント作成

### 状態管理
- `lib/providers/auth_provider.dart`
  - 認証状態の管理
  - UI層への状態通知

### UI
- `lib/screens/auth/`
  - ログイン画面
  - 認証フロー

## Firestore セキュリティルール

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ユーザーは自分のデータのみ読み書き可能
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // サイトは所有者のみ読み書き可能
    match /sites/{siteId} {
      allow read, write: if request.auth != null 
        && resource.data.userId == request.auth.uid;
    }
    
    // 監視結果は所有者のみ読み取り可能
    match /monitoring_results/{resultId} {
      allow read: if request.auth != null 
        && get(/databases/$(database)/documents/sites/$(resource.data.siteId)).data.userId == request.auth.uid;
    }
    
    // リンクチェック結果は所有者のみ読み取り可能
    match /link_check_results/{checkId} {
      allow read: if request.auth != null 
        && get(/databases/$(database)/documents/sites/$(resource.data.siteId)).data.userId == request.auth.uid;
    }
  }
}
```

## ユーザーデータ構造

### Users Collection
```typescript
users/{userId}
├── uid: string
├── email: string
├── displayName: string
├── photoURL: string
├── createdAt: Timestamp
└── lastLoginAt: Timestamp
```

## 認証フロー

1. ユーザーが「Sign in with Google」をタップ
2. Google Sign-In画面が表示
3. ユーザーがGoogleアカウントを選択
4. Firebase Authenticationで認証
5. 初回ログイン時は`users`コレクションにドキュメント作成
6. 認証状態をProviderで管理
7. ホーム画面へ遷移

## プラットフォーム別設定

### Android
- `android/app/build.gradle`: Firebase SDK設定
- Google Play Services認証ライブラリ

### iOS
- `ios/Runner/Info.plist`: URL Scheme設定
- Google Sign-In SDKの統合

## 依存パッケージ

```yaml
firebase_core: ^2.24.2
firebase_auth: ^4.15.3
google_sign_in: ^6.1.6
cloud_firestore: ^4.13.6
```

> 詳細は `pubspec.yaml` を参照

## セキュリティ対策

- ✅ Firestoreセキュリティルールでユーザーデータ保護
- ✅ 認証トークンの適切な管理
- ✅ HTTPS通信の強制
- ✅ ユーザーは自分のデータのみアクセス可能

## 関連ドキュメント

- 実装詳細: `lib/services/auth_service.dart`
- アーキテクチャ: [DEVELOPMENT_GUIDE.md](./DEVELOPMENT_GUIDE.md)
- プロジェクト概要: [PROJECT_CONCEPT.md](./PROJECT_CONCEPT.md)
