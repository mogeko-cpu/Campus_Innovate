/// Where the social login leaves the app, and how it comes back.
///
/// Two implementations chosen at compile time. On the web the page itself is the
/// browser: the flow leaves by navigating to Google and comes back as a fresh
/// load of the app with the one-time code in the address. Everywhere else there
/// is nothing to return to yet — the ROBLE console has one return destination
/// registered, the web app's — so the stub says so instead of opening a browser
/// the user could never get out of. See `docs/roble.md`.
library;

export 'social_browser_stub.dart'
    if (dart.library.js_interop) 'social_browser_web.dart';
