import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart' show testChecked;

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// A page body that counts how often its state was created.
class _Body extends StatefulWidget {
  const _Body(this.label);

  final String label;

  static int created = 0;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  @override
  void initState() {
    super.initState();
    _Body.created++;
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

/// A navigator driven by a list of pages, the way a router delegate drives it.
class _Pages extends StatelessWidget {
  const _Pages(this.pages, {this.onRemoved});

  final List<Page<Object?>> pages;
  final ValueChanged<Page<Object?>>? onRemoved;

  @override
  Widget build(BuildContext context) {
    return Navigator(pages: pages, onDidRemovePage: (Page<Object?> page) => onRemoved?.call(page));
  }
}

Widget _app(Widget home, {bool motion = true}) {
  return KeikaiApp(
    theme: KeikaiThemeData(motion: motion ? const KkMotion() : KkMotion.off),
    home: home,
  );
}

Rect _clipOf(WidgetTester tester, String label, Size size) {
  final ClipRect clip = tester.widget<ClipRect>(
    find.ancestor(of: find.text(label), matching: find.byType(ClipRect)).first,
  );
  return clip.clipper!.getClip(size);
}

void main() {
  setUp(() => _Body.created = 0);

  group('KkPage', () {
    testChecked('makes a KkPageRoute that carries the page as its settings', (WidgetTester tester) async {
      const KkPage<void> page = KkPage<void>(
        key: ValueKey<String>('board'),
        name: '/board',
        arguments: 7,
        child: _Body('board'),
      );
      await tester.pumpWidget(_app(const _Pages(<Page<Object?>>[page]), motion: false));
      expect(find.text('board'), findsOneWidget);
      final ModalRoute<Object?> route = ModalRoute.of(tester.element(find.text('board')))!;
      expect(route, isA<KkPageRoute<void>>());
      expect(route.settings, same(page));
      expect(route.settings.name, '/board');
      expect(route.settings.arguments, 7);
      expect(route.opaque, isTrue);
      expect(route.maintainState, isTrue);
      expect((route as KkPageRoute<void>).fullscreenDialog, isFalse);
      expect(route.debugLabel, contains('/board'));
      // The page paints the screen ground like any other KEIKAI page.
      expect(find.ancestor(of: find.text('board'), matching: find.byType(KkBox)), findsWidgets);
    });

    testChecked('a page of the same key updates its route in place and keeps the state below', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const _Pages(<Page<Object?>>[KkPage<void>(key: ValueKey<String>('board'), child: _Body('first'))]),
          motion: false,
        ),
      );
      expect(find.text('first'), findsOneWidget);
      expect(_Body.created, 1);
      final ModalRoute<Object?> before = ModalRoute.of(tester.element(find.text('first')))!;
      await tester.pumpWidget(
        _app(
          const _Pages(<Page<Object?>>[
            KkPage<void>(
              key: ValueKey<String>('board'),
              maintainState: false,
              fullscreenDialog: true,
              child: _Body('second'),
            ),
          ]),
          motion: false,
        ),
      );
      await tester.pump();
      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsOneWidget);
      expect(_Body.created, 1, reason: 'the state under the page was kept');
      final ModalRoute<Object?> after = ModalRoute.of(tester.element(find.text('second')))!;
      expect(after, same(before));
      // The route follows the page it holds now.
      expect(after.maintainState, isFalse);
      expect((after as KkPageRoute<void>).fullscreenDialog, isTrue);
    });

    testChecked('a page of another key replaces the route', (WidgetTester tester) async {
      await tester.pumpWidget(
        _app(const _Pages(<Page<Object?>>[KkPage<void>(key: ValueKey<String>('a'), child: _Body('a'))]), motion: false),
      );
      await tester.pumpWidget(
        _app(const _Pages(<Page<Object?>>[KkPage<void>(key: ValueKey<String>('b'), child: _Body('b'))]), motion: false),
      );
      await tester.pump();
      expect(find.text('a'), findsNothing);
      expect(find.text('b'), findsOneWidget);
      expect(_Body.created, 2);
    });

    testChecked('an added page wipes in over 0.42s in 7 steps and wipes out when it is removed', (
      WidgetTester tester,
    ) async {
      const Size size = Size(700, 400);
      await _size(tester, size);
      const KkPage<void> board = KkPage<void>(key: ValueKey<String>('board'), child: _Body('board'));
      const KkPage<void> detail = KkPage<void>(key: ValueKey<String>('detail'), child: _Body('detail'));
      await tester.pumpWidget(_app(const _Pages(<Page<Object?>>[board])));
      // Let the app's own first page finish its wipe.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 20));

      await tester.pumpWidget(_app(const _Pages(<Page<Object?>>[board, detail])));
      await tester.pump();
      expect(_clipOf(tester, 'detail', size).width, 0);
      expect(find.text('board'), findsOneWidget, reason: 'both pages are alive during the wipe');
      await tester.pump(const Duration(milliseconds: 30));
      expect(_clipOf(tester, 'detail', size).width, 0);
      for (int step = 1; step <= 6; step++) {
        await tester.pump(const Duration(milliseconds: 60));
        expect(_clipOf(tester, 'detail', size).width, closeTo(100.0 * step, 1e-6), reason: 'step $step');
      }
      await tester.pump(const Duration(milliseconds: 60));
      expect(_clipOf(tester, 'detail', size).width, 700);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('board'), findsNothing, reason: 'the covered page is off stage');

      // Dropping the page from the list plays the wipe in reverse.
      await tester.pumpWidget(_app(const _Pages(<Page<Object?>>[board])));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(_clipOf(tester, 'detail', size).width, closeTo(500, 1e-6));
      expect(find.text('board'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('detail'), findsNothing);
      expect(find.text('board'), findsOneWidget);
    });

    testChecked('wipe false and motion off both change pages at once', (WidgetTester tester) async {
      const KkPage<void> board = KkPage<void>(key: ValueKey<String>('board'), child: _Body('board'));
      // Motion on, but this page opts out.
      await tester.pumpWidget(_app(const _Pages(<Page<Object?>>[board])));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(
        _app(
          const _Pages(<Page<Object?>>[
            board,
            KkPage<void>(key: ValueKey<String>('plain'), wipe: false, child: _Body('plain')),
          ]),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('plain'), findsOneWidget);
      // The only wipe above it is that of the app's own page, which holds the navigator.
      expect(find.ancestor(of: find.text('plain'), matching: find.byType(ClipRect)), findsOneWidget);
      expect(find.ancestor(of: find.byType(_Pages), matching: find.byType(ClipRect)), findsOneWidget);
      final KkPageRoute<void> plain = ModalRoute.of(tester.element(find.text('plain')))! as KkPageRoute<void>;
      expect(plain.transitionDuration, Duration.zero);

      // Motion off: a wiping page arrives at once too.
      await tester.pumpWidget(_app(const _Pages(<Page<Object?>>[board]), motion: false));
      await tester.pump();
      await tester.pump();
      await tester.pumpWidget(
        _app(
          const _Pages(<Page<Object?>>[board, KkPage<void>(key: ValueKey<String>('detail'), child: _Body('detail'))]),
          motion: false,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('detail'), findsOneWidget);
      expect(find.text('board'), findsNothing);
      expect(find.ancestor(of: find.text('detail'), matching: find.byType(ClipRect)), findsNothing);
    });

    testChecked('a pop through the navigator reports the page, and canPop false blocks it', (
      WidgetTester tester,
    ) async {
      final List<Object?> removed = <Object?>[];
      const KkPage<void> board = KkPage<void>(key: ValueKey<String>('board'), child: _Body('board'));
      const KkPage<void> detail = KkPage<void>(key: ValueKey<String>('detail'), child: _Body('detail'));
      await tester.pumpWidget(
        _app(
          _Pages(const <Page<Object?>>[board, detail], onRemoved: (Page<Object?> p) => removed.add(p.key)),
          motion: false,
        ),
      );
      await tester.pump();
      final NavigatorState navigator = Navigator.of(tester.element(find.text('detail')));
      expect(await navigator.maybePop(), isTrue);
      await tester.pump();
      await tester.pump();
      expect(removed, <Object?>[const ValueKey<String>('detail')]);

      // A page that may not be popped stays.
      removed.clear();
      bool? reported;
      await tester.pumpWidget(
        _app(
          _Pages(<Page<Object?>>[
            board,
            KkPage<void>(
              key: const ValueKey<String>('locked'),
              canPop: false,
              onPopInvoked: (bool didPop, void result) => reported = didPop,
              child: const _Body('locked'),
            ),
          ], onRemoved: (Page<Object?> p) => removed.add(p.key)),
          motion: false,
        ),
      );
      await tester.pump();
      await tester.pump();
      final NavigatorState locked = Navigator.of(tester.element(find.text('locked')));
      await locked.maybePop();
      await tester.pump();
      expect(find.text('locked'), findsOneWidget);
      expect(removed, isEmpty);
      expect(reported, isFalse);
    });
  });
}
