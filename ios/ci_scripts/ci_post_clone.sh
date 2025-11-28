#!/bin/sh

# Xcode Cloud Post-Clone Script for SiteCat
# このスクリプトはXcode Cloudがリポジトリをクローンした後に自動実行されます

set -e

echo "========================================="
echo "SiteCat - Xcode Cloud Post-Clone Script"
echo "========================================="

# 1. 環境変数確認とパス設定
echo "\n[1/7] 環境変数確認とパス設定"
echo "CI_WORKSPACE: '$CI_WORKSPACE'"
echo "CI_PRIMARY_REPOSITORY_PATH: '$CI_PRIMARY_REPOSITORY_PATH'"
echo "PWD: '$PWD'"

# CI_WORKSPACEが設定されていない場合のフォールバック
if [ -z "$CI_WORKSPACE" ]; then
    echo "警告: CI_WORKSPACE が設定されていません。推測値を使用します"
    export CI_WORKSPACE="$HOME"
fi

# リポジトリルートパスの設定（このスクリプトは ios/ci_scripts/ にあります）
if [ -z "$CI_PRIMARY_REPOSITORY_PATH" ]; then
    echo "警告: CI_PRIMARY_REPOSITORY_PATH が設定されていません。推測値を使用します"
    # このスクリプトの場所から2階層上がリポジトリルート
    export CI_PRIMARY_REPOSITORY_PATH="$(cd "$(dirname "$0")/../.." && pwd)"
fi

echo "リポジトリルート: '$CI_PRIMARY_REPOSITORY_PATH'"

# 2. Flutter SDKインストール
echo "\n[2/7] Flutter SDKインストール"
cd $CI_WORKSPACE
git clone https://github.com/flutter/flutter.git -b stable --depth 1
echo "Flutter SDKインストール完了"

# 3. FlutterとDartのPATH設定
export PATH="$CI_WORKSPACE/flutter/bin:$PATH"
export PATH="$CI_WORKSPACE/flutter/bin/cache/dart-sdk/bin:$PATH"

# Flutter バージョン確認
echo "\nFlutter バージョン:"
$CI_WORKSPACE/flutter/bin/flutter --version

# 4. Firebase設定ファイル確認
echo "\n[3/7] Firebase設定ファイル確認"
cd $CI_PRIMARY_REPOSITORY_PATH

# iOS用 GoogleService-Info.plist（リポジトリに含まれているものを使用）
if [ ! -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo "エラー: ios/Runner/GoogleService-Info.plist が見つかりません"
    exit 1
fi
echo "GoogleService-Info.plist の存在を確認しました"

# firebase_options.dartは不要（以前はexampleからコピーして使用していましたが、現在はネイティブ設定ファイルのみを使用）
# 今後はfirebase_options.dartの管理は不要です

# 5. Flutter依存関係インストール
echo "\n[4/7] Flutter依存関係インストール"
$CI_WORKSPACE/flutter/bin/flutter pub get

# 6. iOSエンジンプリキャッシュ
echo "\n[5/7] iOSエンジンプリキャッシュ"
$CI_WORKSPACE/flutter/bin/flutter precache --ios

# 7. CocoaPods依存関係インストール
echo "\n[6/7] CocoaPods依存関係インストール"
cd ios
pod install
cd ..

# 8. Flutter 依存関係のプリキャッシュ（重複だが念のため）
echo "\n[7/7] 最終確認"
echo "Flutter SDK: $CI_WORKSPACE/flutter/bin/flutter"

echo "\n========================================="
echo "ビルド前準備完了！"
echo "次はXcode Cloudが自動的にArchiveを実行します"
echo "========================================="
