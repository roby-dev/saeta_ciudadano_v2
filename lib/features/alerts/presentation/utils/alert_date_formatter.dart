const _spanishMonthAbbreviations = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Formats an ISO 8601 [isoDate] (e.g. `2026-09-26T14:32:00.000Z`) as
/// `26 sep 2026 · 14:32` (Spanish 3-letter month abbreviation, 24h time).
///
/// Reads the date/time fields directly off the parsed [DateTime] without a
/// `toLocal()` conversion — the rest of the app already displays alert
/// dates/times as-is with no timezone handling, so converting only here
/// would be inconsistent and would make the result depend on the machine's
/// timezone (non-deterministic in tests/CI).
///
/// Falls back to returning [isoDate] unchanged when it can't be parsed.
String formatAlertDate(String isoDate) {
  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null) return isoDate;

  final day = parsed.day.toString().padLeft(2, '0');
  final month = _spanishMonthAbbreviations[parsed.month - 1];
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '$day $month ${parsed.year} · $hour:$minute';
}
