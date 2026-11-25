import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/shell/shell_paint.dart';

import '../support/harness.dart';

/// The ground painter of the shell item that shows [text].
KkItemGroundPainter _ground(WidgetTester tester, String text) => tester
    .widgetList<CustomPaint>(find.ancestor(of: find.text(text), matching: find.byType(CustomPaint)))
    .map((CustomPaint p) => p.painter)
    .whereType<KkItemGroundPainter>()
    .first;

Color? _ink(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style!.color;

const List<KkTab> _tabs = <KkTab>[
  KkTab(cjk: '状況', en: 'situation'),
  KkTab(cjk: '系統', en: 'systems'),
  KkTab(cjk: '封鎖', en: 'lockdown', enabled: false),
];

const List<KkNavItem> _destinations = <KkNavItem>[
  KkNavItem(icon: KkIcons.grid, label: 'board'),
  KkNavItem(icon: KkIcons.bell, label: 'alarms'),
  KkNavItem(icon: KkIcons.lock, label: 'secure', enabled: false),
];

const List<KkNavSection<String>> _sections = <KkNavSection<String>>[
  KkNavSection<String>(
    cjk: '監視',
    en: 'monitor',
    items: <KkNavDrawerItem<String>>[
      KkNavDrawerItem<String>(value: 'a', icon: KkIcons.grid, cjk: '状況', en: 'situation', meta: '12'),
      KkNavDrawerItem<String>(value: 'b', icon: KkIcons.bell, cjk: '警報', en: 'alarms', meta: '02'),
      KkNavDrawerItem<String>(value: 'c', icon: KkIcons.lock, cjk: '封鎖', en: 'lockdown', enabled: false),
    ],
  ),
];

/// A desk with a mouse: hover feedback is off while the last input was touch.
void _useMouse() {
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
}

Future<TestGesture> _hover(WidgetTester tester, Finder target) async {
  final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(790, 590));
  addTearDown(mouse.removePointer);
  await mouse.moveTo(tester.getCenter(target));
  await tester.pump();
  return mouse;
}

void main() {
  setUpAll(loadKkFonts);

  testWidgets('a tab under the pointer gets the bg-200 ground and full ink', (WidgetTester tester) async {
    _useMouse();
    await pumpKk(tester, KkTabs(tabs: _tabs, index: 0, onChanged: (int _) {}));
    const KkColors c = KkColors.standby;
    expect(_ground(tester, 'SYSTEMS').fill, isNull);
    expect(_ink(tester, '系統'), c.inkDim);
    expect(_ink(tester, 'SYSTEMS'), c.inkDim);

    final TestGesture mouse = await _hover(tester, find.text('SYSTEMS'));
    expect(_ground(tester, 'SYSTEMS').fill, c.bg200);
    expect(_ground(tester, 'SYSTEMS').mark, KkItemMark.none);
    expect(_ink(tester, '系統'), c.ink);
    expect(_ink(tester, 'SYSTEMS'), c.ink);
    // The selected tab keeps its signal subtitle and bar, and lights up too.
    await mouse.moveTo(tester.getCenter(find.text('SITUATION')));
    await tester.pump();
    expect(_ground(tester, 'SYSTEMS').fill, isNull);
    expect(_ground(tester, 'SITUATION').fill, c.bg200);
    expect(_ground(tester, 'SITUATION').mark, KkItemMark.bottom);
    expect(_ink(tester, 'SITUATION'), c.signal);
    // A disabled tab does not react.
    await mouse.moveTo(tester.getCenter(find.text('LOCKDOWN')));
    await tester.pump();
    expect(_ground(tester, 'LOCKDOWN').fill, isNull);
    expect(_ink(tester, 'LOCKDOWN'), c.inkFaint);
    expect(_ink(tester, '封鎖'), c.inkFaint);
  });

  testWidgets('a rail destination under the pointer gets the bg-200 ground and full ink', (WidgetTester tester) async {
    _useMouse();
    await pumpKk(
      tester,
      KkNavRail(items: _destinations, index: 0, onChanged: (int _) {}),
      size: const Size(800, 600),
    );
    const KkColors c = KkColors.standby;
    Color? icon(String label) => tester
        .widget<KkIcon>(
          find.descendant(
            of: find.ancestor(of: find.text(label), matching: find.byType(KkPressable)),
            matching: find.byType(KkIcon),
          ),
        )
        .color;
    expect(_ground(tester, 'ALARMS').fill, isNull);
    expect(_ink(tester, 'ALARMS'), c.inkDim);
    expect(icon('ALARMS'), c.inkDim);
    final TestGesture mouse = await _hover(tester, find.text('ALARMS'));
    expect(_ground(tester, 'ALARMS').fill, c.bg200);
    expect(_ground(tester, 'ALARMS').mark, KkItemMark.none);
    expect(_ink(tester, 'ALARMS'), c.ink);
    // Only the current destination has a signal icon.
    expect(icon('ALARMS'), c.ink);
    expect(icon('BOARD'), c.signal);
    await mouse.moveTo(tester.getCenter(find.text('SECURE')));
    await tester.pump();
    expect(_ground(tester, 'ALARMS').fill, isNull);
    expect(_ground(tester, 'SECURE').fill, isNull);
    expect(_ink(tester, 'SECURE'), c.inkFaint);
    expect(icon('SECURE'), c.inkFaint);
  });

  testWidgets('a drawer destination under the pointer gets bg-200; the current one stays bg-300', (
    WidgetTester tester,
  ) async {
    _useMouse();
    await pumpKk(
      tester,
      KkNavDrawer<String>(sections: _sections, value: 'a', onChanged: (String _) {}),
      size: const Size(800, 600),
    );
    const KkColors c = KkColors.standby;
    expect(_ground(tester, 'ALARMS').fill, isNull);
    expect(_ink(tester, 'ALARMS'), c.inkDim);
    final TestGesture mouse = await _hover(tester, find.text('ALARMS'));
    expect(_ground(tester, 'ALARMS').fill, c.bg200);
    expect(_ground(tester, 'ALARMS').mark, KkItemMark.none);
    expect(_ink(tester, 'ALARMS'), c.ink);
    // The title in 漢字 is full ink either way; the reading stays dim.
    expect(_ink(tester, '警報'), c.ink);
    expect(_ink(tester, '02'), c.inkDim);
    await mouse.moveTo(tester.getCenter(find.text('SITUATION')));
    await tester.pump();
    expect(_ground(tester, 'SITUATION').fill, c.bg300);
    expect(_ground(tester, 'SITUATION').mark, KkItemMark.left);
    await mouse.moveTo(tester.getCenter(find.text('LOCKDOWN')));
    await tester.pump();
    expect(_ground(tester, 'LOCKDOWN').fill, isNull);
    expect(_ink(tester, 'LOCKDOWN'), c.inkFaint);
  });

  testWidgets('a breadcrumb link is underlined under the pointer, 3px below its type', (WidgetTester tester) async {
    _useMouse();
    await pumpKk(
      tester,
      KkBreadcrumbs(
        items: <KkCrumb>[
          KkCrumb(en: 'board', onPressed: () {}),
          KkCrumb(en: 'systems', onPressed: () {}),
          const KkCrumb(en: 'pumps'),
        ],
      ),
      padding: const EdgeInsets.all(20),
    );
    const KkColors c = KkColors.standby;
    Finder link(String text) => find.ancestor(of: find.text(text), matching: find.byType(CustomPaint)).first;
    PaintPattern underline(Size size) => paints
      ..something((Symbol method, List<dynamic> arguments) {
        if (method != #drawRect) return false;
        final Object? rect = arguments[0];
        final Object? paint = arguments[1];
        // A paint keeps its colour in 32-bit floats: compare the 8-bit channels.
        return rect == Rect.fromLTWH(0, size.height - 3, size.width, 1) &&
            paint is Paint &&
            paint.color.toARGB32() == c.signal.toARGB32();
      });

    final Size size = tester.getSize(link('SYSTEMS'));
    expect(size.height, 18);
    expect(link('SYSTEMS'), isNot(underline(size)));
    final TestGesture mouse = await _hover(tester, find.text('SYSTEMS'));
    expect(link('SYSTEMS'), underline(size));
    expect(link('BOARD'), isNot(underline(tester.getSize(link('BOARD')))));
    // Links stay signal, the current page stays ink and never underlines.
    expect(_ink(tester, 'SYSTEMS'), c.signal);
    await mouse.moveTo(tester.getCenter(find.text('PUMPS')));
    await tester.pump();
    expect(link('SYSTEMS'), isNot(underline(size)));
    expect(_ink(tester, 'PUMPS'), c.ink);
    expect(
      find.ancestor(of: find.text('PUMPS'), matching: find.byType(CustomPaint)),
      findsNothing,
      reason: 'the current page has no link ground',
    );
  });

  testWidgets('KkStateOverride shows the hover and focus looks of shell items without input', (
    WidgetTester tester,
  ) async {
    await pumpKk(
      tester,
      KkStateOverride(
        hovered: true,
        focused: true,
        child: KkColumn(
          shrinkWrap: true,
          children: <Widget>[
            KkTabs(tabs: _tabs, index: 0, onChanged: (int _) {}),
            KkNavRail(items: _destinations, index: 0, onChanged: (int _) {}, bar: true),
            KkList(
              children: <Widget>[
                KkListRow(cjk: '記録', en: 'log', onPressed: () {}),
                const KkListRow(cjk: '静的', en: 'static'),
              ],
            ),
          ],
        ),
      ),
    );
    const KkColors c = KkColors.standby;
    expect(_ground(tester, 'SYSTEMS').fill, c.bg200);
    expect(_ground(tester, 'ALARMS').fill, c.bg200);
    expect(_ground(tester, 'LOG').fill, c.bg200);
    // Never on what is disabled or is no control.
    expect(_ground(tester, 'LOCKDOWN').fill, isNull);
    expect(_ground(tester, 'SECURE').fill, isNull);
    expect(_ground(tester, 'STATIC').fill, isNull);
    bool ring(String text) => tester
        .widget<KkFocusRing>(find.ancestor(of: find.text(text), matching: find.byType(KkFocusRing)).first)
        .visible;
    expect(ring('SYSTEMS'), isTrue);
    expect(ring('ALARMS'), isTrue);
    expect(ring('LOG'), isTrue);
    expect(ring('LOCKDOWN'), isFalse);
    expect(ring('SECURE'), isFalse);
    expect(ring('STATIC'), isFalse);
  });
}
