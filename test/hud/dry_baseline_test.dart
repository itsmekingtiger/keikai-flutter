import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart';
import '../support/harness.dart';

const Key _row = ValueKey<String>('row');
const Key _probe = ValueKey<String>('probe');

/// A baseline-aligned row of [subject] and a small line of text.
Widget _baselineRow(Widget subject) {
  return KkRow(
    key: _row,
    shrinkWrap: true,
    cross: KkCrossAlign.baseline,
    children: <Widget>[
      subject,
      const KkText.num('00', key: _probe, size: 11),
    ],
  );
}

RenderBox _box(WidgetTester tester, Finder finder) => tester.renderObject<RenderBox>(finder);

/// The first render box of the private type [name] in the tree.
RenderBox _private(WidgetTester tester, String name) =>
    _box(tester, find.byWidgetPredicate((Widget w) => w.runtimeType.toString() == name));

/// Measures the row without laying it out, as a parent that sizes itself from
/// its children does. A child with no dry baseline makes this throw.
void _expectDryRow(WidgetTester tester) {
  final RenderBox row = _box(tester, find.byKey(_row));
  expect(row.getDryLayout(row.constraints), row.size);
}

void main() {
  setUpAll(loadKkFonts);

  group('KkHeading', () {
    testChecked('the dry baseline is the main line', (WidgetTester tester) async {
      await pumpKk(tester, _baselineRow(const KkHeading(stem: '設計', code: 'KK-00', en: 'keikai', main: '警戒')));
      _expectDryRow(tester);
      final RenderBox heading = _private(tester, '_HeadingLayout');
      final Rect headingRect = tester.getRect(find.byType(KkHeading));
      final Finder mainLine = find.byWidgetPredicate((Widget w) => w is KkText && w.data == '警戒');
      final double mainTop = tester.getRect(mainLine).top - headingRect.top;
      final double? inMain = baselineOf(_box(tester, mainLine));
      expect(inMain, isNotNull);
      expect(baselineOf(heading), closeTo(mainTop + inMain!, 1e-6));
      // The small line of text sits on the same baseline.
      final RenderBox probe = _box(tester, find.byKey(_probe));
      final double probeTop = tester.getRect(find.byKey(_probe)).top - tester.getRect(find.byKey(_row)).top;
      final double headingTop = headingRect.top - tester.getRect(find.byKey(_row)).top;
      expect(probeTop + baselineOf(probe)!, closeTo(headingTop + baselineOf(heading)!, 1e-6));
    });

    testChecked('dry layout matches the real one with and without a stem, at any width', (WidgetTester tester) async {
      for (final double width in <double>[60, 180, 420]) {
        for (final bool stacked in <bool>[false, true]) {
          await pumpKk(
            tester,
            KkBox(
              width: width,
              child: KkHeading(stem: '設計言語体系', code: 'KK-00', en: 'keikai for flutter', main: '警戒', stacked: stacked),
            ),
          );
          final RenderBox heading = _private(tester, '_HeadingLayout');
          expect(heading.getDryLayout(heading.constraints), heading.size, reason: 'width $width stacked $stacked');
          expect(baselineOf(heading), isNotNull);
        }
      }
    });

    testChecked('a heading with only a main line still has a baseline', (WidgetTester tester) async {
      await pumpKk(tester, _baselineRow(const KkHeading(main: '警戒', stacked: true)));
      _expectDryRow(tester);
      final RenderBox heading = _private(tester, '_HeadingLayout');
      final Finder mainLine = find.byWidgetPredicate((Widget w) => w is KkText && w.data == '警戒');
      expect(baselineOf(heading), closeTo(baselineOf(_box(tester, mainLine))!, 1e-6));
    });
  });

  group('KkPanel', () {
    testChecked('the body measures its baseline dry, with and without a spine', (WidgetTester tester) async {
      for (final String? spine in <String?>[null, '監視']) {
        await pumpKk(
          tester,
          _baselineRow(
            KkBox(
              width: 320,
              child: KkPanel(
                code: 'SEC-04',
                cjk: '区画',
                en: 'sector',
                spine: spine,
                boot: false,
                child: const KkText('内容', key: ValueKey<String>('content')),
              ),
            ),
          ),
        );
        _expectDryRow(tester);
        final RenderBox body = _private(tester, '_PanelBody');
        final RenderBox content = _box(tester, find.byKey(const ValueKey<String>('content')));
        final double contentTop = content.localToGlobal(Offset.zero).dy - body.localToGlobal(Offset.zero).dy;
        expect(baselineOf(body), closeTo(contentTop + baselineOf(content)!, 1e-6), reason: 'spine $spine');
      }
    });

    testChecked('an empty panel has no body baseline', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 320,
          child: KkPanel(code: 'SEC-04', cjk: '区画', boot: false),
        ),
      );
      final Finder body = find.byWidgetPredicate((Widget w) => w.runtimeType.toString() == '_PanelBody');
      if (body.evaluate().isNotEmpty) {
        expect(baselineOf(_box(tester, body)), isNull);
      }
    });
  });

  group('KkFillColumn', () {
    testChecked('the dry baseline is that of the first child with one, below those without', (
      WidgetTester tester,
    ) async {
      await pumpKk(
        tester,
        _baselineRow(
          KkBox(
            width: 200,
            child: KkFillColumn(
              leading: const <Widget>[KkBox(height: 30)],
              body: const KkText('本文', key: ValueKey<String>('body')),
              trailing: const <Widget>[KkText('末尾')],
            ),
          ),
        ),
      );
      _expectDryRow(tester);
      final RenderBox column = _box(tester, find.byType(KkFillColumn));
      final RenderBox body = _box(tester, find.byKey(const ValueKey<String>('body')));
      expect(baselineOf(column), closeTo(30 + baselineOf(body)!, 1e-6));
    });

    testChecked('a body squeezed by a fixed height keeps the same dry and real baseline', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 200,
          height: 120,
          child: KkFillColumn(
            leading: const <Widget>[KkText('見出し', key: ValueKey<String>('lead'))],
            body: const KkBox(),
            trailing: const <Widget>[KkText('末尾')],
          ),
        ),
      );
      final RenderBox column = _box(tester, find.byType(KkFillColumn));
      expect(column.getDryLayout(column.constraints), column.size);
      expect(baselineOf(column), closeTo(baselineOf(_box(tester, find.byKey(const ValueKey<String>('lead'))))!, 1e-6));
    });

    testChecked('no child with a baseline, no baseline', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 200,
          child: KkFillColumn(leading: const <Widget>[KkBox(height: 30)], body: const KkBox(height: 40)),
        ),
      );
      expect(baselineOf(_box(tester, find.byType(KkFillColumn))), isNull);
    });
  });

  group('KkHexMatrix', () {
    testChecked('a honeycomb in a baseline row has no baseline and sits at the top', (WidgetTester tester) async {
      await pumpKk(
        tester,
        _baselineRow(
          const KkHexMatrix(
            columns: 3,
            entrance: false,
            cells: <KkHexCell>[
              KkHexCell(id: 'A1', value: '12', level: KkLevel.nominal),
              KkHexCell(id: 'A2', value: '40', level: KkLevel.caution),
              KkHexCell.empty(),
              KkHexCell(id: 'B1', value: '88', level: KkLevel.critical),
            ],
          ),
        ),
      );
      _expectDryRow(tester);
      final RenderBox matrix = _private(tester, '_HexLayout');
      expect(baselineOf(matrix), isNull);
      expect(tester.getRect(find.byType(KkHexMatrix)).top, tester.getRect(find.byKey(_row)).top);
    });
  });
}
