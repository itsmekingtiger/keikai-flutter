import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart';
import '../support/harness.dart';

String _digits(WidgetTester tester) {
  final Text text = tester.widget(find.descendant(of: find.byType(KkBlink), matching: find.byType(Text)));
  return text.textSpan!.toPlainText();
}

/// The fill the bar is painted with, 0 to 1.
double _bar(WidgetTester tester) {
  final CustomPaint paint = tester.widget(
    find.descendant(of: find.byType(KkTimer), matching: find.byType(CustomPaint)),
  );
  // ignore: avoid_dynamic_calls
  return (paint.painter! as dynamic).value as double;
}

void main() {
  setUpAll(loadKkFonts);

  group('kkFormatTimer', () {
    ({String digits, String? centis}) f(Duration d, [KkTimerFormat format = KkTimerFormat.auto]) =>
        kkFormatTimer(d, format: format);

    test('zero', () {
      expect(f(Duration.zero), (digits: '00:00', centis: '.00'));
      expect(f(Duration.zero, KkTimerFormat.hours), (digits: '00:00:00', centis: null));
    });

    test('minutes, seconds and centiseconds below one hour', () {
      expect(f(const Duration(minutes: 4, seconds: 59, milliseconds: 820)), (digits: '04:59', centis: '.82'));
      expect(f(const Duration(milliseconds: 9)), (digits: '00:00', centis: '.00'));
      expect(f(const Duration(milliseconds: 10)), (digits: '00:00', centis: '.01'));
      expect(f(const Duration(minutes: 59, seconds: 59, milliseconds: 999)), (digits: '59:59', centis: '.99'));
    });

    test('hours from one hour on', () {
      expect(f(const Duration(hours: 1)), (digits: '01:00:00', centis: null));
      expect(f(const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 456)), (
        digits: '01:02:03',
        centis: null,
      ));
      expect(f(const Duration(hours: 123, minutes: 4, seconds: 5)), (digits: '123:04:05', centis: null));
    });

    test('forced formats', () {
      expect(f(const Duration(hours: 2, minutes: 5, seconds: 7, milliseconds: 330), KkTimerFormat.minutes), (
        digits: '125:07',
        centis: '.33',
      ));
      expect(f(const Duration(seconds: 61), KkTimerFormat.hours), (digits: '00:01:01', centis: null));
    });

    test('negative times keep one sign in front; a rounding-size negative has none', () {
      expect(f(const Duration(seconds: -5, milliseconds: -250)), (digits: '-00:05', centis: '.25'));
      expect(f(const Duration(hours: -1, minutes: -30)), (digits: '-01:30:00', centis: null));
      expect(f(const Duration(milliseconds: -4)), (digits: '00:00', centis: '.00'));
    });
  });

  testWidgets('a controlled timer shows its value; the box hugs the digits, 264px at least', (
    WidgetTester tester,
  ) async {
    await pumpKk(
      tester,
      const KkTimer(
        cjk: '残り時間',
        en: 't-minus',
        mode: 'COUNTDOWN',
        value: Duration(minutes: 4, seconds: 59, milliseconds: 820),
        progress: 0.62,
      ),
    );
    expect(_digits(tester), '04:59.82');
    expect(find.text('COUNTDOWN'), findsOneWidget);
    final Size size = tester.getSize(find.byType(KkTimer));
    expect(size.width, greaterThanOrEqualTo(264));
    expect(size.height, lessThan(140));
    // The digits are a 56px line.
    expect(tester.getSize(find.descendant(of: find.byType(KkBlink), matching: find.byType(Text))).height, 56);

    await pumpKk(tester, const KkTimer(value: Duration(seconds: 3)));
    expect(tester.getSize(find.byType(KkTimer)).width, 264);
    // No head row when there is nothing to put in it: 1 + 12 + 56 + 8 + 4 + 12 + 1.
    expect(tester.getSize(find.byType(KkTimer)).height, 94);
  });

  testWidgets('the head is its labels and the mode with one gap between each', (WidgetTester tester) async {
    // A timer that hugs a long head is as wide as cjk + 8 + en + 8 + mode inside its 16px padding and 1px border.
    await pumpKk(
      tester,
      const KkWrap(
        children: <Widget>[
          KkTimer(
            cjk: '残り時間残り時間',
            en: 't-minus to automatic shutdown',
            mode: 'COUNTDOWN ARMED',
            value: Duration(seconds: 5),
          ),
        ],
      ),
    );
    Rect cjk = tester.getRect(find.byType(KkSqueeze));
    Rect en = tester.getRect(find.text('T-MINUS TO AUTOMATIC SHUTDOWN'));
    final Rect mode = tester.getRect(find.text('COUNTDOWN ARMED'));
    expect(en.left - cjk.right, closeTo(8, 0.01));
    expect(mode.left - en.right, closeTo(8, 0.01));
    expect(tester.getSize(find.byType(KkTimer)).width, greaterThan(264));
    expect(
      tester.getSize(find.byType(KkTimer)).width,
      closeTo(1 + 16 + cjk.width + 8 + en.width + 8 + mode.width + 16 + 1, 0.01),
    );

    // Without a mode nothing follows the labels, not even a gap.
    await pumpKk(
      tester,
      const KkWrap(
        children: <Widget>[
          KkTimer(cjk: '残り時間残り時間', en: 't-minus to automatic shutdown sequence', value: Duration(seconds: 5)),
        ],
      ),
    );
    cjk = tester.getRect(find.byType(KkSqueeze));
    en = tester.getRect(find.text('T-MINUS TO AUTOMATIC SHUTDOWN SEQUENCE'));
    expect(tester.getSize(find.byType(KkTimer)).width, greaterThan(264));
    expect(tester.getSize(find.byType(KkTimer)).width, closeTo(1 + 16 + cjk.width + 8 + en.width + 16 + 1, 0.01));

    // With room to spare, and alone in the head, the mode sits at the right.
    await pumpKk(tester, const KkTimer(cjk: '保持', en: 'hold', mode: 'T-MINUS', value: Duration(seconds: 5)));
    expect(tester.getRect(find.byType(KkSqueeze)).left, 17);
    expect(tester.getRect(find.text('T-MINUS')).right, closeTo(264 - 17, 0.01));
    await pumpKk(tester, const KkTimer(mode: 'T-MINUS', value: Duration(seconds: 5)));
    expect(tester.getRect(find.text('T-MINUS')).right, closeTo(264 - 17, 0.01));
  });

  testChecked('with any mix of head parts it passes the render self-checks at any width', (WidgetTester tester) async {
    const List<Widget> timers = <Widget>[
      KkTimer(cjk: '残り時間', en: 't-minus', mode: 'COUNTDOWN', value: Duration(seconds: 5)),
      KkTimer(en: 't-minus', value: Duration(seconds: 5)),
      KkTimer(mode: 'COUNTDOWN', value: Duration(hours: 5)),
      KkTimer(value: Duration(seconds: 5)),
    ];
    // Hugging, side by side.
    await pumpKk(
      tester,
      const KkWrap(gap: 8, cross: KkCrossAlign.start, children: timers),
      size: const Size(1400, 600),
    );
    expect(tester.takeException(), isNull);
    // Filling a column, down to widths where neither head nor digits fit.
    for (final double width in <double>[0, 40, 120, 264, 400]) {
      await pumpKk(
        tester,
        KkBox(
          width: width,
          child: const KkColumn(gap: 8, shrinkWrap: true, children: timers),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    // On a shared baseline, which measures each one without laying it out.
    await pumpKk(
      tester,
      const KkRow(cross: KkCrossAlign.baseline, gap: 8, children: timers),
      size: const Size(1400, 600),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('caution colours the border; critical adds the glow and blinks the digits', (WidgetTester tester) async {
    const KkColors c = KkColors.standby;
    KkDecoration frame() =>
        tester.widget<KkBox>(find.descendant(of: find.byType(KkTimer), matching: find.byType(KkBox)).first).decoration!;

    await pumpKk(tester, const KkTimer(value: Duration(seconds: 90)));
    expect(frame().edges.top.color, c.line);
    expect(frame().glow, isNull);
    expect(tester.widget<KkBlink>(find.byType(KkBlink)).enabled, isFalse);

    await pumpKk(tester, const KkTimer(value: Duration(seconds: 90), level: KkLevel.caution));
    expect(frame().edges.top.color, c.caution);
    expect(frame().glow, isNull);

    await pumpKk(tester, const KkTimer(value: Duration(seconds: 9), level: KkLevel.critical));
    expect(frame().edges.top.color, c.alert);
    expect(frame().glow, c.glowAlert);
    expect(tester.widget<KkBlink>(find.byType(KkBlink)).enabled, isTrue);
  });

  testWidgets('critical digits blink: full for 0.6s, dim for 0.6s', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkTimer(value: Duration(seconds: 9), level: KkLevel.critical, boot: false),
      motion: true,
    );
    double opacity() =>
        tester.widget<Opacity>(find.descendant(of: find.byType(KkBlink), matching: find.byType(Opacity))).opacity;
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(), 1);
    await tester.pump(const Duration(milliseconds: 600));
    expect(opacity(), 0.2);
    await tester.pump(const Duration(milliseconds: 600));
    expect(opacity(), 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a countdown ticks by itself, changes level near the end and reports when done', (
    WidgetTester tester,
  ) async {
    int done = 0;
    await pumpKk(
      tester,
      KkTimer.countdown(
        from: const Duration(seconds: 3),
        cautionAt: const Duration(seconds: 2),
        criticalAt: const Duration(seconds: 1),
        onDone: () => done++,
      ),
    );
    KkDecoration frame() =>
        tester.widget<KkBox>(find.descendant(of: find.byType(KkTimer), matching: find.byType(KkBox)).first).decoration!;
    expect(_digits(tester), '00:03.00');
    expect(frame().edges.top.color, KkColors.standby.line);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_digits(tester), '00:02.00');
    expect(frame().edges.top.color, KkColors.standby.caution);

    await tester.pump(const Duration(milliseconds: 1250));
    expect(_digits(tester), '00:00.75');
    expect(frame().edges.top.color, KkColors.standby.alert);
    expect(done, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(_digits(tester), '00:00.00');
    expect(done, 1);
    // It has stopped: more time changes nothing and does not call again.
    await tester.pump(const Duration(seconds: 5));
    expect(_digits(tester), '00:00.00');
    expect(done, 1);
  });

  testWidgets('the bar of a countdown is the time left, not the whole seconds left', (WidgetTester tester) async {
    // With motion off the bar shows the share that is left at once.
    await pumpKk(tester, const KkTimer.countdown(from: Duration(seconds: 2)));
    expect(_bar(tester), 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_digits(tester), '00:01.50');
    expect(_bar(tester), 0.75);
    await tester.pump(const Duration(milliseconds: 1250));
    expect(_digits(tester), '00:00.25');
    expect(_bar(tester), 0.125);
    await tester.pump(const Duration(milliseconds: 250));
    expect(_digits(tester), '00:00.00');
    expect(_bar(tester), 0);

    // With motion on it steps down after the time, never more than 0.65s behind it.
    await pumpKk(tester, const KkTimer.countdown(from: Duration(seconds: 3), boot: false), motion: true);
    expect(_bar(tester), 1);
    for (int ms = 16; ms <= 3008; ms += 16) {
      await tester.pump(const Duration(milliseconds: 16));
      final double left = ms >= 3000 ? 0 : (3000 - ms) / 3000;
      expect(_bar(tester), greaterThanOrEqualTo(left - 1e-9), reason: '${ms}ms');
      expect(_bar(tester) - left, lessThan(0.65 / 3), reason: '${ms}ms');
    }
    expect(_digits(tester), '00:00.00');
    // It is empty no later than one transition after the time has run out.
    await tester.pump(const Duration(milliseconds: 450));
    expect(_bar(tester), 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the bar of a controlled timer follows a progress that changes with every frame', (
    WidgetTester tester,
  ) async {
    Duration left = const Duration(seconds: 10);
    late StateSetter rebuild;
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          rebuild = setState;
          return KkTimer(value: left, progress: left.inMilliseconds / 10000, boot: false);
        },
      ),
      motion: true,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(_bar(tester), 1);
    // The app counts down itself and rebuilds the timer with each 16ms frame.
    for (int frame = 1; frame <= 300; frame++) {
      rebuild(() => left = Duration(milliseconds: 10000 - frame * 16));
      await tester.pump(const Duration(milliseconds: 16));
      final double progress = left.inMilliseconds / 10000;
      expect(_bar(tester), greaterThanOrEqualTo(progress - 1e-9), reason: 'frame $frame');
      expect(_bar(tester) - progress, lessThan(0.65 / 10), reason: 'frame $frame');
    }
    expect(_digits(tester), '00:05.20');
    expect(_bar(tester), lessThan(0.6));
    await tester.pump(const Duration(milliseconds: 450));
    expect(_bar(tester), closeTo(0.52, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a controller starts, stops and resets a stopwatch', (WidgetTester tester) async {
    final KkTimerController controller = KkTimerController();
    addTearDown(controller.dispose);
    int notified = 0;
    controller.addListener(() => notified++);
    await pumpKk(tester, KkTimer.stopwatch(controller: controller, autostart: false));
    expect(controller.isRunning, isFalse);
    expect(_digits(tester), '00:00.00');
    await tester.pump(const Duration(seconds: 1));
    expect(_digits(tester), '00:00.00');

    controller.start();
    expect(controller.isRunning, isTrue);
    expect(notified, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(_digits(tester), '00:01.50');
    expect(controller.elapsed, const Duration(milliseconds: 1500));

    controller.stop();
    expect(controller.isRunning, isFalse);
    await tester.pump(const Duration(seconds: 3));
    expect(_digits(tester), '00:01.50', reason: 'stopped time is kept');

    controller.toggle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_digits(tester), '00:02.00', reason: 'resuming adds to the banked time');

    controller.reset();
    await tester.pump();
    expect(controller.isRunning, isFalse);
    expect(controller.elapsed, Duration.zero);
    expect(_digits(tester), '00:00.00');
    // start, stop, toggle (start), reset.
    expect(notified, 4);

    // A controller with no timer attached is inert.
    final KkTimerController loose = KkTimerController();
    addTearDown(loose.dispose);
    loose
      ..start()
      ..stop()
      ..reset();
    expect(loose.isRunning, isFalse);
    expect(loose.elapsed, Duration.zero);
  });

  testWidgets('a countdown keeps time under a page that covers it and reports done there', (WidgetTester tester) async {
    final KkTimerController controller = KkTimerController();
    addTearDown(controller.dispose);
    int done = 0;
    int notified = 0;
    controller.addListener(() => notified++);
    await pumpKk(
      tester,
      KkTimer.countdown(from: const Duration(seconds: 5), controller: controller, onDone: () => done++),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(_digits(tester), '00:04.00');

    // Another page covers the timer's. Tickers under it are silent from here on.
    final NavigatorState navigator = tester.state(find.byType(Navigator));
    navigator.push(KkPageRoute<void>(builder: (BuildContext context) => const KkText.en('another page')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkTimer), findsNothing);
    expect(find.byType(KkTimer, skipOffstage: false), findsOneWidget);

    // The time is counted all the same, a tenth of a second at a time.
    await tester.pump(const Duration(milliseconds: 3900));
    expect(done, 0);
    expect(controller.isRunning, isTrue);
    expect(controller.elapsed.inMilliseconds, inInclusiveRange(4800, 4900));
    await tester.pump(const Duration(milliseconds: 200));
    expect(done, 1, reason: 'when the time is up, not when the page comes back');
    expect(notified, 1);
    expect(controller.isRunning, isFalse);
    expect(controller.elapsed, const Duration(seconds: 5));

    await tester.pump(const Duration(seconds: 6));
    navigator.pop();
    await tester.pump();
    await tester.pump();
    expect(_digits(tester), '00:00.00');
    expect(done, 1);
    expect(notified, 1);
  });

  testWidgets('a stopwatch keeps time while tickers are disabled around it', (WidgetTester tester) async {
    final KkTimerController controller = KkTimerController();
    addTearDown(controller.dispose);
    bool enabled = true;
    late StateSetter rebuild;
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          rebuild = setState;
          return TickerMode(
            enabled: enabled,
            child: KkTimer.stopwatch(controller: controller),
          );
        },
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(_digits(tester), '00:01.00');

    rebuild(() => enabled = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5050));
    // No frame reports the time now, so the digits stand still, but the time is counted.
    expect(_digits(tester), '00:01.00');
    expect(controller.isRunning, isTrue);
    expect(controller.elapsed.inMilliseconds, inInclusiveRange(5950, 6050));

    // Stopped there, the timer keeps what was counted there.
    controller.stop();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.elapsed.inMilliseconds, inInclusiveRange(5950, 6050));
    controller.start();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.elapsed.inMilliseconds, inInclusiveRange(6950, 7050));

    // Back on the frame clock the count goes on from there.
    rebuild(() => enabled = true);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.elapsed.inMilliseconds, inInclusiveRange(7450, 7550));
    expect(_digits(tester), startsWith('00:07.5'));
  });

  testWidgets('time under disabled tickers is exact once frames report it again', (WidgetTester tester) async {
    bool enabled = true;
    late StateSetter rebuild;
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          rebuild = setState;
          return TickerMode(enabled: enabled, child: const KkTimer.stopwatch());
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 1230));
    rebuild(() => enabled = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5040));
    rebuild(() => enabled = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // 1.23s shown, 5.04s hidden, 0.1s shown: nothing is rounded to the tenths counted while hidden.
    expect(_digits(tester), '00:06.37');
  });

  testWidgets('a countdown built under disabled tickers counts from its first frame, once', (
    WidgetTester tester,
  ) async {
    final KkTimerController controller = KkTimerController();
    addTearDown(controller.dispose);
    bool enabled = false;
    int done = 0;
    late StateSetter rebuild;
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          rebuild = setState;
          return TickerMode(
            enabled: enabled,
            child: KkTimer.countdown(from: const Duration(seconds: 3), controller: controller, onDone: () => done++),
          );
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 1040));
    expect(controller.elapsed, const Duration(seconds: 1));

    // The frame clock takes over with the whole 1.04s, not on top of the second counted so far.
    rebuild(() => enabled = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.elapsed, const Duration(milliseconds: 1540));
    expect(_digits(tester), '00:01.46');

    // Hidden again, it runs out there.
    rebuild(() => enabled = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(done, 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(done, 1);
    expect(controller.isRunning, isFalse);
    expect(_digits(tester), '00:00.00');
  });

  testWidgets('a disposed stopwatch lets go of its controller and its ticker', (WidgetTester tester) async {
    final KkTimerController controller = KkTimerController();
    addTearDown(controller.dispose);
    await pumpKk(tester, KkTimer.stopwatch(controller: controller));
    expect(controller.isRunning, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(controller.isRunning, isFalse);
    controller.start();
    expect(controller.isRunning, isFalse);
  });

  testWidgets('odd input and tiny boxes do not throw', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkBox(
        width: 20,
        height: 10,
        child: KkTimer(cjk: '残り時間', en: 't-minus', mode: 'COUNTDOWN', value: Duration(hours: 99), progress: 7),
      ),
    );
    expect(tester.takeException(), isNull);
    await pumpKk(tester, const KkTimer(value: Duration(seconds: -5), progress: double.nan));
    expect(tester.takeException(), isNull);
    expect(_digits(tester), '-00:05.00');
    await pumpKk(tester, const KkTimer.countdown(from: Duration.zero));
    expect(tester.takeException(), isNull);
    expect(_digits(tester), '00:00.00');
  });
}
