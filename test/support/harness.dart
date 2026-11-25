import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

const Map<String, List<String>> _fontFiles = <String, List<String>>{
  'Zen Old Mincho': <String>['ZenOldMincho-Black.ttf'],
  'Noto Serif KR': <String>['NotoSerifKR-Black.ttf'],
  'Sofia Sans Extra Condensed': <String>[
    'SofiaSansExtraCondensed-SemiBold.ttf',
    'SofiaSansExtraCondensed-Bold.ttf',
    'SofiaSansExtraCondensed-ExtraBold.ttf',
  ],
  'IBM Plex Mono': <String>['IBMPlexMono-Regular.ttf', 'IBMPlexMono-Medium.ttf', 'IBMPlexMono-SemiBold.ttf'],
  'IBM Plex Sans KR': <String>['IBMPlexSansKR-Regular.ttf', 'IBMPlexSansKR-Medium.ttf', 'IBMPlexSansKR-Bold.ttf'],
};

bool _fontsLoaded = false;

/// Loads the bundled KEIKAI fonts so text renders with real glyphs in tests.
/// Call it in `setUpAll`.
Future<void> loadKkFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final String root = Directory('fonts').existsSync() ? 'fonts' : '../fonts';
  for (final MapEntry<String, List<String>> family in _fontFiles.entries) {
    final FontLoader loader = FontLoader('packages/keikai/${family.key}');
    for (final String file in family.value) {
      final Uint8List bytes = File('$root/$file').readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

/// A [KeikaiApp] around [child] for tests.
///
/// Motion is off unless [motion] is true, so `pumpAndSettle` works.
Widget kkHarness(
  Widget child, {
  KkCondition condition = KkCondition.standby,
  bool motion = false,
  KeikaiThemeData theme = const KeikaiThemeData(),
  Alignment? alignment = Alignment.topLeft,
  EdgeInsets padding = EdgeInsets.zero,
  bool grid = false,
}) {
  return KeikaiApp(
    theme: theme.copyWith(motion: motion ? theme.motion : KkMotion.off),
    condition: condition,
    home: Builder(
      builder: (BuildContext context) {
        final KkColors c = KeikaiTheme.of(context).colors;
        return KkBox(
          decoration: KkDecoration(fill: c.bg000, pattern: grid ? KkPattern.grid(color: c.grid) : null),
          alignment: alignment,
          padding: padding,
          child: child,
        );
      },
    ),
  );
}

/// Pumps [child] inside [kkHarness] on a surface of [size] logical pixels.
Future<void> pumpKk(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(800, 600),
  double pixelRatio = 1,
  KkCondition condition = KkCondition.standby,
  bool motion = false,
  KeikaiThemeData theme = const KeikaiThemeData(),
  Alignment? alignment = Alignment.topLeft,
  EdgeInsets padding = EdgeInsets.zero,
  bool grid = false,
}) async {
  tester.view.devicePixelRatio = pixelRatio;
  tester.view.physicalSize = size * pixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    kkHarness(
      child,
      condition: condition,
      motion: motion,
      theme: theme,
      alignment: alignment,
      padding: padding,
      grid: grid,
    ),
  );
  await tester.pump();
}

/// Compares the whole screen with `goldens/<name>.png` next to the test file.
/// Run `flutter test --update-goldens` to (re)write the images.
///
/// The images are rendered on Linux. Glyph rasterisation differs on other
/// platforms, so there the comparison is skipped unless goldens are being
/// updated.
Future<void> expectKkGolden(WidgetTester tester, String name) async {
  if (!Platform.isLinux && !autoUpdateGoldenFiles) return;
  await expectLater(find.byType(KeikaiApp), matchesGoldenFile('goldens/$name.png'));
}

const Key _kkSheetKey = ValueKey<String>('kk-sheet');

/// Pumps a catalogue [sheet] at [width] logical pixels and sizes the surface
/// to the sheet's natural height, ready for [expectKkGolden].
Future<void> pumpKkSheet(
  WidgetTester tester,
  Widget sheet, {
  double width = 1440,
  double pixelRatio = 2,
  KkCondition condition = KkCondition.standby,
  bool motion = false,
  KeikaiThemeData theme = const KeikaiThemeData(),
}) async {
  await pumpKk(
    tester,
    KkScroll(
      child: KeyedSubtree(key: _kkSheetKey, child: sheet),
    ),
    size: Size(width, 6000),
    pixelRatio: pixelRatio,
    condition: condition,
    motion: motion,
    theme: theme,
    alignment: null,
  );
  final double height = tester.getSize(find.byKey(_kkSheetKey)).height.ceilToDouble();
  tester.view.physicalSize = Size(width, height) * pixelRatio;
  await tester.pump();
  await tester.pump();
}
