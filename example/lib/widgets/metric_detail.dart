import 'dart:math' as math;

import 'package:keikai/keikai.dart';

import '../model/settings.dart';
import '../model/station.dart';
import 'live.dart';

/// Opens the last minute of a metric in a dialog: its trace against the two
/// limits, and the lowest, the mean and the highest value of that minute.
///
/// [pick] finds the metric in the station, so the dialog follows the plant
/// for as long as it is open. A [temperature] is shown in the unit the
/// operator chose.
Future<void> openMetric(BuildContext context, Metric Function(Station station) pick, {bool temperature = false}) {
  return showKkDialog<void>(
    context: context,
    builder: (BuildContext context) => MetricDialog(pick: pick, temperature: temperature),
  );
}

/// The last minute of one metric.
class MetricDialog extends StatelessWidget {
  const MetricDialog({super.key, required this.pick, this.temperature = false});

  final Metric Function(Station station) pick;
  final bool temperature;

  @override
  Widget build(BuildContext context) {
    return Live(
      builder: (BuildContext context, Station station, AppSettings settings) {
        final Metric metric = pick(station);
        double shown(double value) => temperature ? settings.degrees(value) : value;
        String text(double value) => temperature ? settings.temperature(value) : metric.format(value);
        final String unit = temperature ? settings.tempSymbol : metric.unit;

        final List<double> history = metric.history.isEmpty ? <double>[metric.value] : metric.history;
        double low = history.first;
        double high = history.first;
        double sum = 0;
        for (final double value in history) {
          low = math.min(low, value);
          high = math.max(high, value);
          sum += value;
        }
        final double mean = sum / history.length;
        final List<DateTime> times = <DateTime>[
          for (int i = 0; i < history.length; i++) station.now.subtract(Duration(seconds: history.length - 1 - i)),
        ];

        Widget figure(String cjk, String en, double value) => KkStat(
          cjk: cjk,
          en: en,
          value: text(value),
          unit: unit,
          level: metric.levelOf(value),
          showState: false,
          boot: false,
          semanticLabel: '$en ${text(value)} $unit, ${metric.levelOf(value).word}',
        );
        final List<Widget> figures = <Widget>[
          figure('最小', 'lowest', low),
          figure('平均', 'mean', mean),
          figure('最大', 'highest', high),
        ];

        return KkDialog(
          code: metric.code,
          cjk: metric.cjk,
          en: metric.en,
          level: metric.level == KkLevel.critical ? KkLevel.critical : null,
          actions: <Widget>[
            KkButton(label: 'close', cjk: '閉', autofocus: true, onPressed: () => Navigator.of(context).pop()),
          ],
          child: KkColumn(
            gap: 12,
            shrinkWrap: true,
            children: <Widget>[
              KkWrap(
                gap: 8,
                runGap: 8,
                children: <Widget>[
                  KkStatusTag.status(metric.level),
                  KkStatusTag('now ${text(metric.value)} $unit', icon: KkIcons.pulse),
                  KkStatusTag('last ${kkFixed(history.length, digits: 2)} s', icon: KkIcons.clock),
                ],
              ),
              KkTimeSeries(
                frame: false,
                height: 168,
                series: <KkSeries>[
                  KkSeries(
                    name: metric.code,
                    values: <double?>[for (final double value in history) shown(value)],
                    area: true,
                  ),
                ],
                times: times,
                thresholds: <KkThreshold>[
                  KkThreshold(shown(metric.warn), label: 'CAUTION ${text(metric.warn)}'),
                  KkThreshold(shown(metric.crit), level: KkLevel.critical, label: 'CRITICAL ${text(metric.crit)}'),
                ],
                valueFormat: (double value) => '${kkFixed(value, digits: 1, decimals: metric.digits)} $unit',
                boot: false,
                semanticLabel: '${metric.en} over the last minute',
              ),
              // Three across where there is room, one under the other in a
              // narrow dialog.
              KkBreakpoint(
                builder: (BuildContext context, KkWindowClass windowClass, BoxConstraints constraints) {
                  if (constraints.maxWidth < 420) return KkColumn(gap: 8, shrinkWrap: true, children: figures);
                  return KkRow(
                    gap: 8,
                    cross: KkCrossAlign.start,
                    children: <Widget>[for (final Widget f in figures) KkExpanded(child: f)],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
