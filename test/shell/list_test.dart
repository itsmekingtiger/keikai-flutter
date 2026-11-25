import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/shell/shell_paint.dart';

import '../support/harness.dart';

KkItemGroundPainter _ground(WidgetTester tester, Finder row) => tester
    .widgetList<CustomPaint>(find.descendant(of: row, matching: find.byType(CustomPaint)))
    .map((CustomPaint p) => p.painter)
    .whereType<KkItemGroundPainter>()
    .first;

void main() {
  setUpAll(loadKkFonts);

  testWidgets('a row is at least 48px high; a second line makes it taller', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkList(
        children: <Widget>[
          KkListRow(key: ValueKey<String>('one'), cjk: '電源', en: 'power', meta: 'SEC-01'),
          KkListRow(key: ValueKey<String>('two'), cjk: '冷却', en: 'coolant', sub: '냉각수 압력 저하.', meta: 'SEC-04'),
        ],
      ),
      size: const Size(600, 400),
    );
    final Rect one = tester.getRect(find.byKey(const ValueKey<String>('one')));
    final Rect two = tester.getRect(find.byKey(const ValueKey<String>('two')));
    expect(one.width, 600);
    expect(one.height, 48);
    // 8px, the title line (two fonts on one baseline), 3px, the second line
    // (12px at 1.4) and 8px.
    final Rect title = tester.getRect(find.text('冷却')).expandToInclude(tester.getRect(find.text('COOLANT')));
    final Rect second = tester.getRect(find.text('냉각수 압력 저하.'));
    expect(title.top - two.top, closeTo(8, 0.01));
    expect(title.height, greaterThanOrEqualTo(14 * 1.55 - 0.01));
    expect(title.height, lessThan(14 * 1.55 + 3));
    expect(second.top - title.bottom, closeTo(3, 0.01));
    // Text boxes are whole pixels high.
    expect(second.height, closeTo(12 * 1.4, 0.5));
    expect(two.bottom - second.bottom, closeTo(8, 0.01));
    expect(two.height, greaterThan(48));
    // A 1px hairline between the rows, none after the last.
    expect(two.top - one.bottom, 1);
    expect(tester.getSize(find.byType(KkList)).height, one.height + 1 + two.height);
    const KkColors c = KkColors.standby;
    expect(tester.widget<Text>(find.text('電源')).style!.fontSize, 14);
    expect(tester.widget<Text>(find.text('POWER')).style!.fontSize, 12);
    expect(tester.widget<Text>(find.text('POWER')).style!.color, c.inkDim);
    expect(tester.widget<Text>(find.text('냉각수 압력 저하.')).style!.fontSize, 12);
    expect(tester.widget<Text>(find.text('SEC-01')).style!.fontSize, 11);
    // 12px padding at the sides; meta at the right.
    expect(tester.getTopLeft(find.text('電源')).dx, 12);
    expect(tester.getTopRight(find.text('SEC-01')).dx, 600 - 12);
    final KkBox ground = tester.widget<KkBox>(
      find.descendant(of: find.byType(KkList), matching: find.byType(KkBox)).first,
    );
    expect(ground.fill, c.bg100);
  });

  testWidgets('dense rows are 32px and drop the second line', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkList(
        dense: true,
        children: <Widget>[
          KkListRow(key: ValueKey<String>('one'), cjk: '電源', en: 'power', sub: 'HIDDEN', meta: 'SEC-01'),
          KkListRow(key: ValueKey<String>('two'), cjk: '冷却', en: 'coolant', dense: false, sub: 'SHOWN'),
        ],
      ),
      size: const Size(600, 400),
    );
    expect(tester.getSize(find.byKey(const ValueKey<String>('one'))).height, 32);
    expect(find.text('HIDDEN'), findsNothing);
    // A row can opt out of the list's density.
    expect(find.text('SHOWN'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey<String>('two'))).height, greaterThan(48));
  });

  testWidgets('a row sizes to its content when the height is only limited', (WidgetTester tester) async {
    // Loose constraints with a finite maximum must not blow the row up.
    await pumpKk(
      tester,
      const KkListRow(level: KkLevel.nominal, cjk: '電源', en: 'power'),
      size: const Size(600, 400),
    );
    expect(tester.getSize(find.byType(KkListRow)), const Size(600, 48));
  });

  testWidgets('the leading slot is 16px wide: level icon, icon or widget, in the level colour', (
    WidgetTester tester,
  ) async {
    await pumpKk(
      tester,
      const KkList(
        children: <Widget>[
          KkListRow(level: KkLevel.caution, cjk: '中継'),
          KkListRow(icon: KkIcons.lock, level: KkLevel.critical, cjk: '封鎖'),
          KkListRow(leading: KkText.num('07'), cjk: '記録'),
          KkListRow(cjk: '無'),
        ],
      ),
      size: const Size(600, 400),
    );
    const KkColors c = KkColors.standby;
    final KkGlyph glyph = tester.widget<KkGlyph>(find.byType(KkGlyph));
    expect(glyph.level, KkLevel.caution);
    expect(glyph.color, c.caution);
    expect(tester.widget<KkIcon>(find.byType(KkIcon)).color, c.alert);
    expect(tester.widget<Text>(find.text('07')).style!.color, c.inkDim);
    // Titles line up after the 16px slot and the 12px gap; without a slot they start at the padding.
    expect(tester.getTopLeft(find.text('中継')).dx, 12 + 16 + 12);
    expect(tester.getTopLeft(find.text('封鎖')).dx, 12 + 16 + 12);
    expect(tester.getTopLeft(find.text('無')).dx, 12);
    expect(tester.getRect(find.byType(KkGlyph)).center.dx, 12 + 8);
  });

  testWidgets('a tappable row reports taps and long presses and lights up under the pointer', (
    WidgetTester tester,
  ) async {
    // A desk with a mouse: hover feedback is off while the last input was touch.
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    int taps = 0;
    int holds = 0;
    await pumpKk(
      tester,
      KkList(
        children: <Widget>[
          KkListRow(cjk: '電源', en: 'power', onPressed: () => taps++, onLongPress: () => holds++),
          const KkListRow(cjk: '冷却', en: 'coolant'),
        ],
      ),
      size: const Size(600, 400),
    );
    await tester.tap(find.text('POWER'));
    expect(taps, 1);
    await tester.longPress(find.text('POWER'));
    await tester.pump(kLongPressTimeout);
    expect(holds, 1);

    final Finder row = find.byType(KkListRow).first;
    expect(_ground(tester, row).fill, isNull);
    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(590, 390));
    await mouse.moveTo(tester.getCenter(row));
    await tester.pump();
    expect(_ground(tester, row).fill, KkColors.standby.bg200);
    // A row that is not a button does not react.
    await mouse.moveTo(tester.getCenter(find.byType(KkListRow).last));
    await tester.pump();
    expect(_ground(tester, find.byType(KkListRow).last).fill, isNull);
    expect(_ground(tester, row).fill, isNull);
    await mouse.removePointer();
  });

  testWidgets('Enter activates the focused row; the ring is drawn inside it', (WidgetTester tester) async {
    int taps = 0;
    await pumpKk(
      tester,
      KkList(
        children: <Widget>[KkListRow(cjk: '電源', en: 'power', onPressed: () => taps++)],
      ),
      size: const Size(600, 400),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final KkFocusRing ring = tester.widget<KkFocusRing>(
      find.descendant(of: find.byType(KkListRow), matching: find.byType(KkFocusRing)),
    );
    expect(ring.visible, isTrue);
    expect(ring.offset, -2);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('the current row: lightest ground, signal subtitle, the mark, selected for screen readers', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpKk(
      tester,
      KkList(
        children: <Widget>[
          KkListRow(cjk: '中継', en: 'relay', current: true, onPressed: () {}),
          const KkListRow(cjk: '静的', en: 'static', current: true),
        ],
      ),
      size: const Size(600, 400),
    );
    const KkColors c = KkColors.standby;
    for (final Finder row in <Finder>[find.byType(KkListRow).first, find.byType(KkListRow).last]) {
      final KkItemGroundPainter ground = _ground(tester, row);
      expect(ground.fill, c.bg300);
      expect(ground.mark, KkItemMark.left);
      expect(ground.markColor, c.signal);
      expect(ground.thickness, 4);
      expect(ground.length, 16);
    }
    expect(tester.widget<Text>(find.text('RELAY')).style!.color, c.signal);
    expect(
      tester.getSemantics(find.text('RELAY')),
      isSemantics(isButton: true, isSelected: true, hasSelectedState: true),
    );
    handle.dispose();
  });

  testWidgets('a disabled row is faint, has no mark and ignores presses', (WidgetTester tester) async {
    int taps = 0;
    await pumpKk(
      tester,
      KkList(
        children: <Widget>[
          KkListRow(
            icon: KkIcons.lock,
            level: KkLevel.critical,
            cjk: '封鎖',
            en: 'lockdown',
            sub: '권한 없음.',
            meta: 'SEC-00',
            current: true,
            enabled: false,
            onPressed: () => taps++,
          ),
        ],
      ),
      size: const Size(600, 400),
    );
    const KkColors c = KkColors.standby;
    await tester.tap(find.text('LOCKDOWN'));
    expect(taps, 0);
    for (final String text in <String>['封鎖', 'LOCKDOWN', '권한 없음.', 'SEC-00']) {
      expect(tester.widget<Text>(find.text(text)).style!.color, c.inkFaint, reason: text);
    }
    expect(tester.widget<KkIcon>(find.byType(KkIcon)).color, c.inkFaint);
    final KkItemGroundPainter ground = _ground(tester, find.byType(KkListRow));
    expect(ground.fill, isNull);
    expect(ground.mark, KkItemMark.none);
  });

  testWidgets('a trailing widget and a custom title are placed; long text is cut, not wrapped', (
    WidgetTester tester,
  ) async {
    await pumpKk(
      tester,
      KkBox(
        width: 240,
        child: KkList(
          separated: false,
          fill: KkColors.standby.bg200,
          children: <Widget>[
            const KkListRow(
              key: ValueKey<String>('long'),
              cjk: '冷却系統異常警報',
              en: 'a latin subtitle that is far too long for the row',
              sub: 'A SECOND LINE THAT IS ALSO FAR TOO LONG TO FIT IN TWO HUNDRED AND FORTY PIXELS',
              meta: '14:02:31Z',
              trailing: KkStatusTag.status(KkLevel.nominal),
            ),
            KkListRow(key: const ValueKey<String>('custom'), title: const KkText('CUSTOM TITLE'), onPressed: () {}),
          ],
        ),
      ),
      size: const Size(600, 400),
    );
    expect(tester.takeException(), isNull);
    final Rect row = tester.getRect(find.byKey(const ValueKey<String>('long')));
    expect(row.width, 240);
    expect(tester.getRect(find.byType(KkStatusTag)).right, 240 - 12);
    // One line each: the row is no taller than a two-line row.
    expect(row.height, lessThan(64));
    expect(find.text('CUSTOM TITLE'), findsOneWidget);
    // No hairline when separated is off.
    expect(tester.getRect(find.byKey(const ValueKey<String>('custom'))).top, row.bottom);
    final KkBox ground = tester.widget<KkBox>(
      find.descendant(of: find.byType(KkList), matching: find.byType(KkBox)).first,
    );
    expect(ground.fill, KkColors.standby.bg200);
  });

  testWidgets('KkList.builder builds only the rows near the view and scrolls', (WidgetTester tester) async {
    final Set<int> built = <int>{};
    await pumpKk(
      tester,
      KkBox(
        height: 300,
        child: KkList.builder(
          dense: true,
          itemCount: 1000,
          itemBuilder: (BuildContext context, int index) {
            built.add(index);
            return KkListRow(cjk: '区', en: 'sector $index', meta: '$index');
          },
        ),
      ),
      size: const Size(600, 400),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('SECTOR 0'), findsOneWidget);
    expect(find.text('SECTOR 999'), findsNothing);
    expect(built.length, lessThan(60));
    // 32px rows and a 1px hairline.
    expect(tester.getTopLeft(find.text('SECTOR 1')).dy - tester.getTopLeft(find.text('SECTOR 0')).dy, 33);
    await tester.drag(find.text('SECTOR 3'), const Offset(0, -2000));
    await tester.pump();
    expect(find.text('SECTOR 0'), findsNothing);
    expect(built.any((int i) => i > 40), isTrue);
  });

  testWidgets('an empty list and both themes are fine', (WidgetTester tester) async {
    await pumpKk(tester, const KkList(children: <Widget>[]));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(KkList)).height, 0);
    await pumpKk(tester, KkList.builder(itemCount: 0, itemBuilder: (BuildContext c, int i) => null));
    expect(tester.takeException(), isNull);
    await pumpKk(
      tester,
      KkList(
        children: <Widget>[KkListRow(cjk: '中継', en: 'relay', current: true, onPressed: () {})],
      ),
      condition: KkCondition.alert,
    );
    expect(_ground(tester, find.byType(KkListRow)).fill, KkColors.alertTheme.bg300);
    expect(tester.widget<Text>(find.text('RELAY')).style!.color, KkColors.alertTheme.signal);
  });
}
