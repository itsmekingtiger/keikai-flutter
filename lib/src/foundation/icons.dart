import 'package:flutter/foundation.dart';

/// One icon: path data on a 16×16 grid.
///
/// [stroke] is drawn with a 1.5px line, square ends and mitred joins;
/// [fill] is filled (even-odd); [dashed] is stroked with a 2.6 / 1.9 dash.
/// All three take the current text colour.
@immutable
class KkIconData {
  const KkIconData(this.name, {this.stroke = '', this.fill = '', this.dashed = ''});

  final String name;
  final String stroke;
  final String fill;
  final String dashed;

  @override
  bool operator ==(Object other) =>
      other is KkIconData &&
      other.name == name &&
      other.stroke == stroke &&
      other.fill == fill &&
      other.dashed == dashed;

  @override
  int get hashCode => Object.hash(name, stroke, fill, dashed);

  @override
  String toString() => 'KkIconData($name)';
}

/// The KEIKAI icon set: 16px grid, 1.5px line, square ends, straight lines,
/// 45° diagonals and arcs.
///
/// The five `status*` icons are the only ones that may show a level. General
/// icons such as [warning] or [info] never stand in for a status.
abstract final class KkIcons {
  static const String _plate = 'M5 1.75H14.25V14.25H1.75V5Z';
  static const String _ring = 'M13.25 8A5.25 5.25 0 1 1 2.75 8A5.25 5.25 0 1 1 13.25 8Z';
  static const String _lens = 'M11.25 7A4.25 4.25 0 1 1 2.75 7A4.25 4.25 0 1 1 11.25 7Z M10.2 10.2L13.5 13.5';
  static const String _frame = 'M2.75 2.75H13.25V13.25H2.75Z';
  static const String _eyeOutline = 'M1.75 8L4.75 4.75H11.25L14.25 8L11.25 11.25H4.75Z';
  static const String _bellBody = 'M4.25 11.25V7A3.75 3.75 0 0 1 11.75 7V11.25 M2.75 11.5H13.25 M6.75 13.75H9.25';
  static const String _lockBody = 'M3.75 7.25H12.25V13.25H3.75Z';

  // ── status: a plate cut at the top left, with a mark ────────────────────
  static const KkIconData statusNominal = KkIconData('status-nominal', stroke: '$_plate M4.7 8.3l2.3 2.3 4.4-4.7');
  static const KkIconData statusCaution = KkIconData(
    'status-caution',
    stroke: '$_plate M8 4.3v4.9',
    fill: 'M7.1 10.6h1.8v1.8h-1.8z',
  );
  static const KkIconData statusCritical = KkIconData(
    'status-critical',
    fill:
        'M4.5 1H15V15H1V4.5Z M9.80 4.71L11.29 6.20L9.48 8.00L11.29 9.80L9.80 11.29L8.00 9.48'
        'L6.20 11.29L4.71 9.80L6.52 8.00L4.71 6.20L6.20 4.71L8.00 6.52Z',
  );
  static const KkIconData statusOffline = KkIconData('status-offline', stroke: 'M4.9 8h6.2', dashed: _plate);
  static const KkIconData statusInfo = KkIconData(
    'status-info',
    stroke: '$_plate M8 7.2v4.6',
    fill: 'M7.1 4.2h1.8v1.8h-1.8z',
  );

  // ── navigation ──────────────────────────────────────────────────────────
  static const KkIconData menu = KkIconData('menu', stroke: 'M2.75 4.5H13.25 M2.75 8H13.25 M2.75 11.5H13.25');
  static const KkIconData close = KkIconData('close', stroke: 'M4 4L12 12 M12 4L4 12');
  static const KkIconData check = KkIconData('check', stroke: 'M3.25 8.4L6.4 11.5L12.75 4.6');
  static const KkIconData plus = KkIconData('plus', stroke: 'M8 3.25V12.75 M3.25 8H12.75');
  static const KkIconData minus = KkIconData('minus', stroke: 'M3.25 8H12.75');
  static const KkIconData chevronUp = KkIconData('chevron-up', stroke: 'M3.75 10L8 5.75L12.25 10');
  static const KkIconData chevronDown = KkIconData('chevron-down', stroke: 'M3.75 6L8 10.25L12.25 6');
  static const KkIconData chevronLeft = KkIconData('chevron-left', stroke: 'M10 3.75L5.75 8L10 12.25');
  static const KkIconData chevronRight = KkIconData('chevron-right', stroke: 'M6 3.75L10.25 8L6 12.25');
  static const KkIconData arrowUp = KkIconData('arrow-up', stroke: 'M8 13V3.5 M4 7.25L8 3.25L12 7.25');
  static const KkIconData arrowDown = KkIconData('arrow-down', stroke: 'M8 3V12.5 M4 8.75L8 12.75L12 8.75');
  static const KkIconData arrowLeft = KkIconData('arrow-left', stroke: 'M13 8H3.5 M7.25 4L3.25 8L7.25 12');
  static const KkIconData arrowRight = KkIconData('arrow-right', stroke: 'M3 8H12.5 M8.75 4L12.75 8L8.75 12');
  static const KkIconData caretUp = KkIconData('caret-up', fill: 'M4 10.25L8 5.5L12 10.25Z');
  static const KkIconData caretDown = KkIconData('caret-down', fill: 'M4 5.75L8 10.5L12 5.75Z');
  static const KkIconData first = KkIconData('first', stroke: 'M11.5 3.75L7.25 8L11.5 12.25 M4.5 3.25V12.75');
  static const KkIconData last = KkIconData('last', stroke: 'M4.5 3.75L8.75 8L4.5 12.25 M11.5 3.25V12.75');
  static const KkIconData home = KkIconData('home', stroke: 'M2.25 8L8 2.5L13.75 8 M4.25 7V13.25H11.75V7');
  static const KkIconData more = KkIconData('more', fill: 'M2.5 7h2v2h-2z M7 7h2v2H7z M11.5 7h2v2h-2z');
  static const KkIconData moreVertical = KkIconData(
    'more-vertical',
    fill: 'M7 2.5h2v2H7z M7 7h2v2H7z M7 11.5h2v2H7z',
  );
  static const KkIconData grip = KkIconData(
    'grip',
    fill:
        'M5 3h1.75v1.75H5z M9.25 3H11v1.75H9.25z M5 7.1h1.75v1.75H5z M9.25 7.1H11v1.75H9.25z '
        'M5 11.25h1.75V13H5z M9.25 11.25H11V13H9.25z',
  );
  static const KkIconData external = KkIconData(
    'external',
    stroke: 'M6.5 3.5H2.75V13.25H12.5V9.5 M9 2.75H13.25V7 M13.25 2.75L7.5 8.5',
  );
  static const KkIconData undo = KkIconData(
    'undo',
    stroke: 'M6 4L2.75 7.25L6 10.5 M3 7.25H10.25A3 3 0 0 1 10.25 13.25H7',
  );
  static const KkIconData redo = KkIconData(
    'redo',
    stroke: 'M10 4L13.25 7.25L10 10.5 M13 7.25H5.75A3 3 0 0 0 5.75 13.25H9',
  );
  static const KkIconData swap = KkIconData(
    'swap',
    stroke: 'M2.75 5.5H13 M10.25 2.75L13.25 5.5L10.25 8.25 M13.25 10.5H3 M5.75 7.75L2.75 10.5L5.75 13.25',
  );

  // ── actions ─────────────────────────────────────────────────────────────
  static const KkIconData search = KkIconData('search', stroke: _lens);
  static const KkIconData zoomIn = KkIconData('zoom-in', stroke: '$_lens M5 7H9 M7 5V9');
  static const KkIconData zoomOut = KkIconData('zoom-out', stroke: '$_lens M5 7H9');
  static const KkIconData filter = KkIconData('filter', stroke: 'M2.5 3.5H13.5L9.5 8.25V12.75L6.5 11.25V8.25Z');
  static const KkIconData sort = KkIconData(
    'sort',
    stroke: 'M5 12.5V3.5 M2.75 5.75L5 3.5L7.25 5.75 M11 3.5V12.5 M8.75 10.25L11 12.5L13.25 10.25',
  );
  static const KkIconData refresh = KkIconData(
    'refresh',
    stroke: 'M12.33 5.5A5 5 0 1 0 13 8 M12.75 2.25V5.75H9.25',
  );
  static const KkIconData sync = KkIconData(
    'sync',
    stroke:
        'M2.75 7A5.25 5.25 0 0 1 12.5 5.25 M12.75 2.25V5.5H9.5 '
        'M13.25 9A5.25 5.25 0 0 1 3.5 10.75 M3.25 13.75V10.5H6.5',
  );
  static const KkIconData download = KkIconData(
    'download',
    stroke: 'M8 2.75V10.5 M4.5 7.25L8 10.75L11.5 7.25 M2.75 13.25H13.25',
  );
  static const KkIconData upload = KkIconData(
    'upload',
    stroke: 'M8 10.75V3 M4.5 6.25L8 2.75L11.5 6.25 M2.75 13.25H13.25',
  );
  static const KkIconData link = KkIconData(
    'link',
    stroke: 'M6.75 4.75H4.5A3.25 3.25 0 0 0 4.5 11.25H6.75 M9.25 4.75H11.5A3.25 3.25 0 0 1 11.5 11.25H9.25 M5.5 8H10.5',
  );
  static const KkIconData copy = KkIconData(
    'copy',
    stroke: 'M5.75 5.75H13.25V13.25H5.75Z M10.25 5.5V2.75H2.75V10.25H5.5',
  );
  static const KkIconData edit = KkIconData(
    'edit',
    stroke: 'M2.75 13.25V10.5L10.5 2.75L13.25 5.5L5.5 13.25Z M8.75 4.5L11.5 7.25',
  );
  static const KkIconData trash = KkIconData(
    'trash',
    stroke: 'M2.75 4.5H13.25 M6 4.25V2.75H10V4.25 M4.25 4.75V13.25H11.75V4.75 M6.75 7V11 M9.25 7V11',
  );
  static const KkIconData save = KkIconData(
    'save',
    stroke: 'M2.75 2.75H10.75L13.25 5.25V13.25H2.75Z M5.25 2.75V6H9.75V2.75 M5.25 13.25V9.25H10.75V13.25',
  );
  static const KkIconData send = KkIconData('send', stroke: 'M2.25 2.75L14 8L2.25 13.25L4.5 8Z M4.5 8H9');
  static const KkIconData expand = KkIconData(
    'expand',
    stroke: 'M2.75 6V2.75H6 M10 2.75H13.25V6 M13.25 10V13.25H10 M6 13.25H2.75V10',
  );
  static const KkIconData collapse = KkIconData(
    'collapse',
    stroke: 'M6 2.75V6H2.75 M13.25 6H10V2.75 M10 13.25V10H13.25 M2.75 10H6V13.25',
  );
  static const KkIconData fit = KkIconData('fit', stroke: _frame, fill: 'M6.5 6.5h3v3h-3z');
  static const KkIconData play = KkIconData('play', stroke: 'M4.5 2.75L13 8L4.5 13.25Z');
  static const KkIconData pause = KkIconData('pause', stroke: 'M4 3.25H6.5V12.75H4Z M9.5 3.25H12V12.75H9.5Z');
  static const KkIconData stop = KkIconData('stop', stroke: 'M3.75 3.75H12.25V12.25H3.75Z');
  static const KkIconData skip = KkIconData('skip', stroke: 'M3.5 3.25L9.5 8L3.5 12.75Z M12 3.25V12.75');
  static const KkIconData power = KkIconData('power', stroke: 'M8 1.75V7.5 M4.64 4.64A4.75 4.75 0 1 0 11.36 4.64');

  // ── objects ─────────────────────────────────────────────────────────────
  static const KkIconData settings = KkIconData(
    'settings',
    stroke: 'M6 1.75H10L14.25 6V10L10 14.25H6L1.75 10V6Z M6.25 6.25H9.75V9.75H6.25Z',
  );
  static const KkIconData sliders = KkIconData(
    'sliders',
    stroke:
        'M2.75 4.5H8.5 M11.5 4.5H13.25 M2.75 11.5H4.5 M7.5 11.5H13.25 '
        'M8.75 2.75H11.25V6.25H8.75Z M4.75 9.75H7.25V13.25H4.75Z',
  );
  static const KkIconData lock = KkIconData(
    'lock',
    stroke: '$_lockBody M5.5 7V5.25A2.5 2.5 0 0 1 10.5 5.25V7',
    fill: 'M7.25 9.4h1.5v1.8h-1.5z',
  );
  static const KkIconData unlock = KkIconData(
    'unlock',
    stroke: '$_lockBody M5.5 7V5.25A2.5 2.5 0 0 1 10.25 4.2',
    fill: 'M7.25 9.4h1.5v1.8h-1.5z',
  );
  static const KkIconData key = KkIconData(
    'key',
    stroke: 'M7.75 8A2.75 2.75 0 1 1 2.25 8A2.75 2.75 0 1 1 7.75 8Z M7.75 8H14 M11.25 8V10.5 M13.75 8V10',
  );
  static const KkIconData eye = KkIconData('eye', stroke: _eyeOutline, fill: 'M6.75 6.75h2.5v2.5h-2.5z');
  static const KkIconData eyeOff = KkIconData('eye-off', stroke: '$_eyeOutline M2.75 13.25L13.25 2.75');
  static const KkIconData bell = KkIconData('bell', stroke: _bellBody);
  static const KkIconData bellOff = KkIconData('bell-off', stroke: '$_bellBody M2.5 14L13.5 2');
  static const KkIconData user = KkIconData(
    'user',
    stroke: 'M10.5 5.25A2.5 2.5 0 1 1 5.5 5.25A2.5 2.5 0 1 1 10.5 5.25Z M2.75 13.5V12.25L5 10H11L13.25 12.25V13.5',
  );
  static const KkIconData calendar = KkIconData(
    'calendar',
    stroke: 'M2.75 3.75H13.25V13.25H2.75Z M2.75 6.75H13.25 M5.5 2V4.5 M10.5 2V4.5',
  );
  static const KkIconData clock = KkIconData('clock', stroke: '$_ring M8 4.75V8H10.75');
  static const KkIconData pin = KkIconData(
    'pin',
    stroke: 'M8 14.25L3.75 8.5V5.75L6.75 2.75H9.25L12.25 5.75V8.5Z',
    fill: 'M7 5.5h2v2H7z',
  );
  static const KkIconData flag = KkIconData('flag', stroke: 'M3.5 14.25V2.75 M3.75 3H12.75L10.5 6L12.75 9H3.75');
  static const KkIconData bookmark = KkIconData('bookmark', stroke: 'M4.25 2.75H11.75V13.5L8 10.5L4.25 13.5Z');
  static const KkIconData star = KkIconData(
    'star',
    stroke: 'M8 2.4L9.53 6.3L13.71 6.55L10.47 9.2L11.53 13.25L8 11L4.47 13.25L5.53 9.2L2.29 6.55L6.47 6.3Z',
  );
  static const KkIconData file = KkIconData(
    'file',
    stroke: 'M3.75 1.75H9.5L12.25 4.5V14.25H3.75Z M6 7.25H10 M6 9.75H10 M6 12.25H8.5',
  );
  static const KkIconData folder = KkIconData('folder', stroke: 'M1.75 3.75H6L7.5 5.5H14.25V12.75H1.75Z');
  static const KkIconData globe = KkIconData(
    'globe',
    stroke: '$_ring M2.75 8H13.25 M8 2.75L5.75 5.5V10.5L8 13.25L10.25 10.5V5.5Z',
  );
  static const KkIconData shield = KkIconData('shield', stroke: 'M8 1.75L13.25 3.75V8.75L8 14.25L2.75 8.75V3.75Z');
  static const KkIconData hex = KkIconData('hex', stroke: 'M8 1.75L13.5 4.9V11.1L8 14.25L2.5 11.1V4.9Z');
  static const KkIconData square = KkIconData('square', stroke: 'M3.25 3.25H12.75V12.75H3.25Z');
  static const KkIconData dot = KkIconData('dot', fill: 'M6 6h4v4H6z');

  // ── systems ─────────────────────────────────────────────────────────────
  static const KkIconData bolt = KkIconData('bolt', stroke: 'M9.25 1.75L3.75 9H7.75L6.75 14.25L12.25 7H8.25Z');
  static const KkIconData plug = KkIconData(
    'plug',
    stroke: 'M5.5 1.75V5.5 M10.5 1.75V5.5 M3.75 5.75H12.25V8.5L9.75 11H6.25L3.75 8.5Z M8 11V14.25',
  );
  static const KkIconData battery = KkIconData(
    'battery',
    stroke: 'M1.75 4.75H12.25V11.25H1.75Z M12.5 6.5H14.25V9.5H12.5',
    fill: 'M3.5 6.5h2v3h-2z M6.5 6.5h2v3h-2z',
  );
  static const KkIconData signal = KkIconData(
    'signal',
    stroke: 'M3 13.25V10.5 M6.33 13.25V8 M9.67 13.25V5.5 M13 13.25V2.75',
  );
  static const KkIconData radio = KkIconData(
    'radio',
    stroke: 'M8 8.75V14.25 M5.25 9.75A3.9 3.9 0 0 1 5.25 4.25 M10.75 4.25A3.9 3.9 0 0 1 10.75 9.75',
    fill: 'M7 6h2v2H7z',
  );
  static const KkIconData radar = KkIconData('radar', stroke: '$_ring M8 8L11.7 4.3', fill: 'M4.75 9.25h1.5v1.5h-1.5z');
  static const KkIconData target = KkIconData(
    'target',
    stroke: 'M12 8A4 4 0 1 1 4 8A4 4 0 1 1 12 8Z M8 1.75V4.5 M8 11.5V14.25 M1.75 8H4.5 M11.5 8H14.25',
  );
  static const KkIconData gauge = KkIconData(
    'gauge',
    stroke: 'M2.75 11.5A5.25 5.25 0 0 1 13.25 11.5 M8 11.5L10.6 6.9',
    fill: 'M7.1 10.6h1.8v1.8h-1.8z',
  );
  static const KkIconData thermo = KkIconData(
    'thermo',
    stroke: 'M6.5 2.75H9.5V9L11 10.5V12.5L9.5 14H6.5L5 12.5V10.5L6.5 9Z M8 5.5V11',
  );
  static const KkIconData drop = KkIconData('drop', stroke: 'M8 2L12.25 8.25V11L10 13.5H6L3.75 11V8.25Z');
  static const KkIconData pulse = KkIconData('pulse', stroke: 'M1.75 8H4.5L6.25 3.5L9.25 12.5L11 8H14.25');
  static const KkIconData terminal = KkIconData(
    'terminal',
    stroke: 'M2.75 3.25H13.25V12.75H2.75Z M5 6.25L7 8L5 9.75 M8.5 10H11',
  );
  static const KkIconData code = KkIconData('code', stroke: 'M5.5 4.25L1.75 8L5.5 11.75 M10.5 4.25L14.25 8L10.5 11.75');
  static const KkIconData database = KkIconData(
    'database',
    stroke:
        'M2.75 4.5A5.25 1.75 0 0 1 13.25 4.5V11.5A5.25 1.75 0 0 1 2.75 11.5Z '
        'M2.75 4.5A5.25 1.75 0 0 0 13.25 4.5 M2.75 8A5.25 1.75 0 0 0 13.25 8',
  );
  static const KkIconData server = KkIconData(
    'server',
    stroke: '$_frame M2.75 6.25H13.25 M2.75 9.75H13.25',
    fill: 'M4.4 3.9h1.3v1.3H4.4z M4.4 7.4h1.3v1.3H4.4z M4.4 10.9h1.3v1.3H4.4z',
  );
  static const KkIconData cpu = KkIconData(
    'cpu',
    stroke:
        'M4.25 4.25H11.75V11.75H4.25Z M6.5 6.5H9.5V9.5H6.5Z M6 1.75V4 M10 1.75V4 M6 12V14.25 M10 12V14.25 '
        'M1.75 6H4 M1.75 10H4 M12 6H14.25 M12 10H14.25',
  );
  static const KkIconData layers = KkIconData(
    'layers',
    stroke: 'M8 2.25L14 5.5L8 8.75L2 5.5Z M2.6 8.4L8 11.4L13.4 8.4 M2.6 11.2L8 14.2L13.4 11.2',
  );
  static const KkIconData node = KkIconData(
    'node',
    stroke:
        'M2.75 6.5H5.75V9.5H2.75Z M10.25 2.75H13.25V5.75H10.25Z M10.25 10.25H13.25V13.25H10.25Z '
        'M5.75 8H8 M8 4.25H10.25 M8 11.75H10.25 M8 4.25V11.75',
  );

  // ── data ────────────────────────────────────────────────────────────────
  static const KkIconData chartLine = KkIconData(
    'chart-line',
    stroke: 'M2.75 2.75V13.25H13.25 M4.75 10.5L7.25 7L9.5 9L12.75 4.25',
  );
  static const KkIconData chartBar = KkIconData(
    'chart-bar',
    stroke: 'M2.75 13.25H13.25 M4.5 13V8.5 M8 13V3.5 M11.5 13V6.5',
  );
  static const KkIconData table = KkIconData(
    'table',
    stroke: '$_frame M2.75 6.25H13.25 M2.75 9.75H13.25 M6.25 6.25V13.25',
  );
  static const KkIconData columns = KkIconData('columns', stroke: '$_frame M8 2.75V13.25');
  static const KkIconData panel = KkIconData('panel', stroke: '$_frame M6.25 2.75V13.25');
  static const KkIconData grid = KkIconData(
    'grid',
    stroke:
        'M2.75 2.75H6.75V6.75H2.75Z M9.25 2.75H13.25V6.75H9.25Z M2.75 9.25H6.75V13.25H2.75Z M9.25 9.25H13.25V13.25H9.25Z',
  );
  static const KkIconData list = KkIconData(
    'list',
    stroke: 'M5.5 4H13.25 M5.5 8H13.25 M5.5 12H13.25',
    fill: 'M2.25 3.25h1.5v1.5h-1.5z M2.25 7.25h1.5v1.5h-1.5z M2.25 11.25h1.5v1.5h-1.5z',
  );

  // ── general notices (never a status) ────────────────────────────────────
  static const KkIconData info = KkIconData('info', stroke: '$_ring M8 7.5V11', fill: 'M7.25 4.75h1.5v1.5h-1.5z');
  static const KkIconData warning = KkIconData(
    'warning',
    stroke: 'M8 2.25L14.25 13.25H1.75Z M8 6.5V9.75',
    fill: 'M7.25 10.9h1.5v1.5h-1.5z',
  );
  static const KkIconData help = KkIconData(
    'help',
    stroke: '$_ring M6.25 6.5V5.5H9.75V7.75H8V9.25',
    fill: 'M7.25 10.5h1.5v1.5h-1.5z',
  );

  /// Every icon in the set, in catalogue order.
  static const List<KkIconData> values = <KkIconData>[
    statusNominal, statusCaution, statusCritical, statusOffline, statusInfo, //
    menu, close, check, plus, minus, chevronUp, chevronDown, chevronLeft, chevronRight, //
    arrowUp, arrowDown, arrowLeft, arrowRight, caretUp, caretDown, first, last, home, more, moreVertical, grip, //
    external, undo, redo, swap, search, zoomIn, zoomOut, filter, sort, refresh, sync, download, upload, link, //
    copy, edit, trash, save, send, expand, collapse, fit, play, pause, stop, skip, power, //
    settings, sliders, lock, unlock, key, eye, eyeOff, bell, bellOff, user, calendar, clock, pin, flag, bookmark, //
    star, file, folder, globe, shield, hex, square, dot, //
    bolt, plug, battery, signal, radio, radar, target, gauge, thermo, drop, pulse, terminal, code, database, //
    server, cpu, layers, node, chartLine, chartBar, table, columns, panel, grid, list, info, warning, help,
  ];

  /// The icon called [name], or null.
  static KkIconData? byName(String name) {
    for (final KkIconData icon in values) {
      if (icon.name == name) return icon;
    }
    return null;
  }
}
