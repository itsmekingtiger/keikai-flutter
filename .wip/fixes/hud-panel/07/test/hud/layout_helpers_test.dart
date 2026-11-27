import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

const Key _a = ValueKey<String>('a');
const Key _b = ValueKey<String>('b');
const Key _c = ValueKey<String>('c');

void main() {
  setUpAll(loadKkFonts);

  group('KkFillColumn', () {
    testWidgets('fixed height: the body takes what the others leave', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 200,
          height: 300,
          child: KkFillColumn(
            leading: const <Widget>[KkBox(key: _a, height: 30)],
            body: const KkBox(key: _b),
            trailing: const <Widget>[KkBox(key: _c, height: 20)],
          ),
        ),
      );
      expect(tester.getRect(find.byKey(_a)), const Rect.fromLTWH(0, 0, 200, 30));
      expect(tester.getRect(find.byKey(_b)), const Rect.fromLTWH(0, 30, 200, 250));
      expect(tester.getRect(find.byKey(_c)), const Rect.fromLTWH(0, 280, 200, 20));
    });

    testWidgets('free height: every child keeps its own height', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 200,
          child: KkFillColumn(
            leading: const <Widget>[KkBox(key: _a, height: 30)],
            body: const KkBox(key: _b, height: 70),
          ),
        ),
      );
      expect(tester.getSize(find.byType(KkFillColumn)), const Size(200, 100));
      expect(tester.getRect(find.byKey(_b)), const Rect.fromLTWH(0, 30, 200, 70));
    });

    testWidgets('a height limit caps the body without forcing it', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 200,
          maxHeight: 100,
          child: KkFillColumn(
            leading: const <Widget>[KkBox(key: _a, height: 30)],
            body: const KkScroll(child: KkBox(key: _b, height: 400)),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkFillColumn)), const Size(200, 100));
      expect(tester.getSize(find.byType(KkScroll)).height, 70);
    });

    testWidgets('free width: as wide as the widest child, all children that wide', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkRow(
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkFillColumn(
              leading: const <Widget>[KkBox(key: _a, width: 80, height: 10)],
              body: const KkBox(key: _b, width: 140, height: 10),
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkFillColumn)), const Size(140, 20));
      expect(tester.getSize(find.byKey(_a)).width, 140, reason: 'every child is as wide as the column');
    });

    testWidgets('free width, fixed height: the body is measured at the height it gets', (WidgetTester tester) async {
      // An aspect-ratio box has no size of its own: it needs one bounded side.
      await pumpKk(
        tester,
        KkRow(
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkBox(
              height: 212,
              child: KkFillColumn(
                leading: const <Widget>[KkBox(key: _a, width: 100, height: 32)],
                body: const AspectRatio(aspectRatio: 2, child: KkBox(key: _b)),
                trailing: const <Widget>[KkBox(key: _c, width: 40, height: 20)],
              ),
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      // 212 - 32 - 20 is left for the body, which is twice as wide as it is tall.
      expect(tester.getRect(find.byKey(_b)), const Rect.fromLTWH(0, 32, 320, 160));
      expect(tester.getSize(find.byType(KkFillColumn)), const Size(320, 212));
      expect(tester.getRect(find.byKey(_a)), const Rect.fromLTWH(0, 0, 320, 32));
      expect(tester.getRect(find.byKey(_c)), const Rect.fromLTWH(0, 192, 320, 20));
    });

    testWidgets('free width, limited height: the body is measured within what is left', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkRow(
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkBox(
              maxHeight: 132,
              child: KkFillColumn(
                leading: const <Widget>[KkBox(key: _a, width: 100, height: 32)],
                body: const AspectRatio(aspectRatio: 2, child: KkBox(key: _b)),
              ),
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(_b)), const Rect.fromLTWH(0, 32, 200, 100));
      expect(tester.getSize(find.byType(KkFillColumn)), const Size(200, 132));
    });

    testWidgets('a body is never built for a height it does not get', (WidgetTester tester) async {
      final List<BoxConstraints> seen = <BoxConstraints>[];
      await pumpKk(
        tester,
        KkRow(
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkBox(
              height: 212,
              child: KkFillColumn(
                leading: const <Widget>[KkBox(key: _a, width: 100, height: 32)],
                body: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    seen.add(constraints);
                    return const KkBox(key: _b, width: 140);
                  },
                ),
              ),
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(seen, isNotEmpty);
      for (final BoxConstraints constraints in seen) {
        expect(constraints.minHeight, 180, reason: '$constraints');
        expect(constraints.maxHeight, 180, reason: '$constraints');
      }
      expect(seen.last, const BoxConstraints.tightFor(width: 140, height: 180));
      expect(tester.getSize(find.byKey(_b)), const Size(140, 180));
    });

    testWidgets('no body, no children, too little room: nothing throws', (WidgetTester tester) async {
      await pumpKk(tester, KkBox(width: 100, height: 50, child: KkFillColumn()));
      expect(tester.getSize(find.byType(KkFillColumn)), const Size(100, 50));
      await pumpKk(
        tester,
        KkBox(
          width: 100,
          height: 20,
          child: KkFillColumn(
            leading: const <Widget>[KkBox(key: _a, height: 30)],
            body: const KkBox(key: _b),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(_b)).height, 0);
    });
  });

  group('KkHugWidth', () {
    testWidgets('loose width: the child is as wide as its content needs', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkHugWidth(
          child: KkColumn(
            shrinkWrap: true,
            children: <Widget>[
              KkRow(children: <Widget>[KkBox(key: _a, width: 60, height: 10), KkSpacer(), KkBox(width: 40, height: 10)]),
              KkBox(key: _b, height: 10),
            ],
          ),
        ),
      );
      expect(tester.getSize(find.byType(KkHugWidth)), const Size(100, 20));
      // The stretched child is laid out at the hugged width.
      expect(tester.getSize(find.byKey(_b)).width, 100);
    });

    testWidgets('fixed width: the child fills it', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 300,
          child: KkHugWidth(
            child: KkRow(children: <Widget>[KkBox(key: _a, width: 60, height: 10), KkSpacer(), KkBox(key: _b, width: 40, height: 10)]),
          ),
        ),
      );
      expect(tester.getSize(find.byType(KkHugWidth)).width, 300);
      expect(tester.getTopRight(find.byKey(_b)).dx, 300);
    });

    testWidgets('never wider than the room it has', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkHugWidth(child: KkBox(key: _a, minWidth: 2000, height: 10)),
        size: const Size(400, 300),
      );
      expect(tester.getSize(find.byType(KkHugWidth)).width, 400);
      await pumpKk(tester, const KkHugWidth());
      expect(tester.getSize(find.byType(KkHugWidth)), Size.zero);
    });
  });

  group('KkStateWord', () {
    testWidgets('icon and word in the level colour; INFO in dim ink without a level', (WidgetTester tester) async {
      const KkColors c = KkColors.standby;
      for (final KkLevel level in KkLevel.values) {
        await pumpKk(tester, KkStateWord(level: level));
        expect(tester.widget<Text>(find.text(level.word)).style!.color, c.level(level));
        expect(tester.widget<KkGlyph>(find.byType(KkGlyph)).level, level);
      }
      await pumpKk(tester, const KkStateWord());
      expect(tester.widget<Text>(find.text('INFO')).style!.color, c.inkDim);
      await pumpKk(tester, const KkStateWord(level: KkLevel.caution, text: 'hold', showGlyph: false));
      expect(find.text('HOLD'), findsOneWidget);
      expect(find.byType(KkGlyph), findsNothing);
    });
  });
}
