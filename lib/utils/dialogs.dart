import 'package:flutter/material.dart';

/// Reusable dialog helpers to standardize confirm/info/error patterns
class Dialogs {
  Dialogs._();

  /// Confirmation dialog with title, message and OK/Cancel.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String okText = 'OK',
    String cancelText = 'Cancel',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(okText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Simple info dialog with dismiss button.
  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
    String closeText = 'Close',
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(closeText),
          ),
        ],
      ),
    );
  }

  /// Error dialog convenience.
  static Future<void> error(
    BuildContext context, {
    String title = 'Error',
    required String message,
    String closeText = 'Close',
  }) async {
    await info(context, title: title, message: message, closeText: closeText);
  }
}
