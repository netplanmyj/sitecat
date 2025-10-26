/// アプリケーション全体で使用する定数定義
class AppConstants {
  // プライベートコンストラクタでインスタンス化を防ぐ
  AppConstants._();

  /// サイト登録制限
  static const int freePlanSiteLimit = 1;

  /// プランに関する説明メッセージ
  static const String siteLimitMessage =
      '無料版では$freePlanSiteLimit個までサイトを登録できます。';
  static const String siteLimitReachedMessage =
      'サイト登録数が上限に達しています。追加するには既存のサイトを削除してください。';

  /// 監視間隔の制限（分）
  static const int minCheckInterval = 5;
  static const int maxCheckInterval = 1440; // 24時間
  static const int defaultCheckInterval = 60; // 1時間
}
