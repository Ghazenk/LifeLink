import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelink/core/theme/app_theme.dart';
import 'package:lifelink/features/diet/diet_plan_screen.dart';
import 'package:lifelink/features/legal/policy_screen.dart';

class FakeMeals implements MealDraftApi {
  FakeMeals(this.configured);
  final bool configured;
  Map<String, dynamic>? sent;
  @override
  Future<Map<String, dynamic>> availability() async => {
    'configured': configured,
    'provider': 'Groq',
  };
  @override
  Future<Map<String, dynamic>> generate(
    Map<String, dynamic> preferences,
  ) async {
    sent = preferences;
    return {
      'plan': {
        'meals': [
          {
            'label': 'Breakfast',
            'idea': 'A sample draft',
            'ingredients': ['Rice', 'Yogurt'],
          },
        ],
        'questions': ['What portions are appropriate?'],
      },
    };
  }
}

void main() {
  Future<void> mount(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          policySettingsProvider.overrideWith(
            (ref) async => const PolicySettings(
              operatorName: 'LifeLink Test',
              email: 'privacy@test.invalid',
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Unconfigured AI is unavailable and still explains doctor review',
    (tester) async {
      await mount(tester, DietPlanScreen(api: FakeMeals(false)));
      expect(find.text(doctorNotice), findsOneWidget);
      expect(find.text('Generate a draft'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'AI requires both confirmations and sends only selected preferences',
    (tester) async {
      final api = FakeMeals(true);
      await mount(tester, DietPlanScreen(api: api));
      final generate = find.ancestor(
        of: find.text('Generate a draft'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      );
      await tester.scrollUntilVisible(find.text('Generate a draft'), 250);
      expect(tester.widget<FilledButton>(generate).onPressed, isNull);
      for (final box
          in find
              .byType(CheckboxListTile)
              .evaluate()
              .map((e) => e.widget)
              .toList()) {
        final tile = box as CheckboxListTile;
        tile.onChanged!(true);
        await tester.pump();
      }
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();
      expect(api.sent!.keys.toSet(), {
        'consent',
        'adult_and_clinician_confirmed',
        'cuisine',
        'preference',
      });
      expect(find.text('Draft · not yet reviewed by a doctor'), findsOneWidget);
      expect(tester.widget<FilledButton>(generate).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Public privacy and cookie notices use operator settings', (
    tester,
  ) async {
    await mount(tester, const PolicyScreen());
    expect(find.textContaining('LifeLink Test'), findsWidgets);
    expect(tester.takeException(), isNull);
    await mount(tester, const PolicyScreen(cookies: true));
    expect(find.text('No optional tracking enabled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
