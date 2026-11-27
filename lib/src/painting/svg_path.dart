import 'dart:ui';

/// Parses SVG path data (`M L H V C S Q T A Z`, absolute and relative) into a
/// [Path]. The icon set and the status glyphs are stored as path data on a
/// 16×16 grid and drawn through this.
///
/// Throws a [FormatException] when [d] is not valid path data. As in SVG, data
/// that draws anything has to begin with a moveto; empty data is an empty path.
Path kkParseSvgPath(String d) => _SvgPathParser(d).parse();

class _SvgPathParser {
  _SvgPathParser(this.src);

  final String src;
  int _i = 0;

  static bool _isCommand(int c) {
    // A-Z / a-z except 'e' and 'E', which belong to numbers.
    final bool upper = c >= 0x41 && c <= 0x5A;
    final bool lower = c >= 0x61 && c <= 0x7A;
    return (upper || lower) && c != 0x45 && c != 0x65;
  }

  void _skipSeparators() {
    while (_i < src.length) {
      final int c = src.codeUnitAt(_i);
      if (c == 0x20 || c == 0x2C || c == 0x09 || c == 0x0A || c == 0x0D) {
        _i++;
      } else {
        break;
      }
    }
  }

  bool _hasNumber() {
    _skipSeparators();
    if (_i >= src.length) return false;
    final int c = src.codeUnitAt(_i);
    return (c >= 0x30 && c <= 0x39) || c == 0x2D || c == 0x2B || c == 0x2E;
  }

  double _number() {
    _skipSeparators();
    final int start = _i;
    if (_i < src.length && (src.codeUnitAt(_i) == 0x2D || src.codeUnitAt(_i) == 0x2B)) _i++;
    bool digits = false;
    while (_i < src.length && _isDigit(src.codeUnitAt(_i))) {
      _i++;
      digits = true;
    }
    if (_i < src.length && src.codeUnitAt(_i) == 0x2E) {
      _i++;
      while (_i < src.length && _isDigit(src.codeUnitAt(_i))) {
        _i++;
        digits = true;
      }
    }
    if (!digits) throw FormatException('Expected a number', src, start);
    if (_i < src.length && (src.codeUnitAt(_i) == 0x65 || src.codeUnitAt(_i) == 0x45)) {
      final int mark = _i;
      _i++;
      if (_i < src.length && (src.codeUnitAt(_i) == 0x2D || src.codeUnitAt(_i) == 0x2B)) _i++;
      if (_i < src.length && _isDigit(src.codeUnitAt(_i))) {
        while (_i < src.length && _isDigit(src.codeUnitAt(_i))) {
          _i++;
        }
      } else {
        _i = mark;
      }
    }
    return double.parse(src.substring(start, _i));
  }

  bool _flag() {
    _skipSeparators();
    if (_i >= src.length) throw FormatException('Expected an arc flag', src, _i);
    final int c = src.codeUnitAt(_i);
    if (c != 0x30 && c != 0x31) throw FormatException('Expected an arc flag (0 or 1)', src, _i);
    _i++;
    return c == 0x31;
  }

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  Path parse() {
    final Path path = Path();
    double x = 0, y = 0; // current point
    double sx = 0, sy = 0; // sub-path start
    double cx = 0, cy = 0; // last control point (for S / T)
    int last = 0;
    int cmd = 0;

    _skipSeparators();
    while (_i < src.length) {
      final int c = src.codeUnitAt(_i);
      if (_isCommand(c)) {
        // Without this the path would silently start at the origin.
        if (last == 0 && c != 0x4D && c != 0x6D) {
          throw FormatException('Path data must begin with a moveto (M or m)', src, _i);
        }
        cmd = c;
        _i++;
      } else if (cmd == 0) {
        throw FormatException('Path data must start with a command', src, _i);
      } else if (cmd == 0x4D) {
        cmd = 0x4C; // implicit lineto after M
      } else if (cmd == 0x6D) {
        cmd = 0x6C; // implicit lineto after m
      } else if (cmd == 0x5A || cmd == 0x7A) {
        throw FormatException('Unexpected number after close path', src, _i);
      }

      final bool rel = cmd >= 0x61;
      switch (String.fromCharCode(cmd).toUpperCase()) {
        case 'M':
          final double nx = _number() + (rel ? x : 0);
          final double ny = _number() + (rel ? y : 0);
          x = nx;
          y = ny;
          sx = x;
          sy = y;
          path.moveTo(x, y);
        case 'L':
          final double nx = _number() + (rel ? x : 0);
          final double ny = _number() + (rel ? y : 0);
          x = nx;
          y = ny;
          path.lineTo(x, y);
        case 'H':
          x = _number() + (rel ? x : 0);
          path.lineTo(x, y);
        case 'V':
          y = _number() + (rel ? y : 0);
          path.lineTo(x, y);
        case 'C':
          final double x1 = _number() + (rel ? x : 0);
          final double y1 = _number() + (rel ? y : 0);
          final double x2 = _number() + (rel ? x : 0);
          final double y2 = _number() + (rel ? y : 0);
          final double nx = _number() + (rel ? x : 0);
          final double ny = _number() + (rel ? y : 0);
          path.cubicTo(x1, y1, x2, y2, nx, ny);
          cx = x2;
          cy = y2;
          x = nx;
          y = ny;
        case 'S':
          final bool smooth = last == 0x43 || last == 0x63 || last == 0x53 || last == 0x73;
          final double x1 = smooth ? 2 * x - cx : x;
          final double y1 = smooth ? 2 * y - cy : y;
          final double x2 = _number() + (rel ? x : 0);
          final double y2 = _number() + (rel ? y : 0);
          final double nx = _number() + (rel ? x : 0);
          final double ny = _number() + (rel ? y : 0);
          path.cubicTo(x1, y1, x2, y2, nx, ny);
          cx = x2;
          cy = y2;
          x = nx;
          y = ny;
        case 'Q':
          final double x1 = _number() + (rel ? x : 0);
          final double y1 = _number() + (rel ? y : 0);
          final double nx = _number() + (rel ? x : 0);
          final double ny = _number() + (rel ? y : 0);
          path.quadraticBezierTo(x1, y1, nx, ny);
          cx = x1;
          cy = y1;
          x = nx;
          y = ny;
        case 'T':
          final bool smooth = last == 0x51 || last == 0x71 || last == 0x54 || last == 0x74;
          final double x1 = smooth ? 2 * x - cx : x;
          final double y1 = smooth ? 2 * y - cy : y;
          final double nx = _number() + (rel ? x : 0);
          final double ny = _number() + (rel ? y : 0);
          path.quadraticBezierTo(x1, y1, nx, ny);
          cx = x1;
          cy = y1;
          x = nx;
          y = ny;
        case 'A':
          final double rx = _number().abs();
          final double ry = _number().abs();
          final double rotation = _number();
          final bool large = _flag();
          final bool sweep = _flag();
          final double nx = _number() + (rel ? x : 0);
          final double ny = _number() + (rel ? y : 0);
          if (rx == 0 || ry == 0) {
            path.lineTo(nx, ny);
          } else if (nx != x || ny != y) {
            path.arcToPoint(
              Offset(nx, ny),
              radius: Radius.elliptical(rx, ry),
              rotation: rotation,
              largeArc: large,
              clockwise: sweep,
            );
          }
          x = nx;
          y = ny;
        case 'Z':
          path.close();
          x = sx;
          y = sy;
        default:
          throw FormatException('Unknown path command "${String.fromCharCode(cmd)}"', src, _i - 1);
      }
      last = cmd;
      _skipSeparators();
      // After Z only a new command may follow.
      if ((cmd == 0x5A || cmd == 0x7A) && _i < src.length && !_isCommand(src.codeUnitAt(_i))) {
        throw FormatException('Unexpected number after close path', src, _i);
      }
      if (_i < src.length && !_isCommand(src.codeUnitAt(_i)) && !_hasNumber()) {
        throw FormatException('Unexpected character in path data', src, _i);
      }
    }
    return path;
  }
}
