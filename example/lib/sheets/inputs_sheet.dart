import 'package:keikai/keikai.dart';
// ignore: implementation_imports
import 'package:keikai/src/controls/controls.dart';
// ignore: implementation_imports
import 'package:keikai/src/inputs/inputs.dart';

import 'sheet_scaffold.dart';

void _ignoreText(String value) {}
void _ignoreDate(DateTime value) {}
void _ignoreTime(KkTime value) {}
void _ignoreBool(bool value) {}
void _ignore() {}

const List<KkSelectOption<String>> _sectors = <KkSelectOption<String>>[
  KkSelectOption<String>(value: 'SEC-01', label: 'Power', cjk: '電源', code: 'SEC-01'),
  KkSelectOption<String>(value: 'SEC-04', label: 'Coolant', cjk: '冷却', code: 'SEC-04'),
  KkSelectOption<String>(value: 'SEC-07', label: 'Comms', cjk: '通信', code: 'SEC-07'),
  KkSelectOption<String>(value: 'SEC-09', label: 'Control', cjk: '制御', code: 'SEC-09'),
  KkSelectOption<String>(value: 'SEC-12', label: 'Spare', cjk: '予備', code: 'SEC-12', enabled: false),
];

const List<KkSelectOption<int>> _presets = <KkSelectOption<int>>[
  KkSelectOption<int>(value: 15, label: 'LAST 15 MIN'),
  KkSelectOption<int>(value: 60, label: 'LAST 1 H'),
  KkSelectOption<int>(value: 360, label: 'LAST 6 H'),
  KkSelectOption<int>(value: 1440, label: 'LAST 24 H'),
];

const List<KkMenuEntry<String>> _actions = <KkMenuEntry<String>>[
  KkMenuLabel<String>('sector SEC-04'),
  KkMenuItem<String>(value: 'ack', label: 'acknowledge', cjk: '確認', icon: KkIcons.check, shortcut: 'CTRL+K'),
  KkMenuItem<String>(value: 'trend', label: 'open trend', cjk: '推移', icon: KkIcons.chartLine, shortcut: 'T'),
  KkMenuItem<String>(value: 'mute', label: 'mute alarm', checked: true),
  KkMenuItem<String>(value: 'pin', label: 'pin to board', checked: false),
  KkMenuItem<String>(value: 'export', label: 'export log', icon: KkIcons.download, enabled: false),
  KkMenuSeparator<String>(),
  KkMenuItem<String>(value: 'trip', label: 'trip breaker', cjk: '遮断', icon: KkIcons.power, danger: true),
];

/// The inputs of KEIKAI: text fields, select, search, menus, tooltips, the
/// date and time pickers and the time-range bar.
class InputsSheet extends StatelessWidget {
  const InputsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const SheetScaffold(
      code: 'F-03',
      cjk: '入力',
      en: 'inputs',
      note: '조작 요소의 테두리는 평시에 흐린 잉크, 포커스에서 신호색이 되고 네 귀퉁이에 브래킷이 붙는다. 겹침면은 페이드 없이 와이프로 열린다.',
      sections: <Widget>[
        SheetSection(code: 'I-01', cjk: '文字入力', en: 'text field', child: _Fields()),
        SheetSection(code: 'I-02', cjk: '選択', en: 'select', child: _Selects()),
        SheetSection(code: 'I-03', cjk: '検索', en: 'search', child: _Searches()),
        SheetSection(code: 'I-04', cjk: '指令', en: 'menu', child: _Menus()),
        SheetSection(code: 'I-05', cjk: '注記', en: 'tooltip', child: _Tooltips()),
        SheetSection(code: 'I-06', cjk: '日付', en: 'date picker', child: _Dates()),
        SheetSection(code: 'I-07', cjk: '時刻', en: 'time picker · time range', child: _Times()),
      ],
    );
  }
}

// ── text field ────────────────────────────────────────────────────────────

class _Fields extends StatelessWidget {
  const _Fields();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkWrap(
      gap: 24,
      runGap: 28,
      cross: KkCrossAlign.start,
      children: <Widget>[
        const SheetItem(
          caption: 'idle · placeholder · support',
          width: 320,
          child: KkTextField(cjk: '識別符号', en: 'call sign', placeholder: 'SEC-04', support: 'SECTOR CODE · 6 CHARS'),
        ),
        const SheetItem(
          caption: 'filled · icon · suffix · mono',
          width: 320,
          child: KkTextField(
            cjk: '冷却水圧',
            en: 'coolant pressure',
            icon: KkIcons.gauge,
            suffix: 'kPa',
            mono: true,
            initialValue: '256',
          ),
        ),
        const SheetItem(
          caption: 'hover',
          width: 320,
          child: KkStateOverride(
            hovered: true,
            child: KkTextField(cjk: '回線', en: 'channel', prefix: 'CH.', mono: true, initialValue: '12'),
          ),
        ),
        const SheetItem(
          caption: 'focus · brackets + inner ring',
          width: 320,
          child: KkStateOverride(
            focused: true,
            child: KkTextField(cjk: '担当', en: 'operator', isRequired: true, mono: true, initialValue: 'OP-07'),
          ),
        ),
        const SheetItem(
          caption: 'error',
          width: 320,
          child: KkTextField(
            cjk: '設定圧',
            en: 'set point',
            suffix: 'kPa',
            mono: true,
            initialValue: '096',
            error: 'BELOW LIMIT 120 kPa',
          ),
        ),
        const SheetItem(
          caption: 'error · focus',
          width: 320,
          child: KkStateOverride(
            focused: true,
            child: KkTextField(
              cjk: '設定圧',
              en: 'set point',
              suffix: 'kPa',
              mono: true,
              initialValue: '096',
              error: 'BELOW LIMIT 120 kPa',
            ),
          ),
        ),
        const SheetItem(
          caption: 'disabled',
          width: 320,
          child: KkTextField(
            cjk: '母線',
            en: 'sensor bus',
            initialValue: 'SENSOR BUS B',
            enabled: false,
            support: 'LOCKED BY OP-01',
          ),
        ),
        const SheetItem(
          caption: 'required · counter',
          width: 320,
          child: KkTextField(
            cjk: '符号',
            en: 'node code',
            isRequired: true,
            mono: true,
            maxLength: 12,
            initialValue: 'N-07',
            support: 'A-Z 0-9 -',
          ),
        ),
        const SheetItem(
          caption: 'obscured',
          width: 320,
          child: KkTextField(cjk: '認証', en: 'access key', icon: KkIcons.key, obscureText: true, initialValue: '0x3F7A21C4'),
        ),
        const SheetItem(
          caption: 'multiline · counter',
          width: 320,
          child: KkTextField(
            cjk: '所見',
            en: 'remarks',
            maxLines: null,
            maxLength: 120,
            initialValue: '냉각수 압력이 기준치 아래로 떨어졌습니다.\n보조 펌프를 기동하십시오.',
          ),
        ),
        const SheetItem(
          caption: 'multiline · empty',
          width: 320,
          child: KkTextField(cjk: '引継', en: 'handover', maxLines: null, placeholder: '두 줄 이내로 적는다.'),
        ),
        SheetItem(
          caption: 'KkTextInput · bare, in your own chrome',
          width: 320,
          child: KkBox(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: KkDecoration(fill: c.bg000, edges: KkEdges.line(c.inkFaint)),
            child: KkRow(
              gap: 6,
              children: <Widget>[
                KkIcon(KkIcons.filter, size: 12, color: c.inkDim),
                KkExpanded(
                  child: KkTextInput(
                    placeholder: 'FILTER',
                    style: context.kk.type.mono(12, weight: FontWeight.w500, spacingEm: 0.04),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── select ────────────────────────────────────────────────────────────────

class _Selects extends StatelessWidget {
  const _Selects();

  @override
  Widget build(BuildContext context) {
    return const KkWrap(
      gap: 24,
      runGap: 28,
      cross: KkCrossAlign.start,
      children: <Widget>[
        SheetItem(
          caption: 'empty · placeholder',
          width: 320,
          child: KkSelect<String>(
            cjk: '区画',
            en: 'sector',
            placeholder: 'SELECT SECTOR',
            options: _sectors,
            onChanged: _ignoreText,
          ),
        ),
        SheetItem(
          caption: 'chosen',
          width: 320,
          child: KkSelect<String>(
            cjk: '区画',
            en: 'sector',
            options: _sectors,
            value: 'SEC-04',
            onChanged: _ignoreText,
            support: 'OWNER OP-07',
          ),
        ),
        SheetItem(
          caption: 'open · the list is as wide as the field',
          width: 320,
          child: KkBox(
            height: 256,
            alignment: Alignment.topLeft,
            child: KkSelect<String>(
              cjk: '区画',
              en: 'sector',
              isRequired: true,
              options: _sectors,
              value: 'SEC-04',
              onChanged: _ignoreText,
              initiallyOpen: true,
            ),
          ),
        ),
        SheetItem(
          caption: 'error',
          width: 320,
          child: KkSelect<String>(
            cjk: '区画',
            en: 'sector',
            placeholder: 'SELECT SECTOR',
            options: _sectors,
            onChanged: _ignoreText,
            error: 'SECTOR REQUIRED',
          ),
        ),
        SheetItem(
          caption: 'disabled',
          width: 320,
          child: KkSelect<String>(cjk: '区画', en: 'sector', options: _sectors, value: 'SEC-01', enabled: false),
        ),
        SheetItem(
          caption: 'sm 32 · inline',
          child: KkSelect<int>(size: KkSelectSize.sm, options: _presets, value: 60, onChanged: _ignoreInt),
        ),
        SheetItem(
          caption: 'xs 24 · inline',
          child: KkSelect<int>(size: KkSelectSize.xs, options: _pageSizes, value: 25, onChanged: _ignoreInt),
        ),
      ],
    );
  }
}

void _ignoreInt(int value) {}

const List<KkSelectOption<int>> _pageSizes = <KkSelectOption<int>>[
  KkSelectOption<int>(value: 10, label: '10'),
  KkSelectOption<int>(value: 25, label: '25'),
  KkSelectOption<int>(value: 50, label: '50'),
];

// ── search ────────────────────────────────────────────────────────────────

const List<KkSearchResult<String>> _hits = <KkSearchResult<String>>[
  KkSearchResult<String>(value: 'SEC-04', code: 'SEC-04', title: 'COOLANT LOOP A', meta: 'SECTOR'),
  KkSearchResult<String>(value: 'P-01', code: 'P-01', title: 'COOLANT PRESSURE', meta: 'METRIC'),
  KkSearchResult<String>(value: 'T-01', code: 'T-01', title: 'COOLANT TEMP', meta: 'METRIC'),
  KkSearchResult<String>(value: 'V-17', code: 'V-17', title: 'COOLANT RETURN VALVE', meta: 'OFFLINE', enabled: false),
];

class _Searches extends StatelessWidget {
  const _Searches();

  @override
  Widget build(BuildContext context) {
    return const KkWrap(
      gap: 24,
      runGap: 28,
      cross: KkCrossAlign.start,
      children: <Widget>[
        SheetItem(
          caption: 'empty · key hint',
          width: 400,
          child: KkSearch<String>(placeholder: 'SECTOR, NODE, CHANNEL', hint: 'CTRL+K'),
        ),
        SheetItem(
          caption: 'focus',
          width: 400,
          child: KkStateOverride(
            focused: true,
            child: KkSearch<String>(initialQuery: 'SEC-0', hint: 'ESC', open: false),
          ),
        ),
        SheetItem(caption: 'disabled', width: 400, child: KkSearch<String>(placeholder: 'LINK DOWN', enabled: false)),
        SheetItem(
          caption: 'results · match marked, first row selected',
          width: 400,
          child: KkBox(
            height: 196,
            alignment: Alignment.topLeft,
            child: KkSearch<String>(initialQuery: 'cool', hint: 'ESC', results: _hits, open: true),
          ),
        ),
        SheetItem(
          caption: 'no match',
          width: 400,
          child: KkBox(
            height: 196,
            alignment: Alignment.topLeft,
            child: KkSearch<String>(initialQuery: 'reactor', open: true),
          ),
        ),
      ],
    );
  }
}

// ── menu ──────────────────────────────────────────────────────────────────

class _Menus extends StatelessWidget {
  const _Menus();

  @override
  Widget build(BuildContext context) {
    return KkWrap(
      gap: 24,
      runGap: 28,
      cross: KkCrossAlign.start,
      children: <Widget>[
        const SheetItem(
          caption: 'KkMenu · label, icons, key hints, checked, disabled, danger',
          child: KkMenu<String>(entries: _actions),
        ),
        const SheetItem(
          caption: 'highlighted row',
          child: KkMenu<String>(entries: _actions, initialValue: 'trend'),
        ),
        const SheetItem(
          caption: 'highlighted danger row',
          child: KkMenu<String>(entries: _actions, initialValue: 'trip'),
        ),
        SheetItem(
          caption: 'KkMenuAnchor · open under its trigger',
          child: KkBox(
            width: 280,
            height: 296,
            alignment: Alignment.topLeft,
            child: KkMenuAnchor<String>(
              entries: _actions,
              initiallyOpen: true,
              takeFocus: false,
              builder: (BuildContext context, KkMenuController menu) =>
                  KkButton(label: 'actions', trailingIcon: KkIcons.chevronDown, onPressed: menu.toggle),
            ),
          ),
        ),
      ],
    );
  }
}

// ── tooltip ───────────────────────────────────────────────────────────────

class _Tooltips extends StatelessWidget {
  const _Tooltips();

  @override
  Widget build(BuildContext context) {
    Widget stage(
      String caption,
      Widget child, {
      double width = 200,
      double height = 112,
      Alignment alignment = Alignment.center,
      EdgeInsets padding = EdgeInsets.zero,
    }) => SheetItem(
      caption: caption,
      child: KkBox(
        width: width,
        height: height,
        alignment: alignment,
        padding: padding,
        edges: KkEdges.line(context.kk.colors.bg200, dashed: true),
        child: child,
      ),
    );
    return KkWrap(
      gap: 24,
      runGap: 28,
      cross: KkCrossAlign.start,
      children: <Widget>[
        stage(
          'top',
          const KkTooltip(
            message: 'ACKNOWLEDGE · CTRL+K',
            open: true,
            child: KkIconButton(icon: KkIcons.check, variant: KkIconButtonVariant.outline, onPressed: _ignore),
          ),
        ),
        stage(
          'bottom',
          const KkTooltip(
            message: 'REFRESH · 14:02:31Z',
            side: KkPopupSide.below,
            open: true,
            child: KkIconButton(icon: KkIcons.refresh, variant: KkIconButtonVariant.outline, onPressed: _ignore),
          ),
        ),
        stage(
          'left',
          const KkTooltip(
            message: 'MUTED',
            side: KkPopupSide.left,
            open: true,
            child: KkIconButton(icon: KkIcons.bellOff, variant: KkIconButtonVariant.outline, onPressed: _ignore),
          ),
        ),
        stage(
          'right',
          const KkTooltip(
            message: 'LOCKED BY OP-01',
            side: KkPopupSide.right,
            open: true,
            child: KkIconButton(icon: KkIcons.lock, variant: KkIconButtonVariant.outline, onPressed: _ignore),
          ),
        ),
        stage(
          'rich · title, body, action',
          const KkTooltip.rich(
            cjk: '冷却水圧',
            en: 'coolant pressure',
            body: '기준치 120 kPa 아래로 떨어지면 경보가 울립니다. 현재 256 kPa.',
            side: KkPopupSide.below,
            open: true,
            action: KkButton(label: 'open trend', size: KkButtonSize.sm, onPressed: _ignore),
            child: KkStatusTag('P-01', level: KkLevel.nominal),
          ),
          width: 296,
          height: 192,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 16),
        ),
      ],
    );
  }
}

// ── date ──────────────────────────────────────────────────────────────────

bool _noSundays(DateTime day) => day.weekday != DateTime.sunday;

class _Dates extends StatelessWidget {
  const _Dates();

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.utc(2026, 11, 24);
    return KkWrap(
      gap: 24,
      runGap: 28,
      cross: KkCrossAlign.start,
      children: <Widget>[
        SheetItem(
          caption: 'chosen 18 · today 24 outlined · ISO weeks',
          child: KkDatePicker(value: DateTime.utc(2026, 11, 18), today: today, onChanged: _ignoreDate),
        ),
        SheetItem(
          caption: 'limits 09–27, no Sundays · struck through',
          child: KkDatePicker(
            today: today,
            firstDate: DateTime.utc(2026, 11, 9),
            lastDate: DateTime.utc(2026, 11, 27),
            selectableDayPredicate: _noSundays,
            onChanged: _ignoreDate,
            caption: 'check',
            footer: const KkButton(label: 'clear', size: KkButtonSize.sm, variant: KkButtonVariant.ghost, onPressed: _ignore),
          ),
        ),
        SheetItem(
          caption: 'no week numbers · year boundary',
          child: KkDatePicker(
            value: DateTime.utc(2027, 1, 1),
            today: today,
            onChanged: _ignoreDate,
            showWeekNumbers: false,
            showTodayButton: false,
          ),
        ),
        SheetItem(
          caption: 'disabled',
          child: KkDatePicker(value: DateTime.utc(2026, 11, 18), today: today, enabled: false),
        ),
      ],
    );
  }
}

// ── time ──────────────────────────────────────────────────────────────────

class _Times extends StatelessWidget {
  const _Times();

  @override
  Widget build(BuildContext context) {
    final DateTime start = DateTime.utc(2026, 11, 24, 14);
    final DateTime end = DateTime.utc(2026, 11, 24, 15);
    return KkColumn(
      gap: 28,
      shrinkWrap: true,
      cross: KkCrossAlign.start,
      children: <Widget>[
        const KkWrap(
          gap: 24,
          runGap: 28,
          cross: KkCrossAlign.start,
          children: <Widget>[
            SheetItem(
              caption: 'HH : MM',
              child: KkTimePicker(value: KkTime(14, 2), cjk: '開始', en: 'start', onChanged: _ignoreTime),
            ),
            SheetItem(
              caption: 'HH : MM : SS',
              child: KkTimePicker(
                value: KkTime(4, 59, 8),
                cjk: '猶予',
                en: 'hold',
                showSeconds: true,
                onChanged: _ignoreTime,
              ),
            ),
            SheetItem(
              caption: 'disabled',
              child: KkTimePicker(value: KkTime(23, 45), cjk: '締切', en: 'cut-off', enabled: false),
            ),
            SheetItem(
              caption: 'frameless · no head',
              child: KkTimePicker(value: KkTime(9, 0), zone: null, frame: false, onChanged: _ignoreTime),
            ),
          ],
        ),
        KkWrap(
          gap: 24,
          runGap: 28,
          cross: KkCrossAlign.start,
          children: <Widget>[
            SheetItem(
              caption: 'KkTimeRange · range only',
              child: KkTimeRange<int>(start: start, end: end),
            ),
            SheetItem(
              caption: 'live off · presets · refresh',
              child: KkTimeRange<int>(
                start: start,
                end: end,
                onLiveChanged: _ignoreBool,
                presets: _presets,
                preset: 60,
                onPresetChanged: _ignoreInt,
                onRefresh: _ignore,
              ),
            ),
            SheetItem(
              caption: 'live on · lamp blinks every 1s',
              child: KkTimeRange<int>(
                start: start,
                end: end,
                live: true,
                onLiveChanged: _ignoreBool,
                presets: _presets,
                preset: 15,
                onPresetChanged: _ignoreInt,
                onRefresh: _ignore,
              ),
            ),
            SheetItem(
              caption: 'disabled',
              child: KkTimeRange<int>(
                start: start,
                end: end,
                live: true,
                onLiveChanged: _ignoreBool,
                presets: _presets,
                preset: 60,
                onPresetChanged: _ignoreInt,
                onRefresh: _ignore,
                enabled: false,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
