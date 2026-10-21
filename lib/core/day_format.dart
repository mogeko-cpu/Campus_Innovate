/// "15 nov": a day as the board shows it, without pulling in `intl` for six
/// letters. The year is added only when it is not the current one.
String shortDay(DateTime day, {DateTime? now}) {
  const months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  final label = '${day.day} ${months[day.month - 1]}';
  final year = (now ?? DateTime.now()).year;

  return day.year == year ? label : '$label ${day.year}';
}
