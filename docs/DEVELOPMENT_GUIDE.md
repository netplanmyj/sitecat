# 開発ガイド - SiteCat

> **対象読者**: 開発者  
> **目的**: SiteCatの技術詳細、開発環境構築、アーキテクチャ、実装ガイド  
> **ドキュメントバージョン**: v2.1  
> **最終更新**: 2025年12月  
> **現在のアプリバージョン**: v1.0.3+ - App Store配信中

---

## 開発環境セットアップ

### 前提条件
- **Flutter SDK**: 3.27以上
- **Dart SDK**: 3.10以上
- **Xcode**: 15以上（iOS開発用、現在iOS専用アプリ）
- **Firebase CLI**: 最新版
- **Git**: バージョン管理
- **CocoaPods**: iOS依存関係管理

### 初期セットアップ手順

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

## 開発ワークフロー

### 1. Gitフロー
- **main**: 本番用ブランチ
- **develop**: 開発用ブランチ
- **feature/***: 機能開発ブランチ
- **hotfix/***: 緊急修正ブランチ

### 1.1 PR作成前チェックリスト

**PR作成前に必ず以下を実行してください。これにより CIエラーを事前に防ぐことができます。**

```bash
# 1. 静的解析（コード品質チェック）
flutter analyze

# 2. フォーマット（コードスタイル統一）
dart format --set-exit-if-changed .

# 3. テスト実行（機能動作確認）
flutter test

# 4. すべてOKなら、修正をコミット・プッシュ
git add -A
git commit -m "fix: Changes based on analyze and format results"
git push origin <branch-name>
```

**各チェックの詳細:**
- `flutter analyze`: Lintエラー、型チェック、その他の潜在的な問題を検出
- `dart format --set-exit-if-changed .`: コード自動フォーマット。変更がある場合は終了コード1を返す
- `flutter test`: 全ユニット・ウィジェットテストを実行

**一括実行:**
```bash
flutter analyze && dart format --set-exit-if-changed . && flutter test
```

⚠️ **注意**:  
これらをスキップして PR を作成すると、CI/CD パイプラインで失敗し、マージが遅延します。

### 1.2 GitHub CLI 便利コマンド

**PR関連:**
```bash
# PR作成
gh pr create --title "タイトル" --body "説明"

# PR一覧表示
gh pr list

# PR詳細表示
gh pr view <PR番号>

# PRマージ
gh pr merge <PR番号> --squash
```

**Issue関連:**
```bash
# Issue作成
gh issue create --title "タイトル" --body "説明" --label bug

# Issue一覧表示
gh issue list

# Issue詳細表示
gh issue view <Issue番号>

# Issueクローズ
gh issue close <Issue番号>
```

**Copilot reviewコメント確認（PR単位）:**
```bash
# 全コメント（会話）を見る
gh pr view 316 --comments

# レビューコメント（差分行単位）
gh api repos/netplanmyj/sitecat/pulls/316/comments --paginate | jq '.[] | {user: .user.login, path, line, body}'

# 会話コメントのみ
gh api repos/netplanmyj/sitecat/issues/316/comments --paginate | jq '.[] | {user: .user.login, body}'
```

注記:
- Copilotのコメントは user.login が github-advanced-security[bot] や github-copilot 系になることがあります。
- 出力を貼っていただければ要点整理します。

### 1.3 Site Scan カウントダウン仕様

- 対象: Site Detail > Site Scan タブの Start / Stop / Continue
- トリガー: Start/Continue 押下時、Stop 押下時、バッチ完了時（例: 100ページ終了）
- 挙動: 30秒間 Start/Continue を無効化（Stop は常に有効、緊急停止用）
- UI: 残り時間を CountdownTimer で表示（Start/Continue 共通で表示）
- 設定: 30秒に固定。将来は設定画面で変更可能にする（別Issueで対応）

### 1.4 Firebase環境の切替（dev/prod）

**クライアントアプリ（Flutter）:**

- **自動選択ロジック**:
  - Debug/Profile build (`flutter run`, `flutter run --profile`) → `sitecat-dev`
  - Release build (`flutter run --release`) → `sitecat-prod`
  - 選択は `lib/firebase_options.dart` の `kReleaseMode` で判定

- **開発（dev）でテスト**:
  ```bash
  flutter run
  # または
  flutter run --debug
  ```

- **プロファイル（dev）で計測**:
  ```bash
  flutter run --profile
  ```

- **本番（prod）でテスト**:
  ```bash
  flutter run --release
  ```

- **接続先確認方法**:
  起動時のログで確認してください：
  ```
  🟢 Firebase: Using DEVELOPMENT (sitecat-dev)  # Debug/Profile
  🔴 Firebase: Using PRODUCTION (sitecat-prod)  # Release
  🔥 Firebase init → project: sitecat-dev       # 実際の接続先
  ```

**備考**:
- iOSの`Info.plist`にはdev/prod両方のURLスキームを登録済み
- Firebase初期化は`lib/firebase_options.dart`の`DefaultFirebaseOptions.currentPlatform`を使用
- 環境選択は`kReleaseMode`（Flutter SDK組み込み定数）で自動判定
- `--dart-define=FIREBASE_ENV=dev/prod`は不要（自動選択を信頼）

**トラブルシューティング**:
- `flutter run` で prod に繋がる場合:
  1. `flutter clean` → `flutter pub get` 実行
  2. Xcode の Build Settings で Build Configuration が Debug になっているか確認
  3. 起動ログで "🟢 Firebase: Using DEVELOPMENT" が表示されるか確認

<!-- ...existing code... -->