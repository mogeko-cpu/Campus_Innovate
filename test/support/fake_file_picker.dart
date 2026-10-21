import 'dart:convert';
import 'dart:typed_data';

import 'package:campus_innovate/core/i_file_picker.dart';

/// An [IFilePicker] that "chooses" whatever the test put in [next], or nothing
/// at all — the person closing the chooser — while [next] is null.
class FakeFilePicker implements IFilePicker {
  PickedFile? next;

  /// How many times the screen opened the chooser.
  var calls = 0;

  /// A small text file, for the tests that only need something to upload.
  static PickedFile textFile(String name, [String content = 'contenido']) =>
      PickedFile(name: name, bytes: Uint8List.fromList(utf8.encode(content)));

  @override
  Future<PickedFile?> pickFile() async {
    calls++;

    return next;
  }
}
