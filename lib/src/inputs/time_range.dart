import 'package:flutter/widgets.dart';

import '../controls/control_style.dart';
import '../controls/icon_button.dart';
import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/wrap.dart';
import '../motion/loops.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/clock.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'select.dart';

/// The time-range bar of a dashboard: the range as text, a LIVE toggle, a
/// preset select and a refresh button.
///
/// Every part is optional: a part without its callback (or, for the presets,
/// without options) is left out, except the range text, which always shows.
class KkTimeRange<T> extends StatefulWidget {
  const KkTimeRange({
    super.key,
    this.start,
    this.end,
    this.text,
    this.onRangePressed,
    this.live = false,
    this.onLiveChanged,
    this.liveLabel = 'live',
    this.presets = const <Never>[],
    this.preset,
    this.onPresetChanged,
    this.presetPlaceholder,
    this.onRefresh,
    this.refreshLabel = 'Refresh',
    this.showSeconds = false,
    this.enabled = true,
  });

  /// Start of the range. Shown as UTC `HH:MMZ`.
  final DateTime? start;

  /// End of the range.
  final DateTime? end;

  /// Replaces the text built from [start] and [end].
  final String? text;

  /// Makes the range text a button (to open a picker, say).
  final VoidCallback? onRangePressed;

  /// Whether the view follows the present.
  final bool live;
  final ValueChanged<bool>? onLiveChanged;
  final String liveLabel;

  /// Preset ranges, such as the last 15 minutes or the last hour.
  final List<KkSelectOption<T>> presets;
  final T? preset;
  final ValueChanged<T>? onPresetChanged;
  final String? presetPlaceholder;

  /// Called by the refresh button, whose icon turns once per press.
  final VoidCallback? onRefresh;
  final String refreshLabel;

  /// Show seconds in the range text.
  final bool showSeconds;
  final bool enabled;

  @override
  State<KkTimeRange<T>> createState() => _KkTimeRangeState<T>();
}

class _KkTimeRangeState<T> extends State<KkTimeRange<T>> {
  int _spins = 0;

  String get _text {
    final String? given = widget.text;
    if (given != null) return given;
    String f(DateTime? t) => t == null ? '--:--' : '${kkFormatTime(t.toUtc(), seconds: widget.showSeconds)}Z';
    return '${f(widget.start)} — ${f(widget.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool enabled = widget.enabled;

    Widget rangeBox(KkStates s) => KkFocusRing(
      visible: s.focused,
      offset: 2,
      width: m.stroke2,
      child: KkBox(
        height: m.space8,
        padding: EdgeInsets.symmetric(horizontal: m.space3),
        decoration: KkDecoration(
          fill: s.hovered ? c.bg300 : c.bg100,
          edges: KkEdges.line(enabled ? c.line : c.offline, width: m.stroke1, dashed: !enabled),
        ),
        child: KkRow(
          shrinkWrap: true,
          gap: 6,
          children: <Widget>[
            KkIcon(KkIcons.calendar, size: 16, color: enabled ? c.signal : c.inkFaint),
            KkText.num(_text, size: 12, weight: FontWeight.w500, color: enabled ? c.ink : c.inkFaint),
          ],
        ),
      ),
    );

    final VoidCallback? onRange = widget.onRangePressed;
    final Widget range = onRange == null
        ? Semantics(label: _text, child: ExcludeSemantics(child: rangeBox(const KkStates())))
        : KkPressable(
            onPressed: onRange,
            enabled: enabled,
            semanticLabel: _text,
            excludeSemantics: true,
            builder: (BuildContext context, KkStates s) => rangeBox(KkStateOverride.resolve(context, s)),
          );

    final ValueChanged<bool>? onLive = widget.onLiveChanged;
    final Widget? live = onLive == null && !widget.live
        ? null
        : KkPressable(
            onPressed: onLive == null ? null : () => onLive(!widget.live),
            enabled: enabled,
            toggled: widget.live,
            semanticLabel: widget.liveLabel,
            excludeSemantics: true,
            builder: (BuildContext context, KkStates raw) {
              final KkStates s = KkStateOverride.resolve(context, raw);
              final bool on = widget.live && enabled;
              final Color ink = !enabled
                  ? c.inkFaint
                  : on
                  ? c.nominal
                  : (s.hovered ? c.ink : c.inkDim);
              final Color edge = !enabled
                  ? c.offline
                  : on
                  ? c.nominal
                  : c.inkFaint;
              return KkFocusRing(
                visible: s.focused,
                offset: 2,
                width: m.stroke2,
                child: KkBox(
                  height: m.space8,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: KkDecoration(
                    fill: c.bg100,
                    edges: KkEdges.line(edge, width: m.stroke1, dashed: !enabled),
                  ),
                  child: KkRow(
                    shrinkWrap: true,
                    gap: 6,
                    children: <Widget>[
                      KkBlink(
                        period: KkMotion.colon,
                        enabled: on,
                        child: KkBox(
                          width: 8,
                          height: 8,
                          decoration: KkDecoration(
                            fill: on ? ink : null,
                            edges: KkEdges.line(ink, width: 1.5),
                          ),
                        ),
                      ),
                      KkText.en(widget.liveLabel, size: 11, spacing: 0.14, color: ink),
                    ],
                  ),
                ),
              );
            },
          );

    final ValueChanged<T>? onPreset = widget.onPresetChanged;
    final Widget? presets = widget.presets.isEmpty
        ? null
        : KkSelect<T>(
            size: KkSelectSize.sm,
            options: widget.presets,
            value: widget.preset,
            placeholder: widget.presetPlaceholder,
            enabled: enabled,
            onChanged: onPreset,
            semanticLabel: 'Range preset',
          );

    final VoidCallback? onRefresh = widget.onRefresh;
    final Widget? refresh = onRefresh == null
        ? null
        : KkIconButton(
            icon: KkIcons.refresh,
            variant: KkIconButtonVariant.outline,
            spinTrigger: _spins,
            enabled: enabled,
            semanticLabel: widget.refreshLabel,
            onPressed: () {
              setState(() => _spins++);
              onRefresh();
            },
          );

    return KkWrap(
      gap: m.space2,
      runGap: m.space2,
      children: <Widget>[range, ?live, ?presets, ?refresh],
    );
  }
}
