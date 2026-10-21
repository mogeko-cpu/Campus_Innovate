/// "hace 5 min", in the shortest unit that is still accurate.
///
/// Shared by the screens that date what other people did — a notification, a
/// file somebody shared — so the same moment reads the same everywhere.
String timeAgo(DateTime moment, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(moment);

  if (elapsed.inMinutes < 1) return 'ahora';
  if (elapsed.inMinutes < 60) return 'hace ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24) return 'hace ${elapsed.inHours} h';

  return 'hace ${elapsed.inDays} d';
}
