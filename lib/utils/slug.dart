/// Turns a free-typed display string (school name, player name) into a
/// stable, Firestore-doc-id-safe key: lowercase, spaces/punctuation
/// collapsed to single hyphens, leading/trailing hyphens trimmed.
///
/// Used so "Central Texas College" and " central texas college " (typos in
/// casing/whitespace across different game sessions) aggregate into the
/// SAME school document instead of silently splitting a school's score
/// across multiple near-duplicate leaderboard entries.
String slugify(String input) {
  final lower = input.trim().toLowerCase();
  final collapsed = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  final trimmed = collapsed.replaceAll(RegExp(r'^-+|-+$'), '');
  return trimmed.isEmpty ? 'unknown' : trimmed;
}
