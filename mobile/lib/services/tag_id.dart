/// Normalizes a tag ID by stripping separators (colons, spaces, dashes)
/// and uppercasing. Produces canonical format: uppercase hex, no separators.
///
/// Example: "04:a3:2b:ff" → "04A32BFF"
///
/// Must match Go `NormalizeTagID` in `internal/server/service/tagid.go`.
String normalizeTagId(String raw) {
  return raw
      .replaceAll(':', '')
      .replaceAll(' ', '')
      .replaceAll('-', '')
      .toUpperCase();
}
