import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelink/features/auth/data/recovery_repository.dart';
import 'package:lifelink/features/auth/password_recovery_screen.dart';

class FakeRecovery implements RecoveryApi {
  int sends = 0, verifies = 0, updates = 0;
  bool reject = false, closed = false;
  @override
  Future<void> sendCode(String email) async {
    sends++;
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    verifies++;
    if (reject) throw Exception('expired');
  }

  @override
  Future<bool> updatePassword(String password) async {
    updates++;
    return true;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

void main() {
  testWidgets(
    'Recovery requires email, verified code and matching strong passwords',
    (tester) async {
      final api = FakeRecovery();
      await tester.pumpWidget(
        MaterialApp(home: PasswordRecoveryScreen(api: api)),
      );
      await tapVisible(tester, find.text('Send recovery code'));
      await tester.pump();
      expect(api.sends, 0);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tapVisible(tester, find.text('Send recovery code'));
      await tester.pumpAndSettle();
      expect(api.sends, 1);
      expect(find.text('New password'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Recovery code'),
        '12345678',
      );
      api.reject = true;
      await tapVisible(tester, find.text('Verify code'));
      await tester.pumpAndSettle();
      expect(find.text('New password'), findsNothing);
      expect(api.updates, 0);
      api.reject = false;
      await tapVisible(tester, find.text('Verify code'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'Long-password-123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'different-password',
      );
      await tapVisible(tester, find.text('Save new password'));
      await tester.pump();
      expect(api.updates, 0);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'Long-password-123',
      );
      await tapVisible(tester, find.text('Save new password'));
      await tester.pumpAndSettle();
      expect(api.updates, 1);
      expect(find.text('Password changed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(api.closed, isTrue);
    },
  );

  testWidgets(
    'Existing code can be verified without requesting another email',
    (tester) async {
      final api = FakeRecovery();
      await tester.pumpWidget(
        MaterialApp(
          home: PasswordRecoveryScreen(
            api: api,
            initialEmail: 'test@example.com',
          ),
        ),
      );
      await tapVisible(tester, find.text('I already have a code'));
      await tester.pumpAndSettle();
      expect(api.sends, 0);
      expect(find.text('Recovery code'), findsOneWidget);
      await tapVisible(tester, find.text('Verify code'));
      await tester.pump();
      expect(api.verifies, 0);
      await tester.pumpWidget(const SizedBox());
      expect(api.closed, isTrue);
    },
  );
}
