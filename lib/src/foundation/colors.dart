import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'level.dart';

/// `color-mix(in srgb, a amount, b)`: [amount] of [a] over [b].
Color kkMix(Color a, double amount, Color b) => Color.lerp(b, a, amount)!;

/// `color-mix(in srgb, c amount, transparent)`: [c] at [opacity] of its own alpha.
Color kkFade(Color c, double opacity) => c.withValues(alpha: c.a * opacity);

/// A glow: a hard 1px ring plus a blurred halo. KEIKAI has no drop shadows;
/// only active and alarm surfaces emit light.
@immutable
class KkGlow {
  const KkGlow({required this.color, this.ring = 1, this.blur = 18, this.alpha = 0.3});

  final Color color;

  /// Width of the solid ring drawn just outside the surface.
  final double ring;

  /// CSS blur radius of the halo (the Gaussian sigma is half of it).
  final double blur;

  /// Opacity of the halo.
  final double alpha;

  @override
  bool operator ==(Object other) =>
      other is KkGlow && other.color == color && other.ring == ring && other.blur == blur && other.alpha == alpha;

  @override
  int get hashCode => Object.hash(color, ring, blur, alpha);
}

/// The colour roles of KEIKAI for one theme.
///
/// Surfaces are separated by lightness and lines, never by gradients.
/// [signal] is the colour of structure and controls; it never means a state.
/// States are [nominal], [caution], [alert] and [offline], and they always
/// travel with a word and a status icon.
@immutable
class KkColors {
  const KkColors({
    required this.bg000,
    required this.bg100,
    required this.bg200,
    required this.bg300,
    required this.line,
    required this.grid,
    required this.ink,
    required this.inkDim,
    required this.inkFaint,
    required this.signal,
    required this.signalDim,
    required this.alert,
    required this.alertDeep,
    required this.caution,
    required this.nominal,
    required this.offline,
    required this.onFill,
    required this.series1,
    required this.series2,
    required this.series3,
    required this.focus,
    this.glowSignalAlpha = 0.3,
  });

  /// 평시 STANDBY: signal orange on black.
  static const KkColors standby = KkColors(
    bg000: Color(0xFF050506),
    bg100: Color(0xFF0C0C0E),
    bg200: Color(0xFF16161A),
    bg300: Color(0xFF212127),
    line: Color(0xFF643412),
    grid: Color(0xFF190E08),
    ink: Color(0xFFEFE9DD),
    inkDim: Color(0xFFA8A196),
    inkFaint: Color(0xFF857F75),
    signal: Color(0xFFFF7A1A),
    signalDim: Color(0xFF422410),
    alert: Color(0xFFF8283C),
    alertDeep: Color(0xFF8F0F1C),
    caution: Color(0xFFFFD21F),
    nominal: Color(0xFF5CFF9D),
    offline: Color(0xFF8F8A82),
    onFill: Color(0xFF0A0705),
    series1: Color(0xFFE8660F),
    series2: Color(0xFF2F9BE0),
    series3: Color(0xFFD65BB0),
    focus: Color(0xFFFFF3DC),
  );

  /// 경보 ALERT: the whole screen turns red.
  static const KkColors alertTheme = KkColors(
    bg000: Color(0xFF080203),
    bg100: Color(0xFF120405),
    bg200: Color(0xFF1E0709),
    bg300: Color(0xFF2C0B0E),
    line: Color(0xFF6C1A1A),
    grid: Color(0xFF1E0708),
    ink: Color(0xFFF7E8E4),
    inkDim: Color(0xFFBBA29D),
    inkFaint: Color(0xFF957D78),
    signal: Color(0xFFFF3D3D),
    signalDim: Color(0xFF4B1212),
    alert: Color(0xFFF8283C),
    alertDeep: Color(0xFF8F0F1C),
    caution: Color(0xFFFFD21F),
    nominal: Color(0xFF5CFF9D),
    offline: Color(0xFF958985),
    onFill: Color(0xFF0A0303),
    series1: Color(0xFFE8660F),
    series2: Color(0xFF2F9BE0),
    series3: Color(0xFFD65BB0),
    focus: Color(0xFFFFF3DC),
    glowSignalAlpha: 0.35,
  );

  /// Screen ground (void). Floor of the grid and hazard patterns.
  final Color bg000;

  /// Panel bodies, log rows, readout cards.
  final Color bg100;

  /// Panel header bands, CommandBar cells, floating surfaces.
  final Color bg200;

  /// Hover and selected rows, inner wells.
  final Color bg300;

  /// 1px panel borders and dividers (decorative).
  final Color line;

  /// Background grid lines (decorative).
  final Color grid;

  /// Titles, body text, readout values.
  final Color ink;

  /// Secondary text, Latin subtitles, units.
  final Color inkDim;

  /// Meta, tick numbers, disabled text. Only on bg000 to bg200.
  final Color inkFaint;

  /// Identity colour: brackets, code blocks, active and selected, primary
  /// buttons, control borders. Never a state.
  final Color signal;

  /// Unlit meter segments, weak signal fields (decorative, never text).
  final Color signalDim;

  /// Critical text, lines and fills.
  final Color alert;

  /// The dark phase of an alarm fill: strobe alternate, alarm rows.
  final Color alertDeep;

  final Color caution;
  final Color nominal;
  final Color offline;

  /// Text and glyphs on signal, alert, caution, nominal and offline fills.
  final Color onFill;

  /// Chart series, in fixed order. No status meaning; never used for text.
  final Color series1;
  final Color series2;
  final Color series3;

  /// Keyboard focus ring: 2px solid, 2px away.
  final Color focus;

  /// Halo opacity of [glowSignal] (0.30 standby, 0.35 alert).
  final double glowSignalAlpha;

  /// The three chart series colours in their fixed order.
  List<Color> get series => <Color>[series1, series2, series3];

  /// The colour for [level], or [fallback] (default [signal]) when it is null.
  Color level(KkLevel? level, {Color? fallback}) => switch (level) {
    KkLevel.nominal => nominal,
    KkLevel.caution => caution,
    KkLevel.critical => alert,
    KkLevel.offline => offline,
    null => fallback ?? signal,
  };

  /// Selected and active panels, pressed primary buttons.
  KkGlow get glowSignal => KkGlow(color: signal, blur: 18, alpha: glowSignalAlpha);

  /// Alarm panels, critical AlertBar.
  KkGlow get glowAlert => KkGlow(color: alert, blur: 22, alpha: 0.45);

  /// Phosphor bloom of a live trace line.
  KkGlow get glowTrace => KkGlow(color: nominal, ring: 0, blur: 4, alpha: 0.6);

  /// The six-step intensity ramp used by Heatmap and Waterfall, from nearly
  /// black to hot: signal at 8 / 22 / 42 / 68 / 100 % over [bg000], then ink.
  List<Color> get ramp => <Color>[
    kkMix(signal, 0.08, bg000),
    kkMix(signal, 0.22, bg000),
    kkMix(signal, 0.42, bg000),
    kkMix(signal, 0.68, bg000),
    signal,
    kkMix(ink, 0.55, signal),
  ];

  /// The scrim behind dialogs: 78 % [bg000].
  Color get scrim => kkFade(bg000, 0.78);

  /// The scrim behind sheets: 70 % [bg000].
  Color get scrimSheet => kkFade(bg000, 0.70);

  KkColors copyWith({
    Color? bg000,
    Color? bg100,
    Color? bg200,
    Color? bg300,
    Color? line,
    Color? grid,
    Color? ink,
    Color? inkDim,
    Color? inkFaint,
    Color? signal,
    Color? signalDim,
    Color? alert,
    Color? alertDeep,
    Color? caution,
    Color? nominal,
    Color? offline,
    Color? onFill,
    Color? series1,
    Color? series2,
    Color? series3,
    Color? focus,
    double? glowSignalAlpha,
  }) {
    return KkColors(
      bg000: bg000 ?? this.bg000,
      bg100: bg100 ?? this.bg100,
      bg200: bg200 ?? this.bg200,
      bg300: bg300 ?? this.bg300,
      line: line ?? this.line,
      grid: grid ?? this.grid,
      ink: ink ?? this.ink,
      inkDim: inkDim ?? this.inkDim,
      inkFaint: inkFaint ?? this.inkFaint,
      signal: signal ?? this.signal,
      signalDim: signalDim ?? this.signalDim,
      alert: alert ?? this.alert,
      alertDeep: alertDeep ?? this.alertDeep,
      caution: caution ?? this.caution,
      nominal: nominal ?? this.nominal,
      offline: offline ?? this.offline,
      onFill: onFill ?? this.onFill,
      series1: series1 ?? this.series1,
      series2: series2 ?? this.series2,
      series3: series3 ?? this.series3,
      focus: focus ?? this.focus,
      glowSignalAlpha: glowSignalAlpha ?? this.glowSignalAlpha,
    );
  }

  List<Object> get _props => <Object>[
    bg000, bg100, bg200, bg300, line, grid, ink, inkDim, inkFaint, signal, signalDim, //
    alert, alertDeep, caution, nominal, offline, onFill, series1, series2, series3, focus, glowSignalAlpha,
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is KkColors && listEquals(other._props, _props));

  @override
  int get hashCode => Object.hashAll(_props);
}
