/// Up to 2 uppercase initials from an emergency contact's free-text [name]
/// (first letter of the first 2 whitespace-separated words). `"?"` when
/// [name] is empty/whitespace-only.
String contactInitials(String name) {
  final words =
      name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';

  final first = words[0][0];
  final second = words.length > 1 ? words[1][0] : '';
  return '$first$second'.toUpperCase();
}
