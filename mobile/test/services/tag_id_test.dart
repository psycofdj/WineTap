import 'package:flutter_test/flutter_test.dart';
import 'package:wine_tap_mobile/services/tag_id.dart';

void main() {
  // Test cases match Go NormalizeTagID in internal/server/service/tagid_test.go
  group('normalizeTagId', () {
    final cases = <(String, String)>[
      ('04:a3:2b:ff', '04A32BFF'),
      ('04 a3 2b ff', '04A32BFF'),
      ('04-a3-2b-ff', '04A32BFF'),
      ('04a32bff', '04A32BFF'),
      ('04A32BFF', '04A32BFF'),
      ('04:A3:2B:FF', '04A32BFF'),
      ('', ''),
      ('aa:bb:cc:dd:ee:ff:00', 'AABBCCDDEEFF00'),
      ('  04 A3 ', '04A3'),
    ];

    for (final (input, expected) in cases) {
      test('normalizeTagId("$input") == "$expected"', () {
        expect(normalizeTagId(input), equals(expected));
      });
    }
  });
}
