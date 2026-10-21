import 'package:campus_innovate/core/i_link_opener.dart';

/// An [ILinkOpener] that remembers what it was asked to open instead of opening
/// it.
class FakeLinkOpener implements ILinkOpener {
  final List<String> opened = [];

  /// What [open] answers: false plays a device without anything to open it.
  var canOpen = true;

  @override
  Future<bool> open(String url) async {
    opened.add(url);

    return canOpen;
  }
}
