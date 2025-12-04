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
  @Deprecated('Use premiumPlanPageLimit instead')
  static const int standardPlanPageLimit = 500;
  static const int proPlanPageLimit = 5000; // Future use

  /// 履歴保持件数制限
  static const int freePlanHistoryLimit = 10;
  static const int premiumHistoryLimit = 50;

  /// プランに関する説明メッセージ
  static const String siteLimitMessage =
      '無料版では$freePlanSiteLimit個までサイトを登録できます。';
  static const String siteLimitReachedMessage =
      'サイト登録数が上限に達しています。追加するには既存のサイトを削除してください。';
  static const String premiumSiteLimitReachedMessage =
      'サイト登録数が上限（$premiumSiteLimit個）に達しています。';
  static const String pageLimitMessage =
      '無料版では$freePlanPageLimitページまでクロール可能です。';

  /// 監視間隔の制限（分）
  static const int minCheckInterval = 5;
  static const int maxCheckInterval = 1440; // 24時間
  static const int defaultCheckInterval = 60; // 1時間
}
