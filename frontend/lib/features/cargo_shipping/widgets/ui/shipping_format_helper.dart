import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

/// Display helpers shared by the cargo-shipping widgets.
class ShippingFormat {
  ShippingFormat._();

  /// `2026-08-16 | 1:56 PM` (date only for plain dates, a hint when empty).
  static String dateTime(String? raw, BuildContext ctx) {
    if (raw == null || raw.trim().isEmpty) return ctx.l10n.cargoShippingClickToSetDateTime;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final datePart = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    if (!raw.contains('T') && !raw.contains(':')) return datePart;
    final ml = MaterialLocalizations.of(ctx);
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? ml.postMeridiemAbbreviation : ml.anteMeridiemAbbreviation;
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$datePart | $hour:$minute $ampm';
  }

  static AppSeverity statusSeverity(String status) {
    switch (status) {
      case 'Completed':
        return AppSeverity.success;
      case 'Cargo Ready':
        return AppSeverity.info;
      default:
        return AppSeverity.info;
    }
  }
}
