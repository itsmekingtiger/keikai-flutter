import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart' show testChecked;

const Color _red = Color(0xFFFF0000);
const Color _blue = Color(0xFF0000FF);

/// Runs [draw] against a real canvas and makes sure it produces a picture.
void _paint(void Function(Canvas canvas) draw) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  draw(canvas);
  recorder.endRecording().dispose();
}

double _length(Path path) => path.computeMetrics().fold<double>(0, (double a, ui.PathMetric m) => a + m.length);

Matcher _rect(double l, double t, double r, double b) => within<Rect>(distance: 1e-3, from: Rect.fromLTRB(l, t, r, b));

/// The bounds of the drawn outline. `Path.getBounds` also covers the control
/// points of curves and arcs, which lie off the outline.
Rect _tight(Path path) {
  double l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
  for (final ui.PathMetric metric in path.computeMetrics()) {
    final int samples = (metric.length / 0.02).ceil().clamp(1, 20000);
    for (int i = 0; i <= samples; i++) {
      final Offset p = metric.getTangentForOffset(metric.length * i / samples)!.position;
      if (p.dx < l) l = p.dx;
      if (p.dx > r) r = p.dx;
      if (p.dy < t) t = p.dy;
      if (p.dy > b) b = p.dy;
    }
  }
  return l.isFinite ? Rect.fromLTRB(l, t, r, b) : Rect.zero;
}

Matcher _near(double l, double t, double r, double b, [double tolerance = 0.05]) =>
    within<Rect>(distance: tolerance, from: Rect.fromLTRB(l, t, r, b));

/// What [draw] left on a [width] × [height] canvas.
class _Pixels {
  _Pixels(this._bytes, this.width, this.height);

  final ByteData _bytes;
  final int width;
  final int height;

  /// The alpha of the pixel at ([x], [y]), 0 to 255.
  int alpha(int x, int y) => _bytes.getUint8((y * width + x) * 4 + 3);

  /// One row of pixels as text: `#` is opaque, `.` is clear and `+` is anything between.
  String row(int y) => String.fromCharCodes(<int>[for (int x = 0; x < width; x++) _mark(alpha(x, y))]);

  /// One column of pixels, read downwards, in the notation of [row].
  String column(int x) => String.fromCharCodes(<int>[for (int y = 0; y < height; y++) _mark(alpha(x, y))]);

  List<String> get rows => <String>[for (int y = 0; y < height; y++) row(y)];

  static int _mark(int alpha) => switch (alpha) {
    0 => 0x2E,
    255 => 0x23,
    _ => 0x2B,
  };
}

/// Runs [draw] on a real canvas and reads back the pixels it painted.
Future<_Pixels> _render(WidgetTester tester, int width, int height, void Function(Canvas canvas) draw) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final ui.Picture picture = recorder.endRecording();
  late ByteData bytes;
  await tester.runAsync(() async {
    final ui.Image image = await picture.toImage(width, height);
    bytes = (await image.toByteData())!;
    image.dispose();
  });
  picture.dispose();
  return _Pixels(bytes, width, height);
}

/// The lengths of the runs of equal marks in a [_Pixels.row] or column: `###..#` is 3, 2, 1.
List<int> _runs(String marks) => <int>[for (final Match m in RegExp(r'#+|\.+|\++').allMatches(marks)) m.end - m.start];

void main() {
  group('kkParseSvgPath', () {
    test('absolute commands', () {
      expect(kkParseSvgPath('M0 0L10 0L10 10Z').getBounds(), _rect(0, 0, 10, 10));
      expect(kkParseSvgPath('M0 0H10V5').getBounds(), _rect(0, 0, 10, 5));
      expect(_length(kkParseSvgPath('M0 0H10V5')), closeTo(15, 1e-3));
      expect(kkParseSvgPath('M2,3 L4,5').getBounds(), _rect(2, 3, 4, 5));
    });

    test('relative commands', () {
      expect(kkParseSvgPath('m1 1l2 0l0 2z').getBounds(), _rect(1, 1, 3, 3));
      expect(kkParseSvgPath('M5 5h3v-4').getBounds(), _rect(5, 1, 8, 5));
      expect(_length(kkParseSvgPath('M5 5h3v-4')), closeTo(7, 1e-3));
    });

    test('numbers after a command repeat it; after M they are lines', () {
      expect(kkParseSvgPath('M0 0 10 0 10 10').getBounds(), _rect(0, 0, 10, 10));
      expect(_length(kkParseSvgPath('M0 0 10 0 10 10')), closeTo(20, 1e-3));
      expect(kkParseSvgPath('m1 1 2 0 0 2').getBounds(), _rect(1, 1, 3, 3));
      expect(_length(kkParseSvgPath('M0 0L1 0 1 1 0 1')), closeTo(3, 1e-3));
      expect(_length(kkParseSvgPath('M0 0h1 1 1')), closeTo(3, 1e-3));
      expect(kkParseSvgPath('M0 0V1 2 5').getBounds(), _rect(0, 0, 0, 5));
    });

    test('compact numbers: 1.5.5, -1-1, exponents, leading dots and signs', () {
      expect(kkParseSvgPath('M1.5.5L-1-1').getBounds(), _rect(-1, -1, 1.5, 0.5));
      expect(kkParseSvgPath('M1e1 0L2E1 0').getBounds(), _rect(10, 0, 20, 0));
      expect(kkParseSvgPath('M.5.25l+1+1').getBounds(), _rect(0.5, 0.25, 1.5, 1.25));
      expect(kkParseSvgPath('M5e-1 2.5e+0L1 3').getBounds(), _rect(0.5, 2.5, 1, 3));
      expect(kkParseSvgPath('M0 0L10-5').getBounds(), _rect(0, -5, 10, 0));
    });

    test('arcs', () {
      // A half circle from left to right: clockwise goes over the top.
      expect(_tight(kkParseSvgPath('M0 0A5 5 0 0 1 10 0')), _near(0, -5, 10, 0));
      // Counter-clockwise goes under.
      expect(_tight(kkParseSvgPath('M0 0A5 5 0 0 0 10 0')), _near(0, 0, 10, 5));
      // Flags may be packed against each other and against the next number.
      expect(_tight(kkParseSvgPath('M0 0a5 5 0 0110 0')), _near(0, -5, 10, 0));
      expect(_tight(kkParseSvgPath('M0 0a5 5 0 01.5 0')).width, closeTo(0.5, 1e-3));
      // A full circle from two half arcs.
      final Path circle = kkParseSvgPath('M13.25 8A5.25 5.25 0 1 1 2.75 8A5.25 5.25 0 1 1 13.25 8Z');
      expect(_tight(circle), _near(2.75, 2.75, 13.25, 13.25));
      expect(circle.contains(const Offset(8, 8)), isTrue);
      expect(circle.contains(const Offset(3.5, 3.5)), isFalse);
      // Its length is the circumference (measured on a large circle, where the
      // engine's flattening does not matter).
      final Path big = kkParseSvgPath('M500 0A500 500 0 1 1 -500 0A500 500 0 1 1 500 0Z');
      expect(_length(big), closeTo(2 * 3.14159265 * 500, 2));
      // The large-arc flag picks the long way round: a 270° arc against a 90° one.
      expect(_tight(kkParseSvgPath('M0 0A5 5 0 1 1 5 5')), _near(0, -5, 10, 5));
      expect(_tight(kkParseSvgPath('M0 0A5 5 0 0 1 5 5')), _near(0, 0, 5, 5));
      expect(_tight(kkParseSvgPath('M0 0A5 5 0 0 0 5 5')), _near(0, 0, 5, 5));
      expect(_tight(kkParseSvgPath('M0 0A5 5 0 1 0 5 5')), _near(-5, 0, 5, 10));
      // The arc of the refresh icon: 330° around (8, 8).
      expect(_tight(kkParseSvgPath('M12.33 5.5A5 5 0 1 0 13 8')), _near(3, 3, 13, 13, 0.06));
      // An ellipse.
      expect(_tight(kkParseSvgPath('M0 0A10 4 0 0 1 20 0')), _near(0, -4, 20, 0));
      // A rotated ellipse: 90° swaps the radii.
      expect(_tight(kkParseSvgPath('M0 0A10 4 90 0 1 8 0')), _near(0, -10, 8, 0));
      // A zero radius is a straight line; an arc to the same point is nothing.
      expect(_length(kkParseSvgPath('M0 0A0 5 0 0 1 10 0')), closeTo(10, 1e-3));
      expect(_length(kkParseSvgPath('M0 0A5 5 0 0 1 0 0L3 0')), closeTo(3, 1e-3));
      // Negative radii are taken as positive.
      expect(_tight(kkParseSvgPath('M0 0A-5 -5 0 0 1 10 0')), _near(0, -5, 10, 0));
      // Radii too small to span the chord are scaled up to fit (a half circle).
      expect(_tight(kkParseSvgPath('M0 0A1 1 0 0 1 10 0')), _near(0, -5, 10, 0));
    });

    test('curves, including the smooth forms', () {
      expect(_tight(kkParseSvgPath('M0 0C0 10 10 10 10 0')), _near(0, 0, 10, 7.5));
      expect(_tight(kkParseSvgPath('M0 0Q5 10 10 0')), _near(0, 0, 10, 5));
      // S reflects the previous control point: a symmetric S-curve.
      expect(_tight(kkParseSvgPath('M0 0C0 10 10 10 10 0S20 -10 20 0')), _near(0, -7.5, 20, 7.5));
      // T reflects the previous quadratic control point.
      expect(_tight(kkParseSvgPath('M0 0Q5 10 10 0T20 0')), _near(0, -5, 20, 5));
      // Without a previous curve the control point is the current point.
      expect(_tight(kkParseSvgPath('M0 0S10 10 10 0')).right, closeTo(10, 0.05));
      expect(_tight(kkParseSvgPath('M0 0T10 0')), _near(0, 0, 10, 0));
      // Relative forms.
      expect(_tight(kkParseSvgPath('M0 0c0 10 10 10 10 0s10 -10 10 0')), _near(0, -7.5, 20, 7.5));
      expect(_tight(kkParseSvgPath('M0 0q5 10 10 0t10 0')), _near(0, -5, 20, 5));
      // A line between two curves resets the reflection.
      expect(_tight(kkParseSvgPath('M0 0Q5 10 10 0L20 0T30 0')), _near(0, 0, 30, 5));
    });

    test('closing returns to the start of the sub-path', () {
      // After z the current point is (5, 5) again, so m1 1 lands on (6, 6).
      expect(kkParseSvgPath('M5 5l5 0l0 5zm1 1l1 0').getBounds(), _rect(5, 5, 10, 10));
      final Path two = kkParseSvgPath('M0 0h2v2h-2zM10 10h2v2h-2z');
      expect(two.computeMetrics().length, 2);
      expect(two.contains(const Offset(1, 1)), isTrue);
      expect(two.contains(const Offset(11, 11)), isTrue);
      expect(two.contains(const Offset(5, 5)), isFalse);
    });

    test('whitespace and commas are free-form', () {
      expect(kkParseSvgPath('  M 0 , 0\n\tL 10,10  ').getBounds(), _rect(0, 0, 10, 10));
      expect(kkParseSvgPath('').computeMetrics(), isEmpty);
      expect(kkParseSvgPath('   ').computeMetrics(), isEmpty);
    });

    test('bad data throws a FormatException', () {
      for (final String bad in <String>[
        '10 10',
        'M',
        'M0',
        'M0 0L5',
        'M0 0X5 5',
        'M0 0Z5 5',
        'M0 0A5 5 0 2 1 10 0',
        'M0 0A5 5 0 0',
        'M0 0L5 5#',
        'M0 0L--5 5',
        'M0 0L. 5',
        'M0 0C1 1 2 2',
      ]) {
        expect(() => kkParseSvgPath(bad), throwsFormatException, reason: '"$bad"');
      }
    });

    test('path data must begin with a moveto', () {
      // The grammar of SVG starts every path with M or m, and a browser draws
      // nothing for data that does not. Drawing it from (0, 0) would hide a
      // mistyped icon behind a stray line.
      for (final String bad in <String>[
        'L10 10',
        'l5 5z',
        'H5',
        'v5',
        'C0 0 1 1 2 2',
        'Q1 1 2 2',
        'A5 5 0 0 1 10 0',
        'Z',
        'z',
        ' \n L1 1',
        'ZM0 0L1 1',
      ]) {
        expect(() => kkParseSvgPath(bad), throwsFormatException, reason: '"$bad"');
      }
      expect(
        () => kkParseSvgPath('  L10 10'),
        throwsA(
          isA<FormatException>()
              .having((FormatException e) => e.message, 'message', contains('moveto'))
              .having((FormatException e) => e.offset, 'offset', 2),
        ),
      );
      // Either case of the letter will do, and only the first command has to
      // be one: after a close the next sub-path starts where the last began.
      expect(kkParseSvgPath('m2 3l4 0').getBounds(), _rect(2, 3, 6, 3));
      final Path two = kkParseSvgPath('M5 5h2v2zl-1 -1');
      expect(two.computeMetrics().length, 2);
      expect(two.getBounds(), _rect(4, 4, 7, 7));
    });
  });

  group('icons', () {
    test('every icon parses and stays on the 16px grid', () {
      expect(KkIcons.values.length, greaterThanOrEqualTo(63));
      for (final KkIconData icon in KkIcons.values) {
        expect(icon.stroke.isNotEmpty || icon.fill.isNotEmpty || icon.dashed.isNotEmpty, isTrue, reason: icon.name);
        for (final String d in <String>[icon.stroke, icon.fill, icon.dashed]) {
          if (d.isEmpty) continue;
          final Rect bounds = _tight(kkParseSvgPath(d));
          expect(bounds.left, greaterThanOrEqualTo(0.9), reason: icon.name);
          expect(bounds.top, greaterThanOrEqualTo(0.9), reason: icon.name);
          expect(bounds.right, lessThanOrEqualTo(15.1), reason: icon.name);
          expect(bounds.bottom, lessThanOrEqualTo(15.1), reason: icon.name);
        }
      }
    });

    test('names are unique and byName finds them', () {
      final Set<String> names = <String>{for (final KkIconData icon in KkIcons.values) icon.name};
      expect(names.length, KkIcons.values.length);
      for (final KkIconData icon in KkIcons.values) {
        expect(KkIcons.byName(icon.name), same(icon));
        expect(icon.name, matches(RegExp(r'^[a-z]+(-[a-z]+)*$')));
      }
      expect(KkIcons.byName('no-such-icon'), isNull);
    });

    test('every icon paints at several sizes', () {
      for (final KkIconData icon in KkIcons.values) {
        for (final double size in <double>[0, 1, 12, 16, 64]) {
          _paint((Canvas canvas) => kkPaintIcon(canvas, Rect.fromLTWH(3, 3, size, size), icon, _red));
        }
        _paint((Canvas canvas) => kkPaintIcon(canvas, const Rect.fromLTWH(0, 0, 16, 16), icon, const Color(0x00000000)));
      }
    });

    test('bad path data throws and leaves the canvas as it was', () {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      canvas.translate(3, 4);
      final int saves = canvas.getSaveCount();
      final Float64List transform = canvas.getTransform();
      for (final KkIconData bad in const <KkIconData>[
        KkIconData('bad-fill', fill: 'M0 0 L5'),
        KkIconData('bad-stroke', stroke: 'M0 0 L5'),
        KkIconData('bad-dashed', dashed: 'M0 0 L5'),
        // The parts that are drawn first are fine.
        KkIconData('bad-last', fill: 'M0 0h4v4z', stroke: 'M0 0L4 4', dashed: 'M0 0 L5'),
      ]) {
        expect(
          () => kkPaintIcon(canvas, const Rect.fromLTWH(10, 10, 32, 32), bad, _red),
          throwsFormatException,
          reason: bad.name,
        );
        // No save left open and no translation or scale left behind: whatever
        // is painted next on this canvas lands where it should.
        expect(canvas.getSaveCount(), saves, reason: bad.name);
        expect(canvas.getTransform(), transform, reason: bad.name);
      }
      recorder.endRecording().dispose();
    });

    test('the status icon of each level', () {
      expect(kkStatusIcon(KkLevel.nominal), KkIcons.statusNominal);
      expect(kkStatusIcon(KkLevel.caution), KkIcons.statusCaution);
      expect(kkStatusIcon(KkLevel.critical), KkIcons.statusCritical);
      expect(kkStatusIcon(KkLevel.offline), KkIcons.statusOffline);
      expect(kkStatusIcon(null), KkIcons.statusInfo);
      // Critical is the only filled plate, offline the only dashed one.
      expect(KkIcons.statusCritical.stroke, isEmpty);
      expect(KkIcons.statusCritical.fill, isNotEmpty);
      expect(KkIcons.statusOffline.dashed, isNotEmpty);
      for (final KkIconData icon in <KkIconData>[KkIcons.statusNominal, KkIcons.statusCaution, KkIcons.statusInfo]) {
        expect(icon.dashed, isEmpty);
        expect(icon.stroke, startsWith('M5 1.75H14.25V14.25H1.75V5Z'));
      }
    });

    test('icon data equality', () {
      const KkIconData a = KkIconData('x', stroke: 'M0 0L1 1');
      expect(a, const KkIconData('x', stroke: 'M0 0L1 1'));
      expect(a.hashCode, const KkIconData('x', stroke: 'M0 0L1 1').hashCode);
      expect(a == const KkIconData('x', stroke: 'M0 0L2 2'), isFalse);
      expect(a == const KkIconData('y', stroke: 'M0 0L1 1'), isFalse);
      expect(a.toString(), 'KkIconData(x)');
    });
  });

  group('kkDashPath', () {
    final Path line = Path()
      ..moveTo(0, 0)
      ..lineTo(10, 0);

    test('cuts a path into on and off runs', () {
      final Path dashed = kkDashPath(line, const <double>[2, 3]);
      expect(dashed.computeMetrics().length, 2);
      expect(_length(dashed), closeTo(4, 1e-3));
      expect(dashed.getBounds(), _rect(0, 0, 7, 0));
    });

    test('phase shifts the pattern', () {
      final Path dashed = kkDashPath(line, const <double>[2, 3], phase: 1);
      // On: 0..1, 4..6, 9..10.
      expect(_length(dashed), closeTo(4, 1e-3));
      expect(dashed.computeMetrics().length, 3);
      expect(kkDashPath(line, const <double>[2, 3], phase: 5).getBounds(), _rect(0, 0, 7, 0));
    });

    test('an odd number of lengths repeats as on and off in turn, and the phase wraps at that whole period', () {
      final Path long = Path()
        ..moveTo(0, 0)
        ..lineTo(20, 0);
      // Where each dash starts and ends along the line.
      List<String> spans(Path dashed) => <String>[
        for (final ui.PathMetric m in dashed.computeMetrics())
          '${m.getTangentForOffset(0)!.position.dx.toStringAsFixed(1)}..'
              '${m.getTangentForOffset(m.length)!.position.dx.toStringAsFixed(1)}',
      ];
      // [5] is 5 on, 5 off: one period is 10, twice the sum of the list.
      expect(spans(kkDashPath(long, const <double>[5])), <String>['0.0..5.0', '10.0..15.0']);
      expect(spans(kkDashPath(long, const <double>[5], phase: 5)), <String>['5.0..10.0', '15.0..20.0']);
      expect(spans(kkDashPath(long, const <double>[5], phase: 7)), <String>['3.0..8.0', '13.0..18.0']);
      expect(spans(kkDashPath(long, const <double>[5], phase: 10)), <String>['0.0..5.0', '10.0..15.0']);
      expect(spans(kkDashPath(long, const <double>[5], phase: 15)), <String>['5.0..10.0', '15.0..20.0']);
      // A negative phase moves the pattern the other way.
      expect(spans(kkDashPath(long, const <double>[5], phase: -3)), <String>['3.0..8.0', '13.0..18.0']);
      expect(spans(kkDashPath(long, const <double>[5], phase: -13)), <String>['3.0..8.0', '13.0..18.0']);
      // [5, 3, 2] is [5, 3, 2, 5, 3, 2], whatever the phase.
      for (final double phase in <double>[0, 4, 10, 13.5, 20, 27, -6, -10, -31]) {
        expect(
          spans(kkDashPath(long, const <double>[5, 3, 2], phase: phase)),
          spans(kkDashPath(long, const <double>[5, 3, 2, 5, 3, 2], phase: phase)),
          reason: 'phase $phase',
        );
      }
      expect(
        spans(kkDashPath(long, const <double>[5, 3, 2], phase: 10)),
        <String>['5.0..8.0', '10.0..15.0', '18.0..20.0'],
      );
      // An even number of lengths wraps at its sum.
      expect(spans(kkDashPath(long, const <double>[5, 5], phase: 5)), <String>['5.0..10.0', '15.0..20.0']);
      expect(
        spans(kkDashPath(long, const <double>[2, 3], phase: -1)),
        <String>['1.0..3.0', '6.0..8.0', '11.0..13.0', '16.0..18.0'],
      );
    });

    test('a pattern longer than the path keeps what fits', () {
      expect(_length(kkDashPath(line, const <double>[50, 5])), closeTo(10, 1e-3));
      expect(_length(kkDashPath(line, const <double>[4])), closeTo(6, 1e-3));
    });

    test('follows every contour', () {
      final Path two = Path()
        ..addRect(const Rect.fromLTWH(0, 0, 10, 10))
        ..addRect(const Rect.fromLTWH(20, 0, 10, 10));
      final Path dashed = kkDashPath(two, const <double>[5, 5]);
      expect(_length(dashed), closeTo(40, 1e-2));
      expect(dashed.getBounds().right, closeTo(30, 1e-3));
    });

    test('an empty path stays empty; a pattern that cannot advance is rejected', () {
      expect(kkDashPath(Path(), const <double>[2, 2]).computeMetrics(), isEmpty);
      expect(() => kkDashPath(line, const <double>[]), throwsAssertionError);
      expect(() => kkDashPath(line, const <double>[0, 0]), throwsAssertionError);
      expect(() => kkDashPath(line, const <double>[2, -1]), throwsAssertionError);
    });
  });

  test('kkPolygon', () {
    final Path hex = kkPolygon(const Offset(10, 10), 5, 6);
    expect(hex.getBounds().top, closeTo(5, 1e-3));
    expect(hex.getBounds().bottom, closeTo(15, 1e-3));
    expect(hex.contains(const Offset(10, 10)), isTrue);
    expect(hex.contains(const Offset(10, 4)), isFalse);
    final Path square = kkPolygon(Offset.zero, 10, 4, rotation: 0);
    expect(square.getBounds(), _rect(-10, -10, 10, 10));
  });

  group('KkShape', () {
    const Rect r = Rect.fromLTWH(10, 20, 100, 60);
    const List<KkShape> all = <KkShape>[
      KkShape.rect(),
      KkShape.chamfer(tl: 6, tr: 4, br: 10, bl: 2),
      KkShape.plate(10),
      KkShape.slant(14),
      KkShape.hex(),
      KkShape.arrow(),
      KkShape.arrow(notch: false),
    ];

    test('every shape fills its rectangle edge to edge', () {
      for (final KkShape shape in all) {
        expect(shape.path(r).getBounds(), _rect(10, 20, 110, 80), reason: '$shape');
        expect(shape.contains(r, r.center), isTrue);
        expect(shape.contains(r, const Offset(0, 0)), isFalse);
        expect(shape.contains(r, const Offset(111, 50)), isFalse);
      }
    });

    test('rect', () {
      const KkShape s = KkShape.rect();
      expect(s.isRect, isTrue);
      expect(s.contains(r, const Offset(10.5, 20.5)), isTrue);
      expect(const KkShape.plate(4).isRect, isFalse);
    });

    test('chamfer cuts exactly the named corners at 45°', () {
      const KkShape s = KkShape.chamfer(tl: 20);
      expect(s.contains(r, const Offset(15, 25)), isFalse);
      expect(s.contains(r, const Offset(25, 35)), isTrue);
      expect(s.contains(r, const Offset(108, 22)), isTrue);
      expect(s.contains(r, const Offset(108, 78)), isTrue);
      expect(s.contains(r, const Offset(12, 78)), isTrue);
      // The cut runs from (30, 20) to (10, 40).
      expect(s.contains(r, const Offset(21, 30)), isTrue);
      expect(s.contains(r, const Offset(19, 30)), isFalse);
      const KkShape plate = KkShape.plate(20);
      expect(plate.tl, 20);
      expect(plate.br, 20);
      expect(plate.tr, 0);
      expect(plate.bl, 0);
      expect(plate.contains(r, const Offset(12, 22)), isFalse);
      expect(plate.contains(r, const Offset(108, 78)), isFalse);
      expect(plate.contains(r, const Offset(108, 22)), isTrue);
      expect(plate.contains(r, const Offset(12, 78)), isTrue);
      expect(const KkShape.chamfer(tr: 20).contains(r, const Offset(108, 22)), isFalse);
      expect(const KkShape.chamfer(bl: 20).contains(r, const Offset(12, 78)), isFalse);
    });

    test('slant leans the right edge in at the bottom', () {
      const KkShape s = KkShape.slant(20);
      expect(s.contains(r, const Offset(108, 22)), isTrue);
      expect(s.contains(r, const Offset(108, 78)), isFalse);
      expect(s.contains(r, const Offset(88, 78)), isTrue);
      expect(s.contains(r, const Offset(12, 78)), isTrue);
    });

    test('hex is pointy at the top and bottom', () {
      const KkShape s = KkShape.hex();
      expect(s.contains(r, const Offset(60, 21)), isTrue);
      expect(s.contains(r, const Offset(12, 22)), isFalse);
      expect(s.contains(r, const Offset(108, 78)), isFalse);
      expect(s.contains(r, const Offset(11, 50)), isTrue);
      expect(s.contains(r, const Offset(109, 50)), isTrue);
    });

    test('arrow has a head on the right and an optional notch on the left', () {
      const KkShape s = KkShape.arrow(head: 20);
      expect(s.contains(r, const Offset(108, 50)), isTrue);
      expect(s.contains(r, const Offset(108, 22)), isFalse);
      expect(s.contains(r, const Offset(15, 50)), isFalse);
      expect(s.contains(r, const Offset(12, 22)), isTrue);
      expect(const KkShape.arrow(head: 20, notch: false).contains(r, const Offset(15, 50)), isTrue);
    });

    test('cuts larger than the box are clamped and never leave it', () {
      for (final Rect tiny in const <Rect>[
        Rect.fromLTWH(0, 0, 10, 10),
        Rect.fromLTWH(0, 0, 3, 40),
        Rect.fromLTWH(0, 0, 40, 3),
        Rect.fromLTWH(0, 0, 1, 1),
      ]) {
        for (final KkShape shape in const <KkShape>[
          KkShape.chamfer(tl: 50, tr: 50, br: 50, bl: 50),
          KkShape.plate(50),
          KkShape.slant(500),
          KkShape.arrow(head: 500),
          KkShape.hex(),
        ]) {
          final Rect bounds = shape.path(tiny).getBounds();
          expect(bounds.left, greaterThanOrEqualTo(tiny.left - 1e-6));
          expect(bounds.top, greaterThanOrEqualTo(tiny.top - 1e-6));
          expect(bounds.right, lessThanOrEqualTo(tiny.right + 1e-6));
          expect(bounds.bottom, lessThanOrEqualTo(tiny.bottom + 1e-6));
        }
      }
    });

    test('an empty rectangle gives an empty path', () {
      for (final KkShape shape in all) {
        expect(shape.path(Rect.zero).computeMetrics(), isEmpty);
        expect(shape.path(const Rect.fromLTWH(5, 5, 0, 10)).computeMetrics(), isEmpty);
        expect(shape.contains(Rect.zero, Offset.zero), isFalse);
      }
    });

    test('equality', () {
      expect(const KkShape.plate(10), const KkShape.chamfer(tl: 10, br: 10));
      expect(const KkShape.plate(10).hashCode, const KkShape.chamfer(tl: 10, br: 10).hashCode);
      expect(const KkShape.plate(10) == const KkShape.plate(11), isFalse);
      expect(const KkShape.slant(14) == const KkShape.arrow(head: 14), isFalse);
      expect(const KkShape.arrow() == const KkShape.arrow(notch: false), isFalse);
      expect(const KkShape.rect() == const KkShape.chamfer(), isFalse);
      expect(const KkShape.hex(), const KkShape.hex());
    });
  });

  group('surface, glow, edges, brackets', () {
    const List<Rect> rects = <Rect>[
      Rect.fromLTWH(0, 0, 120, 40),
      Rect.zero,
      Rect.fromLTWH(0, 0, 1, 1),
      Rect.fromLTWH(5, 5, 2, 40),
      Rect.fromLTWH(-20, -20, 10, 10),
    ];

    test('kkPaintSurface copes with every size, edge width and missing colour', () {
      for (final Rect rect in rects) {
        for (final double edgeWidth in <double>[0, 1, 2, 30]) {
          _paint(
            (Canvas canvas) => kkPaintSurface(
              canvas,
              rect,
              shape: const KkShape.plate(10),
              fill: _red,
              edge: _blue,
              edgeWidth: edgeWidth,
              glow: const KkGlow(color: _blue),
            ),
          );
        }
        _paint((Canvas canvas) => kkPaintSurface(canvas, rect));
        _paint((Canvas canvas) => kkPaintSurface(canvas, rect, fill: _red));
        _paint((Canvas canvas) => kkPaintSurface(canvas, rect, edge: _red));
        _paint((Canvas canvas) => kkPaintSurface(canvas, rect, fill: const Color(0x00000000), edge: const Color(0x00000000)));
      }
    });

    test('kkPaintGlow with and without ring and halo', () {
      for (final Rect rect in rects) {
        for (final KkGlow glow in const <KkGlow>[
          KkGlow(color: _red),
          KkGlow(color: _red, ring: 0),
          KkGlow(color: _red, blur: 0),
          KkGlow(color: _red, alpha: 0),
          KkGlow(color: _red, ring: 0, blur: 0),
        ]) {
          _paint((Canvas canvas) => kkPaintGlow(canvas, rect, glow, shape: const KkShape.hex()));
        }
      }
    });

    testChecked('the halo of a glow is the blurred outline itself, with the ring painted over its first pixel', (
      WidgetTester tester,
    ) async {
      // glow-signal is two shadows of one box: `0 0 0 1px c` and `0 0 18px c` at 30%.
      const Rect box = Rect.fromLTWH(60, 60, 200, 200);
      Future<_Pixels> glow(KkGlow g) => _render(tester, 320, 320, (Canvas canvas) => kkPaintGlow(canvas, box, g));
      final _Pixels ringed = await glow(const KkGlow(color: _red));
      final _Pixels halo = await glow(const KkGlow(color: _red, ring: 0));
      final Rect ring = box.inflate(1);
      int wrong = 0;
      String first = '';
      for (int y = 0; y < 320; y++) {
        for (int x = 0; x < 320; x++) {
          final Offset centre = Offset(x + 0.5, y + 0.5);
          // Nothing inside the box, the hard ring around it, and beyond the
          // ring the same halo as without one: the ring does not push it out.
          final int expected = box.contains(centre)
              ? 0
              : ring.contains(centre)
              ? 255
              : halo.alpha(x, y);
          if (ringed.alpha(x, y) != expected && wrong++ == 0) {
            first = 'alpha at ($x, $y) is ${ringed.alpha(x, y)}, not $expected';
          }
        }
      }
      expect(wrong, 0, reason: first);
      // The halo is the box blurred by half the CSS radius: d px from the
      // edge its alpha is 30% × (1 − Φ(d / 9)).
      expect(halo.alpha(59, 160), closeTo(36.6, 1.5));
      expect(ringed.alpha(58, 160), closeTo(33.2, 1.5));
      expect(ringed.alpha(50, 160), closeTo(11.1, 1.5));
      expect(ringed.alpha(41, 160), closeTo(1.5, 1.5));
      expect(ringed.alpha(160, 58), ringed.alpha(58, 160));
      expect(ringed.alpha(261, 160), ringed.alpha(58, 160));
    });

    test('KkSide and KkEdges', () {
      expect(KkSide.none.width, 0);
      expect(const KkSide(_red), const KkSide(_red, width: 1));
      expect(const KkSide(_red).hashCode, const KkSide(_red).hashCode);
      expect(const KkSide(_red) == const KkSide(_red, dashed: true), isFalse);
      expect(KkEdges.none.isNone, isTrue);
      expect(KkEdges.none.insets, EdgeInsets.zero);
      final KkEdges all = KkEdges.line(_red, width: 2);
      expect(all.insets, const EdgeInsets.all(2));
      expect(all.isNone, isFalse);
      expect(all, const KkEdges.all(KkSide(_red, width: 2)));
      expect(all.hashCode, const KkEdges.all(KkSide(_red, width: 2)).hashCode);
      const KkEdges mixed = KkEdges(top: KkSide(_red, width: 4), left: KkSide(_blue, width: 1, dashed: true));
      expect(mixed.insets, const EdgeInsets.fromLTRB(1, 4, 0, 0));
      expect(mixed.copyWith(bottom: const KkSide(_red, width: 3)).insets, const EdgeInsets.fromLTRB(1, 4, 0, 3));
      expect(mixed.copyWith(right: const KkSide(_red)).right.color, _red);
      expect(mixed.copyWith(top: KkSide.none, left: KkSide.none), KkEdges.none);
      expect(mixed == all, isFalse);
      for (final Rect rect in rects) {
        _paint((Canvas canvas) => KkEdges.none.paint(canvas, rect));
        _paint((Canvas canvas) => all.paint(canvas, rect));
        _paint((Canvas canvas) => mixed.paint(canvas, rect));
        _paint((Canvas canvas) => KkEdges.line(_red, width: 3, dashed: true).paint(canvas, rect));
        _paint((Canvas canvas) => KkEdges.line(const Color(0x00FF0000)).paint(canvas, rect));
      }
    });

    test('KkBracketSpec', () {
      const KkBracketSpec spec = KkBracketSpec(color: _red);
      expect(spec.length, 12);
      expect(spec.width, 2);
      expect(spec.outset, 1);
      expect(spec, const KkBracketSpec(color: _red));
      expect(spec.hashCode, const KkBracketSpec(color: _red).hashCode);
      expect(spec == const KkBracketSpec(color: _red, length: 8), isFalse);
      for (final Rect rect in rects) {
        _paint((Canvas canvas) => spec.paint(canvas, rect));
        _paint((Canvas canvas) => const KkBracketSpec(color: _red, length: 500, outset: 6).paint(canvas, rect));
        _paint((Canvas canvas) => const KkBracketSpec(color: Color(0x00FF0000)).paint(canvas, rect));
      }
    });

    testChecked('a bracket arm is cut short by the box only along its own direction', (WidgetTester tester) async {
      // Around a one-line readout of 100×14 the brackets frame 102×16. In CSS
      // every horizontal arm is a 12×2 tile and every vertical one 2×12, each
      // clipped by the box: here the vertical arms of two corners meet, and the
      // horizontal ones keep their 12px.
      final _Pixels wide = await _render(
        tester,
        108,
        22,
        (Canvas canvas) => const KkBracketSpec(color: _red).paint(canvas, const Rect.fromLTWH(4, 4, 100, 14)),
      );
      final String arms = '...${'#' * 12}${'.' * 78}${'#' * 12}...';
      final String posts = '...##${'.' * 98}##...';
      final List<String> picture = <String>[
        for (int y = 0; y < 22; y++)
          if (y < 3 || y > 18) '.' * 108 else if (y < 5 || y > 16) arms else posts,
      ];
      expect(wide.rows, picture);
      // The same box on its side.
      final _Pixels tall = await _render(
        tester,
        22,
        108,
        (Canvas canvas) => const KkBracketSpec(color: _red).paint(canvas, const Rect.fromLTWH(4, 4, 14, 100)),
      );
      expect(<String>[for (int x = 0; x < 22; x++) tall.column(x)], picture);
      // Room for both: 12 by 12 in every corner.
      final _Pixels roomy = await _render(
        tester,
        108,
        68,
        (Canvas canvas) => const KkBracketSpec(color: _red).paint(canvas, const Rect.fromLTWH(4, 4, 100, 60)),
      );
      expect(roomy.row(3), arms);
      expect(roomy.row(64), arms);
      expect(roomy.column(3), '...${'#' * 12}${'.' * 38}${'#' * 12}...');
      expect(roomy.column(104), roomy.column(3));
      // Too small for either: all four arms meet and close the frame.
      final _Pixels tiny = await _render(
        tester,
        14,
        14,
        (Canvas canvas) => const KkBracketSpec(color: _red).paint(canvas, const Rect.fromLTWH(4, 4, 6, 6)),
      );
      expect(tiny.rows, <String>[
        for (int y = 0; y < 14; y++)
          if (y < 3 || y > 10) '.' * 14 else if (y < 5 || y > 8) '...########...' else '...##....##...',
      ]);
    });

    test('KkGlow', () {
      const KkGlow g = KkGlow(color: _red);
      expect(g.ring, 1);
      expect(g.blur, 18);
      expect(g.alpha, 0.3);
      expect(g == const KkGlow(color: _red, blur: 22), isFalse);
    });
  });

  group('dashed edges', () {
    testChecked('every side starts and ends on a dash, so a small box is the same from all four corners', (
      WidgetTester tester,
    ) async {
      // The mark of a skipped step: 16×16 with a 2px dashed border.
      final _Pixels p = await _render(
        tester,
        16,
        16,
        (Canvas canvas) => KkEdges.line(_red, width: 2, dashed: true).paint(canvas, const Rect.fromLTWH(0, 0, 16, 16)),
      );
      expect(p.rows, <String>[
        '######....######',
        '######....######',
        '##............##',
        '##............##',
        '##............##',
        '##............##',
        '................',
        '................',
        '................',
        '................',
        '##............##',
        '##............##',
        '##............##',
        '##............##',
        '######....######',
        '######....######',
      ]);
    });

    testChecked('a long side: 3px dashes on whole pixels, spread evenly from a solid corner to a solid corner', (
      WidgetTester tester,
    ) async {
      for (final Size size in const <Size>[Size(100, 40), Size(99, 41), Size(64, 23), Size(37, 12), Size(250, 7)]) {
        final int w = size.width.toInt();
        final int h = size.height.toInt();
        final _Pixels p = await _render(
          tester,
          w,
          h,
          (Canvas canvas) => KkEdges.line(_red, dashed: true).paint(canvas, Offset.zero & size),
        );
        for (final String side in <String>[p.row(0), p.row(h - 1), p.column(0), p.column(w - 1)]) {
          final String reason = '$size: $side';
          expect(side, isNot(contains('+')), reason: reason);
          expect(side, startsWith('###.'), reason: reason);
          expect(side, endsWith('.###'), reason: reason);
          final List<int> runs = _runs(side);
          for (int i = 0; i < runs.length; i++) {
            // Dashes are 3px; the gaps are as close to 3px as the length allows.
            expect(runs[i], i.isEven ? 3 : inInclusiveRange(1, 5), reason: reason);
          }
          final List<int> gaps = <int>[for (int i = 1; i < runs.length; i += 2) runs[i]];
          expect(gaps.reduce(math.max) - gaps.reduce(math.min), lessThanOrEqualTo(1), reason: reason);
          // Both ends of a side look the same. The middle dash of an odd
          // number cannot always be centred on whole pixels, so the two gaps
          // beside it may differ by a pixel.
          final int middle = runs.length ~/ 2;
          for (int i = 0; i < middle; i++) {
            final int slack = i == middle - 1 && middle.isEven ? 1 : 0;
            expect((runs[i] - runs[runs.length - 1 - i]).abs(), lessThanOrEqualTo(slack), reason: reason);
          }
        }
        // Nothing is painted inside the border.
        for (int y = 1; y < h - 1; y++) {
          expect(p.row(y).substring(1, w - 1), '.' * (w - 2), reason: '$size row $y');
        }
      }
    });

    testChecked('a translucent colour is painted once where two dashed sides share a corner', (
      WidgetTester tester,
    ) async {
      const Color glass = Color(0x80FF0000);
      final _Pixels p = await _render(
        tester,
        40,
        40,
        (Canvas canvas) => KkEdges.line(glass, width: 2, dashed: true).paint(canvas, const Rect.fromLTWH(0, 0, 40, 40)),
      );
      final int once = p.alpha(4, 0);
      expect(once, inInclusiveRange(127, 129));
      // The 2×2 squares where a 2px top or bottom dash crosses a left or right one.
      for (final int x in <int>[0, 1, 38, 39]) {
        for (final int y in <int>[0, 1, 38, 39]) {
          expect(p.alpha(x, y), once, reason: 'corner pixel ($x, $y)');
        }
      }
    });

    testChecked('a side too short for two dashes and a gap is solid', (WidgetTester tester) async {
      final _Pixels p = await _render(
        tester,
        6,
        30,
        (Canvas canvas) => KkEdges.line(_red, dashed: true).paint(canvas, const Rect.fromLTWH(0, 0, 6, 30)),
      );
      expect(p.row(0), '######');
      expect(p.row(29), '######');
      expect(p.column(0), startsWith('###.'));
      expect(p.column(0), endsWith('.###'));
      // One pixel more and there is room for a gap.
      final _Pixels q = await _render(
        tester,
        7,
        30,
        (Canvas canvas) => KkEdges.line(_red, dashed: true).paint(canvas, const Rect.fromLTWH(0, 0, 7, 30)),
      );
      expect(q.row(0), '###.###');
    });

    testChecked('one dashed side alone; a dashed side stays out of a solid one', (WidgetTester tester) async {
      // The underline of an editable cell.
      final _Pixels line = await _render(
        tester,
        51,
        10,
        (Canvas canvas) =>
            const KkEdges(bottom: KkSide(_red, dashed: true)).paint(canvas, const Rect.fromLTWH(0, 0, 51, 10)),
      );
      expect(line.row(9), '###...###...###...###...###...###...###...###...###');
      for (int y = 0; y < 9; y++) {
        expect(line.row(y), '.' * 51);
      }
      // A 4px solid top over a 1px dashed left: the corner belongs to the solid
      // side, and the dashed one still ends on a dash at the bottom corner.
      final _Pixels mixed = await _render(
        tester,
        30,
        40,
        (Canvas canvas) => const KkEdges(
          top: KkSide(Color(0x80FF0000), width: 4),
          left: KkSide(Color(0x80FF0000), dashed: true),
        ).paint(canvas, const Rect.fromLTWH(0, 0, 30, 40)),
      );
      final int once = mixed.alpha(15, 2);
      for (int y = 0; y < 4; y++) {
        expect(mixed.alpha(0, y), once, reason: 'the solid band at y=$y is not painted over');
      }
      expect(mixed.column(0), endsWith('.+++'));
      expect(mixed.column(1).substring(4), '.' * 36);
    });
  });

  group('patterns', () {
    const List<Rect> rects = <Rect>[
      Rect.fromLTWH(0, 0, 240, 96),
      Rect.zero,
      Rect.fromLTWH(0, 0, 1, 1),
      Rect.fromLTWH(7.5, 3.25, 0.5, 300),
      Rect.fromLTWH(-100, -100, 50, 50),
      Rect.fromLTWH(0, 0, 3840, 2160),
    ];
    const List<KkPattern> patterns = <KkPattern>[
      KkPattern.grid(color: _red),
      KkPattern.grid(color: _red, pitch: 8),
      KkPattern.plot(minor: _red, major: _blue),
      KkPattern.plot(minor: _red, major: _blue, majorEvery: 4),
      KkPattern.stripes(a: _red),
      KkPattern.stripes(a: _red, b: _blue, width: 3, period: 6),
      KkPattern.stripes(a: _red, b: _blue, shift: 17, tiled: true),
      KkPattern.stripes(a: _red, width: 30, period: 10),
      KkPattern.hex(color: _red),
      KkPattern.hex(color: _red, pitch: 48, opacity: 1),
      KkPattern.scanlines(color: _red),
      KkPattern.segments(color: _red),
      KkPattern.segments(color: _red, pitch: 6, gap: 1),
      KkPattern.ticks(color: _red),
    ];

    test('every pattern paints on normal, empty, tiny, offset and huge rectangles', () {
      for (final KkPattern pattern in patterns) {
        for (final Rect rect in rects) {
          _paint((Canvas canvas) => pattern.paint(canvas, rect));
        }
      }
    });

    test('values that cannot advance paint nothing instead of looping forever', () {
      const Rect rect = Rect.fromLTWH(0, 0, 100, 100);
      const List<KkPattern> degenerate = <KkPattern>[
        KkPattern.grid(color: _red, pitch: 0),
        KkPattern.grid(color: _red, pitch: -5),
        KkPattern.grid(color: _red, stroke: 0),
        KkPattern.plot(minor: _red, major: _blue, pitch: 0),
        KkPattern.plot(minor: _red, major: _blue, majorEvery: 0),
        KkPattern.stripes(a: _red, width: 0),
        KkPattern.stripes(a: _red, period: 0),
        KkPattern.stripes(a: _red, width: -4, period: -8),
        KkPattern.hex(color: _red, pitch: 0),
        KkPattern.hex(color: _red, opacity: 0),
        KkPattern.scanlines(color: _red, on: 0, off: 0),
        KkPattern.scanlines(color: _red, on: 0),
        KkPattern.scanlines(color: _red, on: -1, off: 1),
        KkPattern.segments(color: _red, pitch: 0),
        KkPattern.segments(color: _red, pitch: 4, gap: 9),
        KkPattern.ticks(color: _red, pitch: 0),
        KkPattern.ticks(color: _red, pitch: -1),
        KkPattern.ticks(color: _red, stroke: 0),
      ];
      for (final KkPattern pattern in degenerate) {
        _paint((Canvas canvas) => pattern.paint(canvas, rect));
      }
    });

    test('a transparent colour paints nothing and does not throw', () {
      const Color clear = Color(0x00000000);
      for (final KkPattern pattern in const <KkPattern>[
        KkPattern.grid(color: clear),
        KkPattern.plot(minor: clear, major: clear),
        KkPattern.stripes(a: clear, b: clear),
        KkPattern.hex(color: clear),
        KkPattern.scanlines(color: clear),
        KkPattern.segments(color: clear),
        KkPattern.ticks(color: clear),
      ]) {
        _paint((Canvas canvas) => pattern.paint(canvas, const Rect.fromLTWH(0, 0, 50, 50)));
      }
    });

    test('equal patterns are equal, so a box need not repaint', () {
      for (final KkPattern pattern in patterns) {
        expect(pattern == pattern, isTrue);
        expect(pattern.hashCode, pattern.hashCode);
      }
      expect(const KkPattern.grid(color: _red), const KkPattern.grid(color: _red, pitch: 24));
      expect(const KkPattern.grid(color: _red) == const KkPattern.grid(color: _blue), isFalse);
      expect(const KkPattern.grid(color: _red) == const KkPattern.ticks(color: _red, pitch: 24), isFalse);
      expect(const KkPattern.plot(minor: _red, major: _blue), const KkPattern.plot(minor: _red, major: _blue, majorEvery: 8));
      expect(const KkPattern.stripes(a: _red) == const KkPattern.stripes(a: _red, shift: 1), isFalse);
      expect(const KkPattern.stripes(a: _red), const KkPattern.stripes(a: _red, width: 12));
      expect(const KkPattern.hex(color: _red), const KkPattern.hex(color: _red, opacity: 0.2));
      expect(const KkPattern.scanlines(color: _red), const KkPattern.scanlines(color: _red, on: 1, off: 2));
      expect(const KkPattern.segments(color: _red), const KkPattern.segments(color: _red, pitch: 8, gap: 2));
      expect(const KkPattern.ticks(color: _red) == const KkPattern.ticks(color: _red, stroke: 2), isFalse);
      for (int i = 0; i < patterns.length; i++) {
        for (int j = i + 1; j < patterns.length; j++) {
          expect(patterns[i] == patterns[j], isFalse, reason: '$i vs $j');
        }
      }
    });

    testChecked('stripes rise to the right and start at the bottom-right corner', (WidgetTester tester) async {
      // Sample real pixels: 12px stripes (period 24) on a 96×96 square.
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      const KkPattern.stripes(a: _red, b: _blue).paint(canvas, const Rect.fromLTWH(0, 0, 96, 96));
      final ui.Picture picture = recorder.endRecording();
      late ByteData bytes;
      await tester.runAsync(() async {
        final ui.Image image = await picture.toImage(96, 96);
        bytes = (await image.toByteData())!;
        image.dispose();
      });
      picture.dispose();
      bool isRed(int x, int y) => bytes.getUint8((y * 96 + x) * 4) > 200;
      // The corner itself is in a stripe. Along the main diagonal one period is
      // 24·√2 / 2 ≈ 17px: stripe at 88–95, gap at 79–87, stripe at 71–78.
      expect(isRed(94, 94), isTrue);
      expect(isRed(89, 89), isTrue);
      expect(isRed(83, 83), isFalse);
      expect(isRed(75, 75), isTrue);
      expect(isRed(66, 66), isFalse);
      // Along a "/" diagonal (x + y constant) the colour does not change.
      for (int i = 10; i < 80; i += 7) {
        expect(isRed(i, 90 - i), isRed(10, 80), reason: 'x=$i');
      }
      // Stripe and gap have the same width.
      int red = 0;
      for (int y = 0; y < 96; y++) {
        for (int x = 0; x < 96; x++) {
          if (isRed(x, y)) red++;
        }
      }
      expect(red / (96 * 96), closeTo(0.5, 0.04));
    });

    testChecked('the grid draws one line per pitch from the top-left corner', (WidgetTester tester) async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 48, 48), Paint()..color = _blue);
      const KkPattern.grid(color: _red).paint(canvas, const Rect.fromLTWH(0, 0, 48, 48));
      final ui.Picture picture = recorder.endRecording();
      late ByteData bytes;
      await tester.runAsync(() async {
        final ui.Image image = await picture.toImage(48, 48);
        bytes = (await image.toByteData())!;
        image.dispose();
      });
      picture.dispose();
      bool isRed(int x, int y) => bytes.getUint8((y * 48 + x) * 4) > 200 && bytes.getUint8((y * 48 + x) * 4 + 2) < 50;
      expect(isRed(0, 10), isTrue);
      expect(isRed(1, 10), isFalse);
      expect(isRed(24, 10), isTrue);
      expect(isRed(25, 10), isFalse);
      expect(isRed(10, 0), isTrue);
      expect(isRed(10, 24), isTrue);
      expect(isRed(10, 23), isFalse);
      expect(isRed(47, 47), isFalse);
    });
  });

  group('KkDecoration', () {
    test('paints both layers on any rectangle', () {
      const KkDecoration full = KkDecoration(
        fill: _red,
        pattern: KkPattern.grid(color: _blue),
        edges: KkEdges.all(KkSide(_blue)),
        brackets: KkBracketSpec(color: _blue),
        glow: KkGlow(color: _blue),
        overlay: KkPattern.scanlines(color: _blue),
      );
      for (final Rect rect in const <Rect>[Rect.fromLTWH(0, 0, 100, 50), Rect.zero, Rect.fromLTWH(0, 0, 1, 1)]) {
        _paint((Canvas canvas) => full.paintBackground(canvas, rect));
        _paint((Canvas canvas) => full.paintForeground(canvas, rect));
        _paint((Canvas canvas) => const KkDecoration().paintBackground(canvas, rect));
        _paint((Canvas canvas) => const KkDecoration().paintForeground(canvas, rect));
      }
      expect(full.hasForeground, isTrue);
      expect(const KkDecoration(fill: _red).hasForeground, isFalse);
      expect(const KkDecoration(brackets: KkBracketSpec(color: _red)).hasForeground, isTrue);
      expect(const KkDecoration(overlay: KkPattern.scanlines(color: _red)).hasForeground, isTrue);
    });

    test('copyWith and equality', () {
      const KkDecoration d = KkDecoration(fill: _red);
      expect(d, const KkDecoration(fill: _red));
      expect(d.hashCode, const KkDecoration(fill: _red).hashCode);
      expect(d.copyWith(fill: _blue).fill, _blue);
      expect(d.copyWith(edges: const KkEdges.all(KkSide(_blue))).edges.top.color, _blue);
      expect(d.copyWith(glow: const KkGlow(color: _blue)).glow, const KkGlow(color: _blue));
      expect(d.copyWith(pattern: const KkPattern.grid(color: _blue)).pattern, const KkPattern.grid(color: _blue));
      expect(d.copyWith(brackets: const KkBracketSpec(color: _blue)).brackets, const KkBracketSpec(color: _blue));
      expect(d.copyWith(overlay: const KkPattern.ticks(color: _blue)).overlay, const KkPattern.ticks(color: _blue));
      expect(d.copyWith(), d);
      expect(d == d.copyWith(fill: _blue), isFalse);
    });
  });

  group('text painting', () {
    // No fonts are loaded here: the test font draws every glyph as an em square.
    const TextStyle style = TextStyle(fontSize: 10, height: 1.0, color: _red);

    test('kkMeasureText and kkLayoutText', () {
      expect(kkMeasureText('AAAA', style), 40);
      expect(kkMeasureText('', style), 0);
      expect(kkMeasureText('AAAA', style, scaler: const TextScaler.linear(2)), 80);
      final TextPainter tp = kkLayoutText('AAAA AAAA', style, maxWidth: 50, maxLines: null);
      expect(tp.height, 20);
      tp.dispose();
      final TextPainter one = kkLayoutText('AAAA AAAA', style, maxWidth: 50, ellipsis: true);
      expect(one.height, 10);
      expect(one.width, lessThanOrEqualTo(50));
      one.dispose();
    });

    test('kkPaintText places the box by the alignment and returns it', () {
      const Offset anchor = Offset(100, 100);
      Rect at(Alignment align) {
        late Rect rect;
        _paint((Canvas canvas) => rect = kkPaintText(canvas, 'AAAA', style, anchor, align: align));
        return rect;
      }

      expect(at(Alignment.topLeft), const Rect.fromLTWH(100, 100, 40, 10));
      expect(at(Alignment.center), const Rect.fromLTWH(80, 95, 40, 10));
      expect(at(Alignment.bottomRight), const Rect.fromLTWH(60, 90, 40, 10));
      expect(at(Alignment.centerRight), const Rect.fromLTWH(60, 95, 40, 10));
      expect(at(Alignment.topCenter), const Rect.fromLTWH(80, 100, 40, 10));
      late Rect clipped;
      _paint((Canvas canvas) => clipped = kkPaintText(canvas, 'AAAAAAAA', style, anchor, maxWidth: 30, ellipsis: true));
      expect(clipped.width, lessThanOrEqualTo(30));
      late Rect empty;
      _paint((Canvas canvas) => empty = kkPaintText(canvas, '', style, anchor, align: Alignment.center));
      expect(empty.width, 0);
    });
  });
}
