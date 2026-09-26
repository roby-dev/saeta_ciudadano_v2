/// The alert detail sheet's short id (e.g. `#123456`), built from the last
/// 6 characters of [id], uppercased. Returns the whole [id] uppercased when
/// it is 6 characters or shorter, and `null` when [id] is empty (the caller
/// then hides the short-id text entirely).
String? alertShortId(String id) {
  if (id.isEmpty) return null;
  final tail = id.length <= 6 ? id : id.substring(id.length - 6);
  return tail.toUpperCase();
}
