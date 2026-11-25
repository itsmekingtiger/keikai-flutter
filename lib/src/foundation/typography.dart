import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The four type voices of KEIKAI and the scale built from them.
///
/// * **display**: Zen Old Mincho 900 (Hangul falls back to Noto Serif KR 900).
///   漢字 and Hangul titles only, tracking zero or tighter.
/// * **label**: Sofia Sans Extra Condensed. Latin capitals only.
/// * **mono**: IBM Plex Mono with tabular, slashed-zero figures. Every number,
///   code and time.
/// * **body**: IBM Plex Sans KR. Explanatory sentences, two lines at most.
///
/// The families are bundled with the package. To use your own, pass the family
/// names and set [package] to null (or to the package that declares them).
@immutable
class KkTypography {
  const KkTypography({
    this.displayFamily = 'Zen Old Mincho',
    this.displayFallback = const <String>['Noto Serif KR'],
    this.labelFamily = 'Sofia Sans Extra Condensed',
    this.labelFallback = const <String>['Zen Old Mincho', 'Noto Serif KR'],
    this.monoFamily = 'IBM Plex Mono',
    this.monoFallback = const <String>['IBM Plex Sans KR', 'Zen Old Mincho', 'Noto Serif KR'],
    this.bodyFamily = 'IBM Plex Sans KR',
    this.bodyFallback = const <String>['Zen Old Mincho', 'Noto Serif KR'],
    this.package = 'keikai',
    this.scale = 1.0,
  });

  final String displayFamily;
  final List<String> displayFallback;
  final String labelFamily;
  final List<String> labelFallback;
  final String monoFamily;
  final List<String> monoFallback;
  final String bodyFamily;

  /// Where the body face looks for glyphs it lacks. The bundled IBM Plex Sans
  /// KR has no ideographs, so they come from the display faces: Zen Old Mincho
  /// first, as in the other voices, so that one word is never set in two
  /// designs. Pass an empty list to leave them to the platform's own fonts.
  final List<String> bodyFallback;

  /// The package that declares the font families, or null when the app (or the
  /// platform) provides them.
  final String? package;

  /// Multiplier applied to every font size. Wall displays use 1.25.
  final double scale;

  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
    FontFeature.slashedZero(),
  ];

  String _family(String family) => package == null ? family : 'packages/$package/$family';

  List<String> _fallback(List<String> families) =>
      package == null ? families : <String>[for (final String f in families) 'packages/$package/$f'];

  /// A display (CJK title) style at [size] px.
  TextStyle display(double size, {double height = 1.0, double spacingEm = 0, Color? color}) {
    final double s = size * scale;
    return TextStyle(
      inherit: false,
      fontFamily: _family(displayFamily),
      fontFamilyFallback: _fallback(displayFallback),
      fontSize: s,
      fontWeight: FontWeight.w900,
      height: height,
      letterSpacing: spacingEm * s,
      leadingDistribution: TextLeadingDistribution.even,
      color: color,
      decoration: TextDecoration.none,
      textBaseline: TextBaseline.alphabetic,
    );
  }

  /// A label (Latin capitals) style at [size] px. [spacingEm] is the tracking
  /// in em; the design uses .04 to .2 depending on size.
  TextStyle label(
    double size, {
    FontWeight weight = FontWeight.w700,
    double height = 1.0,
    double spacingEm = 0.1,
    Color? color,
  }) {
    final double s = size * scale;
    return TextStyle(
      inherit: false,
      fontFamily: _family(labelFamily),
      fontFamilyFallback: _fallback(labelFallback),
      fontSize: s,
      fontWeight: weight,
      height: height,
      letterSpacing: spacingEm * s,
      leadingDistribution: TextLeadingDistribution.even,
      color: color,
      decoration: TextDecoration.none,
      textBaseline: TextBaseline.alphabetic,
    );
  }

  /// A monospaced numeric style at [size] px with tabular, slashed-zero figures.
  TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w400,
    double height = 1.0,
    double spacingEm = 0,
    Color? color,
  }) {
    final double s = size * scale;
    return TextStyle(
      inherit: false,
      fontFamily: _family(monoFamily),
      fontFamilyFallback: _fallback(monoFallback),
      fontSize: s,
      fontWeight: weight,
      height: height,
      letterSpacing: spacingEm * s,
      leadingDistribution: TextLeadingDistribution.even,
      fontFeatures: _tabular,
      color: color,
      decoration: TextDecoration.none,
      textBaseline: TextBaseline.alphabetic,
    );
  }

  /// A body style at [size] px.
  TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w400,
    double height = 1.55,
    Color? color,
  }) {
    final double s = size * scale;
    return TextStyle(
      inherit: false,
      fontFamily: _family(bodyFamily),
      fontFamilyFallback: _fallback(bodyFallback),
      fontSize: s,
      fontWeight: weight,
      height: height,
      letterSpacing: 0,
      leadingDistribution: TextLeadingDistribution.even,
      color: color,
      decoration: TextDecoration.none,
      textBaseline: TextBaseline.alphabetic,
    );
  }

  // ── The named scale ────────────────────────────────────────────────────

  /// 72/0.95. Once per screen: full-screen alarms and situation-board titles.
  TextStyle get displayXl => display(72, height: 0.95, spacingEm: -0.02);

  /// 44/1. Section titles, the large glyphs of an AlertBar.
  TextStyle get displayLg => display(44, spacingEm: -0.01);

  /// 24/1.1. Large panel titles, CommandBar condition.
  TextStyle get displayMd => display(24, height: 1.1);

  /// 17/1.15. Panel header titles, readout labels.
  TextStyle get displaySm => display(17, height: 1.15);

  /// 32/1 800. AlertBar text. Always capitals.
  TextStyle get labelXl => label(32, weight: FontWeight.w800, spacingEm: 0.01);

  /// 20/1.1 700. System names, large buttons, screen subtitles.
  TextStyle get labelLg => label(20, height: 1.1, spacingEm: 0.04);

  /// 13/1.2 700. Buttons, tags, Latin subtitles beside a title.
  TextStyle get labelMd => label(13, height: 1.2, spacingEm: 0.1);

  /// 11/1.2 600. Column heads, tick labels, meta.
  TextStyle get labelSm => label(11, weight: FontWeight.w600, height: 1.2, spacingEm: 0.14);

  /// 56/1 500. Timer, the one key figure of a screen.
  TextStyle get readoutXl => mono(56, weight: FontWeight.w500, spacingEm: -0.03);

  /// 32/1 500. Readout values, fixed digit count.
  TextStyle get readout => mono(32, weight: FontWeight.w500, spacingEm: -0.01);

  /// 12/1.5 400. Logs, codes, times, numbers in tables.
  TextStyle get data => mono(12, height: 1.5);

  /// 14/1.55 400. Explanatory sentences.
  TextStyle get bodyMd => body(14);

  /// 12/1.5 400. Notes, help, footnotes.
  TextStyle get bodySm => body(12, height: 1.5);

  KkTypography copyWith({
    String? displayFamily,
    List<String>? displayFallback,
    String? labelFamily,
    List<String>? labelFallback,
    String? monoFamily,
    List<String>? monoFallback,
    String? bodyFamily,
    List<String>? bodyFallback,
    String? package,
    bool clearPackage = false,
    double? scale,
  }) {
    return KkTypography(
      displayFamily: displayFamily ?? this.displayFamily,
      displayFallback: displayFallback ?? this.displayFallback,
      labelFamily: labelFamily ?? this.labelFamily,
      labelFallback: labelFallback ?? this.labelFallback,
      monoFamily: monoFamily ?? this.monoFamily,
      monoFallback: monoFallback ?? this.monoFallback,
      bodyFamily: bodyFamily ?? this.bodyFamily,
      bodyFallback: bodyFallback ?? this.bodyFallback,
      package: clearPackage ? null : (package ?? this.package),
      scale: scale ?? this.scale,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KkTypography &&
        other.displayFamily == displayFamily &&
        listEquals(other.displayFallback, displayFallback) &&
        other.labelFamily == labelFamily &&
        listEquals(other.labelFallback, labelFallback) &&
        other.monoFamily == monoFamily &&
        listEquals(other.monoFallback, monoFallback) &&
        other.bodyFamily == bodyFamily &&
        listEquals(other.bodyFallback, bodyFallback) &&
        other.package == package &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(
    displayFamily,
    Object.hashAll(displayFallback),
    labelFamily,
    Object.hashAll(labelFallback),
    monoFamily,
    Object.hashAll(monoFallback),
    bodyFamily,
    Object.hashAll(bodyFallback),
    package,
    scale,
  );
}
