import 'package:campus_innovate/core/roble/roble_password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// The policy runs before `signup`, which allows 5 attempts per hour per IP: a
/// password ROBLE would reject must never cost one of them.
void main() {
  test('a password meeting every rule passes', () {
    expect(RoblePasswordPolicy.validate('Uninorte1!'), isNull);
    expect(RoblePasswordPolicy.validate('Campus.2026a'), isNull);
    expect(RoblePasswordPolicy.validate('aB3-defg'), isNull);
  });

  test('each missing rule is named', () {
    expect(RoblePasswordPolicy.validate('Ab1!'), contains('8 caracteres'));
    expect(RoblePasswordPolicy.validate('uninorte1!'), contains('mayúscula'));
    expect(RoblePasswordPolicy.validate('UNINORTE1!'), contains('minúscula'));
    expect(RoblePasswordPolicy.validate('Uninortes!'), contains('número'));
    expect(RoblePasswordPolicy.validate('Uninorte1'), contains('símbolos'));
  });

  test('a symbol ROBLE does not accept is still a rejection', () {
    // `%` and `*` look as strong as `!` and are refused all the same, which is
    // the surprise worth catching before the request.
    expect(RoblePasswordPolicy.validate('Uninorte1%'), contains('símbolos'));
    expect(RoblePasswordPolicy.validate('Uninorte1*'), contains('símbolos'));
  });

  test('every accepted symbol is accepted', () {
    for (final symbol in RoblePasswordPolicy.symbols.split('')) {
      expect(
        RoblePasswordPolicy.validate('Uninorte1$symbol'),
        isNull,
        reason: 'ROBLE acepta $symbol',
      );
    }
  });
}
