import 'package:keikai/keikai.dart';

import '../model/app_scope.dart';
import '../model/station.dart';
import '../shell/destinations.dart';
import 'live.dart';

/// The alarm band: for as long as an incident lasts, a thin band under the
/// command bar keeps saying what is wrong, and leads to the procedure when
/// pressed. The board and the procedure say it themselves and go without.
class IncidentBand extends StatelessWidget {
  const IncidentBand({super.key});

  @override
  Widget build(BuildContext context) {
    final Station station = context.station;
    return ValueListenableBuilder<IncidentPhase>(
      valueListenable: station.phaseSignal,
      builder: (BuildContext context, IncidentPhase phase, Widget? _) {
        if (phase == IncidentPhase.none) return const KkBox();
        final KkColors c = context.kk.colors;
        final ({String cjk, String en, KkLevel? level}) words = phaseWords(phase);
        final Color fill = c.level(words.level);
        final bool compact = KkWindowScope.of(context) == KkWindowClass.compact;
        final String headline = incidentHeadline(station);
        // What matters comes first: with motion off the band stands still.
        final String text = '$headline · SEC-04 · ${station.incidentCode}'.toUpperCase();
        // The band grows from the left edge when the incident starts.
        return KkGrow(
          stagger: false,
          child: KkPressable(
            semanticLabel: '${station.incidentCode}, $headline. Opens the procedure.',
            excludeSemantics: true,
            onPressed: () => goTo(context, Destination.procedure),
            builder: (BuildContext context, KkStates states) => KkFocusRing(
              visible: states.focused,
              offset: -2,
              child: KkBox(
                height: 28,
                fill: fill,
                child: KkRow(
                  cross: KkCrossAlign.stretch,
                  children: <Widget>[
                    KkBox(
                      fill: c.bg000,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      shrinkWrap: true,
                      child: KkText.cjk(words.cjk, size: 13, color: fill),
                    ),
                    KkExpanded(
                      child: KkCenter(
                        child: KkMarquee(
                          text,
                          gap: 48,
                          style: context.kk.type.mono(12, weight: FontWeight.w600, spacingEm: 0.08, color: c.onFill),
                        ),
                      ),
                    ),
                    KkBox(
                      fill: states.hovered || states.pressed ? c.bg000 : null,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      shrinkWrap: true,
                      child: KkInk(
                        color: states.hovered || states.pressed ? fill : c.onFill,
                        child: KkRow(
                          shrinkWrap: true,
                          gap: 4,
                          children: <Widget>[
                            if (!compact)
                              const KkText.en('procedure', size: 11, weight: FontWeight.w600, spacing: 0.14),
                            const KkIcon(KkIcons.chevronRight, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
