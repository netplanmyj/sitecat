#!/bin/sh

# Xcode Cloud Post-Clone Script for SiteCat
# このスクリプトはXcode Cloudがリポジトリをクローンした後に自動実行されます

set -e

echo "========================================="
echo "SiteCat - Xcode Cloud Post-Clone Script"
echo "========================================="

# 1. 環境変数確認
echo "\n[1/7] 環境変数確認"
echo "CI_WORKSPACE: $CI_WORKSPACE"
echo "CI_PRIMARY_REPOSITORY_PATH: $CI_PRIMARY_REPOSITORY_PATH"

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

# 4. Firebase設定ファイル注入
echo "\n[3/7] Firebase設定ファイル注入"
cd $CI_PRIMARY_REPOSITORY_PATH

# iOS用 GoogleService-Info.plist
if [ -z "$IOS_GOOGLE_SERVICE_INFO_PLIST" ]; then
    echo "エラー: IOS_GOOGLE_SERVICE_INFO_PLIST 環境変数が設定されていません"
    exit 1
fi
echo "$IOS_GOOGLE_SERVICE_INFO_PLIST" | base64 --decode > ios/Runner/GoogleService-Info.plist
echo "GoogleService-Info.plist 作成完了"

# firebase_options.dart（例から作成）
if [ ! -f "lib/firebase_options.dart" ]; then
    echo "firebase_options.dart をサンプルからコピー"
    cp lib/firebase_options.dart.example lib/firebase_options.dart
fi

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
