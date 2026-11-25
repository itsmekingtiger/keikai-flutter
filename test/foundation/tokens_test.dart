import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

/// The colour tokens of the design system (tokens.json), standby then alert.
const Map<String, (int, int)> _tokens = <String, (int, int)>{
  'bg-000': (0xFF050506, 0xFF080203),
  'bg-100': (0xFF0C0C0E, 0xFF120405),
  'bg-200': (0xFF16161A, 0xFF1E0709),
  'bg-300': (0xFF212127, 0xFF2C0B0E),
  'line': (0xFF643412, 0xFF6C1A1A),
  'grid': (0xFF190E08, 0xFF1E0708),
  'ink': (0xFFEFE9DD, 0xFFF7E8E4),
  'ink-dim': (0xFFA8A196, 0xFFBBA29D),
  'ink-faint': (0xFF857F75, 0xFF957D78),
  'signal': (0xFFFF7A1A, 0xFFFF3D3D),
  'signal-dim': (0xFF422410, 0xFF4B1212),
  'alert': (0xFFF8283C, 0xFFF8283C),
  'alert-deep': (0xFF8F0F1C, 0xFF8F0F1C),
  'caution': (0xFFFFD21F, 0xFFFFD21F),
  'nominal': (0xFF5CFF9D, 0xFF5CFF9D),
  'offline': (0xFF8F8A82, 0xFF958985),
  'on-fill': (0xFF0A0705, 0xFF0A0303),
  'series-1': (0xFFE8660F, 0xFFE8660F),
  'series-2': (0xFF2F9BE0, 0xFF2F9BE0),
  'series-3': (0xFFD65BB0, 0xFFD65BB0),
  'focus': (0xFFFFF3DC, 0xFFFFF3DC),
};

Map<String, Color> _named(KkColors c) => <String, Color>{
  'bg-000': c.bg000,
  'bg-100': c.bg100,
  'bg-200': c.bg200,
  'bg-300': c.bg300,
  'line': c.line,
  'grid': c.grid,
  'ink': c.ink,
  'ink-dim': c.inkDim,
  'ink-faint': c.inkFaint,
  'signal': c.signal,
  'signal-dim': c.signalDim,
  'alert': c.alert,
  'alert-deep': c.alertDeep,
  'caution': c.caution,
  'nominal': c.nominal,
  'offline': c.offline,
  'on-fill': c.onFill,
  'series-1': c.series1,
  'series-2': c.series2,
  'series-3': c.series3,
  'focus': c.focus,
};

void main() {
  group('KkMetrics', () {
    const KkMetrics m = KkMetrics();

    test('defaults are the design system tokens', () {
      expect(<double>[m.space1, m.space2, m.space3, m.space4, m.space6, m.space8, m.space12], <double>[
        4,
        8,
        12,
        16,
        24,
        32,
        48,
      ]);
      expect(<double>[m.stroke1, m.stroke2, m.stroke4], <double>[1, 2, 4]);
      expect(<double>[m.chamferSm, m.chamferMd, m.chamferLg], <double>[6, 10, 14]);
      expect(<double>[m.pitchFine, m.pitchGrid, m.pitchHazard, m.pitchHex], <double>[8, 24, 12, 64]);
      expect(m.gridGutter, 8);
      expect(m.gridMargin, 16);
      expect(m.rowUnit, 48);
      expect(m.cmdbarHeight, 48);
      expect(m.toolbarHeight, 32);
      expect(m.railWidth, 72);
      expect(m.drawerWidth, 256);
      expect(m.sheetWidth, 400);
      expect(m.dialogWidth, 520);
      expect(<double>[m.bpMedium, m.bpExpanded, m.bpLarge, m.bpXlarge, m.bpWall], <double>[600, 840, 1200, 1600, 2560]);
    });

    test('windowClass at every threshold', () {
      expect(m.windowClass(0), KkWindowClass.compact);
      expect(m.windowClass(599.9), KkWindowClass.compact);
      expect(m.windowClass(600), KkWindowClass.medium);
      expect(m.windowClass(839.9), KkWindowClass.medium);
      expect(m.windowClass(840), KkWindowClass.expanded);
      expect(m.windowClass(1199.9), KkWindowClass.expanded);
      expect(m.windowClass(1200), KkWindowClass.large);
      expect(m.windowClass(1599.9), KkWindowClass.large);
      expect(m.windowClass(1600), KkWindowClass.xlarge);
      expect(m.windowClass(2559.9), KkWindowClass.xlarge);
      expect(m.windowClass(2560), KkWindowClass.wall);
      expect(m.windowClass(double.infinity), KkWindowClass.wall);
    });

    test('columnsFor: 4 / 8 / 12 / 16 / 24, with no change at 1200', () {
      expect(m.columnsFor(0), 4);
      expect(m.columnsFor(599), 4);
      expect(m.columnsFor(600), 8);
      expect(m.columnsFor(839), 8);
      expect(m.columnsFor(840), 12);
      expect(m.columnsFor(1200), 12);
      expect(m.columnsFor(1599), 12);
      expect(m.columnsFor(1600), 16);
      expect(m.columnsFor(2559), 16);
      expect(m.columnsFor(2560), 24);
    });

    test('marginFor: 8 compact, 32 wall, 16 between', () {
      expect(m.marginFor(320), 8);
      expect(m.marginFor(599), 8);
      expect(m.marginFor(600), 16);
      expect(m.marginFor(1920), 16);
      expect(m.marginFor(2559), 16);
      expect(m.marginFor(2560), 32);
    });

    test('rowsHeight: n×rowUnit + (n−1)×gutter', () {
      expect(m.rowsHeight(1), 48);
      expect(m.rowsHeight(2), 104);
      expect(m.rowsHeight(4), 216);
      expect(const KkMetrics(rowUnit: 40, gridGutter: 4).rowsHeight(3), 128);
    });

    test('copyWith replaces exactly the named field', () {
      final List<KkMetrics> copies = <KkMetrics>[
        m.copyWith(space1: 99),
        m.copyWith(space2: 99),
        m.copyWith(space3: 99),
        m.copyWith(space4: 99),
        m.copyWith(space6: 99),
        m.copyWith(space8: 99),
        m.copyWith(space12: 99),
        m.copyWith(stroke1: 99),
        m.copyWith(stroke2: 99),
        m.copyWith(stroke4: 99),
        m.copyWith(chamferSm: 99),
        m.copyWith(chamferMd: 99),
        m.copyWith(chamferLg: 99),
        m.copyWith(pitchFine: 99),
        m.copyWith(pitchGrid: 99),
        m.copyWith(pitchHazard: 99),
        m.copyWith(pitchHex: 99),
        m.copyWith(gridGutter: 99),
        m.copyWith(gridMargin: 99),
        m.copyWith(rowUnit: 99),
        m.copyWith(cmdbarHeight: 99),
        m.copyWith(toolbarHeight: 99),
        m.copyWith(railWidth: 99),
        m.copyWith(drawerWidth: 99),
        m.copyWith(sheetWidth: 99),
        m.copyWith(dialogWidth: 99),
        m.copyWith(bpMedium: 99),
        m.copyWith(bpExpanded: 99),
        m.copyWith(bpLarge: 99),
        m.copyWith(bpXlarge: 99),
        m.copyWith(bpWall: 99),
      ];
      // Every copy differs from the original and from every other copy.
      for (int i = 0; i < copies.length; i++) {
        expect(copies[i] == m, isFalse, reason: 'copy $i');
        for (int j = i + 1; j < copies.length; j++) {
          expect(copies[i] == copies[j], isFalse, reason: 'copies $i and $j');
        }
      }
      expect(copies[0].space1, 99);
      expect(copies[19].rowUnit, 99);
      expect(copies[30].bpWall, 99);
      expect(m.copyWith(), m);
    });

    test('equality and hash', () {
      expect(const KkMetrics(), const KkMetrics());
      expect(const KkMetrics().hashCode, const KkMetrics().hashCode);
      expect(const KkMetrics(rowUnit: 40) == const KkMetrics(), isFalse);
      expect(const KkMetrics(rowUnit: 40), const KkMetrics(rowUnit: 40));
    });

    test('custom breakpoints drive the classes', () {
      const KkMetrics custom = KkMetrics(bpMedium: 500, bpExpanded: 700);
      expect(custom.windowClass(550), KkWindowClass.medium);
      expect(custom.columnsFor(550), 8);
      expect(custom.columnsFor(700), 12);
      expect(custom.marginFor(499), 8);
    });
  });

  test('KkLayer: alarms are always on top', () {
    expect(
      <int>[KkLayer.base, KkLayer.sticky, KkLayer.overlay, KkLayer.sheet, KkLayer.modal, KkLayer.toast, KkLayer.alert],
      <int>[0, 10, 100, 200, 300, 400, 500],
    );
  });

  group('KkLevel', () {
    test('words in three scripts', () {
      expect(<String>[for (final KkLevel l in KkLevel.values) l.word], <String>[
        'NOMINAL',
        'CAUTION',
        'CRITICAL',
        'OFFLINE',
      ]);
      expect(<String>[for (final KkLevel l in KkLevel.values) l.cjk], <String>['正常', '注意', '警報', '断線']);
      expect(<String>[for (final KkLevel l in KkLevel.values) l.ko], <String>['정상', '주의', '경보', '단절']);
    });

    test('severity orders nominal < offline < caution < critical', () {
      final List<KkLevel> sorted = KkLevel.values.toList()
        ..sort((KkLevel a, KkLevel b) => a.severity.compareTo(b.severity));
      expect(sorted, <KkLevel>[KkLevel.nominal, KkLevel.offline, KkLevel.caution, KkLevel.critical]);
    });

    test('two conditions', () {
      expect(KkCondition.values, <KkCondition>[KkCondition.standby, KkCondition.alert]);
    });
  });

  group('KkColors', () {
    test('standby matches the tokens exactly', () {
      final Map<String, Color> named = _named(KkColors.standby);
      expect(named.keys.toSet(), _tokens.keys.toSet());
      for (final MapEntry<String, (int, int)> e in _tokens.entries) {
        expect(named[e.key]!.toARGB32(), e.value.$1, reason: e.key);
      }
    });

    test('alert matches the tokens exactly', () {
      final Map<String, Color> named = _named(KkColors.alertTheme);
      for (final MapEntry<String, (int, int)> e in _tokens.entries) {
        expect(named[e.key]!.toARGB32(), e.value.$2, reason: e.key);
      }
    });

    test('status and series colours are the same in both themes', () {
      for (final String name in <String>['alert', 'alert-deep', 'caution', 'nominal', 'series-1', 'series-2', 'series-3', 'focus']) {
        expect(_named(KkColors.standby)[name], _named(KkColors.alertTheme)[name], reason: name);
      }
      expect(KkColors.standby.signal == KkColors.alertTheme.signal, isFalse);
    });

    test('level() maps each level and falls back to signal', () {
      const KkColors c = KkColors.standby;
      expect(c.level(KkLevel.nominal), c.nominal);
      expect(c.level(KkLevel.caution), c.caution);
      expect(c.level(KkLevel.critical), c.alert);
      expect(c.level(KkLevel.offline), c.offline);
      expect(c.level(null), c.signal);
      expect(c.level(null, fallback: c.inkDim), c.inkDim);
      expect(c.level(KkLevel.nominal, fallback: c.inkDim), c.nominal);
    });

    test('series are in their fixed order', () {
      const KkColors c = KkColors.standby;
      expect(c.series, <Color>[c.series1, c.series2, c.series3]);
    });

    test('glows', () {
      const KkColors s = KkColors.standby;
      expect(s.glowSignal, const KkGlow(color: Color(0xFFFF7A1A), ring: 1, blur: 18, alpha: 0.3));
      expect(KkColors.alertTheme.glowSignal, const KkGlow(color: Color(0xFFFF3D3D), ring: 1, blur: 18, alpha: 0.35));
      expect(s.glowAlert, const KkGlow(color: Color(0xFFF8283C), ring: 1, blur: 22, alpha: 0.45));
      expect(s.glowTrace, const KkGlow(color: Color(0xFF5CFF9D), ring: 0, blur: 4, alpha: 0.6));
      expect(s.glowSignal.hashCode, const KkGlow(color: Color(0xFFFF7A1A)).hashCode);
      expect(s.glowSignal == s.glowAlert, isFalse);
    });

    test('ramp: signal at 8 / 22 / 42 / 68 / 100 % over the ground, then toward ink', () {
      for (final KkColors c in <KkColors>[KkColors.standby, KkColors.alertTheme]) {
        final List<Color> ramp = c.ramp;
        expect(ramp, hasLength(6));
        expect(ramp[4], c.signal);
        // color-mix(in srgb, signal 8%, bg-000) lands on the theme's grid colour
        // (the tokens round it by hand, so allow a couple of steps).
        expect(_channelDistance(ramp[0], c.grid), lessThanOrEqualTo(2));
        // Each step is brighter than the last.
        for (int i = 1; i < ramp.length; i++) {
          expect(ramp[i].computeLuminance(), greaterThan(ramp[i - 1].computeLuminance()), reason: 'step $i');
        }
        for (final Color q in ramp) {
          expect(q.a, 1);
        }
      }
      // Spot values for standby.
      expect(KkColors.standby.ramp[1].toARGB32(), kkMix(KkColors.standby.signal, 0.22, KkColors.standby.bg000).toARGB32());
      expect(KkColors.standby.ramp[5].toARGB32(), kkMix(KkColors.standby.ink, 0.55, KkColors.standby.signal).toARGB32());
    });

    test('scrims are the ground at 78% and 70%', () {
      const KkColors c = KkColors.standby;
      expect(c.scrim.a, closeTo(0.78, 1e-6));
      expect(c.scrimSheet.a, closeTo(0.70, 1e-6));
      expect(c.scrim.withValues(alpha: 1), c.bg000);
    });

    test('kkMix and kkFade', () {
      const Color a = Color(0xFFFF0000);
      const Color b = Color(0xFF0000FF);
      expect(kkMix(a, 0, b), b);
      expect(kkMix(a, 1, b), a);
      final Color mid = kkMix(a, 0.5, b);
      expect(mid.r, closeTo(0.5, 1e-6));
      expect(mid.b, closeTo(0.5, 1e-6));
      expect(mid.a, 1);
      expect(kkFade(a, 0.5).a, closeTo(0.5, 1e-6));
      expect(kkFade(const Color(0x80FF0000), 0.5).a, closeTo(0x80 / 255 / 2, 1e-6));
      expect(kkFade(a, 0.5).r, 1);
      expect(kkFade(a, 0).a, 0);
    });

    test('copyWith replaces exactly the named colour', () {
      const KkColors c = KkColors.standby;
      const Color x = Color(0xFF123456);
      final List<KkColors> copies = <KkColors>[
        c.copyWith(bg000: x),
        c.copyWith(bg100: x),
        c.copyWith(bg200: x),
        c.copyWith(bg300: x),
        c.copyWith(line: x),
        c.copyWith(grid: x),
        c.copyWith(ink: x),
        c.copyWith(inkDim: x),
        c.copyWith(inkFaint: x),
        c.copyWith(signal: x),
        c.copyWith(signalDim: x),
        c.copyWith(alert: x),
        c.copyWith(alertDeep: x),
        c.copyWith(caution: x),
        c.copyWith(nominal: x),
        c.copyWith(offline: x),
        c.copyWith(onFill: x),
        c.copyWith(series1: x),
        c.copyWith(series2: x),
        c.copyWith(series3: x),
        c.copyWith(focus: x),
        c.copyWith(glowSignalAlpha: 0.9),
      ];
      for (int i = 0; i < copies.length; i++) {
        expect(copies[i] == c, isFalse, reason: 'copy $i');
        for (int j = i + 1; j < copies.length; j++) {
          expect(copies[i] == copies[j], isFalse, reason: 'copies $i and $j');
        }
      }
      final List<Color> changed = _named(copies[9]).values.where((Color v) => v == x).toList();
      expect(changed, hasLength(1));
      expect(copies[9].signal, x);
      expect(c.copyWith(), c);
      expect(c.copyWith().hashCode, c.hashCode);
    });
  });

  group('KkTypography', () {
    const KkTypography t = KkTypography();

    test('families are the bundled ones, addressed through the package', () {
      expect(t.display(14).fontFamily, 'packages/keikai/Zen Old Mincho');
      expect(t.display(14).fontFamilyFallback, <String>['packages/keikai/Noto Serif KR']);
      expect(t.label(14).fontFamily, 'packages/keikai/Sofia Sans Extra Condensed');
      expect(t.label(14).fontFamilyFallback, <String>['packages/keikai/Zen Old Mincho', 'packages/keikai/Noto Serif KR']);
      expect(t.mono(14).fontFamily, 'packages/keikai/IBM Plex Mono');
      expect(t.body(14).fontFamily, 'packages/keikai/IBM Plex Sans KR');
    });

    test('without a package the plain family names are used', () {
      final KkTypography plain = t.copyWith(clearPackage: true);
      expect(plain.package, isNull);
      expect(plain.display(14).fontFamily, 'Zen Old Mincho');
      expect(plain.display(14).fontFamilyFallback, <String>['Noto Serif KR']);
      expect(plain.mono(14).fontFamily, 'IBM Plex Mono');
      const KkTypography custom = KkTypography(
        displayFamily: 'A',
        labelFamily: 'B',
        monoFamily: 'C',
        bodyFamily: 'D',
        package: 'brand',
      );
      expect(custom.display(10).fontFamily, 'packages/brand/A');
      expect(custom.label(10).fontFamily, 'packages/brand/B');
      expect(custom.mono(10).fontFamily, 'packages/brand/C');
      expect(custom.body(10).fontFamily, 'packages/brand/D');
    });

    test('display is always weight 900; mono has tabular, slashed-zero figures', () {
      expect(t.display(20).fontWeight, FontWeight.w900);
      expect(t.mono(12).fontFeatures, const <FontFeature>[FontFeature.tabularFigures(), FontFeature.slashedZero()]);
      expect(t.label(12).fontFeatures, isNull);
    });

    test('tracking is given in em and stored in px', () {
      expect(t.label(10, spacingEm: 0.14).letterSpacing, closeTo(1.4, 1e-9));
      expect(t.display(50, spacingEm: -0.02).letterSpacing, closeTo(-1, 1e-9));
      expect(t.mono(20, spacingEm: 0.06).letterSpacing, closeTo(1.2, 1e-9));
      expect(t.body(14).letterSpacing, 0);
    });

    test('every style stands alone: no inheritance, no decoration, even leading', () {
      for (final TextStyle s in <TextStyle>[t.display(10), t.label(10), t.mono(10), t.body(10)]) {
        expect(s.inherit, isFalse);
        expect(s.decoration, TextDecoration.none);
        expect(s.leadingDistribution, TextLeadingDistribution.even);
        expect(s.textBaseline, TextBaseline.alphabetic);
      }
      expect(t.body(14, color: const Color(0xFF010203)).color, const Color(0xFF010203));
    });

    test('the named scale matches the design system', () {
      void check(TextStyle s, double size, double height, FontWeight weight, double spacingEm) {
        expect(s.fontSize, size);
        expect(s.height, height);
        expect(s.fontWeight, weight);
        expect(s.letterSpacing, closeTo(spacingEm * size, 1e-9));
      }

      check(t.displayXl, 72, 0.95, FontWeight.w900, -0.02);
      check(t.displayLg, 44, 1.0, FontWeight.w900, -0.01);
      check(t.displayMd, 24, 1.1, FontWeight.w900, 0);
      check(t.displaySm, 17, 1.15, FontWeight.w900, 0);
      check(t.labelXl, 32, 1.0, FontWeight.w800, 0.01);
      check(t.labelLg, 20, 1.1, FontWeight.w700, 0.04);
      check(t.labelMd, 13, 1.2, FontWeight.w700, 0.1);
      check(t.labelSm, 11, 1.2, FontWeight.w600, 0.14);
      check(t.readoutXl, 56, 1.0, FontWeight.w500, -0.03);
      check(t.readout, 32, 1.0, FontWeight.w500, -0.01);
      check(t.data, 12, 1.5, FontWeight.w400, 0);
      check(t.bodyMd, 14, 1.55, FontWeight.w400, 0);
      check(t.bodySm, 12, 1.5, FontWeight.w400, 0);
    });

    test('scale multiplies sizes and tracking (wall displays use 1.25)', () {
      const KkTypography wall = KkTypography(scale: 1.25);
      expect(wall.body(16).fontSize, 20);
      expect(wall.label(10, spacingEm: 0.1).letterSpacing, closeTo(1.25, 1e-9));
      expect(wall.displayXl.fontSize, 90);
      expect(wall.display(10).height, 1.0);
    });

    test('copyWith and equality', () {
      expect(t.copyWith(scale: 2).scale, 2);
      expect(t.copyWith(monoFamily: 'X').monoFamily, 'X');
      expect(t.copyWith(displayFallback: const <String>['Y']).displayFallback, <String>['Y']);
      expect(t.copyWith(package: 'other').package, 'other');
      expect(t.copyWith(), t);
      expect(t.copyWith().hashCode, t.hashCode);
      expect(t == t.copyWith(scale: 2), isFalse);
      expect(t == t.copyWith(labelFallback: const <String>['Z']), isFalse);
      expect(const KkTypography(displayFallback: <String>['Noto Serif KR']), t);
    });
  });
}

int _channelDistance(Color a, Color b) {
  final int x = a.toARGB32();
  final int y = b.toARGB32();
  int worst = 0;
  for (final int shift in <int>[0, 8, 16, 24]) {
    final int d = (((x >> shift) & 0xFF) - ((y >> shift) & 0xFF)).abs();
    if (d > worst) worst = d;
  }
  return worst;
}
