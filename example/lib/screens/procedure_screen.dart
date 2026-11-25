import 'package:keikai/keikai.dart';

import '../model/app_scope.dart';
import '../model/settings.dart';
import '../model/station.dart';
import '../shell/console_shell.dart';
import '../shell/destinations.dart';
import '../widgets/live.dart';
import '../widgets/screen_header.dart';

/// The recovery procedure: what to do next, who agrees, and how long it has
/// been.
class ProcedureScreen extends StatefulWidget {
  const ProcedureScreen({super.key});

  @override
  State<ProcedureScreen> createState() => _ProcedureScreenState();
}

class _ProcedureScreenState extends State<ProcedureScreen> {
  final KkTimerController _hold = KkTimerController();

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  /// Carries out the active step, after asking where a mistake would cost.
  Future<void> _advance(BuildContext context, Station station) async {
    final int index = station.procedure.indexWhere((ProcedureStep s) => s.status == StepStatus.active);
    if (index < 0) return;
    final ProcedureStep step = station.procedure[index];
    final ConsoleNotices notices = context.notices;
    if (index == 2 || index == 4) {
      final bool yes = await showKkConfirm(
        context: context,
        code: 'STEP-${kkFixed(index + 1, digits: 2)}',
        cjk: step.cjk,
        en: step.en,
        message: index == 2
            ? '밸브 V-17을 수동으로 닫습니다. 닫은 뒤에는 냉각수가 보조 계통으로만 흐릅니다.'
            : '주 펌프 A를 다시 기동합니다. 압력이 240 kPa 이상인지 확인했습니까?',
        confirmLabel: 'execute',
        confirmCjk: '実行',
      );
      if (!yes) return;
    }
    station.advanceProcedure();
    notices.show(
      code: 'STEP-${kkFixed(index + 1, digits: 2)}',
      level: KkLevel.nominal,
      message: '${step.en.toUpperCase()} COMPLETE',
    );
  }

  Future<void> _emergencyStop(BuildContext context, Station station) async {
    final bool yes = await showKkConfirm(
      context: context,
      code: 'E-0001',
      cjk: '緊急停止',
      en: 'emergency stop',
      message: '주 펌프 A를 즉시 정지합니다. 정지 후에는 수동 재기동 절차가 필요합니다.',
      confirmLabel: 'stop',
      confirmCjk: '停止',
      danger: true,
    );
    if (yes) station.emergencyStop();
  }

  @override
  Widget build(BuildContext context) {
    return Live(
      builder: (BuildContext context, Station station, AppSettings settings) {
        final IncidentPhase phase = station.phase;
        final ({String cjk, String en, KkLevel? level}) words = phaseWords(phase);
        final int active = station.procedure.indexWhere((ProcedureStep s) => s.status == StepStatus.active);
        final int done = station.procedure.where((ProcedureStep s) => s.status == StepStatus.done).length;
        final bool finished = done == station.procedure.length;
        final bool wide = KkWindowScope.of(context).isAtLeast(KkWindowClass.expanded);

        final Widget steps = KkSequence(
          cjk: '復旧手順',
          en: 'recovery procedure',
          level: finished ? KkLevel.nominal : words.level,
          steps: <KkSequenceStep>[
            for (final ProcedureStep s in station.procedure)
              KkSequenceStep(
                cjk: s.cjk,
                en: s.en,
                note: s.note,
                time: s.at == null ? null : formatClock(s.at!),
                status: switch (s.status) {
                  StepStatus.pending => KkStepStatus.pending,
                  StepStatus.active => KkStepStatus.active,
                  StepStatus.done => KkStepStatus.done,
                  StepStatus.failed => KkStepStatus.failed,
                  StepStatus.skipped => KkStepStatus.skipped,
                },
              ),
          ],
        );

        final Widget next = active >= 0
            ? KkButton(
                label: station.procedure[active].en,
                cjk: station.procedure[active].cjk,
                icon: KkIcons.play,
                variant: KkButtonVariant.primary,
                size: KkButtonSize.lg,
                expand: true,
                semanticLabel: 'Execute step ${active + 1}: ${station.procedure[active].en}',
                onPressed: () => _advance(context, station),
              )
            : KkEmpty(
                cjk: finished ? '手順完了' : '待機中',
                en: finished ? 'procedure complete' : 'no active procedure',
                sub: finished
                    ? 'ALL ${station.procedure.length} STEPS DONE · ${phase == IncidentPhase.none ? 'CONDITION STANDBY' : 'PLANT RECOVERING'}'
                    : 'THE PROCEDURE STARTS WITH AN ALARM',
                minHeight: 120,
                action: phase == IncidentPhase.none
                    ? KkButton(
                        label: 'start drill',
                        cjk: '訓練',
                        icon: KkIcons.play,
                        onPressed: () => startDrill(context),
                      )
                    : null,
              );

        final Widget poll = KkConsensus(
          cjk: '可否判定',
          en: 'go / no-go',
          meta: 'RESTART PUMP A',
          voters: <KkVoter>[
            for (final Channel ch in station.channels)
              KkVoter(
                id: ch.id,
                name: ch.name,
                note: ch.note,
                vote: switch (ch.verdict) {
                  Verdict.go => KkVote.go,
                  Verdict.noGo => KkVote.nogo,
                  Verdict.wait => KkVote.wait,
                  Verdict.fault => KkVote.fault,
                },
              ),
          ],
        );

        final Widget elapsed = KkTimer(
          value: station.incidentElapsed,
          progress: (station.incidentElapsed.inSeconds / 120).clamp(0.0, 1.0),
          cjk: '経過',
          en: 'elapsed',
          mode: phase == IncidentPhase.none ? 'IDLE' : station.incidentCode,
          level: words.level,
          format: KkTimerFormat.hours,
        );

        final Widget hold = KkColumn(
          gap: 8,
          shrinkWrap: true,
          children: <Widget>[
            KkTimer.countdown(
              from: const Duration(seconds: 60),
              controller: _hold,
              autostart: false,
              cautionAt: const Duration(seconds: 20),
              criticalAt: const Duration(seconds: 10),
              cjk: '保持',
              en: 'hold',
              mode: 'T-MINUS',
              onDone: () => context.notices.show(code: 'HOLD', level: KkLevel.caution, message: 'HOLD TIME ELAPSED'),
            ),
            ListenableBuilder(
              listenable: _hold,
              builder: (BuildContext context, Widget? _) => KkRow(
                gap: 8,
                children: <Widget>[
                  KkExpanded(
                    child: KkButton(
                      label: _hold.isRunning ? 'stop' : 'start',
                      icon: _hold.isRunning ? KkIcons.pause : KkIcons.play,
                      expand: true,
                      semanticLabel: _hold.isRunning ? 'Stop hold timer' : 'Start hold timer',
                      onPressed: _hold.toggle,
                    ),
                  ),
                  KkExpanded(
                    child: KkButton(
                      label: 'reset',
                      icon: KkIcons.undo,
                      variant: KkButtonVariant.ghost,
                      expand: true,
                      semanticLabel: 'Reset hold timer',
                      onPressed: _hold.reset,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final Widget recovery = KkRow(
          gap: 16,
          children: <Widget>[
            KkRing(
              value: done / station.procedure.length,
              size: 56,
              level: finished ? KkLevel.nominal : words.level,
              label: '${kkFixed(done, digits: 2)}/${kkFixed(station.procedure.length, digits: 2)}',
              semanticLabel: 'Steps done',
            ),
            KkExpanded(
              child: KkProgress(
                cjk: '圧力回復',
                en: 'pressure recovery',
                value: ((station.coolantPressure.value - 96) / (240 - 96)).clamp(0.0, 1.0),
                level: station.coolantPressure.level,
              ),
            ),
          ],
        );

        return KkColumn(
          gap: 16,
          shrinkWrap: true,
          children: <Widget>[
            ScreenHeader(
              destination: Destination.procedure,
              note: '경보가 울리면 여기서 단계를 차례로 실행한다. 위험한 단계는 실행 전에 한 번 더 묻는다.',
              actions: <Widget>[
                KkButton(
                  label: 'reset',
                  cjk: '復帰',
                  icon: KkIcons.undo,
                  onPressed: phase == IncidentPhase.none ? null : () => resetPlant(context),
                ),
                KkFab.extended(
                  label: 'emergency stop',
                  icon: KkIcons.power,
                  variant: KkFabVariant.danger,
                  onPressed: station.alert ? null : () => _emergencyStop(context, station),
                ),
              ],
            ),
            KkModeStrip(
              current: station.mode,
              target: phase == IncidentPhase.caution ? 2 : (phase == IncidentPhase.acknowledged ? 3 : null),
              level: words.level,
              steps: const <KkModeStep>[
                KkModeStep(cjk: '待機', en: 'standby'),
                KkModeStep(cjk: '監視', en: 'monitor'),
                KkModeStep(cjk: '対処', en: 'respond'),
                KkModeStep(cjk: '復旧', en: 'recover'),
              ],
            ),
            if (wide)
              KkRow(
                gap: 16,
                cross: KkCrossAlign.start,
                children: <Widget>[
                  KkExpanded(
                    flex: 3,
                    // What to do now comes first: it is on screen without
                    // scrolling, and clear of the snackbars at the bottom left.
                    child: KkColumn(gap: 16, shrinkWrap: true, children: <Widget>[next, steps, recovery]),
                  ),
                  KkExpanded(
                    flex: 2,
                    child: KkColumn(gap: 16, shrinkWrap: true, children: <Widget>[poll, elapsed, hold]),
                  ),
                ],
              )
            else ...<Widget>[next, steps, recovery, poll, elapsed, hold],
          ],
        );
      },
    );
  }
}
