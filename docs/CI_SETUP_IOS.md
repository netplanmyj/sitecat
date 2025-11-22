# iOS リリースビルド CI セットアップガイド

## 概要

GitHub Actions を使用して iOS アプリを自動的にビルドし、App Store Connect にアップロードするワークフローです。

## 前提条件

- Apple Developer Program への登録
- App Store Connect へのアプリ登録
- Xcode でのローカルビルド成功経験

## セットアップ手順

### 1. Apple Developer での準備

#### 1.1 App Store Connect API Key の作成

1. [App Store Connect](https://appstoreconnect.apple.com/) にログイン
2. **Users and Access** → **Keys** タブを選択
3. **Generate API Key** または **+** ボタンをクリック
4. 以下を設定:
   - Name: `GitHub Actions CI`
   - Access: `Developer` または `App Manager`
5. **Generate** をクリックして API Key を作成
6. 以下の情報を記録:
   - **Issuer ID** (ページ上部に表示)
   - **Key ID** (生成されたキーの ID)
   - **Download API Key** をクリックして `.p8` ファイルをダウンロード

⚠️ **重要**: `.p8` ファイルは一度しかダウンロードできません。安全に保管してください。

#### 1.2 Distribution Certificate のエクスポート

ローカルの Xcode から証明書をエクスポートします:

1. **Keychain Access** を開く
2. **Certificates** カテゴリーを選択
3. **Apple Distribution** 証明書を右クリック → **Export**
4. ファイル形式: `.p12`
5. パスワードを設定して保存
6. ファイルを Base64 エンコード:
   ```bash
   base64 -i /path/to/certificate.p12 | pbcopy
   ```

#### 1.3 Provisioning Profile のエクスポート

1. Xcode を開く → **Settings** → **Accounts**
2. Apple ID を選択 → **Download Manual Profiles** をクリック
3. Finder で `~/Library/MobileDevice/Provisioning Profiles/` を開く
4. App Store 用のプロファイル（`jp.co.netplan.sitecat` 用）を特定
5. Base64 エンコード:
   ```bash
   base64 -i ~/Library/MobileDevice/Provisioning\ Profiles/[UUID].mobileprovision | pbcopy
   ```

プロファイル UUID の確認方法:
```bash
security cms -D -i ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision | grep -A1 "Name"
```

#### 1.4 GoogleService-Info.plist のエクスポート

```bash
base64 -i ios/Runner/GoogleService-Info.plist | pbcopy
```

### 2. GitHub Secrets の設定

リポジトリの **Settings** → **Secrets and variables** → **Actions** で以下を追加:

| Secret 名 | 説明 | 取得方法 |
|-----------|------|----------|
| `BUILD_CERTIFICATE_BASE64` | Distribution Certificate (.p12) | 1.2 でエクスポートした証明書を Base64 エンコード |
| `P12_PASSWORD` | .p12 ファイルのパスワード | 1.2 で設定したパスワード |
| `KEYCHAIN_PASSWORD` | CI 用の一時的なパスワード | 任意の強固なパスワード（例: `openssl rand -base64 32`） |
| `PROVISIONING_PROFILE_BASE64` | Provisioning Profile | 1.3 でエクスポートしたプロファイルを Base64 エンコード |
| `APP_STORE_CONNECT_API_KEY_ID` | API Key ID | 1.1 で記録した Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID | 1.1 で記録した Issuer ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | API Key (.p8) | 1.1 でダウンロードした .p8 ファイルを Base64 エンコード:<br/>`base64 -i AuthKey_XXXXXXXXXX.p8 \| pbcopy` |
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | GoogleService-Info.plist | 1.4 でエクスポート |

### 3. ワークフローの実行

#### 手動実行（推奨）

1. GitHub リポジトリの **Actions** タブを開く
2. **Release iOS to App Store Connect** ワークフローを選択
3. **Run workflow** をクリック
4. オプション設定:
   - `upload_to_testflight`: チェックを入れると App Store Connect にアップロード
5. **Run workflow** を実行

#### 実行結果の確認

- ビルドが成功すると、IPA ファイルが Artifacts としてダウンロード可能
- App Store Connect にアップロードした場合、10-30分後に [App Store Connect](https://appstoreconnect.apple.com/) の TestFlight タブに表示される

## トラブルシューティング

### コード署名エラー

```
error: No signing certificate "iOS Distribution" found
```

**解決方法**:
- `BUILD_CERTIFICATE_BASE64` と `P12_PASSWORD` が正しく設定されているか確認
- 証明書の有効期限を確認（有効期限は1年間）
- Xcode で証明書を再作成してエクスポート

### Provisioning Profile エラー

```
error: Provisioning profile doesn't include signing certificate
```

**解決方法**:
- Provisioning Profile が Distribution Certificate と一致しているか確認
- [Apple Developer](https://developer.apple.com/account/resources/profiles/list) で新しいプロファイルを生成
- 新しいプロファイルを Base64 エンコードして `PROVISIONING_PROFILE_BASE64` を更新

### App Store Connect アップロードエラー

```
Error uploading to App Store Connect
```

**解決方法**:
- API Key の権限が `Developer` または `App Manager` であることを確認
- API Key が有効（期限切れでない）ことを確認
- App Store Connect でアプリが正しく登録されていることを確認
- Bundle ID が `jp.co.netplan.sitecat` と一致することを確認

### ビルド時間が長い

macOS ランナーは GitHub Actions の無料枠で 10倍の分数を消費します:
- 10分のビルド = 100分の消費
- 月間無料枠（Free プラン）: 0分
- 月間無料枠（Pro プラン）: 3000分 = 実質 300分の macOS ビルド

**推奨事項**:
- 頻繁なビルドを避ける
- リリース前の最終ビルドのみ CI を使用
- 開発中はローカルでビルド

## コスト削減のベストプラクティス

1. **workflow_dispatch のみで実行**: 自動トリガー（push, tag など）を避ける
2. **キャッシュの活用**: `~/.pub-cache` と Flutter SDK をキャッシュ（既に設定済み）
3. **必要な時だけアップロード**: `upload_to_testflight` オプションを使い分ける
4. **ローカルビルド優先**: リリース直前のみ CI を使用

## セキュリティのベストプラクティス

1. **Secrets の定期更新**:
   - API Key: 定期的にローテーション
   - 証明書: 有効期限前に更新（1年ごと）
   - P12 パスワード: 強固なパスワードを使用

2. **アクセス制限**:
   - API Key の権限を必要最小限に（`Developer` で十分）
   - GitHub リポジトリへのアクセスを制限

3. **監査ログの確認**:
   - App Store Connect の Activity ログを定期確認
   - GitHub Actions の実行ログを保存

## 参考リンク

- [Apple Developer - Creating API Keys](https://developer.apple.com/documentation/appstoreconnectapi/creating_api_keys_for_app_store_connect_api)
- [GitHub Actions - Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Flutter - Build and release an iOS app](https://docs.flutter.dev/deployment/ios)
- [Fastlane - App Store Connect API](https://docs.fastlane.tools/app-store-connect-api/)
