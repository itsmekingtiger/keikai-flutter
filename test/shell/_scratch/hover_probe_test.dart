import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/shell/shell.dart';
import 'package:keikai/src/shell/shell_paint.dart';

import '../../support/harness.dart';

KkItemGroundPainter _ground(WidgetTester tester, Finder row) => tester
    .widgetList<CustomPaint>(find.descendant(of: row, matching: find.byType(CustomPaint)))
    .map((CustomPaint p) => p.painter)
    .whereType<KkItemGroundPainter>()
    .first;

void main() {
  setUpAll(loadKkFonts);

  testWidgets('probe: hover only', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkList(children: <Widget>[KkListRow(cjk: '電源', en: 'power', onPressed: () {}), const KkListRow(cjk: '冷却', en: 'coolant')]),
      size: const Size(600, 400),
    );
    final Finder row = find.byType(KkListRow).first;
    debugPrint('mode0 ${FocusManager.instance.highlightMode}');
    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(590, 390));
    await mouse.moveTo(tester.getCenter(row));
    await tester.pump();
    debugPrint('mode1 ${FocusManager.instance.highlightMode} fill ${_ground(tester, row).fill}');
    await tester.pump();
    debugPrint('mode2 ${FocusManager.instance.highlightMode} fill ${_ground(tester, row).fill}');
    await mouse.removePointer();
  });

  testWidgets('probe: tap then hover', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkList(children: <Widget>[KkListRow(cjk: '電源', en: 'power', onPressed: () {}, onLongPress: () {}), const KkListRow(cjk: '冷却', en: 'coolant')]),
      size: const Size(600, 400),
    );
    final Finder row = find.byType(KkListRow).first;
    await tester.tap(find.text('POWER'));
    await tester.pump();
    debugPrint('modeA ${FocusManager.instance.highlightMode}');
    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(590, 390));
    await tester.pump();
    debugPrint('modeB ${FocusManager.instance.highlightMode}');
    await mouse.moveTo(tester.getCenter(row));
    await tester.pump();
    debugPrint('modeC ${FocusManager.instance.highlightMode} fill ${_ground(tester, row).fill}');
    await mouse.moveTo(tester.getCenter(row) + const Offset(3, 0));
    await tester.pump();
    debugPrint('modeD ${FocusManager.instance.highlightMode} fill ${_ground(tester, row).fill}');
    await mouse.removePointer();
  });

  testWidgets('probe: longpress then hover', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkList(children: <Widget>[KkListRow(cjk: '電源', en: 'power', onPressed: () {}, onLongPress: () {}), const KkListRow(cjk: '冷却', en: 'coolant')]),
      size: const Size(600, 400),
    );
    final Finder row = find.byType(KkListRow).first;
    await tester.longPress(find.text('POWER'));
    await tester.pump(const Duration(seconds: 1));
    debugPrint('modeA ${FocusManager.instance.highlightMode}');
    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(590, 390));
    await tester.pump();
    debugPrint('modeB ${FocusManager.instance.highlightMode}');
    await mouse.moveTo(tester.getCenter(row));
    await tester.pump();
    debugPrint('modeC ${FocusManager.instance.highlightMode} fill ${_ground(tester, row).fill}');
    await mouse.removePointer();
  });
}
