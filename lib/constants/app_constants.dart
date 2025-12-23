import 'error_messages.dart';

/// アプリケーション全体で使用する定数定義
class AppConstants {
  // プライベートコンストラクタでインスタンス化を防ぐ
  AppConstants._();

  /// サイト登録制限
  static const int freePlanSiteLimit = 3;
  static const int premiumSiteLimit = 30; // Premium users: 30 sites max

  /// ページクローリング制限
  static const int freePlanPageLimit = 200;
  static const int premiumPlanPageLimit = 1000;
  @Deprecated('Use premiumPlanPageLimit instead. Will be removed in v2.0.0')
  static const int standardPlanPageLimit = 500;
  static const int proPlanPageLimit = 5000; // Future use

  /// 履歴保持件数制限
  static const int freePlanHistoryLimit = 10;
  static const int premiumHistoryLimit = 50;

  /// プラン関連のユーザー向けメッセージ
  /// 無料プランのサイト上限に関する案内文
  static const String siteLimitMessage = ErrorMessages.siteLimitMessage;

  /// サイト上限到達時のエラーメッセージ
  static const String siteLimitReachedMessage =
      ErrorMessages.siteLimitReachedMessage;
  static const String premiumSiteLimitReachedMessage =
      ErrorMessages.premiumSiteLimitReachedMessage;
  static const String pageLimitMessage = ErrorMessages.pageLimitMessage;

  /// 監視間隔の制限（分）
  static const int minCheckInterval = 5;
  static const int maxCheckInterval = 1440; // 24時間
  static const int defaultCheckInterval = 60; // 1時間
}
