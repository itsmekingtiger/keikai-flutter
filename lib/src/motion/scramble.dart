import 'package:flutter/widgets.dart';

import '../foundation/motion.dart';
import '../foundation/theme.dart';
import 'stagger.dart';

/// The text of a scramble at [progress] (0 to 1): digits that have not settled
/// yet show a pseudo-random digit; they settle from the front.
///
/// The noise is a pure function of [step], the position and [seed], so the
/// same frame always shows the same digits.
///
/// With [only], the scramble is limited to the characters at those positions
/// (code units of [target]); every other character is shown as it is, and the
/// ones that churn still settle from the front.
String kkScrambleText(
  String target,
  double progress, {
  int step = 0,
  int seed = 0,
  bool letters = false,
  Set<int>? only,
}) {
  if (progress >= 1) return target;
  final List<int> units = target.codeUnits;
  int scrambleable = 0;
  for (int i = 0; i < units.length; i++) {
    if (_churns(units[i], i, letters, only)) scrambleable++;
  }
  if (scrambleable == 0) return target;
  final int settled = kkStepAt(progress.clamp(0.0, 1.0), scrambleable);
  final StringBuffer out = StringBuffer();
  int seen = 0;
  for (int i = 0; i < units.length; i++) {
    final int u = units[i];
    if (!_churns(u, i, letters, only)) {
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

/// Whether the character [u] at position [i] is one that churns.
bool _churns(int u, int i, bool letters, Set<int>? only) =>
    _scrambles(u, letters) && (only == null || only.contains(i));

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
///
/// A value that changes every second is noise for half of the time when all
/// of its digits churn. With [scope] set to [KkScrambleScope.changed] (here,
/// or for a whole app in [KkMotion.scrambleScope]) only the places that
/// changed churn and the rest stays readable.
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
    this.scope,
  }) : builder = null,
       assert(steps > 0);

  /// The same scramble for a value that is not laid out as a [Text]: [builder]
  /// is handed the characters to show and draws them itself, on a canvas for
  /// example. Assistive technology must be given [text] by the caller.
  const KkScramble.builder(
    this.text, {
    super.key,
    this.duration = KkMotion.scramble,
    this.steps = 10,
    this.onMount = true,
    this.letters = false,
    this.enabled = true,
    this.scope,
    required Widget Function(BuildContext context, String shown) this.builder,
  }) : style = null,
       textAlign = null,
       assert(steps > 0);

  final String text;

  /// Defaults to the ambient text style.
  final TextStyle? style;
  final Duration duration;

  /// How many times the noise changes during the scramble. At least 1.
  final int steps;

  /// Scramble when first shown as well as on change.
  final bool onMount;
  final bool letters;
  final TextAlign? textAlign;
  final bool enabled;

  /// Which characters churn when [text] changes: all of its digits, or only
  /// the ones that differ from the text before. Null takes the theme's
  /// [KkMotion.scrambleScope], which is [KkScrambleScope.all] unless set.
  ///
  /// With [KkScrambleScope.changed], a text shown for the first time or of
  /// another length than the one before still churns whole, a change that
  /// touches nothing that can churn (a separator, a unit) starts no scramble,
  /// and what a scramble in flight has not settled yet goes on churning.
  final KkScrambleScope? scope;

  /// Builds what stands in place of the [Text]. `shown` is [text] once the
  /// scramble has settled. Null unless made with [KkScramble.builder].
  final Widget Function(BuildContext context, String shown)? builder;

  @override
  State<KkScramble> createState() => _KkScrambleState();
}

class _KkScrambleState extends State<KkScramble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, value: 1)..addListener(_onTick);

  /// The noise step on screen, or null when the value itself is.
  int? _step;
  int _generation = 0;
  int _seed = 0;
  bool _started = false;

  /// The positions that churn in the scramble in flight, or null when every
  /// digit does.
  Set<int>? _only;

  void _onTick() {
    // The end is not one more step: whatever the step count, the last tick
    // differs from every noise step and puts the value on screen.
    final double p = _controller.value;
    final int? s = p >= 1 ? null : kkStepAt(p, widget.steps);
    if (s != _step) setState(() => _step = s);
  }

  /// Starts the scramble for [widget.text]. [before] is the text it takes the
  /// place of, or null when there was none.
  void _run([String? before]) {
    if (!widget.enabled || !KeikaiTheme.motionOf(context)) {
      _controller.value = 1;
      return;
    }
    final String text = widget.text;
    final KkScrambleScope scope = widget.scope ?? KeikaiTheme.of(context).motion.scrambleScope;
    if (scope == KkScrambleScope.all || before == null || before.length != text.length) {
      _only = null;
    } else {
      final Set<int> changed = <int>{
        for (int i = 0; i < text.length; i++)
          if (text.codeUnitAt(i) != before.codeUnitAt(i) && _scrambles(text.codeUnitAt(i), widget.letters)) i,
      };
      // Nothing that can churn has changed: a scramble in flight goes on as
      // it is, and without one the text is simply shown.
      if (changed.isEmpty) return;
      _only = changed..addAll(_unsettled(before));
    }
    _generation++;
    _seed = _seedFor(widget.text, _generation, KkStagger.of(context));
    _controller.duration = KeikaiTheme.of(context).motion.scaled(widget.duration);
    _controller.forward(from: 0);
  }

  /// The positions that the scramble in flight, which shows [text], has not
  /// settled yet. Empty when none is in flight.
  Set<int> _unsettled(String text) {
    final double p = _controller.value;
    if (p >= 1) return const <int>{};
    final List<int> units = text.codeUnits;
    final List<int> churning = <int>[
      for (int i = 0; i < units.length; i++)
        if (_churns(units[i], i, widget.letters, _only)) i,
    ];
    return churning.skip(kkStepAt(p.clamp(0.0, 1.0), churning.length)).toSet();
  }

  /// Ends a scramble in flight that may no longer run: the value is shown at
  /// once, as it would have been had motion been off from the start.
  void _stopIfOff() {
    if (_controller.isAnimating && (!widget.enabled || !KeikaiTheme.motionOf(context))) _controller.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (widget.onMount) _run();
    } else {
      _stopIfOff();
    }
  }

  @override
  void didUpdateWidget(KkScramble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _run(oldWidget.text);
    } else {
      _stopIfOff();
    }
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
        : kkScrambleText(
            widget.text,
            p,
            step: kkStepAt(p, widget.steps),
            seed: _seed,
            letters: widget.letters,
            only: _only,
          );
    final Widget Function(BuildContext context, String shown)? builder = widget.builder;
    if (builder != null) return builder(context, shown);
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
