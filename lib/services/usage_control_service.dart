// Flutter アプリ側でのコスト制御実装例

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ユーザーのプラン情報
enum UserPlan { free, personal, business, enterprise }

/// プラン別の制限情報
class PlanLimits {
  final int dailyChecks;
  final int maxSites;
  final int historyDays;
  final bool autoMonitoring;
  final bool pushNotifications;
  final bool apiAccess;

  const PlanLimits({
    required this.dailyChecks,
    required this.maxSites,
    required this.historyDays,
    required this.autoMonitoring,
    required this.pushNotifications,
    required this.apiAccess,
  });

  static const Map<UserPlan, PlanLimits> limits = {
    UserPlan.free: PlanLimits(
      dailyChecks: 10,
      maxSites: 10,
      historyDays: 30,
      autoMonitoring: false,
      pushNotifications: false,
      apiAccess: false,
    ),
    UserPlan.personal: PlanLimits(
      dailyChecks: 1000,
      maxSites: 999,
      historyDays: 365,
      autoMonitoring: true,
      pushNotifications: true,
      apiAccess: true,
    ),
    UserPlan.business: PlanLimits(
      dailyChecks: 5000,
      maxSites: 999,
      historyDays: 365,
      autoMonitoring: true,
      pushNotifications: true,
      apiAccess: true,
    ),
  };

  static PlanLimits getLimits(UserPlan plan) {
    return limits[plan] ?? limits[UserPlan.free]!;
  }
}

/// 使用量制御サービス
class UsageControlService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 現在のユーザープラン取得
  Future<UserPlan> getCurrentPlan() async {
    final user = _auth.currentUser;
    if (user == null) return UserPlan.free;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return UserPlan.free;

      final planString = userDoc.data()?['plan'] as String?;
      return UserPlan.values.firstWhere(
        (plan) => plan.name == planString,
        orElse: () => UserPlan.free,
      );
    } catch (e) {
      print('Error getting user plan: $e');
      return UserPlan.free;
    }
  }

  /// 今日の使用量取得
  Future<int> getTodayUsage() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final usageDoc = await _firestore
          .collection('usage_stats')
          .doc('${user.uid}_$today')
          .get();

      return usageDoc.exists
          ? (usageDoc.data()?['checkCount'] as int? ?? 0)
          : 0;
    } catch (e) {
      print('Error getting today usage: $e');
      return 0;
    }
  }

  /// 登録サイト数取得
  Future<int> getSiteCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final sitesSnapshot = await _firestore
          .collection('sites')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      return sitesSnapshot.docs.length;
    } catch (e) {
      print('Error getting site count: $e');
      return 0;
    }
  }

  /// チェック実行可能かチェック
  Future<UsageCheckResult> canExecuteCheck() async {
    final plan = await getCurrentPlan();
    final limits = PlanLimits.getLimits(plan);
    final todayUsage = await getTodayUsage();

    if (todayUsage >= limits.dailyChecks) {
      return UsageCheckResult.limitExceeded(
        'Daily check limit (${limits.dailyChecks}) exceeded. '
        'Upgrade to Personal plan for unlimited checks.',
      );
    }

    return UsageCheckResult.allowed(limits.dailyChecks - todayUsage);
  }

  /// サイト追加可能かチェック
  Future<UsageCheckResult> canAddSite() async {
    final plan = await getCurrentPlan();
    final limits = PlanLimits.getLimits(plan);
    final currentSites = await getSiteCount();

    if (currentSites >= limits.maxSites) {
      return UsageCheckResult.limitExceeded(
        'Site limit (${limits.maxSites}) reached. '
        'Upgrade to Personal plan for unlimited sites.',
      );
    }

    return UsageCheckResult.allowed(limits.maxSites - currentSites);
  }

  /// 機能利用可能かチェック
  Future<bool> canUseFeature(PremiumFeature feature) async {
    final plan = await getCurrentPlan();
    final limits = PlanLimits.getLimits(plan);

    switch (feature) {
      case PremiumFeature.autoMonitoring:
        return limits.autoMonitoring;
      case PremiumFeature.pushNotifications:
        return limits.pushNotifications;
      case PremiumFeature.apiAccess:
        return limits.apiAccess;
      case PremiumFeature.detailedReports:
        return plan != UserPlan.free;
    }
  }
}

/// 使用量チェック結果
class UsageCheckResult {
  final bool isAllowed;
  final String? message;
  final int? remaining;

  UsageCheckResult.allowed(this.remaining) : isAllowed = true, message = null;

  UsageCheckResult.limitExceeded(this.message)
    : isAllowed = false,
      remaining = null;
}

/// プレミアム機能列挙
enum PremiumFeature {
  autoMonitoring,
  pushNotifications,
  apiAccess,
  detailedReports,
}

/// サイト監視サービス
class SiteMonitoringService {
  final UsageControlService _usageControl = UsageControlService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// 手動サイトチェック実行
  Future<SiteCheckResult> checkSiteManually(String siteId) async {
    try {
      // 使用量制限チェック
      final usageCheck = await _usageControl.canExecuteCheck();
      if (!usageCheck.isAllowed) {
        return SiteCheckResult.error(
          usageCheck.message ?? 'Usage limit exceeded',
          isLimitExceeded: true,
        );
      }

      // Cloud Function 呼び出し
      final callable = _functions.httpsCallable('checkSiteManual');
      final result = await callable.call({'siteId': siteId});

      final data = result.data as Map<String, dynamic>;

      return SiteCheckResult.success(
        status: data['status'] as int,
        responseTime: data['responseTime'] as int,
        isSuccess: data['isSuccess'] as bool,
        error: data['error'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        return SiteCheckResult.error(
          e.message ?? 'Usage limit exceeded',
          isLimitExceeded: true,
        );
      }

      return SiteCheckResult.error(
        e.message ?? 'Check failed',
        isLimitExceeded: false,
      );
    } catch (e) {
      return SiteCheckResult.error(
        'Unexpected error: $e',
        isLimitExceeded: false,
      );
    }
  }

  /// サイト追加
  Future<AddSiteResult> addSite(String name, String url) async {
    try {
      // 使用量制限チェック
      final usageCheck = await _usageControl.canAddSite();
      if (!usageCheck.isAllowed) {
        return AddSiteResult.error(
          usageCheck.message ?? 'Site limit exceeded',
          isLimitExceeded: true,
        );
      }

      // Cloud Function 呼び出し
      final callable = _functions.httpsCallable('addSite');
      final result = await callable.call({'name': name, 'url': url});

      final data = result.data as Map<String, dynamic>;

      return AddSiteResult.success(
        siteId: data['siteId'] as String,
        name: data['name'] as String,
        url: data['url'] as String,
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        return AddSiteResult.error(
          e.message ?? 'Site limit exceeded',
          isLimitExceeded: true,
        );
      }

      return AddSiteResult.error(
        e.message ?? 'Failed to add site',
        isLimitExceeded: false,
      );
    } catch (e) {
      return AddSiteResult.error(
        'Unexpected error: $e',
        isLimitExceeded: false,
      );
    }
  }
}

/// サイトチェック結果
class SiteCheckResult {
  final bool isSuccess;
  final int? status;
  final int? responseTime;
  final String? error;
  final bool isLimitExceeded;

  SiteCheckResult.success({
    required this.status,
    required this.responseTime,
    required bool isSuccess,
    this.error,
  }) : this.isSuccess = isSuccess,
       isLimitExceeded = false;

  SiteCheckResult.error(this.error, {required this.isLimitExceeded})
    : isSuccess = false,
      status = null,
      responseTime = null;
}

/// サイト追加結果
class AddSiteResult {
  final bool isSuccess;
  final String? siteId;
  final String? name;
  final String? url;
  final String? error;
  final bool isLimitExceeded;

  AddSiteResult.success({
    required this.siteId,
    required this.name,
    required this.url,
  }) : isSuccess = true,
       error = null,
       isLimitExceeded = false;

  AddSiteResult.error(this.error, {required this.isLimitExceeded})
    : isSuccess = false,
      siteId = null,
      name = null,
      url = null;
}

/// UI側での使用例
class SiteMonitoringScreen extends StatefulWidget {
  @override
  _SiteMonitoringScreenState createState() => _SiteMonitoringScreenState();
}

class _SiteMonitoringScreenState extends State<SiteMonitoringScreen> {
  final SiteMonitoringService _monitoringService = SiteMonitoringService();
  final UsageControlService _usageControl = UsageControlService();

  UserPlan? _currentPlan;
  int _todayUsage = 0;
  int _siteCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUsageInfo();
  }

  Future<void> _loadUsageInfo() async {
    final plan = await _usageControl.getCurrentPlan();
    final usage = await _usageControl.getTodayUsage();
    final sites = await _usageControl.getSiteCount();

    setState(() {
      _currentPlan = plan;
      _todayUsage = usage;
      _siteCount = sites;
    });
  }

  Future<void> _checkSite(String siteId) async {
    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Checking site...'),
          ],
        ),
      ),
    );

    try {
      final result = await _monitoringService.checkSiteManually(siteId);
      Navigator.of(context).pop(); // ローディング閉じる

      if (result.isLimitExceeded) {
        _showUpgradeDialog(result.error!);
      } else if (result.isSuccess) {
        _showCheckResult(result);
        _loadUsageInfo(); // 使用量更新
      } else {
        _showErrorDialog(result.error!);
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorDialog('Unexpected error occurred');
    }
  }

  void _showUpgradeDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upgrade Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToUpgrade();
            },
            child: Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  void _showCheckResult(SiteCheckResult result) {
    final status = result.status!;
    final isHealthy = status >= 200 && status < 400;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isHealthy ? 'Site is Healthy' : 'Site Issue Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status Code: $status'),
            Text('Response Time: ${result.responseTime}ms'),
            if (result.error != null) Text('Error: ${result.error}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToUpgrade() {
    // アップグレード画面への遷移
    Navigator.of(context).pushNamed('/upgrade');
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPlan == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final limits = PlanLimits.getLimits(_currentPlan!);

    return Scaffold(
      appBar: AppBar(
        title: Text('Site Monitoring'),
        actions: [
          if (_currentPlan == UserPlan.free)
            TextButton(
              onPressed: _navigateToUpgrade,
              child: Text('Upgrade', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // 使用量表示
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Plan: ${_currentPlan!.name.toUpperCase()}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _todayUsage / limits.dailyChecks,
                    backgroundColor: Colors.grey[300],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Daily Checks: $_todayUsage / ${limits.dailyChecks}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sites: $_siteCount / ${limits.maxSites}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          // サイト一覧など...
          Expanded(
            child: ListView.builder(
              itemCount: 5, // 仮のデータ
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('Site ${index + 1}'),
                  subtitle: Text('https://example${index + 1}.com'),
                  trailing: ElevatedButton(
                    onPressed: () => _checkSite('site_$index'),
                    child: Text('Check'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
