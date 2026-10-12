/// Field readers shared by the review sources (IMDb, Serializd), whose JSON
/// sends numbers and dates in mixed forms.
library;

/// An int sent as a number or a string; 0 when missing or unreadable.
int jsonInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}

/// An ISO date, or null when missing or unreadable.
DateTime? jsonDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
