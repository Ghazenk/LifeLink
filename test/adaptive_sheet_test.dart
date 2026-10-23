import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelink/core/theme/adaptive_sheet.dart';

Future<void> openSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showAdaptiveSheet<bool>(
                context: context,
                builder: (sheetContext) => AppSheet(
                  title: const Text('Confirm action'),
                  content: const Text('A clear explanation of this action.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('compact screens use a bottom sheet with visible actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openSheet(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Confirm action'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm action'), findsNothing);
  });

  testWidgets('desktop screens use a readable bounded dialog', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openSheet(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.getSize(find.byType(AppSheet)).width, lessThan(600));
    expect(tester.takeException(), isNull);
  });
}
