import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'level.dart';
import 'motion.dart';
import 'tokens.dart';
import 'typography.dart';

/// Everything a KEIKAI widget reads from its surroundings: the colours of both
/// themes and which one is on, the type voices, the measurement tokens and the
/// motion settings.
@immutable
class KeikaiThemeData {
  const KeikaiThemeData({
    this.condition = KkCondition.standby,
    this.standbyColors = KkColors.standby,
    this.alertColors = KkColors.alertTheme,
    this.type = const KkTypography(),
    this.metrics = const KkMetrics(),
    this.motion = const KkMotion(),
  });

  /// Which theme is on.
  final KkCondition condition;

  /// Colours while [condition] is [KkCondition.standby].
  final KkColors standbyColors;

  /// Colours while [condition] is [KkCondition.alert].
  final KkColors alertColors;

  final KkTypography type;
  final KkMetrics metrics;
  final KkMotion motion;

  /// The colours of the current [condition].
  KkColors get colors => condition == KkCondition.alert ? alertColors : standbyColors;

  /// Whether the alert theme is on.
  bool get isAlert => condition == KkCondition.alert;

  /// This theme with [condition] switched.
  KeikaiThemeData withCondition(KkCondition condition) =>
      condition == this.condition ? this : copyWith(condition: condition);

  KeikaiThemeData copyWith({
    KkCondition? condition,
    KkColors? standbyColors,
    KkColors? alertColors,
    KkTypography? type,
    KkMetrics? metrics,
    KkMotion? motion,
  }) {
    return KeikaiThemeData(
      condition: condition ?? this.condition,
      standbyColors: standbyColors ?? this.standbyColors,
      alertColors: alertColors ?? this.alertColors,
      type: type ?? this.type,
      metrics: metrics ?? this.metrics,
      motion: motion ?? this.motion,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KeikaiThemeData &&
        other.condition == condition &&
        other.standbyColors == standbyColors &&
        other.alertColors == alertColors &&
        other.type == type &&
        other.metrics == metrics &&
        other.motion == motion;
  }

  @override
  int get hashCode => Object.hash(condition, standbyColors, alertColors, type, metrics, motion);
}

/// Provides a [KeikaiThemeData] to the subtree and sets the default text style
/// to the body voice in ink.
///
/// `KeikaiApp` inserts one at the root. Insert another to re-theme a region,
/// or use [KkConditionScope] to switch only the condition.
class KeikaiTheme extends StatelessWidget {
  const KeikaiTheme({super.key, required this.data, required this.child});

  final KeikaiThemeData data;
  final Widget child;

  static const KeikaiThemeData _fallback = KeikaiThemeData();

  /// The nearest theme, or the default standby theme when there is none.
  static KeikaiThemeData of(BuildContext context) {
    final _KeikaiThemeScope? scope = context.dependOnInheritedWidgetOfExactType<_KeikaiThemeScope>();
    return scope?.data ?? _fallback;
  }

  /// Whether animations should run here: the theme allows motion and the
  /// platform has not asked for reduced motion.
  ///
  /// The platform asks in one of two ways, and either switches motion off:
  /// "Remove animations" on Android and "Reduce Motion" on iOS. On the web
  /// both stand for `prefers-reduced-motion`.
  static bool motionOf(BuildContext context) {
    if (!of(context).motion.enabled) return false;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return false;
    return !(MediaQuery.maybeReduceMotionOf(context) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return _KeikaiThemeScope(
      data: data,
      child: DefaultTextStyle(
        style: data.type.bodyMd.copyWith(color: data.colors.ink),
        child: child,
      ),
    );
  }
}

class _KeikaiThemeScope extends InheritedWidget {
  const _KeikaiThemeScope({required this.data, required super.child});

  final KeikaiThemeData data;

  @override
  bool updateShouldNotify(_KeikaiThemeScope oldWidget) => oldWidget.data != data;
}

/// Switches the condition for a region: `alert` turns just this subtree red.
///
/// Nothing but the condition changes. The rest of the theme is handed down,
/// and so is the default text style around the region: its size, family,
/// alignment and line limits stay, and its colour follows the condition only
/// where it is the ink of the theme around. A colour that another ancestor
/// chose is kept.
///
/// The region keeps its State when [condition], or the condition around it,
/// switches.
class KkConditionScope extends StatelessWidget {
  const KkConditionScope({super.key, required this.condition, required this.child});

  final KkCondition condition;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData around = KeikaiTheme.of(context);
    final KeikaiThemeData data = around.withCondition(condition);
    final DefaultTextStyle text = DefaultTextStyle.of(context);
    // Text in the ink of the theme around takes the ink of this condition. Any
    // other colour was chosen by an ancestor and stays.
    final Color inkAround = around.colors.ink;
    final Color ink = data.colors.ink;
    final bool reink = ink != inkAround && text.style.color == inkAround;
    // The same wrappers whether or not the condition is already in force: a
    // different widget in this place would rebuild the region from nothing.
    return _KeikaiThemeScope(
      data: data,
      child: DefaultTextStyle(
        style: reink ? text.style.copyWith(color: ink) : text.style,
        textAlign: text.textAlign,
        softWrap: text.softWrap,
        overflow: text.overflow,
        maxLines: text.maxLines,
        textWidthBasis: text.textWidthBasis,
        textHeightBehavior: text.textHeightBehavior,
        child: child,
      ),
    );
  }
}

/// Shorthand: `context.kk.colors.signal`.
extension KeikaiBuildContext on BuildContext {
  /// The ambient [KeikaiThemeData].
  KeikaiThemeData get kk => KeikaiTheme.of(this);
}
