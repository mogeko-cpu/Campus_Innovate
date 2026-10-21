import 'package:file_picker/file_picker.dart';

import 'i_file_picker.dart';

/// [IFilePicker] over the `file_picker` plugin: the native chooser on Android,
/// iOS and desktop, and the browser's file input on the web.
class PlatformFilePicker implements IFilePicker {
  const PlatformFilePicker();

  @override
  Future<PickedFile?> pickFile() async {
    final file = await FilePicker.pickFile();
    if (file == null) return null;

    return PickedFile(
      name: file.name,
      bytes: await file.readAsBytes(),
      mimeType: file.xFile.mimeType,
    );
  }
}
