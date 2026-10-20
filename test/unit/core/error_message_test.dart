import 'package:campus_innovate/core/error_message.dart';
import 'package:campus_innovate/core/roble/roble_exception.dart';
import 'package:campus_innovate/features/groups/domain/group_exception.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('errorMessage', () {
    test('muestra tal cual el mensaje de una excepción pensada para el usuario',
        () {
      expect(
        errorMessage(const ListingException('El proyecto ya está completo.')),
        'El proyecto ya está completo.',
      );
      expect(
        errorMessage(const GroupException('Este grupo ya no existe.')),
        'Este grupo ya no existe.',
      );
      expect(
        errorMessage(const RobleUnauthorizedException()),
        'Tu sesión expiró. Vuelve a iniciar sesión.',
      );
    });

    test('ignora el fallback cuando el error ya habla con el usuario', () {
      expect(
        errorMessage(
          const RobleRateLimitException('Espera 40 segundos.'),
          fallback: 'Algo salió mal',
        ),
        'Espera 40 segundos.',
      );
    });

    test('reemplaza por el fallback un error que no es para el usuario', () {
      expect(
        errorMessage(StateError('Bad state'), fallback: 'No se pudo cargar'),
        'No se pudo cargar',
      );
      expect(
        errorMessage(const FormatException('x'), fallback: 'Dato inválido'),
        'Dato inválido',
      );
    });

    test('sin fallback cae al toString del error', () {
      expect(errorMessage(StateError('roto')), 'Bad state: roto');
      expect(errorMessage('texto suelto'), 'texto suelto');
    });
  });
}
