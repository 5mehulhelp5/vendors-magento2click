// Shared, defensive parsing helpers for the returns (RMA) models.
//
// Kept dependency-free so every returns model can reuse them without importing
// each other.

int? parseReturnInt(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw');
}

num? parseReturnNum(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw;
  return num.tryParse('$raw');
}

/// Magento sends timestamps as UTC wall-clock with no zone marker
/// (e.g. `2026-07-23 10:45:00`). A marker-less string is read as device-local
/// time, which throws `timeago` off by the device's UTC offset — so tag it UTC
/// when no zone is present, then convert to local. Mirrors the handling in
/// `Review._parseMagentoDate`.
DateTime? parseReturnDate(dynamic raw) {
  if (raw == null) return null;
  final s = '$raw'.trim();
  if (s.isEmpty) return null;
  final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
  return DateTime.tryParse(hasZone ? s : '${s}Z')?.toLocal();
}

/// Parse a JSON array into a typed list, skipping anything that isn't a Map.
List<T> parseReturnList<T>(dynamic raw, T Function(Map) fromJson) {
  final list = <T>[];
  if (raw is List) {
    for (final item in raw) {
      if (item is Map) list.add(fromJson(item));
    }
  }
  return list;
}
