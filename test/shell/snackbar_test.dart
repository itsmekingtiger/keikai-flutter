import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/controls/controls.dart';
import 'package:keikai/src/shell/shell.dart';

import '../support/harness.dart';

/// Pumps an empty page and returns the app's messenger.
Future<KkMessengerState> _messenger(
  WidgetTester tester, {
  Size size = const Size(1000, 700),
  bool motion = false,
}) async {
  await pumpKk(tester, const KkBox(key: ValueKey<String>('page')), size: size, motion: motion);
  return KkMessenger.of(tester.element(find.byKey(const ValueKey<String>('page'))));
}

void main() {
  setUpAll(loadKkFonts);

  group('KkSnackbar', () {
    testWidgets('is 40px high with the code block in the level colour', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkSnackbar(code: 'E-4127', level: KkLevel.critical, message: 'COOLANT PRESSURE LOW'),
        size: const Size(1000, 300),
      );
      final KkColors c = KkColors.standby;
      final Rect bar = tester.getRect(find.byType(KkSnackbar));
      expect(bar.height, 40);
      final Finder block = find.descendant(of: find.byType(KkSnackbar), matching: find.byType(KkSurface));
      expect(tester.widget<KkSurface>(block).fill, c.alert);
      expect(tester.widget<KkSurface>(block).shape, const KkShape.slant(10));
      // The block runs the full inner height (40 less the two 1px borders).
      expect(tester.getRect(block).height, 38);
      expect(tester.getRect(block).left, bar.left + 1);
      expect(tester.widget<Text>(find.text('E-4127')).style!.color, c.onFill);
      final KkGlyph glyph = tester.widget<KkGlyph>(find.byType(KkGlyph));
      expect(glyph.level, KkLevel.critical);
      expect(glyph.size, 10);
      expect(glyph.color, c.onFill);
      final Text message = tester.widget<Text>(find.text('COOLANT PRESSURE LOW'));
      expect(message.style!.fontSize, 12);
      expect(message.style!.color, c.ink);
      // 12px after the block; the block is 12 + glyph 10 + 6 + text + 8 + 10 wide.
      expect(tester.getRect(find.text('COOLANT PRESSURE LOW')).left, tester.getRect(block).right + 12);
    });

    testWidgets('without a level the block is signal and has no status icon', (WidgetTester tester) async {
      await pumpKk(tester, const KkSnackbar(code: 'SYS', message: 'ROUTE TABLE UPDATED'));
      final Finder block = find.descendant(of: find.byType(KkSnackbar), matching: find.byType(KkSurface));
      expect(tester.widget<KkSurface>(block).fill, KkColors.standby.signal);
      expect(find.byType(KkGlyph), findsNothing);
    });

    testWidgets('without a code the block reads the level word; with neither there is no block', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, const KkSnackbar(level: KkLevel.caution, message: 'LINK RESYNC'));
      expect(find.text('CAUTION'), findsOneWidget);
      await pumpKk(tester, const KkSnackbar(message: 'MESSAGE ONLY'));
      expect(find.descendant(of: find.byType(KkSnackbar), matching: find.byType(KkSurface)), findsNothing);
      final Rect bar = tester.getRect(find.byType(KkSnackbar));
      expect(tester.getRect(find.text('MESSAGE ONLY')).left, bar.left + 1 + 12);
      expect(bar.height, 40);
    });

    testWidgets('a long message wraps inside 560px and the bar grows', (WidgetTester tester) async {
      int closes = 0;
      await pumpKk(
        tester,
        KkSnackbar(
          code: 'OP-07',
          message: List<String>.filled(30, 'AUX PUMP B START CONFIRMED').join(' · '),
          onClose: () => closes++,
          action: KkButton(label: 'undo', size: KkButtonSize.sm, variant: KkButtonVariant.ghost, onPressed: () {}),
        ),
        size: const Size(1000, 600),
      );
      expect(tester.takeException(), isNull);
      final Rect bar = tester.getRect(find.byType(KkSnackbar));
      expect(bar.width, 560);
      expect(bar.height, greaterThan(40));
      // Close button and action are centred; the block stretches with the bar.
      final Finder block = find.descendant(of: find.byType(KkSnackbar), matching: find.byType(KkSurface)).first;
      expect(tester.getRect(block).height, bar.height - 2);
      expect(tester.getRect(find.byType(KkIconButton)).center.dy, closeTo(bar.center.dy, 0.5));
      expect(tester.getRect(find.byType(KkIconButton)).right, bar.right - 1 - 4);
      await tester.tap(find.byType(KkIconButton));
      expect(closes, 1);
    });

    testWidgets('survives narrow boxes and custom widths', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 40,
          child: KkSnackbar(code: 'E-4127', level: KkLevel.offline, message: 'NO LINK', onClose: () {}),
        ),
      );
      expect(tester.takeException(), isNull);
      await pumpKk(tester, const KkSnackbar(message: 'X', maxWidth: 200));
      expect(tester.getSize(find.byType(KkSnackbar)).width, lessThanOrEqualTo(200));
    });
  });

  group('KkMessenger', () {
    testWidgets('KeikaiApp provides one; a snackbar shows 24px in and 48px up', (WidgetTester tester) async {
      final KkMessengerState messenger = await _messenger(tester);
      expect(find.byType(KkSnackbar), findsNothing);
      final KkSnackbarHandle handle = messenger.show(code: 'SYS', message: 'ROUTE TABLE UPDATED');
      await tester.pump();
      expect(find.byType(KkSnackbar), findsOneWidget);
      expect(find.text('ROUTE TABLE UPDATED'), findsOneWidget);
      final Rect bar = tester.getRect(find.byType(KkSnackbar));
      expect(bar.left, 24);
      expect(bar.bottom, 700 - 48);
      expect(handle.isOpen, isTrue);
      expect(messenger.count, 1);
      handle.close();
      await tester.pump();
    });

    testWidgets('closes by itself after five seconds', (WidgetTester tester) async {
      final KkMessengerState messenger = await _messenger(tester);
      bool closed = false;
      final KkSnackbarHandle handle = messenger.show(message: 'LINK OK');
      handle.closed.then((_) => closed = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4900));
      expect(find.byType(KkSnackbar), findsOneWidget);
      expect(closed, isFalse);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(KkSnackbar), findsNothing);
      expect(handle.isOpen, isFalse);
      expect(closed, isTrue);
      expect(messenger.count, 0);
    });

    testWidgets('a custom duration is honoured; null keeps it until closed', (WidgetTester tester) async {
      final KkMessengerState messenger = await _messenger(tester);
      messenger.show(message: 'SHORT', duration: const Duration(seconds: 1));
      final KkSnackbarHandle sticky = messenger.show(message: 'STICKY', duration: null);
      await tester.pump();
      expect(find.byType(KkSnackbar), findsNWidgets(2));
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.text('SHORT'), findsNothing);
      await tester.pump(const Duration(minutes: 10));
      expect(find.text('STICKY'), findsOneWidget);
      sticky.close();
      await tester.pump();
      expect(find.text('STICKY'), findsNothing);
      // Closing twice is harmless.
      sticky.close();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the close button and the action button close it', (WidgetTester tester) async {
      final KkMessengerState messenger = await _messenger(tester);
      int retries = 0;
      messenger.show(message: 'LINK CH.12 RESYNC', duration: null, actionLabel: 'retry', onAction: () => retries++);
      await tester.pump();
      await tester.tap(find.text('RETRY'));
      await tester.pump();
      expect(retries, 1);
      expect(find.byType(KkSnackbar), findsNothing);

      messenger.show(message: 'LINK OK', duration: null);
      await tester.pump();
      await tester.tap(find.byType(KkIconButton));
      await tester.pump();
      expect(find.byType(KkSnackbar), findsNothing);

      messenger.show(message: 'NO CLOSE', duration: null, closable: false);
      await tester.pump();
      expect(find.byType(KkIconButton), findsNothing);
      messenger.clear();
      await tester.pump();
      expect(find.byType(KkSnackbar), findsNothing);
    });

    testWidgets('stacks upwards, newest at the bottom, 8px apart', (WidgetTester tester) async {
      final KkMessengerState messenger = await _messenger(tester);
      messenger.show(message: 'FIRST', duration: null);
      messenger.show(message: 'SECOND', duration: null);
      messenger.show(message: 'THIRD', duration: null);
      await tester.pump();
      final Rect first = tester.getRect(find.ancestor(of: find.text('FIRST'), matching: find.byType(KkSnackbar)));
      final Rect second = tester.getRect(find.ancestor(of: find.text('SECOND'), matching: find.byType(KkSnackbar)));
      final Rect third = tester.getRect(find.ancestor(of: find.text('THIRD'), matching: find.byType(KkSnackbar)));
      expect(third.bottom, 700 - 48);
      expect(third.top - second.bottom, 8);
      expect(second.top - first.bottom, 8);
      expect(first.left, 24);
      expect(second.left, 24);
      messenger.clear();
      await tester.pump();
      expect(messenger.count, 0);
    });

    testWidgets('at most four show at once: the oldest makes room', (WidgetTester tester) async {
      final KkMessengerState messenger = await _messenger(tester);
      final List<KkSnackbarHandle> handles = <KkSnackbarHandle>[
        for (int i = 0; i < 6; i++) messenger.show(message: 'MESSAGE $i', duration: null),
      ];
      await tester.pump();
      expect(find.byType(KkSnackbar), findsNWidgets(4));
      expect(find.text('MESSAGE 0'), findsNothing);
      expect(find.text('MESSAGE 1'), findsNothing);
      expect(find.text('MESSAGE 5'), findsOneWidget);
      expect(handles[0].isOpen, isFalse);
      expect(handles[1].isOpen, isFalse);
      expect(handles[2].isOpen, isTrue);
      messenger.clear();
      await tester.pump();
      expect(handles.every((KkSnackbarHandle h) => !h.isOpen), isTrue);
    });

    testWidgets('a messenger of your own sets the limit and the position', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 600,
          height: 400,
          child: KkMessenger(
            maxVisible: 1,
            left: 8,
            bottom: 8,
            child: KkBox(key: ValueKey<String>('inner')),
          ),
        ),
        size: const Size(1000, 700),
      );
      final KkMessengerState messenger = KkMessenger.of(tester.element(find.byKey(const ValueKey<String>('inner'))));
      messenger.show(message: 'ONE', duration: null);
      messenger.show(message: 'TWO', duration: null);
      await tester.pump();
      expect(find.byType(KkSnackbar), findsOneWidget);
      expect(find.text('TWO'), findsOneWidget);
      final Rect bar = tester.getRect(find.byType(KkSnackbar));
      expect(bar.left, 8);
      expect(bar.bottom, 400 - 8);
      messenger.clear();
      await tester.pump();
    });

    testWidgets('snackbars sit above dialogs and can be shown from one', (WidgetTester tester) async {
      await pumpKk(
        tester,
        Builder(
          builder: (BuildContext context) => KkButton(
            label: 'open',
            onPressed: () => showKkDialog<void>(
              context: context,
              builder: (BuildContext context) => KkDialog(
                cjk: '確認',
                actions: <Widget>[
                  KkButton(
                    label: 'notify',
                    onPressed: () => KkMessenger.of(context).show(message: 'FROM THE DIALOG', duration: null),
                  ),
                ],
                child: const KkText.body('BODY'),
              ),
            ),
          ),
        ),
        size: const Size(1000, 700),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('NOTIFY'));
      await tester.pump();
      expect(find.text('FROM THE DIALOG'), findsOneWidget);
      // The snackbar takes the tap, not the scrim under it.
      await tester.tap(find.descendant(of: find.byType(KkSnackbar), matching: find.byType(KkIconButton)));
      await tester.pump();
      expect(find.byType(KkSnackbar), findsNothing);
      expect(find.byType(KkDialog), findsOneWidget);
    });

    testWidgets('showCustom places any widget and hands it its handle', (WidgetTester tester) async {
      final KkMessengerState messenger = await _messenger(tester);
      messenger.showCustom(
        (BuildContext context, KkSnackbarHandle handle) =>
            KkButton(label: 'custom', onPressed: handle.close),
        duration: null,
      );
      await tester.pump();
      expect(find.text('CUSTOM'), findsOneWidget);
      await tester.tap(find.text('CUSTOM'));
      await tester.pump();
      expect(find.text('CUSTOM'), findsNothing);
    });

    testWidgets('each snackbar wipes in; pending timers die with the app', (WidgetTester tester) async {
      final KkMessengerState messenger = await _messenger(tester, motion: true);
      await tester.pump(const Duration(milliseconds: 500));
      final KkSnackbarHandle handle = messenger.show(message: 'WIPING IN');
      await tester.pump();
      ClipRect clip() => tester.widget<ClipRect>(
        find.ancestor(of: find.byType(KkSnackbar), matching: find.byType(ClipRect)).first,
      );
      expect(clip().clipBehavior, Clip.hardEdge);
      expect(clip().clipper!.getClip(const Size(700, 40)).width, 0);
      await tester.pump(const Duration(milliseconds: 430));
      await tester.pump();
      expect(clip().clipBehavior, Clip.none);
      // Remove the whole app with the 5s timer still running.
      await tester.pumpWidget(const KkBox());
      expect(handle.isOpen, isFalse);
    });

    testWidgets('maybeOf is null outside a messenger', (WidgetTester tester) async {
      await tester.pumpWidget(const KkBox(key: ValueKey<String>('bare')));
      expect(KkMessenger.maybeOf(tester.element(find.byKey(const ValueKey<String>('bare')))), isNull);
    });

    testWidgets('on a narrow screen snackbars stay inside it', (WidgetTester tester) async {
      final KkMessengerState messenger = await _messenger(tester, size: const Size(320, 500));
      messenger.show(
        code: 'E-4127',
        level: KkLevel.critical,
        message: 'COOLANT PRESSURE LOW · SEC-04 · 14:02:31Z · AUX PUMP B START PENDING',
        duration: null,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final Rect bar = tester.getRect(find.byType(KkSnackbar));
      expect(bar.left, 24);
      expect(bar.right, lessThanOrEqualTo(320 - 24));
      messenger.clear();
      await tester.pump();
    });
  });
}
