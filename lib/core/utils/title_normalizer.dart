/// Utilities for normalizing Work titles for comparison and sorting.
///
/// Two titles are considered the same if, after normalization, they are equal.
/// Normalization rules:
/// - Trim whitespace
/// - Convert to lowercase
/// - Strip trailing non-alphanumeric characters (including punctuation and spaces)
///
/// Sorting helper also ignores leading articles (the, a, an).

String normalizeTitle(String title) {
  var t = title.trim().toLowerCase();
  // Remove trailing non-alphanumeric characters (including spaces and punctuation)
  t = t.replaceAll(RegExp(r'[^a-z0-9]+\$'), '');
  return t;
}

bool sameTitle(String a, String b) => normalizeTitle(a) == normalizeTitle(b);

/// Returns a sort key for titles that ignores leading articles and applies normalization.
String sortKeyTitle(String title) {
  final norm = normalizeTitle(title);
  if (norm.startsWith('the ')) return norm.substring(4);
  if (norm.startsWith('a ')) return norm.substring(2);
  if (norm.startsWith('an ')) return norm.substring(3);
  return norm;
}
