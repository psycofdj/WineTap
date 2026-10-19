import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../database.dart';

Response jsonResponse(
  Object? body, {
  int status = 200,
  Map<String, String> headers = const {},
}) => Response(
  status,
  body: jsonEncode(body),
  headers: {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    ...headers,
  },
);

/// API error (API.md §8): `{ "erreur", "message", ... }`.
Response apiError(
  int status,
  String code,
  String message, [
  Map<String, Object?> extra = const {},
]) => jsonResponse({
  'erreur': code,
  'message': message,
  ...extra,
}, status: status);

class BodyTooLarge implements Exception {}

/// Reads the raw body, at most [maxBytes].
Future<List<int>> readBytes(
  Request request, {
  int maxBytes = 100 * 1024 * 1024,
}) async {
  final out = <int>[];
  await for (final chunk in request.read()) {
    if (out.length + chunk.length > maxBytes) throw BodyTooLarge();
    out.addAll(chunk);
  }
  return out;
}

/// Reads a JSON object body; null if it is not one.
Future<Map<String, dynamic>?> readJson(Request request) async {
  try {
    final bytes = await readBytes(request, maxBytes: 32 * 1024 * 1024);
    if (bytes.isEmpty) return {};
    final v = jsonDecode(utf8.decode(bytes));
    return v is Map<String, dynamic> ? v : null;
  } catch (_) {
    return null;
  }
}

// Field mapping between the tables (unchanged, C-01) and the API.

Map<String, Object?> designationJson(Designation d) => {
  'id': d.id,
  'nom': d.name,
  'region': d.region,
  'description': d.description,
  'a_image': d.picture != null && d.picture!.isNotEmpty,
};

Map<String, Object?> domainJson(Domain d) => {
  'id': d.id,
  'nom': d.name,
  'description': d.description,
};

Map<String, Object?> cuveeJson(Cuvee c) => {
  'id': c.id,
  'nom': c.name,
  'domaine_id': c.domainId,
  'appellation_id': c.designationId,
  'couleur': c.color,
  'description': c.description,
};

Map<String, Object?> bottleJson(Bottle b) => {
  'id': b.id,
  'tag_id': b.tagId,
  'cuvee_id': b.cuveeId,
  'millesime': b.vintage,
  'commentaire': b.description,
  'prix': b.purchasePrice,
  'a_boire_avant': b.drinkBefore,
  'entree_le': b.addedAt,
  'consommee_le': b.consumedAt,
};

/// Content type of an image, from its first bytes.
String imageContentType(List<int> b) {
  bool starts(List<int> sig) =>
      b.length >= sig.length &&
      List.generate(sig.length, (i) => b[i] == sig[i]).every((x) => x);
  if (starts([0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (starts([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (starts([0x47, 0x49, 0x46])) return 'image/gif';
  if (b.length > 12 && String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  if (starts([0x42, 0x4D])) return 'image/bmp';
  return 'image/svg+xml';
}
