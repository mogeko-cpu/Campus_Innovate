import 'dart:js_interop';

/// The page is the browser: the flow leaves the app by navigating away, and the
/// return is a new load of the app with the code in the query.
///
/// `dart:js_interop` and not `dart:html`: the second one is on its way out and
/// does not compile to WebAssembly. Only three JS members are needed, so they are
/// declared here instead of pulling in a package for them.
abstract final class SocialBrowser {
  static bool get isSupported => true;

  /// Leaves the app. Nothing after this call runs: the page is replaced.
  static void goTo(String url) => _window.location.assign(url);

  /// Drops the query from the address, keeping the route.
  ///
  /// `replaceState` and not a navigation: it rewrites the address without
  /// reloading the app and without leaving an entry in the back stack, so
  /// reloading or pressing back cannot try to spend a code ROBLE already
  /// invalidated.
  static void dropQuery() {
    final location = _window.location;

    _window.history.replaceState(
      null,
      '',
      '${location.pathname}${location.hash}',
    );
  }
}

@JS('window')
external _Window get _window;

extension type _Window._(JSObject _) implements JSObject {
  external _Location get location;
  external _History get history;
}

extension type _Location._(JSObject _) implements JSObject {
  external String get pathname;
  external String get hash;
  external void assign(String url);
}

extension type _History._(JSObject _) implements JSObject {
  external void replaceState(JSAny? data, String title, String? url);
}
