import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

const List<KkSelectOption<Duration>> _presets = <KkSelectOption<Duration>>[
  KkSelectOption<Duration>(value: Duration(minutes: 15), label: 'Last 15 min'),
  KkSelectOption<Duration>(value: Duration(hours: 1), label: 'Last 1 h'),
  KkSelectOption<Duration>(value: Duration(hours: 6), label: 'Last 6 h'),
];

final DateTime _start = DateTime.utc(2026, 11, 25, 14);
final DateTime _end = DateTime.utc(2026, 11, 25, 15, 0, 30);

/// Holds the state of a range bar, the way a dashboard would.
class _Host extends StatefulWidget {
  const _Host({this.enabled = true});

  final bool enabled;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool live = false;
  Duration? preset = const Duration(hours: 1);
  int refreshed = 0;
  int rangePressed = 0;
  final List<bool> liveChanges = <bool>[];
  final List<Duration> presetChanges = <Duration>[];

  @override
  Widget build(BuildContext context) => KkTimeRange<Duration>(
    start: _start,
    end: _end,
    enabled: widget.enabled,
    live: live,
    onLiveChanged: (bool v) {
      liveChanges.add(v);
      setState(() => live = v);
    },
    presets: _presets,
    preset: preset,
    onPresetChanged: (Duration v) {
      presetChanges.add(v);
      setState(() => preset = v);
    },
    onRefresh: () => refreshed++,
    onRangePressed: () => rangePressed++,
  );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

/// The 8px lamp of the LIVE toggle.
KkBox _lamp(WidgetTester tester) =>
    tester.widget<KkBox>(find.byWidgetPredicate((Widget w) => w is KkBox && w.width == 8 && w.height == 8));

/// The box of the LIVE toggle.
KkBox _liveBox(WidgetTester tester) =>
    tester.widget<KkBox>(find.ancestor(of: find.text('LIVE'), matching: find.byType(KkBox)).first);

void main() {
  setUpAll(loadKkFonts);
  setUp(KkInputModality.notePointer);

  group('KkTimeRange', () {
    testWidgets('the range reads as UTC times; alone it is just a 32px box', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkTimeRange<Never>(start: _start, end: _end),
        padding: const EdgeInsets.all(20),
      );
      expect(find.text('14:00Z — 15:00Z'), findsOneWidget);
      expect(find.byType(KkPressable), findsNothing);
      expect(find.byType(KkIconButton), findsNothing);
      expect(find.byType(KkSelect<Never>), findsNothing);
      expect(find.text('LIVE'), findsNothing);
      final Size size = tester.getSize(find.byType(KkTimeRange<Never>));
      expect(size.height, 32);
      // 1 + 12 + icon 16 + 6 + text + 12 + 1.
      expect(size.width, closeTo(48 + tester.getSize(find.text('14:00Z — 15:00Z')).width, 0.01));
      const KkColors c = KkColors.standby;
      expect(tester.widget<KkIcon>(find.byType(KkIcon)).icon, KkIcons.calendar);
      expect(tester.widget<KkIcon>(find.byType(KkIcon)).color, c.signal);
      final Text text = tester.widget<Text>(find.text('14:00Z — 15:00Z'));
      expect(text.style!.fontSize, 12);
      expect(text.style!.fontFamily, contains('IBM Plex Mono'));
      expect(text.style!.color, c.ink);
    });

    testWidgets('seconds, open ends, local times and a text of its own', (WidgetTester tester) async {
      await pumpKk(tester, KkTimeRange<Never>(start: _start, end: _end, showSeconds: true));
      expect(find.text('14:00:00Z — 15:00:30Z'), findsOneWidget);
      await pumpKk(tester, KkTimeRange<Never>(start: _start));
      expect(find.text('14:00Z — --:--'), findsOneWidget);
      await pumpKk(tester, const KkTimeRange<Never>());
      expect(find.text('--:-- — --:--'), findsOneWidget);
      // A local time is shown as the UTC instant it is.
      final DateTime local = _start.toLocal();
      await pumpKk(tester, KkTimeRange<Never>(start: local, end: _end));
      expect(find.text('14:00Z — 15:00Z'), findsOneWidget);
      await pumpKk(tester, KkTimeRange<Never>(start: _start, end: _end, text: 'SHIFT B · 14:00Z — 22:00Z'));
      expect(find.text('SHIFT B · 14:00Z — 22:00Z'), findsOneWidget);
      expect(find.text('14:00Z — 15:00Z'), findsNothing);
    });

    testWidgets('all parts: in a row, 32px high, 8px apart', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(20));
      final Rect range = tester.getRect(find.byType(KkPressable).first);
      final Rect live = tester.getRect(find.ancestor(of: find.text('LIVE'), matching: find.byType(KkPressable)));
      final Rect select = tester.getRect(find.byType(KkSelect<Duration>));
      final Rect refresh = tester.getRect(find.byType(KkIconButton));
      for (final Rect r in <Rect>[range, live, select, refresh]) {
        expect(r.height, 32);
        expect(r.top, 20);
      }
      expect(live.left, closeTo(range.right + 8, 0.01));
      expect(select.left, closeTo(live.right + 8, 0.01));
      expect(refresh.left, closeTo(select.right + 8, 0.01));
      expect(refresh.width, 32);
      expect(find.text('Last 1 h'), findsOneWidget);
      expect(tester.widget<KkIconButton>(find.byType(KkIconButton)).variant, KkIconButtonVariant.outline);
      expect(tester.widget<KkSelect<Duration>>(find.byType(KkSelect<Duration>)).size, KkSelectSize.sm);
    });

    testWidgets('in a narrow parent the parts wrap onto a second row, 8px below', (WidgetTester tester) async {
      await pumpKk(tester, const KkBox(width: 260, child: _Host()), padding: const EdgeInsets.all(20));
      final Rect range = tester.getRect(find.byType(KkPressable).first);
      final Rect refresh = tester.getRect(find.byType(KkIconButton));
      expect(refresh.top, greaterThanOrEqualTo(range.bottom + 8));
      expect(refresh.right, lessThanOrEqualTo(20 + 260));
      expect(tester.takeException(), isNull);
    });

    testWidgets('LIVE toggles: onLiveChanged gets the other state; on is nominal with a full lamp', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(20));
      const KkColors c = KkColors.standby;
      expect(tester.widget<Text>(find.text('LIVE')).style!.color, c.inkDim);
      expect(_liveBox(tester).decoration!.edges.top, KkSide(c.inkFaint));
      expect(_lamp(tester).decoration!.fill, isNull);
      expect(_lamp(tester).decoration!.edges.top, KkSide(c.inkDim, width: 1.5));
      expect(tester.widget<KkBlink>(find.byType(KkBlink)).enabled, isFalse);

      await tester.tap(find.text('LIVE'));
      await tester.pump();
      expect(_host(tester).liveChanges, <bool>[true]);
      expect(tester.widget<Text>(find.text('LIVE')).style!.color, c.nominal);
      expect(_liveBox(tester).decoration!.edges.top, KkSide(c.nominal));
      expect(_lamp(tester).decoration!.fill, c.nominal);
      expect(tester.widget<KkBlink>(find.byType(KkBlink)).enabled, isTrue);
      expect(tester.widget<KkBlink>(find.byType(KkBlink)).period, const Duration(seconds: 1));

      await tester.tap(find.text('LIVE'));
      await tester.pump();
      expect(_host(tester).liveChanges, <bool>[true, false]);
      expect(_lamp(tester).decoration!.fill, isNull);
    });

    testWidgets('LIVE from the keyboard: Tab to it, Space toggles', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(20));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(_host(tester).liveChanges, <bool>[true]);
      // The first stop was the range itself.
      expect(_host(tester).rangePressed, 0);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_host(tester).rangePressed, 1);
    });

    testWidgets('the lamp blinks once a second while live, and only with motion on', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkTimeRange<Never>(start: _start, end: _end, live: true, onLiveChanged: (bool v) {}),
        motion: true,
      );
      Finder lampOpacity() => find.ancestor(
        of: find.byWidgetPredicate((Widget w) => w is KkBox && w.width == 8 && w.height == 8),
        matching: find.byType(Opacity),
      );
      final Set<double> seen = <double>{};
      for (int i = 0; i < 12; i++) {
        seen.add(tester.widget<Opacity>(lampOpacity().first).opacity);
        await tester.pump(const Duration(milliseconds: 250));
      }
      // Two states and nothing in between: on, and dim.
      expect(seen.length, 2);
      expect(seen, contains(1.0));

      await pumpKk(tester, KkTimeRange<Never>(start: _start, end: _end, live: true, onLiveChanged: (bool v) {}));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('live with no callback is a plain indicator; neither given, the part is left out', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, KkTimeRange<Never>(start: _start, end: _end, live: true, liveLabel: 'tracking'));
      expect(find.text('TRACKING'), findsOneWidget);
      expect(_lamp(tester).decoration!.fill, isNotNull);
      await tester.tap(find.text('TRACKING'), warnIfMissed: false);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await pumpKk(tester, KkTimeRange<Never>(start: _start, end: _end));
      expect(find.text('LIVE'), findsNothing);
    });

    testWidgets('presets: the select reports the chosen one', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(20));
      await tester.tap(find.byType(KkSelect<Duration>));
      await tester.pump();
      expect(find.text('LAST 15 MIN'), findsOneWidget);
      await tester.tap(find.text('LAST 6 H'));
      await tester.pump();
      await tester.pump();
      expect(_host(tester).presetChanges, <Duration>[const Duration(hours: 6)]);
      expect(find.text('Last 6 h'), findsOneWidget);
      expect(find.byType(KkMenu<Duration>), findsNothing);
      // Nothing else was touched.
      expect(_host(tester).liveChanges, isEmpty);
      expect(_host(tester).refreshed, 0);
    });

    testWidgets('presets: a placeholder while none is chosen; with no callback the select is off', (
      WidgetTester tester,
    ) async {
      await pumpKk(
        tester,
        KkTimeRange<Duration>(start: _start, end: _end, presets: _presets, presetPlaceholder: 'Preset'),
      );
      expect(find.text('Preset'), findsOneWidget);
      await tester.tap(find.byType(KkSelect<Duration>), warnIfMissed: false);
      await tester.pump();
      expect(find.byType(KkMenu<Duration>), findsNothing);
    });

    testWidgets('refresh: each press calls onRefresh and turns the icon once', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(20));
      final Object? before = tester.widget<KkIconButton>(find.byType(KkIconButton)).spinTrigger;
      await tester.tap(find.byType(KkIconButton));
      await tester.pump();
      expect(_host(tester).refreshed, 1);
      final Object? after = tester.widget<KkIconButton>(find.byType(KkIconButton)).spinTrigger;
      expect(after, isNot(before));
      await tester.tap(find.byType(KkIconButton));
      await tester.pump();
      expect(_host(tester).refreshed, 2);
      expect(tester.widget<KkIconButton>(find.byType(KkIconButton)).spinTrigger, isNot(after));
      expect(tester.widget<KkIconButton>(find.byType(KkIconButton)).icon, KkIcons.refresh);
    });

    testWidgets('the range is a button when onRangePressed is given', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(20));
      await tester.tap(find.text('14:00Z — 15:00Z'));
      await tester.pump();
      expect(_host(tester).rangePressed, 1);
      expect(_host(tester).refreshed, 0);
    });

    testWidgets('disabled: dashed and faint, and nothing answers', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(enabled: false), padding: const EdgeInsets.all(20));
      const KkColors c = KkColors.standby;
      expect(tester.widget<Text>(find.text('14:00Z — 15:00Z')).style!.color, c.inkFaint);
      expect(tester.widget<Text>(find.text('LIVE')).style!.color, c.inkFaint);
      expect(_liveBox(tester).decoration!.edges.top, KkSide(c.offline, dashed: true));
      await tester.tap(find.text('14:00Z — 15:00Z'), warnIfMissed: false);
      await tester.tap(find.text('LIVE'), warnIfMissed: false);
      await tester.tap(find.byType(KkIconButton), warnIfMissed: false);
      await tester.tap(find.byType(KkSelect<Duration>), warnIfMissed: false);
      await tester.pump();
      final _HostState host = _host(tester);
      expect(host.rangePressed, 0);
      expect(host.liveChanges, isEmpty);
      expect(host.refreshed, 0);
      expect(find.byType(KkMenu<Duration>), findsNothing);
    });

    testWidgets('semantics: the range as text, a toggle, a labelled select and button', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(20));
      final SemanticsNode range = tester.getSemantics(find.byType(KkPressable).first);
      expect(range.label, '14:00Z — 15:00Z');
      expect(range.flagsCollection.isButton, isTrue);
      final SemanticsNode live = tester.getSemantics(
        find.ancestor(of: find.text('LIVE'), matching: find.byType(KkPressable)),
      );
      expect(live.label, 'live');
      expect(live.flagsCollection.isToggled, Tristate.isFalse);
      expect(tester.getSemantics(find.byType(KkIconButton)).label, 'Refresh');
      await tester.tap(find.text('LIVE'));
      await tester.pump();
      expect(
        tester
            .getSemantics(find.ancestor(of: find.text('LIVE'), matching: find.byType(KkPressable)))
            .flagsCollection
            .isToggled,
        Tristate.isTrue,
      );
      // Without a press handler the range is plain text for a reader.
      await pumpKk(tester, KkTimeRange<Never>(start: _start, end: _end));
      expect(find.bySemanticsLabel('14:00Z — 15:00Z'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the alert theme keeps the live colour apart from the signal', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkTimeRange<Never>(start: _start, end: _end, live: true, onLiveChanged: (bool v) {}),
        condition: KkCondition.alert,
      );
      expect(tester.widget<Text>(find.text('LIVE')).style!.color, KkColors.alertTheme.nominal);
      expect(tester.widget<KkIcon>(find.byType(KkIcon)).color, KkColors.alertTheme.signal);
    });
  });
}
