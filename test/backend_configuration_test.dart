import 'package:flutter_test/flutter_test.dart';
import 'package:lifelink/core/network/backend_configuration.dart';

void main() {
  test('clinic config requires HTTPS and no URL credentials or path', () {
    for (final value in [
      'http://10.77.0.1',
      'https://localhost',
      'https://127.0.0.1',
      'https://user:pass@clinic.example.pk',
      'https://clinic.example.pk/rest/v1',
      'https://clinic.example.pk?key=x',
    ]) {
      expect(() => BackendConfiguration.parseClinic(value, 'public-key'),
          throwsFormatException);
    }
  });

  test('different clinic servers have isolated storage namespaces', () {
    final a = BackendConfiguration.parseClinic('https://clinic-a.example.pk', 'public-key');
    final b = BackendConfiguration.parseClinic('https://clinic-b.example.pk', 'public-key');
    expect(a.namespace, isNot(b.namespace));
    expect(a.clinicMode, isTrue);
  });

  test('server secret keys are refused on clinic clients', () {
    expect(
      () => BackendConfiguration.parseClinic(
        'https://clinic.example.pk', 'sb_' 'secret_do-not-use',
      ),
      throwsFormatException,
    );
  });
}
