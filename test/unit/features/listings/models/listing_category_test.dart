import 'package:campus_innovate/core/user_facing_exception.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('listingCategories', () {
    test('son las seis categorías del campus, en el orden del formulario', () {
      expect(listingCategories, [
        'Tecnología',
        'Investigación',
        'Sostenibilidad',
        'Emprendimiento',
        'Arte y Cultura',
        'Impacto Social',
      ]);
    });

    test('no se repite ninguna', () {
      expect(listingCategories.toSet(), hasLength(listingCategories.length));
    });
  });

  group('ListingException', () {
    test('es para el usuario y su toString es el mensaje', () {
      const error = ListingException('El proyecto ya está completo.');

      expect(error, isA<UserFacingException>());
      expect(error.message, 'El proyecto ya está completo.');
      expect(error.toString(), 'El proyecto ya está completo.');
    });
  });
}
