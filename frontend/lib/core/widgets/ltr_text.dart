import 'package:flutter/widgets.dart';

/// A [Text] for codes and numbers (container no, B/L, PO / invoice / file codes,
/// HS codes, SWIFT, signed amounts) that must keep left-to-right order inside an
/// Arabic (RTL) layout.
///
/// Only the glyph order is forced to LTR. When the ambient direction is RTL and
/// no [textAlign] is given, the text is right-aligned so it still sits at the
/// start edge of its cell (in LTR nothing changes).
class LtrText extends StatelessWidget {
  const LtrText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.textAlign,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    return Text(
      data,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      textDirection: TextDirection.ltr,
      textAlign: textAlign ?? (rtl ? TextAlign.right : null),
    );
  }
}
