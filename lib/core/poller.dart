import 'dart:async';

/// Runs [action] every [interval], one run at a time.
///
/// ROBLE has no push channel — no websockets, no change feed — so a screen that
/// should notice what other people do (a request that was accepted, a message
/// that arrived) has to ask again. This is that asking, kept in one place so
/// every screen gets the same three guarantees:
///
/// - a run that is still in flight is never overlapped by the next tick, so a
///   slow network cannot pile requests up against ROBLE's rate limit;
/// - a failed run is swallowed: the screen keeps what it already shows and the
///   next tick tries again, instead of an error appearing out of nowhere;
/// - it can be [pause]d while another screen is on top, so two screens are not
///   both polling for something only one of them is showing.
class Poller {
  Poller({required this.interval, required this.action});

  /// Switched off by the widget tests: a periodic timer left running when a test
  /// ends is reported by Flutter as a failure, and nothing in a test needs the
  /// screen to refresh by itself.
  static bool enabled = true;

  final Duration interval;
  final Future<void> Function() action;

  Timer? _timer;
  var _running = false;
  var _paused = false;

  bool get isActive => _timer != null;

  void start() {
    if (!enabled) return;

    _timer ??= Timer.periodic(interval, (_) => _tick());
  }

  void pause() => _paused = true;

  void resume() => _paused = false;

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_paused || _running) return;

    _running = true;

    try {
      await action();
    } catch (_) {
      // Ignored on purpose; see the class comment.
    } finally {
      _running = false;
    }
  }
}
