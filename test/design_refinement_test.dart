import 'package:lifelink/features/sharing/connections_screen.dart';
import 'package:lifelink/features/legal/policy_screen.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifelink/core/theme/app_theme.dart';
import 'package:lifelink/features/auth/auth_screen.dart';
import 'package:lifelink/features/admin/admin_screen.dart';
import 'package:lifelink/features/admin/data/admin_repository.dart';
import 'package:lifelink/features/donor/donor_screen.dart';
import 'package:lifelink/features/donor/data/donor_repository.dart';
import 'package:lifelink/features/patient/patient_screen.dart';
import 'package:lifelink/features/patient/data/patient_repository.dart';
import 'package:lifelink/features/reception/reception_screen.dart';
import 'package:lifelink/features/reception/data/reception_repository.dart';
import 'package:lifelink/features/lab/lab_screen.dart';
import 'package:lifelink/features/lab/data/lab_repository.dart';

class MockDonorRepository extends Mock implements DonorRepository {}

class MockPatientRepository extends Mock implements PatientRepository {}

class MockReceptionRepository extends Mock implements ReceptionRepository {}

void main() {
  const capture = bool.fromEnvironment('CAPTURE_PREVIEWS');
  final boundaryKey = GlobalKey();
  setUpAll(() async {
    if (capture && Platform.isWindows) {
      final fontBytes = await File('C:/Windows/Fonts/segoeui.ttf')
          .readAsBytes();
      for (final family in ['Segoe UI', 'Roboto', 'Ahem']) {
        await (FontLoader(
          family,
        )..addFont(Future.value(ByteData.sublistView(fontBytes)))).load();
      }
      await (FontLoader(
        'LifeLinkRoboto',
      )..addFont(rootBundle.load('assets/fonts/Roboto.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    double width = 390,
    bool dark = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final donor = MockDonorRepository();
    final patient = MockPatientRepository();
    final reception = MockReceptionRepository();
    when(() => donor.currentUserId).thenReturn('preview-donor-id');
    when(() => patient.currentUserId).thenReturn('preview-patient-id');
    when(() => reception.searchActiveUsers(any())).thenAnswer((_) async => []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          policySettingsProvider.overrideWith(
            (ref) async => const PolicySettings(),
          ),
          donorRepositoryProvider.overrideWithValue(donor),
          patientRepositoryProvider.overrideWithValue(patient),
          receptionRepositoryProvider.overrideWithValue(reception),
          impactScoreProvider.overrideWith((ref) async => 1500),
          donationHistoryProvider.overrideWith((ref) => Stream.value([])),
          linkedPatientsProvider.overrideWith((ref) async => []),
          leaderboardProvider.overrideWith((ref) async => []),
          medicalHistoryProvider.overrideWith((ref) => Stream.value([])),
          pendingGuardianshipsProvider.overrideWith((ref) async => []),
          adminDashboardStatsProvider.overrideWith(
            (ref) async => {
              'total_blood_ml': 14500,
              'active_patients': 24,
              'active_donors': 48,
              'stock_levels': <String, int>{'A+': 4000, 'O+': 6500, 'B+': 4000},
            },
          ),
          staffListProvider.overrideWith((ref) async => []),
          systemRecordsProvider.overrideWith((ref) async => []),
          pendingUsersProvider.overrideWith((ref) async => []),
          liveInventoryProvider.overrideWith(
            (ref) async => [
              {'blood_group': 'A+', 'volume_ml': 4000},
              {'blood_group': 'O+', 'volume_ml': 6500},
            ],
          ),
          liveQueueProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(key: boundaryKey, child: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> snapshot(WidgetTester tester, String name) async {
    if (!capture) return;
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/design-previews');
      await dir.create(recursive: true);
      await File('${dir.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('Sign in uses only email and password for every role', (
    tester,
  ) async {
    await mount(tester, const AuthScreen());
    expect(find.byIcon(Icons.bloodtype), findsOneWidget);
    await snapshot(tester, 'sign-in');
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
    expect(find.text('Donor'), findsNothing);
    expect(find.text('Patient'), findsNothing);
    expect(find.text('Clinic staff sign in'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('New to LifeLink? Create an account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Donor registration shows screening and no staff role picker', (
    tester,
  ) async {
    await mount(tester, const AuthScreen(), width: 360);
    await tester.ensureVisible(find.text('New to LifeLink? Create an account'));
    await tester.tap(find.text('New to LifeLink? Create an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I am 13 or older'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Donor'));
    await tester.pumpAndSettle();
    expect(find.text('Pre-Donation Medical Questionnaire'), findsOneWidget);
    expect(find.text('ADMIN'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final entry in <String, Widget>{
    'donor': const DonorScreen(),
    'patient': const PatientScreen(),
    'admin': const AdminScreen(),
    'reception': const ReceptionScreen(),
    'lab': const LabScreen(),
    'caregiver': const CaregiverScreen(),
  }.entries) {
    for (final width in [360.0, 1280.0]) {
      testWidgets('${entry.key} layout at $width', (tester) async {
        await mount(tester, entry.value, width: width);
        expect(tester.takeException(), isNull);
        await snapshot(tester, '${entry.key}-${width.toInt()}');
        if (entry.key != 'lab') {
          expect(
            find.byType(width < 840 ? NavigationBar : NavigationRail),
            findsOneWidget,
          );
          final labels = switch (entry.key) {
            'caregiver' => ['About access', 'Connections'],
            'donor' => ['History', 'Family', 'Impact', 'Profile'],
            'patient' => ['Records', 'Guardians'],
            'admin' => ['Staff', 'Settings', 'System'],
            _ => ['Donation', 'Transfusion', 'Inventory'],
          };
          for (final label in labels) {
            await tester.tap(find.text(label).last);
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${entry.key}/$label at $width',
            );
          }
        }
      });
    }
  }

  testWidgets(
    'Caregiver signup has no donor screening or blood group requirement',
    (tester) async {
      await mount(tester, const AuthScreen());
      await tester.tap(find.text('New to LifeLink? Create an account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I am 13 or older'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Caregiver'));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Pre-Donation Medical Questionnaire'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Dark mode and enlarged text fit mobile donor dashboard', (
    tester,
  ) async {
    await mount(tester, const DonorScreen(), dark: true, scale: 1.3);
    expect(tester.takeException(), isNull);
    await snapshot(tester, 'donor-dark');
  });
}
