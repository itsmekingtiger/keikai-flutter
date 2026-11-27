import 'package:keikai/keikai.dart';

import '../model/app_scope.dart';
import '../model/settings.dart';
import '../model/station.dart';
import '../shell/destinations.dart';
import '../widgets/live.dart';
import '../widgets/screen_header.dart';

/// The operator's settings. Every control acts at once: the screen behind it
/// is the preview.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TextEditingController? _callSign;
  TextEditingController? _notes;
  String? _callSignError;

  // A slider takes the keyboard focus when it is pressed, so the arrow keys
  // carry on from where the pointer left it.
  final FocusNode _timeScale = FocusNode(debugLabel: 'time scale');
  final FocusNode _textScale = FocusNode(debugLabel: 'text scale');
  final FocusNode _volume = FocusNode(debugLabel: 'alarm volume');

  @override
  void dispose() {
    _callSign?.dispose();
    _notes?.dispose();
    _timeScale.dispose();
    _textScale.dispose();
    _volume.dispose();
    super.dispose();
  }

  /// A valid call sign is taken at once; an invalid one only shows its error.
  void _onCallSign(AppSettings settings, String text) {
    final String value = text.trim().toUpperCase();
    final String? error = AppSettings.operatorError(value);
    setState(() => _callSignError = error);
    if (error == null) settings.operator = value;
  }

  Future<void> _reset(BuildContext context, AppSettings settings) async {
    final ConsoleNotices notices = context.notices;
    final bool yes = await showKkConfirm(
      context: context,
      code: 'CFG-00',
      cjk: '初期化',
      en: 'reset settings',
      message: '모든 설정을 처음 상태로 되돌립니다. 발전소 상태는 바뀌지 않습니다.',
      confirmLabel: 'reset',
      confirmCjk: '初期化',
      danger: true,
    );
    if (!yes) return;
    settings.reset();
    _callSign?.text = settings.operator;
    _notes?.text = settings.notes;
    if (mounted) setState(() => _callSignError = null);
    notices.show(code: 'CFG', level: KkLevel.nominal, message: 'SETTINGS RESET TO DEFAULTS');
  }

  @override
  Widget build(BuildContext context) {
    return Live(
      builder: (BuildContext context, Station station, AppSettings settings) {
        final KkColors c = context.kk.colors;
        final TextEditingController callSign = _callSign ??= TextEditingController(text: settings.operator);
        final TextEditingController notes = _notes ??= TextEditingController(text: settings.notes);
        final DateTime today = DateTime.utc(station.now.year, station.now.month, station.now.day);

        Widget caption(String cjk, String en, {String? tip}) {
          final Widget label = KkLabel(cjk: cjk, en: en, cjkSize: 14, enSize: 11);
          if (tip == null) return label;
          return KkRow(
            gap: 8,
            shrinkWrap: true,
            children: <Widget>[
              label,
              KkTooltip.rich(
                cjk: cjk,
                en: en,
                body: tip,
                side: KkPopupSide.right,
                child: KkIconButton(
                  icon: KkIcons.info,
                  size: KkIconButtonSize.sm,
                  semanticLabel: 'About $en',
                  onPressed: () {},
                ),
              ),
            ],
          );
        }

        Widget field(Widget label, Widget control) =>
            KkColumn(gap: 8, shrinkWrap: true, cross: KkCrossAlign.start, children: <Widget>[label, control]);

        final Widget operation = KkPanel(
          code: 'OPS',
          cjk: '運用',
          en: 'operation',
          meta: settings.operator,
          child: KkColumn(
            gap: 16,
            shrinkWrap: true,
            children: <Widget>[
              KkTextField(
                controller: callSign,
                cjk: '識別符号',
                en: 'call sign',
                isRequired: true,
                placeholder: 'OP-07',
                icon: KkIcons.user,
                mono: true,
                maxLength: 5,
                error: _callSignError,
                support: 'TWO LETTERS · DASH · TWO DIGITS',
                onChanged: (String text) => _onCallSign(settings, text),
                semanticLabel: 'Call sign',
              ),
              KkSelect<String>(
                cjk: '節点',
                en: 'node',
                value: settings.node,
                onChanged: (String v) => settings.node = v,
                support: 'SHOWN IN THE COMMAND BAR',
                options: <KkSelectOption<String>>[
                  for (int i = 1; i <= 8; i++)
                    KkSelectOption<String>(
                      value: 'NODE ${kkFixed(i, digits: 2)}',
                      label: 'NODE ${kkFixed(i, digits: 2)}',
                      code: i.isEven ? 'AUX' : 'MAIN',
                    ),
                ],
              ),
              field(
                caption('任務', 'duty'),
                KkRadioGroup<Duty>(
                  value: settings.duty,
                  onChanged: (Duty v) => settings.duty = v,
                  direction: Axis.horizontal,
                  semanticLabel: 'Duty',
                  options: const <KkRadioOption<Duty>>[
                    KkRadioOption<Duty>(value: Duty.watch, cjk: '当直', label: 'watch'),
                    KkRadioOption<Duty>(value: Duty.engineer, cjk: '技術', label: 'engineer'),
                    KkRadioOption<Duty>(value: Duty.supervisor, cjk: '監督', label: 'supervisor'),
                  ],
                ),
              ),
              KkTextField(
                controller: notes,
                cjk: '引継',
                en: 'handover notes',
                placeholder: '두 줄 이내로 적는다.',
                maxLines: 3,
                minLines: 3,
                maxLength: 120,
                onChanged: (String text) => settings.notes = text,
                semanticLabel: 'Handover notes',
              ),
            ],
          ),
        );

        final Widget display = KkPanel(
          code: 'DSP',
          cjk: '表示',
          en: 'display',
          meta: KeikaiApp.conditionOf(context).name.toUpperCase(),
          child: KkColumn(
            gap: 16,
            shrinkWrap: true,
            children: <Widget>[
              field(
                caption('状態', 'condition', tip: 'AUTO는 발전소를 따른다. 경보가 위급이거나 확인된 동안만 화면이 붉게 바뀐다.'),
                KkScroll(
                  axis: Axis.horizontal,
                  child: KkSegmented<ConditionMode>(
                    value: settings.conditionMode,
                    onChanged: (ConditionMode v) => settings.conditionMode = v,
                    segments: const <KkSegment<ConditionMode>>[
                      KkSegment<ConditionMode>(value: ConditionMode.auto, cjk: '自動', label: 'auto'),
                      KkSegment<ConditionMode>(value: ConditionMode.standby, cjk: '平時', label: 'standby'),
                      KkSegment<ConditionMode>(value: ConditionMode.alert, cjk: '警報', label: 'alert'),
                    ],
                  ),
                ),
              ),
              // What each condition looks like, whichever one the screen is in.
              const KkRow(
                gap: 8,
                cross: KkCrossAlign.start,
                children: <Widget>[
                  KkExpanded(child: _ConditionSpecimen(condition: KkCondition.standby)),
                  KkExpanded(child: _ConditionSpecimen(condition: KkCondition.alert)),
                ],
              ),
              const KkDivider(code: 'DSP-1', cjk: '動作', en: 'motion and texture'),
              KkWrap(
                gap: 24,
                runGap: 12,
                children: <Widget>[
                  KkSwitch(
                    value: settings.motion,
                    onChanged: (bool v) => settings.motion = v,
                    cjk: '動作',
                    label: 'motion',
                  ),
                  KkSwitch(
                    value: settings.changedDigits,
                    onChanged: settings.motion ? (bool v) => settings.changedDigits = v : null,
                    cjk: '差分',
                    label: 'changed digits only',
                  ),
                  KkSwitch(value: settings.crt, onChanged: (bool v) => settings.crt = v, cjk: '走査', label: 'crt'),
                  KkSwitch(
                    value: settings.dense,
                    onChanged: (bool v) => settings.dense = v,
                    cjk: '密',
                    label: 'dense rows',
                  ),
                ],
              ),
              KkSlider(
                cjk: '時間倍率',
                en: 'time scale',
                unit: '×',
                value: settings.timeScale,
                min: 0.5,
                max: 3,
                divisions: 10,
                fractionDigits: 2,
                enabled: settings.motion,
                focusNode: _timeScale,
                onChangeStart: (double _) => _timeScale.requestFocus(),
                onChanged: settings.motion ? (double v) => settings.timeScale = v : null,
                marks: const <KkSliderMark>[KkSliderMark(0.5, 'FAST'), KkSliderMark(1, '1×'), KkSliderMark(3, 'SLOW')],
              ),
              const KkDivider(code: 'DSP-2', cjk: '文字', en: 'type and units'),
              KkSlider(
                cjk: '文字倍率',
                en: 'text scale',
                unit: '×',
                value: settings.textScale,
                min: 0.9,
                max: 1.3,
                divisions: 8,
                fractionDigits: 2,
                focusNode: _textScale,
                onChangeStart: (double _) => _textScale.requestFocus(),
                onChanged: (double v) => settings.textScale = v,
                marks: const <KkSliderMark>[KkSliderMark(0.9), KkSliderMark(1), KkSliderMark(1.3)],
              ),
              KkCheckbox(
                value: settings.glitch,
                onChanged: (bool? v) => settings.glitch = v ?? false,
                cjk: '閃光',
                label: 'glitch and flash on alert',
              ),
              field(
                caption('温度単位', 'temperature unit'),
                KkRadioGroup<TempUnit>(
                  value: settings.tempUnit,
                  onChanged: (TempUnit v) => settings.tempUnit = v,
                  direction: Axis.horizontal,
                  semanticLabel: 'Temperature unit',
                  options: const <KkRadioOption<TempUnit>>[
                    KkRadioOption<TempUnit>(value: TempUnit.celsius, label: 'celsius °C'),
                    KkRadioOption<TempUnit>(value: TempUnit.fahrenheit, label: 'fahrenheit °F'),
                  ],
                ),
              ),
            ],
          ),
        );

        final int wanted = settings.notify.length;
        final Widget notify = KkPanel(
          code: 'NTF',
          cjk: '通知',
          en: 'notify',
          meta: '${kkFixed(wanted, digits: 2)} / 04',
          child: KkColumn(
            gap: 16,
            shrinkWrap: true,
            cross: KkCrossAlign.start,
            children: <Widget>[
              KkCheckbox(
                value: wanted == KkLevel.values.length ? true : (wanted == 0 ? false : null),
                tristate: true,
                onChanged: (bool? _) => settings.setNotifyAll(on: wanted != KkLevel.values.length),
                cjk: '全水準',
                label: 'every level',
              ),
              KkPadding(
                padding: const EdgeInsets.only(left: 24),
                child: KkWrap(
                  gap: 24,
                  runGap: 12,
                  children: <Widget>[
                    for (final KkLevel level in KkLevel.values)
                      KkCheckbox(
                        value: settings.notify.contains(level),
                        onChanged: (bool? v) => settings.setNotify(level, on: v ?? false),
                        cjk: level.cjk,
                        label: level.word,
                      ),
                  ],
                ),
              ),
              KkSlider(
                cjk: '音量',
                en: 'alarm volume',
                unit: '%',
                value: settings.volume,
                divisions: 20,
                focusNode: _volume,
                onChangeStart: (double _) => _volume.requestFocus(),
                onChanged: (double v) => settings.volume = v,
                marks: const <KkSliderMark>[KkSliderMark(0), KkSliderMark(50), KkSliderMark(100)],
              ),
              // At the right of the panel: the snackbar it raises comes up
              // at the left and leaves the button free for another press.
              KkAlignSelf(
                align: KkCrossAlign.end,
                child: KkButton(
                  label: 'test',
                  cjk: '試験',
                  icon: KkIcons.bell,
                  onPressed: () => context.notices.show(
                    code: 'TEST',
                    level: KkLevel.caution,
                    message: 'NOTIFICATION TEST · VOLUME ${kkFixed(settings.volume, digits: 3)} %',
                  ),
                ),
              ),
            ],
          ),
        );

        final Widget maintenance = KkPanel(
          code: 'MNT',
          cjk: '保守',
          en: 'maintenance',
          meta: kkFormatDate(settings.maintenance),
          child: KkWrap(
            gap: 24,
            runGap: 16,
            cross: KkCrossAlign.start,
            children: <Widget>[
              KkDatePicker(
                value: settings.maintenance,
                onChanged: (DateTime d) => settings.maintenance = d,
                today: today,
                firstDate: today,
                caption: 'window',
                semanticLabel: 'Maintenance date',
              ),
              KkTimePicker(
                value: settings.shiftStart,
                onChanged: (KkTime t) => settings.shiftStart = t,
                cjk: '交代',
                en: 'shift start',
                minuteStep: 15,
                semanticLabel: 'Shift start',
              ),
            ],
          ),
        );

        return KkColumn(
          gap: 16,
          shrinkWrap: true,
          children: <Widget>[
            ScreenHeader(
              destination: Destination.settings,
              note: '바꾸는 즉시 화면 전체에 적용된다. 조작자 부호와 절점은 위쪽 지휘 띠에 나타난다.',
              actions: <Widget>[
                KkStatusTag(settings.motion ? 'motion on' : 'motion off', size: KkStatusTagSize.lg, color: c.inkDim),
                KkButton(
                  label: 'reset',
                  cjk: '初期化',
                  icon: KkIcons.undo,
                  variant: KkButtonVariant.danger,
                  onPressed: () => _reset(context, settings),
                ),
              ],
            ),
            KkBreakpoint(
              builder: (BuildContext context, KkWindowClass windowClass, BoxConstraints constraints) {
                if (windowClass.isBelow(KkWindowClass.expanded)) {
                  return KkColumn(
                    gap: 16,
                    shrinkWrap: true,
                    children: <Widget>[operation, display, notify, maintenance],
                  );
                }
                return KkRow(
                  gap: 16,
                  cross: KkCrossAlign.start,
                  children: <Widget>[
                    KkExpanded(child: KkColumn(gap: 16, shrinkWrap: true, children: <Widget>[operation, notify])),
                    KkExpanded(child: KkColumn(gap: 16, shrinkWrap: true, children: <Widget>[display, maintenance])),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// A small specimen of one condition: its name and its main colours, drawn
/// under that condition whatever the screen around it is in.
class _ConditionSpecimen extends StatelessWidget {
  const _ConditionSpecimen({required this.condition});

  final KkCondition condition;

  @override
  Widget build(BuildContext context) {
    final bool current = KeikaiApp.conditionOf(context) == condition;
    final bool alert = condition == KkCondition.alert;
    return KkConditionScope(
      condition: condition,
      child: Builder(
        builder: (BuildContext context) {
          final KkColors c = context.kk.colors;
          return Semantics(
            label: '${condition.name} condition${current ? ', on screen now' : ''}',
            child: ExcludeSemantics(
              child: KkBox(
                decoration: KkDecoration(fill: c.bg000, edges: KkEdges.line(current ? c.signal : c.line)),
                padding: const EdgeInsets.all(8),
                child: KkColumn(
                  gap: 8,
                  shrinkWrap: true,
                  children: <Widget>[
                    KkRow(
                      gap: 6,
                      cross: KkCrossAlign.baseline,
                      children: <Widget>[
                        KkText.cjk(alert ? '警報' : '平時', size: 14, color: c.signal),
                        KkExpanded(child: KkText.en(condition.name, size: 10, spacing: 0.14, color: c.inkDim)),
                        if (current)
                          KkText.en('now', size: 10, weight: FontWeight.w600, spacing: 0.14, color: c.signal),
                      ],
                    ),
                    KkRow(
                      gap: 4,
                      children: <Widget>[
                        for (final Color colour in <Color>[c.bg200, c.line, c.signalDim, c.signal, c.ink])
                          KkExpanded(child: KkBox(height: 12, fill: colour)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
