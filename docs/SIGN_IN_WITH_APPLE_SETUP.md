atasino# Sign in with Apple セットアップガイド

このドキュメントでは、SiteCat アプリに Sign in with Apple を統合するために必要な手順を説明します。

## 1. Xcode での Capability 追加

### 手順

1. **Xcode でプロジェクトを開く**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Runner プロジェクトを選択**
   - 左側のプロジェクトナビゲーターで「Runner」を選択
   - 「TARGETS」セクションで「Runner」を選択

3. **Signing & Capabilities タブを開く**
   - 上部のタブから「Signing & Capabilities」を選択

4. **Sign in with Apple Capability を追加**
   - 「+ Capability」ボタンをクリック
   - 検索欄に "Sign in with Apple" と入力
   - 「Sign in with Apple」をダブルクリックして追加

5. **Bundle Identifier を確認**
   - 「General」タブで Bundle Identifier が `jp.netplan.sitecat` であることを確認

### 確認方法

- 「Signing & Capabilities」タブに "Sign in with Apple" セクションが表示されていれば成功です
- Runner.entitlements ファイルが自動的に作成され、以下の内容が含まれます:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.applesignin</key>
	<array>
		<string>Default</string>
	</array>
</dict>
</plist>
```

---

## 2. Apple Developer での設定

### 前提条件
- Apple Developer Program のアカウント（有料）
- App ID が作成済み（`jp.netplan.sitecat`）

### 手順

1. **Apple Developer サイトにログイン**
   - https://developer.apple.com/account にアクセス

2. **Certificates, Identifiers & Profiles を開く**
   - 左メニューから「Certificates, Identifiers & Profiles」を選択

3. **App ID を選択**
   - 「Identifiers」を選択
   - `jp.netplan.sitecat` を検索して選択

4. **Sign in with Apple を有効化**
   - 「Capabilities」セクションで「Sign in with Apple」にチェック
   - 「Edit」ボタンをクリック（必要に応じて）
   - 「Enable as a primary App ID」を選択（通常はこれがデフォルト）
   - 「Save」をクリック

5. **Service ID の作成（オプション：Web対応する場合）**
   - 「Identifiers」で「+」ボタンをクリック
   - 「Services IDs」を選択して「Continue」
   - Description: "SiteCat Apple Sign-In"
   - Identifier: `jp.netplan.sitecat.signin`（例）
   - 「Sign in with Apple」にチェック
   - 「Configure」をクリック
   - Primary App ID: `jp.netplan.sitecat` を選択
   - Domains and Subdomains: Firebase のドメインを入力（後述）
   - Return URLs: Firebase の Redirect URI を入力（後述）

---

## 3. Firebase Console での設定

### 手順

1. **Firebase Console にアクセス**
   - https://console.firebase.google.com/
   - SiteCat プロジェクトを選択

2. **Authentication を開く**
   - 左メニューから「Authentication」を選択
   - 「Sign-in method」タブを選択

3. **Apple プロバイダーを有効化**
   - プロバイダー一覧から「Apple」を見つけてクリック
   - 「Enable」トグルをオンにする

4. **Service ID と Key の設定（Web対応する場合）**
   
   **Key の作成:**
   - Apple Developer Console に戻る
   - 「Keys」セクションで「+」ボタンをクリック
   - Key Name: "SiteCat Sign in with Apple Key"
   - 「Sign in with Apple」にチェック
   - 「Configure」をクリック
   - Primary App ID: `jp.netplan.sitecat` を選択
   - 「Save」→「Continue」→「Register」
   - **Key をダウンロード**（一度しかダウンロードできないので注意）
   - Key ID をメモ

   **Firebase Console に入力:**
   - Service ID: `jp.netplan.sitecat.signin`
   - Apple Team ID: Apple Developer の右上に表示される（例: ABC123DEF4）
   - Key ID: 上でメモした ID
   - Private Key: ダウンロードした `.p8` ファイルの内容をコピー＆ペースト

5. **OAuth Redirect URI を確認**
   - Firebase Console の Apple プロバイダー設定画面に表示される
   - 例: `https://sitecat-xxxxx.firebaseapp.com/__/auth/handler`
   - この URL を Apple Developer の Service ID の Return URLs に追加

6. **保存**
   - Firebase Console で「Save」をクリック

### iOS アプリのみの場合

iOS アプリのみで Apple Sign-In を使用する場合（Web 対応しない場合）:
- Service ID、Key、Team ID は **不要**
- Firebase Console で Apple プロバイダーを「Enable」にするだけで OK
- Xcode の Capability 追加が必須

---

## 4. コード実装（完了済み）

以下の実装は完了しています:

✅ `pubspec.yaml` に `sign_in_with_apple: ^6.1.3` を追加  
✅ `AuthService` に `signInWithApple()` メソッドを実装  
✅ `AuthProvider` に `signInWithApple()` メソッドを追加  
✅ `LoginScreen` に Apple Sign-In ボタンを追加  
✅ iOS/macOS でのみボタンを表示するよう条件分岐

---

## 5. テストの実施

### 前提条件
- **実機が必須**: Sign in with Apple はシミュレータでは動作しません
- iOS 13.0 以上の iPhone または iPad
- Apple ID でサインイン済みのデバイス

### テスト手順

1. **ビルドして実機にインストール**
   ```bash
   flutter run --release
   ```
   または Xcode から「Product」→「Run」

2. **ログイン画面を確認**
   - 「Sign in with Google」ボタンの下に「Sign in with Apple」ボタンが表示される
   - iOS でない場合は表示されない（正常）

3. **Apple Sign-In をテスト**
   - 「Sign in with Apple」ボタンをタップ
   - Face ID / Touch ID で認証
   - 初回のみ: 名前とメールの共有を確認（「メールを共有」or「メールを非公開」）
   - アプリにログインできることを確認

4. **ログアウトしてもう一度サインイン**
   - 2回目以降は Face ID / Touch ID のみで即座にサインイン
   - Firebase Console の「Authentication」→「Users」にユーザーが追加されていることを確認

### トラブルシューティング

**エラー: "Sign in with Apple is not available"**
- Xcode で Capability が追加されているか確認
- Bundle Identifier が正しいか確認
- 実機でテストしているか確認

**エラー: "invalid_client" または "invalid_grant"**
- Firebase Console で Apple プロバイダーが有効になっているか確認
- Apple Developer で App ID の Sign in with Apple が有効か確認

**ボタンが表示されない**
- iOS 13.0 以上か確認
- `Platform.isIOS` が true になっているか確認

---

## 6. App Store 審査への対応

### Guideline 4.8 への準拠

Apple のガイドライン 4.8 では、サードパーティの認証（Google Sign-In など）を使用するアプリは、必ず Sign in with Apple も提供する必要があります。

**現在の実装**:
- ✅ Google Sign-In と Apple Sign-In の両方を提供
- ✅ iOS でのみ Apple Sign-In ボタンを表示
- ✅ ユーザーはどちらの方法でもログイン可能

**App Store Connect の審査ノート**:
```
Version 1.0.1 includes Sign in with Apple as required by Guideline 4.8.
Users can sign in using either Google or Apple authentication.
Apple Sign-In is available on iOS 13.0+ devices.
```

---

## 7. 次のステップ

1. ✅ Xcode で Sign in with Apple Capability を追加
2. ✅ Apple Developer で App ID の設定を確認
3. ✅ Firebase Console で Apple プロバイダーを有効化
4. ✅ 実機でテスト
5. ⏳ バージョン 1.0.1 としてビルド
6. ⏳ TestFlight でテスト
7. ⏳ App Store に再提出

---

## 参考リンク

- [Sign in with Apple - Apple Developer](https://developer.apple.com/sign-in-with-apple/)
- [sign_in_with_apple パッケージ](https://pub.dev/packages/sign_in_with_apple)
- [Firebase Apple Authentication](https://firebase.google.com/docs/auth/ios/apple)
- [App Store Review Guidelines 4.8](https://developer.apple.com/app-store/review/guidelines/#sign-in-with-apple)
