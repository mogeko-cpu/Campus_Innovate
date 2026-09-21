import 'roble_exception.dart';

/// Whether ROBLE's error is a `UNIQUE` violation.
///
/// It has to be read out of the message: ROBLE forwards the PostgreSQL error
/// without a code of its own and the status may be 400 or 500. When the wording
/// changes this stops matching and the user sees the generic error instead of a
/// friendly one — wrong message, never wrong data, because the constraint is
/// what actually prevents the duplicate.
///
/// Lives in `core` because three data sources need the same judgement: joining a
/// project, joining a group and reacting to a project all rely on a composite
/// `UNIQUE` to make the second write impossible.
bool isDuplicateRow(RobleException error) {
  final message = error.message.toLowerCase();

  return message.contains('duplicate') ||
      message.contains('unique') ||
      message.contains('llave duplicada') ||
      message.contains('23505');
}
