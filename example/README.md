# KEIKAI 管制 · HQ-03

The example application of the `keikai` package: the operations console of a
small plant, built with KEIKAI widgets only. There is no Material and no
Cupertino in it, and nothing drawn by hand; `test/example_keikai_only_test.dart`
in the package fails as soon as a `Row`, a `Text` or a `Stack` shows up here.

## Run it

```bash
cd example
flutter run -d chrome
```

Any device works: the console lays itself out for a phone (a bar of
destinations at the bottom, lists in place of tables), a tablet, a laptop and a
wall display.

The plant is simulated (`lib/model/station.dart`): it ticks once a second,
and a scripted coolant incident takes it from caution through a full-screen
alarm and a six-step recovery back to standby. Start it with **D** (or the
DRILL button), answer the alarm with **Enter**, then work through the steps on
the procedure screen.

## Screens

| key | address | screen | what it shows |
| --- | --- | --- | --- |
| 1 | `/` | 状況 Situation | the live board: key figures (press one for its last minute), charts, the sector matrix, the alarm wall, the log |
| 2 | `/systems` | 系統 Systems | the sectors as a data table: sort, filter, select and act on several, open a row's detail, edit a load limit in place; the sensor channels; the camera feeds |
| 3 | `/diagram` | 線図 Diagram | the coolant loop and the power grid as node graphs in four layouts, a sequence diagram, and a diagram written as text |
| 4 | `/procedure` | 手順 Procedure | the recovery steps, the go / no-go vote, the timers, the emergency stop |
| 5 | `/log` | 記録 Log | every line the plant wrote, by time range, text and level |
| 6 | `/settings` | 設定 Settings | operator, condition, motion, text size, units, notifications, maintenance |
| 7 | `/catalogue` | 目録 Catalogue | every widget of the language, family by family |

An address that names no screen gets the no-route page; the browser's Back
button works; the console starts with a boot screen that can be skipped.

## Keys

| key | does |
| --- | --- |
| 1 – 7 | go to a screen |
| M | open the drawer |
| D | start the drill |
| A | acknowledge the sounding alarms |
| P | run / pause the plant |
| ? | list the keys |
| Tab, Enter, Space, Esc | move, press, close |

## Where things are

```
lib/
  main.dart                 runApp
  app.dart                  KeikaiApp, routes, the frame around the pages
  model/                    the plant (Station), the settings, the scope that hands them down
  shell/                    command bar, rail, drawer, toolbar, keys; boot and no-route pages
  screens/                  the seven screens
  widgets/                  parts several screens share: header, sector sheet, metric dialog, alarm band
  sheets/                   the catalogue sheets, one per widget family
```

The tests of the app are in the package, under `test/example/`: every screen
at four window sizes in both conditions, with motion on and off, one journey
through a whole incident, and golden images of every screen.
