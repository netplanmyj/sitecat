# GitHub Branch Protection Configuration

この設定により、main ブランチを保護し、PR 時に CI チェックを必須にします。

## リポジトリの設定手順

GitHub のリポジトリ設定で以下を実行してください：

### 1. ブランチ保護ルールの設定

1. GitHub リポジトリの **Settings** タブを開く
2. 左メニューから **Branches** を選択
3. **Add rule** をクリック
4. 以下の設定を行う：

#### 基本設定
- **Branch name pattern**: `main`
- **Restrict pushes that create matching branches**: チェック

#### プロテクションルール
- ✅ **Require a pull request before merging**
  - ✅ **Require approvals**: 1 (レビュー必須にする場合)
  - ✅ **Dismiss stale PR approvals when new commits are pushed**
  - ✅ **Require review from code owners** (CODEOWNERS ファイルがある場合)

- ✅ **Require status checks to pass before merging**
  - ✅ **Require branches to be up to date before merging**
  - **Status checks**: 以下をすべて選択
    - `Analyze and Test`
    - `Build Android`
    - `Build iOS`
    - `Build Web`

- ✅ **Require conversation resolution before merging**
- ✅ **Require signed commits** (推奨)
- ✅ **Require linear history** (推奨)
- ✅ **Include administrators** (管理者も同じルールに従う)
- ✅ **Restrict pushes that create matching branches**

### 2. 必要に応じて CODEOWNERS ファイルを作成

コードレビューの責任者を指定したい場合は、リポジトリルートに `.github/CODEOWNERS` ファイルを作成してください。

### 3. Codecov の設定（オプション）

コードカバレッジレポートを有効にしたい場合：

1. [Codecov](https://codecov.io/) でアカウント作成
2. リポジトリを連携
3. GitHub Secrets に `CODECOV_TOKEN` を追加

## CI ワークフローの機能

### 実行タイミング
- main ブランチへの PR 作成・更新時
- main ブランチへの直接プッシュ時

### チェック項目
1. **Analyze and Test**
   - Dart/Flutter の静的解析
   - コードフォーマットチェック
   - ユニットテスト実行
   - カバレッジレポート生成

2. **Build Android**
   - Android APK ビルド
   - Android App Bundle ビルド

3. **Build iOS**
   - iOS アプリビルド（コード署名なし）

4. **Build Web**
   - Web アプリビルド

### アーティファクト
- ビルド成果物は自動的にアップロードされ、Actions ページからダウンロード可能

## トラブルシューティング

### CI が失敗する場合
1. ローカルで `flutter analyze` を実行して静的解析エラーを確認
2. `dart format .` を実行してコードフォーマットを修正
3. `flutter test` を実行してテストが通ることを確認

### ブランチ保護が効かない場合
- 管理者権限で設定が正しく適用されているか確認
- Status checks の名前が CI ワークフローのジョブ名と一致しているか確認