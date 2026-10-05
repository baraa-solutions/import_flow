import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Bold header cell used by the PO packing / invoice review tables.
class PoHeaderCell extends StatelessWidget {
  const PoHeaderCell(this.label, {super.key, this.fontSize});

  final String label;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize),
      ),
    );
  }
}

/// Row tint for a line whose invoice and packing-list values do not match.
BoxDecoration poMismatchRowDecoration(bool isDark) => BoxDecoration(
      color: isDark
          ? AppTheme.crimson.withOpacity(0.3)
          : AppTheme.crimsonLight.withOpacity(0.35),
    );

/// Alternating row background for the read-only report tables.
BoxDecoration poZebraRowDecoration(int index, bool isDark) => BoxDecoration(
      color: index % 2 == 1
          ? (isDark ? AppTheme.darkInputBackground : AppTheme.charcoalSurface)
          : (isDark ? AppTheme.darkCardBackground : AppTheme.white),
    );
