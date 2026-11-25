import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart';
import '../support/harness.dart';

const Key _row = ValueKey<String>('row');

void main() {
  setUpAll(loadKkFonts);

  testChecked('a bare status timeline in a baseline row measures dry and has no baseline', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkBox(
        width: 520,
        child: KkRow(
          key: _row,
          cross: KkCrossAlign.baseline,
          children: <Widget>[
            KkText.num('CH', size: 11),
            KkExpanded(
              child: KkStatusTimeline(
                frame: false,
                legend: false,
                animate: false,
                axis: <String>['00:00', '12:00', '24:00'],
                rows: <KkTimelineRow>[
                  KkTimelineRow(
                    cjk: '主電源',
                    en: 'main',
                    spans: <KkTimelineSpan>[
                      KkTimelineSpan(KkLevel.nominal, weight: 3),
                      KkTimelineSpan(KkLevel.caution),
                    ],
                  ),
                  KkTimelineRow(en: 'aux', spans: <KkTimelineSpan>[KkTimelineSpan(KkLevel.critical)]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final RenderBox row = tester.renderObject<RenderBox>(find.byKey(_row));
    // Measuring the row without laying it out asks every child for a dry
    // baseline; a grid without one would throw here.
    expect(row.getDryLayout(row.constraints), row.size);
    final RenderBox grid = tester.renderObject<RenderBox>(
      find.byWidgetPredicate((Widget w) => w.runtimeType.toString() == '_TlGrid'),
    );
    expect(grid.getDryLayout(grid.constraints), grid.size);
    expect(baselineOf(grid), isNull);
  });
}
