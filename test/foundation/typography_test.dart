import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

/// The code points a font file has glyphs for, read from its `cmap` table
/// (formats 4 and 12, which is what the bundled fonts carry).
Set<int> _codePoints(String file) {
  final ByteData d = ByteData.sublistView(File(file).readAsBytesSync());
  final int tables = d.getUint16(4);
  int cmap = -1;
  for (int i = 0; i < tables; i++) {
    final int at = 12 + 16 * i;
    final String tag = String.fromCharCodes(<int>[for (int k = 0; k < 4; k++) d.getUint8(at + k)]);
    if (tag == 'cmap') cmap = d.getUint32(at + 8);
  }
  expect(cmap, greaterThan(0), reason: '$file has a cmap table');
  final int count = d.getUint16(cmap + 2);
  int best = -1;
  int bestFormat = 0;
  for (int i = 0; i < count; i++) {
    final int sub = cmap + d.getUint32(cmap + 4 + 8 * i + 4);
    final int format = d.getUint16(sub);
    if ((format == 4 || format == 12) && format > bestFormat) {
      best = sub;
      bestFormat = format;
    }
  }
  expect(best, greaterThan(0), reason: '$file has a format 4 or 12 subtable');
  final Set<int> out = <int>{};
  if (bestFormat == 12) {
    final int groups = d.getUint32(best + 12);
    for (int g = 0; g < groups; g++) {
      final int start = d.getUint32(best + 16 + 12 * g);
      final int end = d.getUint32(best + 20 + 12 * g);
      for (int c = start; c <= end; c++) {
        out.add(c);
      }
    }
  } else {
    final int segX2 = d.getUint16(best + 6);
    for (int s = 0; s < segX2; s += 2) {
      final int end = d.getUint16(best + 14 + s);
      final int start = d.getUint16(best + 16 + segX2 + s);
      if (end == 0xFFFF) continue;
      for (int c = start; c <= end; c++) {
        out.add(c);
      }
    }
  }
  return out;
}

bool _isIdeograph(int c) => c >= 0x3400 && c <= 0x9FFF;

/// Every ideograph written in the Dart sources under [roots].
Map<int, String> _ideographsIn(List<String> roots) {
  final Map<int, String> found = <int, String>{};
  for (final String root in roots) {
    for (final FileSystemEntity e in Directory(root).listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      for (final int rune in e.readAsStringSync().runes) {
        if (_isIdeograph(rune)) found.putIfAbsent(rune, () => e.path);
      }
    }
  }
  return found;
}

void main() {
  const KkTypography type = KkTypography();

  test('every voice falls back to Zen Old Mincho before Noto Serif KR', () {
    // One order everywhere, so a word with ideographs is set in one design
    // whichever voice it is written in.
    expect(type.displayFamily, 'Zen Old Mincho');
    expect(type.displayFallback, <String>['Noto Serif KR']);
    expect(type.labelFallback, <String>['Zen Old Mincho', 'Noto Serif KR']);
    expect(type.bodyFallback, <String>['Zen Old Mincho', 'Noto Serif KR']);
    expect(type.monoFallback, <String>['IBM Plex Sans KR', 'Zen Old Mincho', 'Noto Serif KR']);
    expect(type.body(14).fontFamilyFallback, <String>[
      'packages/keikai/Zen Old Mincho',
      'packages/keikai/Noto Serif KR',
    ]);
    // The platform's own fonts take over when the list is emptied.
    expect(const KkTypography(bodyFallback: <String>[]).body(14).fontFamilyFallback, isEmpty);
  });

  group('the bundled fonts', () {
    late Set<int> zen;
    late Set<int> noto;
    late Set<int> plexSans;
    late Set<int> plexMono;
    late Set<int> sofia;

    setUpAll(() {
      zen = _codePoints('fonts/ZenOldMincho-Black.ttf');
      noto = _codePoints('fonts/NotoSerifKR-Black.ttf');
      plexSans = _codePoints('fonts/IBMPlexSansKR-Regular.ttf');
      plexMono = _codePoints('fonts/IBMPlexMono-Regular.ttf');
      sofia = _codePoints('fonts/SofiaSansExtraCondensed-Bold.ttf');
    });

    test('the body, mono and label faces carry no ideographs, so the fallback order decides their design', () {
      for (final int c in '警戒冷却水圧'.runes) {
        expect(plexSans.contains(c), isFalse);
        expect(plexMono.contains(c), isFalse);
        expect(sofia.contains(c), isFalse);
      }
      // Hangul and Latin are the body face's own.
      for (final int c in '경보 Alert 042.7'.runes) {
        expect(plexSans.contains(c), isTrue, reason: String.fromCharCode(c));
      }
    });

    test('Noto Serif KR lacks Japanese forms that Zen Old Mincho has', () {
      // With Noto first, these few came from Zen and their neighbours from
      // Noto: 冷却水 in one design and 圧 in another.
      final List<int> onlyZen = <int>[
        for (final int c in '圧対数様歴残温炉状継覧録験'.runes)
          if (zen.contains(c) && !noto.contains(c)) c,
      ];
      expect(onlyZen, isNotEmpty);
      for (final int c in '冷却水'.runes) {
        expect(zen.contains(c) && noto.contains(c), isTrue);
      }
    });

    test('every ideograph the package and its example write is in Zen Old Mincho', () {
      final Map<int, String> used = _ideographsIn(<String>['lib', 'example/lib']);
      expect(used.length, greaterThan(200));
      final List<String> missing = <String>[
        for (final MapEntry<int, String> e in used.entries)
          if (!zen.contains(e.key)) '${String.fromCharCode(e.key)} (${e.value})',
      ];
      expect(missing, isEmpty, reason: 'these would be set in Noto Serif KR beside Zen Old Mincho glyphs');
    });

    test('Hangul in a display or label voice comes from Noto Serif KR', () {
      for (final int c in '경보'.runes) {
        expect(zen.contains(c), isFalse);
        expect(noto.contains(c), isTrue);
      }
    });
  });
}
