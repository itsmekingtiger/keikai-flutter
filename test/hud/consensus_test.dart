import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

const KkVote go = KkVote.go;
const KkVote nogo = KkVote.nogo;
const KkVote wait = KkVote.wait;
const KkVote fault = KkVote.fault;

List<KkVoter> _voters(List<KkVote> votes) => <KkVoter>[
  for (int i = 0; i < votes.length; i++) KkVoter(id: 'CH.0${i + 1}', name: 'channel ${i + 1}', vote: votes[i]),
];

/// The fill of the result band (the box that holds the tally).
Color? _band(WidgetTester tester, String tally) =>
    tester.widget<KkBox>(find.ancestor(of: find.text(tally), matching: find.byType(KkBox)).first).fill;

void main() {
  setUpAll(loadKkFonts);

  group('KkConsensus.resultOf', () {
    test('all go passes', () {
      expect(KkConsensus.resultOf(<KkVote>[go, go, go]), go);
      expect(KkConsensus.resultOf(<KkVote>[go, go, go], quorum: 3), go);
    });

    test('a simple majority is enough by default', () {
      expect(KkConsensus.resultOf(<KkVote>[go, go, nogo]), go);
      expect(KkConsensus.resultOf(<KkVote>[go, go, wait]), go);
      expect(KkConsensus.resultOf(<KkVote>[go, nogo, nogo]), nogo);
      // Even counts need more than half.
      expect(KkConsensus.resultOf(<KkVote>[go, go, nogo, nogo]), nogo);
      expect(KkConsensus.resultOf(<KkVote>[go, go, go, nogo]), go);
    });

    test('one no-go sinks a unanimous poll at once', () {
      expect(KkConsensus.resultOf(<KkVote>[go, go, nogo], quorum: 3), nogo);
      expect(KkConsensus.resultOf(<KkVote>[nogo, wait, wait], quorum: 3), nogo);
    });

    test('it waits while the open votes can still decide it', () {
      expect(KkConsensus.resultOf(<KkVote>[wait, wait, wait]), wait);
      expect(KkConsensus.resultOf(<KkVote>[go, wait, wait]), wait);
      expect(KkConsensus.resultOf(<KkVote>[go, nogo, wait]), wait);
      expect(KkConsensus.resultOf(<KkVote>[go, go, wait], quorum: 3), wait);
    });

    test('a faulted channel never counts as go', () {
      expect(KkConsensus.resultOf(<KkVote>[go, go, fault]), go);
      expect(KkConsensus.resultOf(<KkVote>[go, fault, fault]), nogo);
      expect(KkConsensus.resultOf(<KkVote>[go, wait, fault]), wait);
      expect(KkConsensus.resultOf(<KkVote>[go, go, fault], quorum: 3), nogo);
      expect(KkConsensus.resultOf(<KkVote>[fault, fault, fault]), nogo);
    });

    test('the quorum is kept between one and the number of voters', () {
      expect(KkConsensus.quorumFor(3), 2);
      expect(KkConsensus.quorumFor(4), 3);
      expect(KkConsensus.quorumFor(5), 3);
      expect(KkConsensus.quorumFor(1), 1);
      expect(KkConsensus.quorumFor(0), 1);
      expect(KkConsensus.quorumFor(3, quorum: 9), 3);
      expect(KkConsensus.quorumFor(3, quorum: 0), 1);
      expect(KkConsensus.quorumFor(3, quorum: -2), 1);
      expect(KkConsensus.resultOf(<KkVote>[go, nogo, nogo], quorum: 0), go);
      expect(KkConsensus.resultOf(<KkVote>[go, go, go], quorum: 99), go);
    });

    test('nobody voting is a wait', () {
      expect(KkConsensus.resultOf(<KkVote>[]), wait);
    });
  });

  testWidgets('shows every verdict and the computed result', (WidgetTester tester) async {
    const KkColors c = KkColors.standby;
    await pumpKk(
      tester,
      KkBox(
        width: 520,
        child: KkConsensus(cjk: '発進可否', en: 'launch poll', meta: '14:02:40Z', voters: _voters(<KkVote>[go, go, wait])),
      ),
    );
    expect(find.text('発進可否'), findsOneWidget);
    expect(find.text('承認'), findsNWidgets(2));
    expect(find.text('審議'), findsOneWidget);
    expect(find.text('可決'), findsOneWidget);
    expect(find.text('2-OF-3'), findsOneWidget);
    expect(find.text('GO 02 / 03'), findsOneWidget);
    expect(_band(tester, 'GO 02 / 03'), c.nominal);
    expect(tester.widget<Text>(find.text('可決')).style!.color, c.onFill);

    await pumpKk(tester, KkBox(width: 520, child: KkConsensus(voters: _voters(<KkVote>[nogo, go, fault]))));
    expect(find.text('否決'), findsOneWidget);
    expect(find.text('否認'), findsOneWidget);
    expect(find.text('断線'), findsOneWidget);
    expect(_band(tester, 'GO 01 / 03'), c.alert);

    await pumpKk(tester, KkBox(width: 520, child: KkConsensus(voters: _voters(<KkVote>[go, wait, wait]), quorum: 3)));
    expect(find.text('審議中'), findsOneWidget);
    expect(find.text('3-OF-3'), findsOneWidget);
    expect(_band(tester, 'GO 01 / 03'), c.bg300);
    expect(tester.widget<Text>(find.text('審議中')).style!.color, c.ink);
  });

  testWidgets('voter columns share the width; the vote colours their top edge', (WidgetTester tester) async {
    const KkColors c = KkColors.standby;
    await pumpKk(
      tester,
      KkBox(width: 510, child: KkConsensus(voters: _voters(<KkVote>[go, nogo, wait, fault]))),
    );
    KkBox column(String id) => tester.widget<KkBox>(
      find.ancestor(of: find.text(id), matching: find.byType(KkBox)).first,
    );
    Rect rect(String id) => tester.getRect(find.ancestor(of: find.text(id), matching: find.byType(KkBox)).first);
    expect(column('CH.01').decoration!.edges.top.color, c.nominal);
    expect(column('CH.01').decoration!.edges.top.width, 4);
    expect(column('CH.02').decoration!.edges.top.color, c.alert);
    expect(column('CH.03').decoration!.edges.top.color, c.caution);
    expect(column('CH.04').decoration!.edges.top.color, c.offline);
    expect(column('CH.04').decoration!.pattern, isNotNull, reason: 'a faulted channel is hatched');
    expect(column('CH.01').decoration!.pattern, isNull);
    // (510 − 2 borders − 24 padding − 3 gaps of 3) / 4.
    expect(rect('CH.01').width, closeTo(118.75, 0.01));
    expect(rect('CH.02').left - rect('CH.01').right, closeTo(3, 1e-6));
    expect(rect('CH.01').height, rect('CH.04').height);
    expect(rect('CH.01').left - tester.getRect(find.byType(KkConsensus)).left, 13);
  });

  testWidgets('waiting verdicts and a waiting result blink at 1.2s', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkBox(width: 520, child: KkConsensus(voters: _voters(<KkVote>[go, wait, wait]), quorum: 3, boot: false)),
      motion: true,
    );
    List<double> opacities() => tester
        .widgetList<Opacity>(find.descendant(of: find.byType(KkConsensus), matching: find.byType(Opacity)))
        .map((Opacity o) => o.opacity)
        .toList();
    await tester.pump(const Duration(milliseconds: 100));
    // Three voter verdicts and the result band; the go verdict never dims.
    expect(opacities(), <double>[1, 1, 1, 1]);
    await tester.pump(const Duration(milliseconds: 600));
    expect(opacities(), <double>[1, 0.2, 0.2, 0.2]);
    await tester.pump(const Duration(milliseconds: 600));
    expect(opacities(), <double>[1, 1, 1, 1]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('result, rule, tally and words can be overridden', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkBox(
        width: 520,
        child: KkConsensus(
          voters: _voters(<KkVote>[go, go, go]),
          result: KkVote.nogo,
          rule: 'VETO',
          tally: 'OVERRIDE OP-07',
          labels: const KkConsensusLabels(rejectedCjk: '却下', rejectedEn: 'ABORT', goCjk: '可', goEn: 'YES'),
        ),
      ),
    );
    expect(find.text('却下'), findsOneWidget);
    expect(find.text('ABORT'), findsOneWidget);
    expect(find.text('VETO'), findsOneWidget);
    expect(find.text('OVERRIDE OP-07'), findsOneWidget);
    expect(find.text('可'), findsNWidgets(3));
    expect(find.text('YES'), findsNWidgets(3));
    expect(_band(tester, 'OVERRIDE OP-07'), KkColors.standby.alert);
  });

  testWidgets('no voters, many voters and tiny boxes do not throw', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 520, child: KkConsensus(voters: <KkVoter>[])));
    expect(tester.takeException(), isNull);
    expect(find.text('審議中'), findsOneWidget);
    expect(find.text('GO 00 / 00'), findsOneWidget);

    await pumpKk(
      tester,
      KkBox(width: 300, child: KkConsensus(voters: _voters(List<KkVote>.filled(12, KkVote.go)))),
    );
    expect(tester.takeException(), isNull);
    await pumpKk(
      tester,
      KkBox(
        width: 20,
        height: 12,
        child: KkConsensus(
          cjk: '発進可否発進可否',
          en: 'a very long poll title',
          voters: <KkVoter>[
            KkVoter(id: 'CH.01' * 5, name: 'guidance ' * 9, vote: KkVote.wait, note: 'ALIGN ' * 30),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
