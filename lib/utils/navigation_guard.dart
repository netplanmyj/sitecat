import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/link_checker_provider.dart';
import '../constants/error_messages.dart';
import 'dialogs.dart';

/// 前向き遷移や戻る操作の前に、スキャン中なら
/// 「保存して終了」ダイアログを表示し、承認時に保存してから進むヘルパー。
/// 戻り値: true=遷移続行OK / false=キャンセル
Future<bool> confirmAndSaveIfScanning(
  BuildContext context,
  String siteId,
) async {
  final linkChecker = context.read<LinkCheckerProvider>();
  if (!linkChecker.isChecking(siteId)) {
    return true; // スキャン中でなければそのまま遷移OK
  }

  final shouldLeave = await Dialogs.confirm(
    context,
    title: ErrorMessages.confirmEndScanTitle,
    message: ErrorMessages.confirmEndScanMessage,
    okText: ErrorMessages.confirmEndScanOkText,
    cancelText: ErrorMessages.confirmEndScanCancelText,
  );

  if (shouldLeave == true && context.mounted) {
    await linkChecker.saveProgressAndReset(siteId);
    return true;
  }
  return false;
}
