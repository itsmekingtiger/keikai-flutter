import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

Widget _opener({
  KkSheetSide side = KkSheetSide.right,
  bool dismissible = true,
  bool scrim = true,
  int lines = 2,
  List<Object?>? results,
}) {
  return Builder(
    builder: (BuildContext context) => KkColumn(
      shrinkWrap: true,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkButton(
          label: 'open',
          focusNode: FocusNode(debugLabel: 'opener'),
          onPressed: () async {
            final Object? result = await showKkSheet<String>(
              context: context,
              side: side,
              dismissible: dismissible,
              scrim: scrim,
              builder: (BuildContext context) => KkSheet(
                code: 'SEC-04',
                cjk: '冷却',
                en: 'coolant detail',
                actions: <Widget>[
                  KkButton(
                    label: 'done',
                    focusNode: FocusNode(debugLabel: 'done'),
                    onPressed: () => Navigator.of(context).pop('done'),
                  ),
                ],
                child: KkColumn(
                  shrinkWrap: true,
                  children: <Widget>[for (int i = 0; i < lines; i++) KkText.body('LINE $i')],
                ),
              ),
            );
            results?.add(result);
          },
        ),
        KkButton(label: 'other', focusNode: FocusNode(debugLabel: 'other'), onPressed: () {}),
      ],
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('OPEN'));
  await tester.pump();
  await tester.pump();
}

String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

void main() {
  setUpAll(loadKkFonts);

  testWidgets('a right sheet is 400px wide, full height, with a 2px signal line inside', (WidgetTester tester) async {
    await pumpKk(tester, _opener(), size: const Size(1000, 700));
    await _open(tester);
    expect(tester.getRect(find.byType(KkSheet)), const Rect.fromLTWH(600, 0, 400, 700));
    const KkColors c = KkColors.standby;
    final KkBox box = tester.widget<KkBox>(
      find.descendant(of: find.byType(KkSheet), matching: find.byType(KkBox)).first,
    );
    expect(box.decoration!.fill, c.bg100);
    expect(box.decoration!.edges.left, KkSide(c.signal, width: 2));
    expect(box.decoration!.edges.right, KkSide.none);
    expect(tester.widget<ModalBarrier>(find.byType(ModalBarrier).last).color, c.scrimSheet);
    // Head: 44px with the code, the title and a close button.
    final Rect code = tester.getRect(find.text('SEC-04'));
    expect(code.left, 600 + 2 + 16);
    expect(code.center.dy, closeTo(21.5, 0.5));
    expect(tester.widget<Text>(find.text('SEC-04')).style!.color, c.signal);
    expect(tester.getRect(find.byType(KkIconButton)).right, 1000 - 8);
    expect(tester.getTopLeft(find.text('LINE 0')), const Offset(600 + 2 + 16, 44 + 16));
    // The foot is pinned to the bottom edge.
    final Rect done = tester.getRect(find.byType(KkButton).last);
    expect(done.bottom, 700 - 12);
    expect(done.right, 1000 - 16);
    // No grip on a side sheet.
    expect(_grip(), findsNothing);
  });

  testWidgets('a left sheet sits on the left with the line on its right edge', (WidgetTester tester) async {
    await pumpKk(tester, _opener(side: KkSheetSide.left), size: const Size(1000, 700));
    await _open(tester);
    expect(tester.getRect(find.byType(KkSheet)), const Rect.fromLTWH(0, 0, 400, 700));
    final KkBox box = tester.widget<KkBox>(
      find.descendant(of: find.byType(KkSheet), matching: find.byType(KkBox)).first,
    );
    expect(box.decoration!.edges.right.width, 2);
    expect(box.decoration!.edges.left.width, 0);
  });

  testWidgets('a bottom sheet spans the width, is as tall as its content, and has a grip', (
    WidgetTester tester,
  ) async {
    await pumpKk(tester, _opener(side: KkSheetSide.bottom), size: const Size(1000, 700));
    await _open(tester);
    final Rect sheet = tester.getRect(find.byType(KkSheet));
    expect(sheet.left, 0);
    expect(sheet.width, 1000);
    expect(sheet.bottom, 700);
    expect(sheet.height, lessThan(420));
    expect(_grip(), findsOneWidget);
    final Rect grip = tester.getRect(_grip());
    expect(grip.size, const Size(32, 4));
    expect(grip.center.dx, 500);
    // 2px line, then 8px above the grip.
    expect(grip.top, sheet.top + 2 + 8);
  });

  testWidgets('a bottom sheet never takes more than 60% of the height; its body scrolls', (
    WidgetTester tester,
  ) async {
    await pumpKk(tester, _opener(side: KkSheetSide.bottom, lines: 80), size: const Size(1000, 700));
    await _open(tester);
    expect(tester.takeException(), isNull);
    final Rect sheet = tester.getRect(find.byType(KkSheet));
    expect(sheet.height, closeTo(420, 0.01));
    expect(sheet.bottom, 700);
    final double before = tester.getTopLeft(find.text('LINE 0')).dy;
    await tester.drag(find.text('LINE 2'), const Offset(0, -100));
    await tester.pump();
    expect(tester.getTopLeft(find.text('LINE 0')).dy, lessThan(before));
    expect(tester.getRect(find.text('DONE')).bottom, lessThan(700));
  });

  testWidgets('on a narrow screen a side sheet takes the full width', (WidgetTester tester) async {
    await pumpKk(tester, _opener(), size: const Size(320, 600));
    await _open(tester);
    expect(tester.getRect(find.byType(KkSheet)), const Rect.fromLTWH(0, 0, 320, 600));
  });

  testWidgets('the close button, Escape, a tap outside and an action all close it', (WidgetTester tester) async {
    final List<Object?> results = <Object?>[];
    await pumpKk(tester, _opener(results: results), size: const Size(1000, 700));

    await _open(tester);
    await tester.tap(find.byType(KkIconButton));
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkSheet), findsNothing);

    await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkSheet), findsNothing);

    await _open(tester);
    await tester.tapAt(const Offset(100, 600));
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkSheet), findsNothing);

    await _open(tester);
    await tester.tap(find.text('DONE'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkSheet), findsNothing);
    expect(results, <Object?>[null, null, null, 'done']);
  });

  testWidgets('not dismissible: Escape and a tap outside do nothing', (WidgetTester tester) async {
    await pumpKk(tester, _opener(dismissible: false), size: const Size(1000, 700));
    await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.tapAt(const Offset(100, 600));
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkSheet), findsOneWidget);
  });

  testWidgets('scrim: false leaves the page undimmed', (WidgetTester tester) async {
    await pumpKk(tester, _opener(scrim: false), size: const Size(1000, 700));
    await _open(tester);
    expect(tester.widget<ModalBarrier>(find.byType(ModalBarrier).last).color, isNull);
  });

  testWidgets('keyboard focus stays inside the sheet and returns to the opener', (WidgetTester tester) async {
    await pumpKk(tester, _opener(), size: const Size(1000, 700));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focused(), 'opener');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    final Set<String?> visited = <String?>{};
    for (int i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      visited.add(_focused());
    }
    expect(visited, contains('done'));
    expect(visited, isNot(contains('opener')));
    expect(visited, isNot(contains('other')));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(_focused(), 'opener');
  });

  testWidgets('steps in from its edge in seven jumps over 0.42s and steps out on close', (
    WidgetTester tester,
  ) async {
    await pumpKk(tester, _opener(), size: const Size(1000, 700), motion: true);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    await tester.pump();
    // Fully off the right edge at first.
    expect(tester.getRect(find.byType(KkSheet)).left, 1000);
    final Set<double> seen = <double>{};
    for (int i = 0; i < 21; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      seen.add(tester.getRect(find.byType(KkSheet)).left);
    }
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getRect(find.byType(KkSheet)).left, 600);
    // Every position is a seventh of the way: no glide.
    for (final double left in seen) {
      final double sevenths = (1000 - left) / 400 * 7;
      expect(sevenths, closeTo(sevenths.roundToDouble(), 1e-6));
    }
    expect(seen.length, greaterThan(4));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getRect(find.byType(KkSheet)).left, greaterThan(600));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();
    expect(find.byType(KkSheet), findsNothing);
  });

  testWidgets('a bottom sheet steps up from below', (WidgetTester tester) async {
    await pumpKk(tester, _opener(side: KkSheetSide.bottom), size: const Size(1000, 700), motion: true);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    await tester.pump();
    expect(tester.getRect(find.byType(KkSheet)).top, 700);
    await tester.pump(const Duration(milliseconds: 440));
    await tester.pump();
    expect(tester.getRect(find.byType(KkSheet)).bottom, 700);
  });

  group('inline', () {
    testWidgets('a side sheet placed in a layout is 400px wide and as tall as its content', (
      WidgetTester tester,
    ) async {
      int closes = 0;
      await pumpKk(
        tester,
        KkSheet(
          cjk: '絞込',
          en: 'filter',
          onClose: () => closes++,
          actions: <Widget>[KkButton(label: 'apply', onPressed: () {})],
          child: const KkBox(height: 100),
        ),
        size: const Size(1000, 700),
      );
      final Rect sheet = tester.getRect(find.byType(KkSheet));
      expect(sheet.width, 400);
      // 44 head + 16 + 100 + 16 body + (1 + 12 + 36 + 12) foot.
      expect(sheet.height, 44 + 132 + 61);
      await tester.tap(find.byType(KkIconButton));
      expect(closes, 1);
    });

    testWidgets('given a height, its foot is pinned to the bottom', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          height: 500,
          child: KkSheet(
            side: KkSheetSide.left,
            cjk: '絞込',
            showClose: false,
            actions: <Widget>[KkButton(label: 'apply', onPressed: () {})],
            child: const KkBox(height: 40),
          ),
        ),
        size: const Size(1000, 700),
      );
      expect(tester.getSize(find.byType(KkSheet)), const Size(400, 500));
      expect(tester.getRect(find.byType(KkButton)).bottom, 500 - 12);
      expect(find.byType(KkIconButton), findsNothing);
    });

    testWidgets('a bottom sheet fills the width it is given; width and grip can be set', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 560,
          child: KkSheet(side: KkSheetSide.bottom, en: 'log', showClose: false, child: KkBox(height: 20)),
        ),
        size: const Size(1000, 700),
      );
      expect(tester.getSize(find.byType(KkSheet)).width, 560);
      expect(_grip(), findsOneWidget);

      await pumpKk(
        tester,
        const KkSheet(width: 320, grip: true, en: 'narrow', showClose: false, child: KkBox(height: 20)),
        size: const Size(1000, 700),
      );
      expect(tester.getSize(find.byType(KkSheet)).width, 320);
      expect(_grip(), findsOneWidget);
    });

    testWidgets('survives tiny boxes in both themes', (WidgetTester tester) async {
      for (final KkCondition condition in KkCondition.values) {
        for (final KkSheetSide side in KkSheetSide.values) {
          await pumpKk(
            tester,
            KkBox(
              width: 30,
              height: 30,
              child: KkSheet(
                side: side,
                code: 'SEC-04',
                cjk: '冷却系統',
                en: 'a long title',
                onClose: () {},
                actions: <Widget>[KkButton(label: 'apply', onPressed: () {})],
                child: const KkText.body('BODY'),
              ),
            ),
            condition: condition,
          );
          expect(tester.takeException(), isNull, reason: '$side in $condition');
        }
      }
    });
  });
}

/// The grip of dashes: the only 32×4 box in a sheet.
Finder _grip() => find.descendant(
  of: find.byType(KkSheet),
  matching: find.byWidgetPredicate((Widget w) => w is KkBox && w.width == 32 && w.height == 4),
);
