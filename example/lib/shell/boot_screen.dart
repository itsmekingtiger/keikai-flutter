import 'dart:math' as math;

import 'package:keikai/keikai.dart';

import '../model/app_scope.dart';
import '../model/station.dart';
import '../widgets/centered_page.dart';
import '../widgets/live.dart';

/// The start-up screen: the console checks itself line by line, the bar takes
/// a fifth for every check that passes, and the situation board takes over.
/// The button (or Enter) skips it; with motion off it hands over at once.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key, required this.onDone});

  /// Called once, when the boot has finished or was skipped.
  final VoidCallback onDone;

  /// One check at normal speed: its line wipes in, then the bar moves on.
  static const Duration check = Duration(milliseconds: 384);

  /// How long the five checks take, the last sweep of the bar included.
  static const Duration duration = Duration(milliseconds: 2400);

  /// How long the finished bar stays before the board takes over.
  static const Duration hold = Duration(milliseconds: 300);

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  bool _done = false;

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    final Station station = context.station;
    final int up = station.sectors.where((Sector s) => s.level != KkLevel.offline).length;
    final List<(String, String)> checks = <(String, String)>[
      ('TOKENS', 'STANDBY · ALERT'),
      ('TYPE', 'DISPLAY · LABEL · MONO · BODY'),
      ('LINK', 'HQ-03 · ${context.settings.node}'),
      ('SECTORS', '${kkFixed(up, digits: 2)} / ${kkFixed(station.sectors.length, digits: 2)} ONLINE'),
      ('CLOCK', formatClock(station.now)),
    ];
    final Duration checking = BootScreen.check * checks.length;
    final Duration whole = BootScreen.duration + BootScreen.hold;
    return CenteredPage(
      builder: (BuildContext context, bool short) => KkColumn(
        gap: short ? 12 : 24,
        shrinkWrap: true,
        cross: KkCrossAlign.start,
        children: <Widget>[
          const KkBoot(
            child: KkHeading(stem: '起動', code: 'KK-BOOT', en: 'keikai console', main: '警戒'),
          ),
          KkColumn(
            shrinkWrap: true,
            children: <Widget>[
              for (int i = 0; i < checks.length; i++)
                KkBoot(
                  delay: BootScreen.check * i,
                  duration: const Duration(milliseconds: 280),
                  stagger: false,
                  // The space between the lines is inside the wipe, so that
                  // it does not cut the feet of the brackets while it runs.
                  child: KkPadding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: KkRow(
                      gap: 12,
                      cross: KkCrossAlign.baseline,
                      children: <Widget>[
                        KkText.num('[ OK ]', size: 12, weight: FontWeight.w600, color: c.nominal),
                        KkBox(
                          width: 72,
                          alignment: Alignment.centerLeft,
                          shrinkWrap: true,
                          child: KkText.en(checks[i].$1, size: 12, spacing: 0.14, color: c.inkDim),
                        ),
                        KkExpanded(child: KkText.num(checks[i].$2, size: 12, color: c.ink)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          // The session key flickers on like a tube and churns for as long
          // as the checks run.
          KkFlicker(
            stagger: false,
            child: KkRow(
              gap: 12,
              cross: KkCrossAlign.baseline,
              children: <Widget>[
                KkText.en('session', size: 12, spacing: 0.14, color: c.inkDim),
                KkScramble(
                  'HQ03-7A91-${kkFixed(station.now.second, digits: 2)}F4',
                  letters: true,
                  duration: checking,
                  steps: 24,
                  style: context.kk.type.mono(13, weight: FontWeight.w600, color: c.signal),
                ),
              ],
            ),
          ),
          // One clock for the whole boot: it moves the bar and, when it
          // runs out (at once with motion off), hands over.
          KkOneShot(
            duration: whole,
            stagger: false,
            onDone: _finish,
            builder: (BuildContext context, Animation<double> progress, bool done, Widget? _) => ListenableBuilder(
              listenable: progress,
              builder: (BuildContext context, Widget? _) {
                final double elapsed = progress.value * whole.inMicroseconds;
                final bool ready = done || elapsed >= BootScreen.duration.inMicroseconds;
                // A fifth for every check that has passed; the bar itself
                // sweeps to each new mark in its own steps.
                final double passed = kkStepDown(math.min(1, elapsed / checking.inMicroseconds), checks.length);
                return KkProgress(
                  cjk: ready ? '完了' : '起動',
                  en: ready ? 'ready' : 'starting',
                  value: done ? 1 : passed,
                  level: ready ? KkLevel.nominal : null,
                );
              },
            ),
          ),
          KkButton(label: 'skip', cjk: '省略', trailingIcon: KkIcons.skip, autofocus: true, onPressed: _finish),
        ],
      ),
    );
  }
}
