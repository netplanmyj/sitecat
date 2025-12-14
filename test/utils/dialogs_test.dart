import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/utils/dialogs.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('Dialogs.confirm returns true on OK and false on Cancel', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await Dialogs.confirm(
                  context,
                  title: 'Confirm',
                  message: 'Proceed?',
                  okText: 'OK',
                  cancelText: 'Cancel',
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Proceed?'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    // Re-open and tap OK
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('Dialogs.info shows and dismisses', (tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                await Dialogs.info(
                  context,
                  title: 'Info',
                  message: 'Hello',
                  closeText: 'Close',
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Info'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Info'), findsNothing);
  });

  testWidgets('Dialogs.error delegates to info with default title', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                await Dialogs.error(context, message: 'Oops');
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsOneWidget);
    expect(find.text('Oops'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Error'), findsNothing);
  });
}
