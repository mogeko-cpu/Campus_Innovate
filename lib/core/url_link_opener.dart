import 'package:url_launcher/url_launcher.dart';

import 'i_link_opener.dart';

/// [ILinkOpener] over `url_launcher`: a new tab on the web, the browser or the
/// app registered for the address everywhere else.
class UrlLinkOpener implements ILinkOpener {
  const UrlLinkOpener();

  @override
  Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // A platform without a handler throws instead of answering false; for
      // the screen both mean the same thing.
      return false;
    }
  }
}
