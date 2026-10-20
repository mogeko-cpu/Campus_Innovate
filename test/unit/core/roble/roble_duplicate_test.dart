import 'package:campus_innovate/core/roble/roble_duplicate.dart';
import 'package:campus_innovate/core/roble/roble_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reconoce el texto de PostgreSQL en inglés', () {
    expect(
      isDuplicateRow(
        const RobleBadRequestException(
          'duplicate key value violates unique constraint "x_unique"',
        ),
      ),
      isTrue,
    );
  });

  test('reconoce el texto en español y el código 23505', () {
    expect(
      isDuplicateRow(
        const RobleServerException('llave duplicada viola restricción', 500),
      ),
      isTrue,
    );
    expect(
      isDuplicateRow(const RobleServerException('error 23505', 500)),
      isTrue,
    );
  });

  test('no distingue mayúsculas', () {
    expect(
      isDuplicateRow(const RobleBadRequestException('UNIQUE VIOLATION')),
      isTrue,
    );
  });

  test('cualquier otro error no es un duplicado', () {
    expect(
      isDuplicateRow(const RobleBadRequestException('Bad Request')),
      isFalse,
    );
    expect(isDuplicateRow(const RobleNetworkException()), isFalse);
    expect(isDuplicateRow(const RobleServerException('timeout', 504)), isFalse);
  });
}
