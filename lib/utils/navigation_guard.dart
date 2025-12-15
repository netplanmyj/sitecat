import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/link_checker_provider.dart';

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

  final shouldLeave = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('スキャンを終了しますか？'),
        content: const Text('現在の進行状況をResultsに保存して終了します。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存して終了'),
          ),
        ],
      );
    },
  );

  if (shouldLeave == true && context.mounted) {
    await linkChecker.saveProgressAndReset(siteId);
    return true;
  }
  return false;
}
