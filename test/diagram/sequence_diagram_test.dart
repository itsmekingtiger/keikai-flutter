import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/diagram/diagram.dart';

import '../support/harness.dart';

const List<KkSequenceParticipant> parties = <KkSequenceParticipant>[
  KkSequenceParticipant('op', code: 'OP-07', cjk: '運用'),
  KkSequenceParticipant('ctl', code: 'CTRL'),
  KkSequenceParticipant('sec', code: 'SEC-04', level: KkLevel.caution),
  KkSequenceParticipant('log', level: KkLevel.offline),
];

const List<KkSequenceEntry> handover = <KkSequenceEntry>[
  KkSequenceDivider(code: 'PH-01', cjk: '要求', en: 'request'),
  KkSequenceMessage('op', 'ctl', 'REQUEST CONTROL', note: '14:02:31Z'),
  KkSequenceMessage('ctl', 'sec', 'PING'),
  KkSequenceMessage('sec', 'ctl', 'ACK 0x3F', kind: KkSequenceMessageKind.reply),
  KkSequenceMessage('ctl', 'ctl', 'VERIFY KEY'),
  KkSequenceDivider(),
  KkSequenceMessage('ctl', 'op', 'GRANT', kind: KkSequenceMessageKind.reply),
  KkSequenceMessage('sec', 'log', 'STATE CHANGE', kind: KkSequenceMessageKind.async),
  KkSequenceMessage('log', 'op', 'PRESSURE LOW', kind: KkSequenceMessageKind.reply, level: KkLevel.critical),
  KkSequenceMessage('log', 'log', 'ROTATE'),
];

void main() {
  setUpAll(loadKkFonts);

  testWidgets('draws framed, with a head, a message count and a legend', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkBox(
        width: 720,
        child: KkSequenceDiagram(participants: parties, entries: handover, cjk: '制御移管', en: 'control handover'),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('制御移管'), findsOneWidget);
    expect(find.text('CONTROL HANDOVER'), findsOneWidget);
    expect(find.text('08 MSG'), findsOneWidget);
    for (final String key in <String>['CALL', 'REPLY', 'ASYNC']) {
      expect(find.text(key), findsOneWidget);
    }
    expect(tester.getSize(find.byType(KkSequenceDiagram)).width, 720);
  });

  testWidgets('bare, it is just the drawing', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkSequenceDiagram(participants: parties, entries: handover, framed: false, numbered: false),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(KkWidgetFrame), findsNothing);
    expect(find.text('CALL'), findsNothing);
  });

  testWidgets('takes its natural width when free, stretches when given more, shrinks when given less', (
    WidgetTester tester,
  ) async {
    const KkSequenceDiagram diagram = KkSequenceDiagram(participants: parties, entries: handover, framed: false);
    final double natural = kkSequenceNaturalWidth(diagram);
    expect(natural, greaterThan(3 * 120));

    await pumpKk(tester, const KkRow(shrinkWrap: true, cross: KkCrossAlign.start, children: <Widget>[diagram]), size: const Size(2400, 900));
    final Size free = tester.getSize(find.byType(KkSequenceDiagram));
    expect(free.width, closeTo(natural, 0.01));

    await pumpKk(tester, KkBox(width: natural + 300, child: diagram), size: const Size(2400, 900));
    final Size wide = tester.getSize(find.byType(KkSequenceDiagram));
    expect(wide.width, natural + 300);
    expect(wide.height, closeTo(free.height, 0.01));

    await pumpKk(tester, KkBox(width: natural / 2, child: diagram), size: const Size(2400, 900));
    final Size narrow = tester.getSize(find.byType(KkSequenceDiagram));
    expect(narrow.width, closeTo(natural / 2, 0.01));
    expect(narrow.height, closeTo(free.height / 2, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long labels push the lifelines apart', (WidgetTester tester) async {
    const KkSequenceDiagram short = KkSequenceDiagram(
      participants: <KkSequenceParticipant>[KkSequenceParticipant('a'), KkSequenceParticipant('b')],
      entries: <KkSequenceEntry>[KkSequenceMessage('a', 'b', 'OK')],
      framed: false,
    );
    const KkSequenceDiagram long = KkSequenceDiagram(
      participants: <KkSequenceParticipant>[KkSequenceParticipant('a'), KkSequenceParticipant('b')],
      entries: <KkSequenceEntry>[KkSequenceMessage('a', 'b', 'A VERY LONG MESSAGE LABEL THAT NEEDS A LOT OF ROOM TO BE READ')],
      framed: false,
    );
    expect(kkSequenceNaturalWidth(long), greaterThan(kkSequenceNaturalWidth(short) + 200));
    const KkSequenceDiagram self = KkSequenceDiagram(
      participants: <KkSequenceParticipant>[KkSequenceParticipant('a'), KkSequenceParticipant('b')],
      entries: <KkSequenceEntry>[KkSequenceMessage('b', 'b', 'A LOOP WITH A LONG LABEL ON THE LAST LIFELINE')],
      framed: false,
    );
    expect(kkSequenceNaturalWidth(self), greaterThan(kkSequenceNaturalWidth(short) + 150));
    expect(kkSequenceNaturalWidth(short, typeScale: 1.25), greaterThanOrEqualTo(kkSequenceNaturalWidth(short)));
  });

  testWidgets('is announced as a list of who tells whom what', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpKk(tester, const KkSequenceDiagram(participants: parties, entries: handover, framed: false));
    expect(
      find.bySemanticsLabel(RegExp(r'^Sequence, 4 participants\. OP-07 to CTRL: REQUEST CONTROL\. CTRL to SEC-04: PING')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('edge cases: nothing at all, no messages, one party, tiny boxes, both themes', (WidgetTester tester) async {
    final List<Widget> cases = <Widget>[
      const KkSequenceDiagram(participants: <KkSequenceParticipant>[], entries: <KkSequenceEntry>[]),
      const KkSequenceDiagram(participants: parties, entries: <KkSequenceEntry>[]),
      const KkSequenceDiagram(
        participants: <KkSequenceParticipant>[KkSequenceParticipant('solo')],
        entries: <KkSequenceEntry>[KkSequenceMessage('solo', 'solo', 'TICK'), KkSequenceDivider(en: 'only a divider')],
        framed: false,
      ),
      const KkBox(width: 12, height: 9, child: KkSequenceDiagram(participants: parties, entries: handover, framed: false)),
      const KkBox(width: 80, child: KkSequenceDiagram(participants: parties, entries: handover, cjk: '狭', en: 'narrow')),
      const KkSequenceDiagram(participants: parties, entries: handover, rowHeight: 24, minColumnGap: 40, level: KkLevel.critical),
      const KkSequenceDiagram(
        participants: <KkSequenceParticipant>[KkSequenceParticipant('a', code: 'A-PARTICIPANT-WITH-A-VERY-LONG-CODE-0123456789'), KkSequenceParticipant('b')],
        entries: <KkSequenceEntry>[
          KkSequenceMessage('a', 'b', 'X', note: 'A NOTE THAT IS MUCH LONGER THAN NOTES USUALLY ARE'),
          // A reply with no call before it, and calls that are never answered.
          KkSequenceMessage('b', 'a', 'Y', kind: KkSequenceMessageKind.reply),
          KkSequenceMessage('a', 'b', 'Z'),
          KkSequenceMessage('a', 'b', 'Z AGAIN'),
        ],
      ),
    ];
    for (final KkCondition condition in KkCondition.values) {
      for (final Widget w in cases) {
        await pumpKk(tester, w, condition: condition);
        expect(tester.takeException(), isNull, reason: '$w');
      }
    }
  });

  testWidgets('a message that names nobody in the diagram is flagged while developing', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkSequenceDiagram(
        participants: <KkSequenceParticipant>[KkSequenceParticipant('a')],
        entries: <KkSequenceEntry>[KkSequenceMessage('a', 'ghost', 'HELLO')],
        framed: false,
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('messages are drawn one after another, then it rests', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkBox(width: 720, child: KkSequenceDiagram(participants: parties, entries: handover)),
      motion: true,
    );
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
    }
    await pumpKk(tester, const KkBox(width: 720, child: KkSequenceDiagram(participants: parties, entries: handover, animate: false)), motion: true);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
    await pumpKk(tester, const KkBox(width: 720, child: KkSequenceDiagram(participants: parties, entries: handover)));
    await tester.pumpAndSettle();
  });

  test('model values compare by content', () {
    expect(const KkSequenceParticipant('a', code: 'A'), const KkSequenceParticipant('a', code: 'A'));
    expect(const KkSequenceParticipant('a'), isNot(const KkSequenceParticipant('a', level: KkLevel.caution)));
    expect(const KkSequenceParticipant('a').text, 'a');
    expect(const KkSequenceParticipant('a', code: '').text, 'a');
    expect(const KkSequenceMessage('a', 'b', 'X'), const KkSequenceMessage('a', 'b', 'X'));
    expect(const KkSequenceMessage('a', 'b', 'X'), isNot(const KkSequenceMessage('a', 'b', 'X', kind: KkSequenceMessageKind.reply)));
    expect(const KkSequenceMessage('a', 'b', 'X').hashCode, const KkSequenceMessage('a', 'b', 'X').hashCode);
    expect(const KkSequenceDivider(en: 'x'), const KkSequenceDivider(en: 'x'));
    expect(const KkSequenceDivider(en: 'x'), isNot(const KkSequenceDivider(cjk: 'x')));
  });
}
