import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Lays out one run of [text] in [style]. The caller owns the painter and must
/// dispose it.
TextPainter kkLayoutText(
  String text,
  TextStyle style, {
  double maxWidth = double.infinity,
  TextAlign align = TextAlign.left,
  int? maxLines = 1,
  bool ellipsis = false,
  TextScaler scaler = TextScaler.noScaling,
}) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: align,
    textDirection: ui.TextDirection.ltr,
    maxLines: maxLines,
    ellipsis: ellipsis ? '…' : null,
    textScaler: scaler,
  )..layout(maxWidth: maxWidth);
}

/// Paints [text] so that the point of its box given by [align] sits on
/// [anchor]. `Alignment.center` centres the text on the anchor,
/// `Alignment.centerRight` ends it there, and so on.
///
/// Returns the rectangle the text occupied.
Rect kkPaintText(
  Canvas canvas,
  String text,
  TextStyle style,
  Offset anchor, {
  Alignment align = Alignment.topLeft,
  double maxWidth = double.infinity,
  bool ellipsis = false,
  TextScaler scaler = TextScaler.noScaling,
}) {
  final TextPainter tp = kkLayoutText(text, style, maxWidth: maxWidth, ellipsis: ellipsis, scaler: scaler);
  final Offset origin = Offset(
    anchor.dx - tp.width * (align.x + 1) / 2,
    anchor.dy - tp.height * (align.y + 1) / 2,
  );
  tp.paint(canvas, origin);
  final Rect rect = origin & tp.size;
  tp.dispose();
  return rect;
}

/// The width of [text] in [style] on one line.
double kkMeasureText(String text, TextStyle style, {TextScaler scaler = TextScaler.noScaling}) {
  final TextPainter tp = kkLayoutText(text, style, scaler: scaler);
  final double w = tp.width;
  tp.dispose();
  return w;
}
