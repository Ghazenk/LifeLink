import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifelink/features/sharing/share_code_card.dart';
import 'package:lifelink/features/legal/settings_screen.dart';
import 'package:lifelink/features/auth/data/auth_repository.dart';

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';
import 'package:lifelink/features/sharing/sharing_repository.dart';
import 'package:lifelink/features/sharing/qr_scan_screen.dart';

class FakeSharingApi implements SharingApi {
  int generated = 0, revoked = 0;
  @override
  Future<Map<String, dynamic>> createCode(String purpose) async {
    generated++;
    return {
      'code': 'LL-G-ABCD-1234-EF56',
      'expires_at': DateTime.now()
          .add(const Duration(minutes: 15))
          .toIso8601String(),
    };
  }

  @override
  Future<void> revoke(String purpose) async {
    revoked++;
  }

  @override
  Future<Map<String, dynamic>> redeem(String code, String purpose) async =>
      throw UnimplementedError();
}

void main() {
  testWidgets('Sharing requires explicit generation and can be revoked', (
    tester,
  ) async {
    final api = FakeSharingApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharingApiProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShareCodeCard(purpose: 'guardian'),
            ),
          ),
        ),
      ),
    );
    expect(api.generated, 0);
    await tester.tap(find.text('Generate code'));
    await tester.pump();
    await tester.pump();
    expect(find.text('LL-G-ABCD-1234-EF56'), findsOneWidget);
    await tester.ensureVisible(find.text('Revoke this code'));
    await tester.tap(find.text('Revoke this code'));
    await tester.pump();
    await tester.pump();
    expect(api.revoked, 1);
    expect(find.text('LL-G-ABCD-1234-EF56'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Settings exposes all notices without depending on a role', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: AppSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    for (final title in [
      'Privacy notice',
      'Terms of use',
      'Cookies & storage',
      'Copyright & reports',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
  });

  test(
    'Typed codes and app links normalize, UUIDs and wrong purposes fail',
    () {
      expect(
        normalizeLifeLinkCode('ll g abcd 1234 ef56', 'guardian'),
        'LL-G-ABCD-1234-EF56',
      );
      expect(
        normalizeLifeLinkCode(
          'lifelink://connect?code=LL-C-ABCD-1234-EF56',
          'checkin',
        ),
        'LL-C-ABCD-1234-EF56',
      );
      for (final bad in [
        'LL-C-ABCD-1234-EF56',
        'https://google.com',
        '123e4567-e89b-12d3-a456-426614174000',
        'lifelink://evil?code=LL-G-ABCD-1234-EF56',
        'LL-G-ABCD-1234-EF56extra',
      ]) {
        expect(
          () => normalizeLifeLinkCode(bad, 'guardian'),
          throwsFormatException,
        );
      }
    },
  );
  test('QR image roundtrip is decoded locally', () {
    const value = 'lifelink://connect?code=LL-G-ABCD-1234-EF56';
    final matrix = Encoder.encode(value, ErrorCorrectionLevel.m).matrix!;
    const scale = 8, margin = 4;
    final picture = img.Image(
      width: (matrix.width + 2 * margin) * scale,
      height: (matrix.height + 2 * margin) * scale,
    );
    img.fill(picture, color: img.ColorRgb8(255, 255, 255));
    for (var y = 0; y < matrix.height; y++) {
      for (var x = 0; x < matrix.width; x++) {
        if (matrix.get(x, y) == 1) {
          img.fillRect(
            picture,
            x1: (x + margin) * scale,
            y1: (y + margin) * scale,
            x2: (x + margin + 1) * scale - 1,
            y2: (y + margin + 1) * scale - 1,
            color: img.ColorRgb8(0, 0, 0),
          );
        }
      }
    }
    expect(decodeLifeLinkQr(Uint8List.fromList(img.encodePng(picture))), value);
  });
  test('Malformed or oversized images are refused', () {
    expect(() => decodeLifeLinkQr(Uint8List(10)), throwsFormatException);
    expect(
      () => decodeLifeLinkQr(Uint8List(8 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
  });
}
