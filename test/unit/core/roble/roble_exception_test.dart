import 'package:campus_innovate/core/error_message.dart';
import 'package:campus_innovate/core/roble/roble_exception.dart';
import 'package:campus_innovate/core/user_facing_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('los errores de transporte traen un mensaje en español por defecto', () {
    expect(const RobleNetworkException().message, contains('conexión'));
    expect(const RobleTimeoutException().message, contains('tardó'));
    expect(const RobleUnauthorizedException().message, contains('sesión'));
    expect(const RobleForbiddenException().message, contains('permiso'));
  });

  test('el mensaje por defecto se puede reemplazar', () {
    expect(const RobleNetworkException('Sin red').message, 'Sin red');
    expect(const RobleUnauthorizedException('Credenciales').message,
        'Credenciales');
  });

  test('toString es el mensaje plano, sin el nombre de la clase', () {
    const error = RobleBadRequestException('Bad Request');

    expect(error.toString(), 'Bad Request');
  });

  test('todas son UserFacingException, así errorMessage las muestra', () {
    const errors = <RobleException>[
      RobleNetworkException(),
      RobleTimeoutException(),
      RobleUnauthorizedException(),
      RobleForbiddenException(),
      RobleBadRequestException('400'),
      RobleNotFoundException('404'),
      RobleRateLimitException('429'),
      RobleServerException('500', 500),
    ];

    for (final error in errors) {
      expect(error, isA<UserFacingException>());
      expect(errorMessage(error, fallback: 'genérico'), error.message);
    }
  });

  test('el límite de tasa conserva los segundos de espera si ROBLE los dio', () {
    expect(
      const RobleRateLimitException('Espera', retryAfter: 40).retryAfter,
      40,
    );
    expect(const RobleRateLimitException('Espera').retryAfter, isNull);
  });

  test('el error de servidor conserva el código de estado', () {
    expect(const RobleServerException('caído', 503).statusCode, 503);
  });
}
