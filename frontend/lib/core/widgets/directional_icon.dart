import 'package:flutter/material.dart';

/// Direction-sensitive icons whose glyph does NOT set
/// `IconData.matchTextDirection`, so [Icon] never mirrors them by itself.
///
/// Icons such as `arrow_forward`, `arrow_back(_ios)`, `chevron_left/right`,
/// `navigate_*`, `first_page/last_page` and `arrow_right_alt` already carry
/// `matchTextDirection: true`: [Icon] mirrors them in RTL. Adding them here
/// would flip them twice (back to the LTR glyph).
final Set<IconData> _manuallyMirroredIcons = {
  Icons.keyboard_arrow_right,
  Icons.keyboard_arrow_left,
  Icons.keyboard_arrow_right_rounded,
  Icons.keyboard_arrow_left_rounded,
  Icons.keyboard_double_arrow_right,
  Icons.keyboard_double_arrow_left,
  Icons.keyboard_double_arrow_right_rounded,
  Icons.keyboard_double_arrow_left_rounded,
  Icons.double_arrow,
  Icons.double_arrow_rounded,
  Icons.menu_open,
  Icons.menu_open_rounded,
};

/// Whether [icon] points in a reading direction and should look mirrored in
/// RTL (either automatically by [Icon] or manually by [DirectionalIcon]).
bool isDirectionalIcon(IconData icon) =>
    icon.matchTextDirection || _manuallyMirroredIcons.contains(icon);

/// An icon that points in the reading direction: mirrored in RTL.
///
/// Glyphs with `matchTextDirection` are left to [Icon] (no second flip);
/// the keyboard-arrow / double-arrow / menu-open family is flipped here.
/// [forceMirror] sets the wanted final state explicitly (true = mirrored,
/// false = never mirrored, even for `matchTextDirection` glyphs in RTL).
class DirectionalIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final bool? forceMirror;

  const DirectionalIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.forceMirror,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    // What Icon already does on its own.
    final mirroredByIcon = isRtl && icon.matchTextDirection;
    final wantMirrored = forceMirror ?? (isRtl && isDirectionalIcon(icon));

    final iconWidget = Icon(
      icon,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    );

    if (wantMirrored != mirroredByIcon) {
      return Transform.scale(
        scaleX: -1.0,
        alignment: Alignment.center,
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}

/// A localized workflow arrow widget or symbol that points in the forward
/// reading direction (right '→' in LTR / English, left '←' in RTL / Arabic).
class DirectionalArrow extends StatelessWidget {
  final TextStyle? style;
  final Color? color;
  final double? size;

  const DirectionalArrow({
    super.key,
    this.style,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final arrowChar = isRtl ? '←' : '→';

    return Text(
      arrowChar,
      style: (style ?? const TextStyle()).copyWith(
        color: color,
        fontSize: size,
      ),
    );
  }

  /// Return arrow string symbol directly based on active RTL state.
  static String symbol(BuildContext context) {
    return Directionality.of(context) == TextDirection.rtl ? '←' : '→';
  }

  /// Return arrow string symbol directly based on isArabic boolean flag.
  static String symbolForArabic(bool isArabic) {
    return isArabic ? '←' : '→';
  }
}
