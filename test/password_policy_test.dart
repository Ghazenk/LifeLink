import 'package:flutter_test/flutter_test.dart';
import 'package:lifelink/core/security/password_policy.dart';

void main() {
  test('password policy rejects weak and oversized passwords', () {
    expect(PasswordPolicy.validate('short'), isNotNull);
    expect(PasswordPolicy.validate('alllowercase123!'), isNotNull);
    expect(PasswordPolicy.validate('ALLUPPERCASE123!'), isNotNull);
    expect(PasswordPolicy.validate('NoDigitsHere!'), isNotNull);
    expect(PasswordPolicy.validate('NoSymbolsHere123'), isNotNull);
    expect(PasswordPolicy.validate('A1!${'x' * 126}'), isNotNull);
  });

  test('password policy accepts a strong password', () {
    expect(PasswordPolicy.validate('Strong-password-123'), isNull);
  });
}
