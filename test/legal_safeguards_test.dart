import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifelink/features/auth/auth_screen.dart';
import 'package:lifelink/features/legal/policy_screen.dart';

void main() {
  Future<void> mount(WidgetTester t, Widget child) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          policySettingsProvider.overrideWith(
            (_) async => const PolicySettings(),
          ),
        ],
        child: MaterialApp(home: child),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'Signup gathers no identity until age eligibility; under-13 stops',
    (t) async {
      await mount(t, const AuthScreen());
      await t.ensureVisible(find.text('New to LifeLink? Create an account'));
      await t.tap(find.text('New to LifeLink? Create an account'));
      await t.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      await t.tap(find.text('I am under 13'));
      await t.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Create account'), findsNothing);
      expect(find.text('I am 13 or older'), findsNothing);
    },
  );
  testWidgets('Eligible signup requires affirmative Terms acceptance', (
    t,
  ) async {
    await mount(t, const AuthScreen());
    await t.ensureVisible(find.text('New to LifeLink? Create an account'));
    await t.tap(find.text('New to LifeLink? Create an account'));
    await t.pumpAndSettle();
    await t.tap(find.text('I am 13 or older'));
    await t.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(4));
    final button = find.widgetWithText(FilledButton, 'Create account');
    expect(t.widget<FilledButton>(button).onPressed, isNull);
    final terms = find.byType(CheckboxListTile);
    await t.ensureVisible(terms);
    await t.tap(terms);
    await t.pump();
    expect(t.widget<FilledButton>(button).onPressed, isNotNull);
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Copyright'), findsOneWidget);
  });
  test(
    'Copyright notice uses actual configured agent and contains procedures',
    () {
      final sections = copyrightSections(
        const PolicySettings(
          agentName: 'Test agent',
          copyrightEmail: 'agent@test.invalid',
          agentAddress: 'Test address',
          agentPhone: 'Test phone',
        ),
      );
      expect(
        sections['Send a copyright notice'],
        contains('agent@test.invalid'),
      );
      expect(sections['Disputing removal'], contains('Pakistani law'));
      expect(sections['Repeat infringement'], contains('terminates accounts'));
      expect(
        copyrightSections(const PolicySettings())['Send a copyright notice'],
        contains('incomplete'),
      );
    },
  );
}
