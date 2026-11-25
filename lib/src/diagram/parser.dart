import 'dart:collection';
import 'dart:ui' show Offset;

import '../foundation/level.dart';
import 'model.dart';

/// Reads a [KkDiagram] from text.
///
/// The language is line based. `#` starts a comment, blank lines are ignored
/// and `;` separates statements on one line.
///
/// ```text
/// flow LR                      # or: flow TB (alias TD). Default is LR.
///
/// SEC01[SEC-01|PUMP A]         # node:     ID[code|label|cjk]
/// CORE((CORE))                 # hub:      ID((text))
/// CHK{PRESSURE}                # decision: ID{text}
/// HALT([HALT])                 # terminal: ID([text])
/// L1>VALVE]                    # leaf:     ID>text]
/// SEC02[SEC-02]:::critical     # level:    :::nominal | caution | critical | offline
/// SEC03[SEC-03]@0.25,0.5       # position for a manual layout: @x,y
///
/// SEC01 --> CORE               # wire with an arrow head
/// SEC01 --- CORE               # wire without one
/// SEC01 ==> CORE               # active wire, flow marks run forward
/// SEC01 ==< CORE               # active wire, flow marks run in reverse
/// SEC01 === CORE               # active wire, no flow, no head
/// SEC01 -.-> CORE              # offline (dashed) wire; -.- has no head
/// CHK -->|LOW| HALT            # label
/// CHK -->|LOW|:::critical HALT # wire level, right after the wire
/// A --> B --> C                # chain
/// ```
///
/// A node text has up to three fields split by `|`: the code, a label and a
/// CJK title. A field may be wrapped in double quotes to hold brackets or `|`.
/// An id is letters, digits and `_`, with single `-` or `.` allowed inside
/// (`SEC-01`). A bare id declares a plain node whose code is the id.
///
/// After a wire, `:::` takes a comma separated list: a level, `active`,
/// `flow`, `reverse` (flow against the wire) or `noarrow`.
///
/// Throws a [FormatException] whose message starts with `line N:` on bad
/// input.
KkDiagram kkParseDiagram(String source) => _DiagramParser(source).parse();

/// Writes [diagram] in the language [kkParseDiagram] reads. Parsing the result
/// gives an equal diagram, except that node sizes and info lines (which have
/// no text form) are dropped.
///
/// Throws an [ArgumentError] when an id or a text cannot be written.
String kkDiagramToSource(KkDiagram diagram) {
  final StringBuffer out = StringBuffer();
  out.writeln(diagram.direction == KkDiagramDirection.leftToRight ? 'flow LR' : 'flow TB');
  for (final KkDiagramNode node in diagram.nodes) {
    out.writeln(_nodeSource(node));
  }
  for (final KkDiagramEdge edge in diagram.edges) {
    out.writeln('${_checkedId(edge.from)} ${_edgeSource(edge)} ${_checkedId(edge.to)}');
  }
  return out.toString();
}

const Map<String, KkLevel> _levels = <String, KkLevel>{
  'nominal': KkLevel.nominal,
  'caution': KkLevel.caution,
  'critical': KkLevel.critical,
  'offline': KkLevel.offline,
};

const String _special = '[](){}<>|:;#"=@,';

bool _isCore(int c) {
  if (c <= 0x20 || c == 0x7F) return false;
  if (c == 0x2D || c == 0x2E) return false; // '-' and '.'
  return !_special.codeUnits.contains(c);
}

/// Length of the id that starts at [start] in [s] (0 when there is none).
int _idLength(String s, int start) {
  int i = start;
  while (i < s.length) {
    final int c = s.codeUnitAt(i);
    if (_isCore(c)) {
      i++;
    } else if ((c == 0x2D || c == 0x2E) && i > start && i + 1 < s.length && _isCore(s.codeUnitAt(i + 1))) {
      i += 2;
    } else {
      break;
    }
  }
  return i - start;
}

String _checkedId(String id) {
  if (id.isEmpty || _idLength(id, 0) != id.length) {
    throw ArgumentError.value(id, 'id', 'This node id cannot be written as diagram source');
  }
  return id;
}

String _field(String text) {
  if (text.contains('"') || text.contains('\n') || text.contains('\r')) {
    throw ArgumentError.value(text, 'text', 'Quotes and line breaks cannot be written as diagram source');
  }
  final bool quote = text != text.trim() || text.codeUnits.any((int c) => '|[](){}<>'.codeUnits.contains(c));
  return quote ? '"$text"' : text;
}

String _number(double v) => v == v.roundToDouble() && v.abs() < 1e15 ? v.toInt().toString() : v.toString();

String _nodeSource(KkDiagramNode node) {
  final StringBuffer out = StringBuffer(_checkedId(node.id));
  final String? label = node.label == null || node.label!.isEmpty ? null : node.label;
  final String? cjk = node.cjk == null || node.cjk!.isEmpty ? null : node.cjk;
  final bool bare = node.kind == KkNodeKind.node && node.text == node.id && label == null && cjk == null;
  if (!bare) {
    final List<String> fields = <String>[_field(node.text)];
    if (label != null || cjk != null) fields.add(label == null ? '' : _field(label));
    if (cjk != null) fields.add(_field(cjk));
    final String text = fields.join('|');
    out.write(switch (node.kind) {
      KkNodeKind.node => '[$text]',
      KkNodeKind.hub => '(($text))',
      KkNodeKind.decision => '{$text}',
      KkNodeKind.terminal => '([$text])',
      KkNodeKind.leaf => '>$text]',
    });
  }
  final KkLevel? level = node.level;
  if (level != null) out.write(':::${level.name}');
  final Offset? p = node.position;
  if (p != null) out.write('@${_number(p.dx)},${_number(p.dy)}');
  return out.toString();
}

String _edgeSource(KkDiagramEdge edge) {
  final List<String> attrs = <String>[];
  String op;
  bool levelDone = false;
  bool activeDone = false;
  bool flowDone = false;
  if (edge.active && edge.arrow && edge.flow == KkEdgeFlow.forward) {
    op = '==>';
    activeDone = flowDone = true;
  } else if (edge.active && edge.arrow && edge.flow == KkEdgeFlow.reverse) {
    op = '==<';
    activeDone = flowDone = true;
  } else if (edge.active && !edge.arrow && edge.flow == KkEdgeFlow.none) {
    op = '===';
    activeDone = flowDone = true;
  } else if (edge.level == KkLevel.offline) {
    op = edge.arrow ? '-.->' : '-.-';
    levelDone = true;
  } else {
    op = edge.arrow ? '-->' : '---';
  }
  final KkLevel? level = edge.level;
  if (level != null && !levelDone) attrs.add(level.name);
  if (edge.active && !activeDone) attrs.add('active');
  if (!flowDone && edge.flow == KkEdgeFlow.forward) attrs.add('flow');
  if (!flowDone && edge.flow == KkEdgeFlow.reverse) attrs.add('reverse');
  final StringBuffer out = StringBuffer(op);
  final String? label = edge.label;
  if (label != null && label.isNotEmpty) out.write('|${_field(label)}|');
  if (attrs.isNotEmpty) out.write(':::${attrs.join(',')}');
  return out.toString();
}

class _NodeDraft {
  _NodeDraft(this.id);

  final String id;
  String? code;
  String? label;
  String? cjk;
  KkNodeKind kind = KkNodeKind.node;
  KkLevel? level;
  Offset? position;

  KkDiagramNode build() =>
      KkDiagramNode(id, code: code, label: label, cjk: cjk, kind: kind, level: level, position: position);
}

class _DiagramParser {
  _DiagramParser(this.source);

  final String source;
  final LinkedHashMap<String, _NodeDraft> _nodes = LinkedHashMap<String, _NodeDraft>();
  final List<KkDiagramEdge> _edges = <KkDiagramEdge>[];
  KkDiagramDirection _direction = KkDiagramDirection.leftToRight;

  String _line = '';
  int _lineNo = 0;
  int _i = 0;

  static const List<String> _ops = <String>['-.->', '-.-', '-->', '---', '==>', '==<', '==='];

  Never _fail(String message, [int? at]) => throw FormatException('line $_lineNo: $message', _line, at ?? _i);

  bool get _end => _i >= _line.length;

  int get _peek => _line.codeUnitAt(_i);

  bool _at(String s) => _line.startsWith(s, _i);

  void _ws() {
    while (!_end && (_peek == 0x20 || _peek == 0x09)) {
      _i++;
    }
  }

  bool get _statementEnd => _end || _peek == 0x23 || _peek == 0x3B; // '#', ';'

  KkDiagram parse() {
    final List<String> lines = source.split('\n');
    for (int n = 0; n < lines.length; n++) {
      String line = lines[n];
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      _line = line;
      _lineNo = n + 1;
      _i = 0;
      _parseLine();
    }
    return KkDiagram(
      nodes: _nodes.values.map((_NodeDraft d) => d.build()),
      edges: _edges,
      direction: _direction,
    );
  }

  void _parseLine() {
    while (true) {
      _ws();
      if (_end || _peek == 0x23) return;
      if (_peek == 0x3B) {
        _i++;
        continue;
      }
      if (_tryHeader()) continue;
      _parseChain();
      _ws();
      if (!_statementEnd) _fail('unexpected "${_line[_i]}"');
    }
  }

  bool _tryHeader() {
    final int start = _i;
    final int len = _idLength(_line, _i);
    if (len != 4 || _line.substring(_i, _i + 4).toLowerCase() != 'flow') return false;
    _i += 4;
    if (_end || (_peek != 0x20 && _peek != 0x09)) {
      _i = start;
      return false;
    }
    _ws();
    final int wordStart = _i;
    final int wordLen = _idLength(_line, _i);
    if (wordLen == 0) {
      _i = start;
      return false;
    }
    final String word = _line.substring(_i, _i + wordLen);
    _i += wordLen;
    _ws();
    if (!_statementEnd) {
      // "flow" used as a node id: `flow --> B`, `flow A --> B` is not valid anyway.
      _i = start;
      return false;
    }
    switch (word.toUpperCase()) {
      case 'LR':
        _direction = KkDiagramDirection.leftToRight;
      case 'TB' || 'TD':
        _direction = KkDiagramDirection.topToBottom;
      default:
        _fail('unknown flow direction "$word" (use LR or TB)', wordStart);
    }
    return true;
  }

  void _parseChain() {
    String left = _parseNodeRef();
    while (true) {
      _ws();
      if (_statementEnd) return;
      final KkDiagramEdge wire = _parseWire();
      _ws();
      if (_statementEnd) _fail('expected a node id after the wire');
      final String right = _parseNodeRef();
      _edges.add(wire.copyWith(from: left, to: right));
      left = right;
    }
  }

  String _parseNodeRef() {
    final int len = _idLength(_line, _i);
    if (len == 0) _fail(_end ? 'expected a node id' : 'expected a node id, found "${_line[_i]}"');
    final String id = _line.substring(_i, _i + len);
    _i += len;
    final _NodeDraft draft = _nodes.putIfAbsent(id, () => _NodeDraft(id));
    if (!_end) {
      switch (_peek) {
        case 0x5B: // [
          _i++;
          _parseText(']', draft, KkNodeKind.node);
        case 0x28: // (
          if (_at('((')) {
            _i += 2;
            _parseText('))', draft, KkNodeKind.hub);
          } else if (_at('([')) {
            _i += 2;
            _parseText('])', draft, KkNodeKind.terminal);
          } else {
            _fail('expected "((" or "([" after the node id');
          }
        case 0x7B: // {
          _i++;
          _parseText('}', draft, KkNodeKind.decision);
        case 0x3E: // >
          _i++;
          _parseText(']', draft, KkNodeKind.leaf);
      }
    }
    while (true) {
      final int save = _i;
      _ws();
      if (_at(':::')) {
        _i += 3;
        final int at = _i;
        final String word = _word();
        final KkLevel? level = _levels[word];
        if (level == null) {
          _fail('unknown level "$word" (use nominal, caution, critical or offline)', at);
        }
        draft.level = level;
      } else if (!_end && _peek == 0x40) {
        _i++;
        final double x = _numberValue();
        if (_end || _peek != 0x2C) _fail('expected "," between the x and y of a position');
        _i++;
        final double y = _numberValue();
        draft.position = Offset(x, y);
      } else {
        _i = save;
        return id;
      }
    }
  }

  void _parseText(String close, _NodeDraft draft, KkNodeKind kind) {
    final List<String> fields = <String>[];
    while (true) {
      fields.add(_fieldValue(close));
      if (_end) _fail('missing "$close"');
      if (_peek == 0x7C) {
        _i++;
        continue;
      }
      if (_at(close)) {
        _i += close.length;
        break;
      }
      _fail('expected "|" or "$close"');
    }
    if (fields.length > 3) _fail('a node text has at most three fields: code|label|cjk');
    draft.kind = kind;
    draft.code = fields[0].isEmpty ? null : fields[0];
    draft.label = fields.length > 1 && fields[1].isNotEmpty ? fields[1] : null;
    draft.cjk = fields.length > 2 && fields[2].isNotEmpty ? fields[2] : null;
  }

  /// Reads one text field up to (not including) `|` or [close].
  String _fieldValue(String close) {
    _ws();
    if (!_end && _peek == 0x22) {
      final int end = _line.indexOf('"', _i + 1);
      if (end < 0) _fail('missing closing quote');
      final String value = _line.substring(_i + 1, end);
      _i = end + 1;
      _ws();
      return value;
    }
    final int start = _i;
    while (!_end && _peek != 0x7C && !_at(close)) {
      _i++;
    }
    if (_end) _fail('missing "$close"', start);
    return _line.substring(start, _i).trim();
  }

  KkDiagramEdge _parseWire() {
    String? op;
    for (final String candidate in _ops) {
      if (_at(candidate)) {
        op = candidate;
        break;
      }
    }
    if (op == null) {
      _fail('expected a wire (-->, ---, ==>, ==<, ===, -.-> or -.-), found "${_line[_i]}"');
    }
    _i += op.length;
    bool active = false;
    bool arrow = true;
    KkEdgeFlow flow = KkEdgeFlow.none;
    KkLevel? level;
    switch (op) {
      case '---':
        arrow = false;
      case '==>':
        active = true;
        flow = KkEdgeFlow.forward;
      case '==<':
        active = true;
        flow = KkEdgeFlow.reverse;
      case '===':
        active = true;
        arrow = false;
      case '-.->':
        level = KkLevel.offline;
      case '-.-':
        level = KkLevel.offline;
        arrow = false;
    }
    String? label;
    int save = _i;
    _ws();
    if (!_end && _peek == 0x7C) {
      _i++;
      label = _fieldValue('|');
      if (_end || _peek != 0x7C) _fail('missing "|" after the wire label');
      _i++;
      if (label.isEmpty) label = null;
    } else {
      _i = save;
    }
    save = _i;
    _ws();
    if (_at(':::')) {
      _i += 3;
      while (true) {
        final int at = _i;
        final String word = _word();
        final KkLevel? l = _levels[word];
        if (l != null) {
          level = l;
        } else {
          switch (word) {
            case 'active':
              active = true;
            case 'flow':
              flow = KkEdgeFlow.forward;
            case 'reverse':
              flow = KkEdgeFlow.reverse;
            case 'noarrow':
              arrow = false;
            case 'arrow':
              arrow = true;
            default:
              _fail(
                'unknown wire attribute "$word" (use a level, active, flow, reverse or noarrow)',
                at,
              );
          }
        }
        if (!_end && _peek == 0x2C) {
          _i++;
          continue;
        }
        break;
      }
    } else {
      _i = save;
    }
    return KkDiagramEdge('', '', label: label, level: level, active: active, flow: flow, arrow: arrow);
  }

  String _word() {
    final int start = _i;
    while (!_end && ((_peek >= 0x41 && _peek <= 0x5A) || (_peek >= 0x61 && _peek <= 0x7A))) {
      _i++;
    }
    return _line.substring(start, _i).toLowerCase();
  }

  double _numberValue() {
    final int start = _i;
    while (!_end) {
      final int c = _peek;
      final bool digit = c >= 0x30 && c <= 0x39;
      final bool sign = (c == 0x2D || c == 0x2B) && (_i == start || _line[_i - 1] == 'e' || _line[_i - 1] == 'E');
      final bool exp = (c == 0x65 || c == 0x45) && _i > start;
      if (digit || c == 0x2E || sign || exp) {
        _i++;
      } else {
        break;
      }
    }
    final double? v = double.tryParse(_line.substring(start, _i));
    if (v == null || !v.isFinite) _fail('expected a number', start);
    return v;
  }
}
