import 'package:flutter/widgets.dart';

import '../foundation/motion.dart';
import '../foundation/theme.dart';
import 'stagger.dart';

/// The text of a scramble at [progress] (0 to 1): digits that have not settled
/// yet show a pseudo-random digit; they settle from the front.
///
/// The noise is a pure function of [step], the position and [seed], so the
/// same frame always shows the same digits.
String kkScrambleText(String target, double progress, {int step = 0, int seed = 0, bool letters = false}) {
  if (progress >= 1) return target;
  final List<int> units = target.codeUnits;
  int scrambleable = 0;
  for (final int u in units) {
    if (_scrambles(u, letters)) scrambleable++;
  }
  if (scrambleable == 0) return target;
  final int settled = (progress.clamp(0.0, 1.0) * scrambleable).floor();
  final StringBuffer out = StringBuffer();
  int seen = 0;
  for (int i = 0; i < units.length; i++) {
    final int u = units[i];
    if (!_scrambles(u, letters)) {
      out.writeCharCode(u);
      continue;
    }
    if (seen < settled) {
      out.writeCharCode(u);
    } else {
      final int h = _hash(seed, step, i);
      if (u >= 0x30 && u <= 0x39) {
        out.writeCharCode(0x30 + h % 10);
      } else if (u >= 0x41 && u <= 0x5A) {
        out.writeCharCode(0x41 + h % 26);
      } else {
        out.writeCharCode(0x61 + h % 26);
      }
    }
    seen++;
  }
  return out.toString();
}

bool _scrambles(int u, bool letters) {
  if (u >= 0x30 && u <= 0x39) return true;
  if (!letters) return false;
  return (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A);
}

int _hash(int a, int b, int c) {
  int h = 0x811C9DC5 ^ (a & 0xFFFFFFFF);
  h = (h * 0x01000193) & 0xFFFFFFFF;
  h ^= b & 0xFFFFFFFF;
  h = (h * 0x01000193) & 0xFFFFFFFF;
  h ^= c & 0xFFFFFFFF;
  h = (h * 0x01000193) & 0xFFFFFFFF;
  h ^= h >> 13;
  h = (h * 0x5BD1E995) & 0xFFFFFFFF;
  h ^= h >> 15;
  return h & 0x7FFFFFFF;
}

/// A seed for [kkScrambleText] made of every character of [text], of [run]
/// and of [cell]. Two values of the same length then get different noise,
/// while the same value in the same place always gets the same.
int _seedFor(String text, int run, int cell) {
  int seed = _hash(run, cell, text.length);
  for (final int unit in text.codeUnits) {
    seed = _hash(seed, unit, 0);
  }
  return seed;
}

/// A value that scrambles when it changes: the digits churn for 0.46s and
/// settle from the front. Readouts, stats, gauges and totals update this way.
///
/// Only digits scramble unless [letters] is true; punctuation and units stay
/// put, so the text never changes width in a tabular face.
///
/// The noise is made from the value and from the cell of the grid it is in
/// (the ambient [KkStagger] index), so the readouts of a screen churn each in
/// their own way and not in unison.
class KkScramble extends StatefulWidget {
  const KkScramble(
    this.text, {
    super.key,
    this.style,
    this.duration = KkMotion.scramble,
    this.steps = 10,
    this.onMount = true,
    this.letters = false,
    this.textAlign,
    this.enabled = true,
  });

  final String text;

  /// Defaults to the ambient text style.
  final TextStyle? style;
  final Duration duration;

  /// How many times the noise changes during the scramble.
  final int steps;

  /// Scramble when first shown as well as on change.
  final bool onMount;
  final bool letters;
  final TextAlign? textAlign;
  final bool enabled;

  @override
  State<KkScramble> createState() => _KkScrambleState();
}

class _KkScrambleState extends State<KkScramble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, value: 1)..addListener(_onTick);
  int _step = -1;
  int _generation = 0;
  int _seed = 0;
  bool _started = false;

  void _onTick() {
    final int s = (_controller.value * widget.steps).floor();
    if (s != _step) setState(() => _step = s);
  }

  void _run() {
    if (!widget.enabled || !KeikaiTheme.motionOf(context)) {
      _controller.value = 1;
      return;
    }
    _generation++;
    _seed = _seedFor(widget.text, _generation, KkStagger.of(context));
    _controller.duration = KeikaiTheme.of(context).motion.scaled(widget.duration);
    _controller.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (widget.onMount) _run();
    }
  }

  @override
  void didUpdateWidget(KkScramble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _run();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double p = _controller.value;
    final String shown = p >= 1
        ? widget.text
        : kkScrambleText(widget.text, p, step: (p * widget.steps).floor(), seed: _seed, letters: widget.letters);
    return Text(
      shown,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      semanticsLabel: widget.text,
    );
  }
}
