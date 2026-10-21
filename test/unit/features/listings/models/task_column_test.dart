import 'package:campus_innovate/features/listings/domain/models/task_column.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el orden de los valores es el de las columnas, de izquierda a derecha',
      () {
    expect(TaskColumn.values, [
      TaskColumn.todo,
      TaskColumn.doing,
      TaskColumn.done,
    ]);
  });

  test('cada columna tiene su etiqueta en español', () {
    expect(TaskColumn.todo.label, 'Por hacer');
    expect(TaskColumn.doing.label, 'En progreso');
    expect(TaskColumn.done.label, 'Hecho');
  });

  group('previous y next', () {
    test('la primera columna no tiene anterior', () {
      expect(TaskColumn.todo.previous, isNull);
      expect(TaskColumn.todo.next, TaskColumn.doing);
    });

    test('la del medio tiene ambas vecinas', () {
      expect(TaskColumn.doing.previous, TaskColumn.todo);
      expect(TaskColumn.doing.next, TaskColumn.done);
    });

    test('la última columna no tiene siguiente', () {
      expect(TaskColumn.done.previous, TaskColumn.doing);
      expect(TaskColumn.done.next, isNull);
    });

    test('avanzar y retroceder una vez vuelve a la misma columna', () {
      for (final column in TaskColumn.values) {
        final next = column.next;
        if (next != null) expect(next.previous, column);
      }
    });
  });

  group('fromName', () {
    test('lee de vuelta el nombre que se guarda en la columna status', () {
      for (final column in TaskColumn.values) {
        expect(TaskColumn.fromName(column.name), column);
      }
    });

    test('un valor nulo o desconocido cae en "Por hacer" y no se pierde', () {
      expect(TaskColumn.fromName(null), TaskColumn.todo);
      expect(TaskColumn.fromName(''), TaskColumn.todo);
      expect(TaskColumn.fromName('blocked'), TaskColumn.todo);
    });
  });
}
