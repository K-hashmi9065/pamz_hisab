import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/shared/widgets/app_dialog.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('AppDialog widget tests', () {
    testWidgets('renders title and text content', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () => AppDialog.show(
              context: ctx,
              title: 'Test Title',
              content: 'Test content message',
            ),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test content message'), findsOneWidget);
    });

    testWidgets('renders contentWidget when provided instead of content string', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () => AppDialog.show(
              context: ctx,
              title: 'Widget Content Dialog',
              contentWidget: const Text('Custom widget body'),
            ),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Custom widget body'), findsOneWidget);
    });

    testWidgets('renders with no content when both content and contentWidget are null', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () => AppDialog.show(
              context: ctx,
              title: 'No Content Dialog',
            ),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('No Content Dialog'), findsOneWidget);
    });

    testWidgets('renders directly as AppDialog widget with actions', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppDialog(
          title: 'Direct Dialog',
          content: 'Direct content',
          actions: [Text('Action 1'), Text('Action 2')],
        ),
      ));

      expect(find.text('Direct Dialog'), findsOneWidget);
      expect(find.text('Direct content'), findsOneWidget);
      expect(find.text('Action 1'), findsOneWidget);
      expect(find.text('Action 2'), findsOneWidget);
    });
  });

  group('ConfirmationDialog widget tests', () {
    testWidgets('renders title, message, confirm, and cancel buttons', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () => ConfirmationDialog.show(
              context: ctx,
              title: 'Delete?',
              message: 'This action is permanent.',
              confirmLabel: 'Delete',
              cancelLabel: 'Cancel',
              isDestructive: true,
            ),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete?'), findsOneWidget);
      expect(find.text('This action is permanent.'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancel button pops dialog with false result', (tester) async {
      bool? result;
      await tester.pumpWidget(_wrap(
        Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () async {
              result = await ConfirmationDialog.show(
                context: ctx,
                title: 'Confirm',
                message: 'Are you sure?',
              );
            },
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('confirm button pops dialog with true result', (tester) async {
      bool? result;
      await tester.pumpWidget(_wrap(
        Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () async {
              result = await ConfirmationDialog.show(
                context: ctx,
                title: 'Confirm',
                message: 'Are you sure?',
                confirmLabel: 'Yes',
              );
            },
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('renders ConfirmationDialog directly with default labels', (tester) async {
      await tester.pumpWidget(_wrap(
        const ConfirmationDialog(
          title: 'Direct Confirm',
          message: 'Direct message',
        ),
      ));

      expect(find.text('Direct Confirm'), findsOneWidget);
      expect(find.text('Direct message'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
