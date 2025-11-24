# Xcode Cloud セットアップガイド

## 概要

Xcode Cloud を使用して、SiteCat の iOS ビルドを自動化し、TestFlight に配信します。

## 前提条件

- Apple Developer Program への登録
- App Store Connect へのアプリ登録
- GitHub リポジトリへのアクセス権限

## セットアップ手順

### 1. Xcode Cloud 環境変数の設定

App Store Connect で環境変数を設定します：

1. [App Store Connect](https://appstoreconnect.apple.com/) にログイン
2. **Apps** → **SiteCat** を選択
3. **Xcode Cloud** タブをクリック
4. **Settings** → **Environment Variables** を選択
5. 以下の環境変数を追加：

#### 必須の環境変数

| 変数名 | 値 | 説明 |
|--------|-----|------|
| `IOS_GOOGLE_SERVICE_INFO_PLIST` | Base64エンコードされた内容 | Firebase iOS設定ファイル |

#### IOS_GOOGLE_SERVICE_INFO_PLIST の作成方法

```bash
# GoogleService-Info.plist を Base64 エンコード
base64 -i ios/Runner/GoogleService-Info.plist | pbcopy
```

クリップボードにコピーされた内容を、Xcode Cloud の環境変数に貼り付けます。

**重要**: 
- 環境変数は **Secret** にチェックを入れる
- すべてのワークフローで使用できるように設定

### 2. Xcode でワークフロー作成

1. Xcode で `ios/Runner.xcworkspace` を開く
2. メニューバー → **Product** → **Xcode Cloud** → **Create Workflow**
3. **Get Started** をクリック

#### ワークフロー設定

**General:**
- Name: `Release to TestFlight`
- Restrict Editing: オフ

**Environment:**
- Xcode Version: Latest Release（または特定のバージョン）
- macOS Version: Latest Release
- Clean: チェック（クリーンビルド推奨）

**Start Conditions（トリガー設定）:**
- Branch Changes:
  - Branch: `main`
  - File and Folder Conditions: すべて
  - Auto-cancel builds: オン（推奨）

**Actions:**
1. **Archive**
   - Platform: iOS
   - Scheme: Runner
   - Archive Method: iOS App Store

**Post-Actions:**
1. **TestFlight Internal Testing**
   - Group: App Store Connect Users（内部テスター）
   - Automatically publish: オン

### 3. ワークフロー設定ファイルの確認

Xcode Cloud は自動的に設定ファイルを作成します：

```
.swiftpm/xcode/xcschemes/Runner.xcscheme
```

このファイルは自動生成されるので、手動編集は不要です。

### 4. ci_scripts の動作確認

リポジトリに `ci_scripts/ci_post_clone.sh` が含まれていることを確認：

```bash
ls -la ci_scripts/
# 出力: ci_post_clone.sh（実行権限付き）
```

このスクリプトは Xcode Cloud が自動的に検出して実行します。

### 5. 初回ビルドの実行

#### 方法1: Xcode から手動実行

1. Xcode → **Product** → **Xcode Cloud** → **Start Build**
2. Workflow を選択 → **Start Build**

#### 方法2: GitHub へのプッシュで自動実行

```bash
git add ci_scripts/
git commit -m "feat: Xcode Cloud 設定を追加"
git push origin main
```

main ブランチへのプッシュで自動的にビルドが開始されます。

### 6. ビルド状況の確認

1. App Store Connect → **Apps** → **SiteCat** → **Xcode Cloud** タブ
2. 実行中のビルドをクリックして詳細を確認
3. ログで各ステップの進行状況を確認可能

### 7. TestFlight での確認

ビルドが成功すると：

1. 10-30分後に TestFlight に表示
2. App Store Connect → **TestFlight** タブで確認
3. 内部テスターに自動配信（設定した場合）

## トラブルシューティング

### Firebase設定ファイルエラー

```
error: GoogleService-Info.plist not found
```

**解決方法**:
- `IOS_GOOGLE_SERVICE_INFO_PLIST` 環境変数が正しく設定されているか確認
- Base64 エンコードが正しいか確認
- 環境変数が Secret になっているか確認

### Flutter SDKインストールエラー

```
error: Flutter command not found
```

**解決方法**:
- `ci_post_clone.sh` が実行権限を持っているか確認: `chmod +x ci_scripts/ci_post_clone.sh`
- スクリプトが `ci_scripts/` ディレクトリに配置されているか確認

### CocoaPods エラー

```
error: pod install failed
```

**解決方法**:
- `Podfile.lock` をコミットしている場合は削除してみる
- `ios/Podfile` の設定を確認

### ビルド時間が長い

**対策**:
- `flutter precache --ios` でエンジンを事前キャッシュ（スクリプトに含まれています）
- Clean Build を無効化（不要なクリーンビルドを避ける）
- 頻繁なビルドを避ける（main への直接プッシュを制限）

## コスト管理

### Xcode Cloud の無料枠

- **個人開発者**: 月25時間まで無料
- **小規模チーム**: 追加購入可能

### ビルド時間の目安

- SiteCat の場合: 約15-20分/ビルド
- 月間無料枠で約75-100ビルド可能

### コスト削減のベストプラクティス

1. **自動ビルドの制限**
   - main ブランチへの直接プッシュを制限
   - PR マージ時のみビルド実行

2. **手動ビルドの活用**
   - 開発中は Xcode から手動ビルド
   - リリース時のみ自動ビルド

3. **GitHub Actions との併用**
   - 軽量なテスト（analyze/test）は GitHub Actions
   - Archive/配信のみ Xcode Cloud

## GitHub Actions との連携

現在の構成：

```
1. Pull Request → GitHub Actions（analyze/test）
2. PR マージ → main ブランチ更新
3. main更新 → Xcode Cloud（Archive → TestFlight）
```

この構成により：
- ✅ コード品質は GitHub Actions で保証
- ✅ 配信は Xcode Cloud で自動化
- ✅ コード署名の手動管理不要

## セキュリティのベストプラクティス

1. **環境変数の管理**
   - すべての機密情報を Secret として設定
   - `GoogleService-Info.plist` は Base64 エンコード

2. **アクセス制限**
   - Xcode Cloud へのアクセスを必要最小限に
   - ワークフロー編集権限を制限

3. **監査ログ**
   - Xcode Cloud のビルドログを定期確認
   - 異常なビルドがないか監視

## 参考リンク

- [Xcode Cloud 公式ドキュメント](https://developer.apple.com/documentation/xcode/xcode-cloud)
- [Custom Build Scripts](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
- [Flutter on Xcode Cloud](https://docs.flutter.dev/deployment/cd#xcode-cloud)
- [環境変数の設定](https://developer.apple.com/documentation/xcode/environment-variable-reference)

## 次のステップ

1. ✅ `ci_scripts/ci_post_clone.sh` をコミット
2. ✅ Xcode Cloud 環境変数を設定
3. ✅ ワークフローを作成
4. ⏳ 初回ビルドを実行
5. ⏳ TestFlight で確認
