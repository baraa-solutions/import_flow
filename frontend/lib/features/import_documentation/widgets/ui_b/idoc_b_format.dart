import 'package:flutter/material.dart';

import '../../../../core/widgets/metric_card.dart';

/// Presentation-only number formatting for the import-documentation package-B
/// screens (ACID, Form 46, COO, inspection). No business math lives here.
class IdocBFormat {
  IdocBFormat._();

  /// `1,234,567.50` (two decimals, thousands grouping, always Latin digits).
  static String money(double value) {
    final negative = value < 0;
    final fixed = value.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return '${negative ? '-' : ''}$buf.${parts[1]}';
  }
}

/// Feature-local composition over the core tokens: section cards, status
/// chips, notices, empty / error / loading panels, a dialog frame and the
/// itemised money table used by Form 46.
class IdocBUi {
  IdocBUi._();

  /// [MetricCardStrip] on wide layouts; a wrapped grid of cards when narrow.
  static Widget metrics(List<MetricCardData> data) => LayoutBuilder(
        builder: (context, c) {
          // Long Arabic labels need ~300px per card before a single row fits.
          if (c.maxWidth >= 300.0 * data.length) return MetricCardStrip(metrics: data);
          final w = c.maxWidth >= 520 ? (c.maxWidth - 8) / 2 : c.maxWidth;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in data)
                SizedBox(width: w, child: MetricCard(data: m, forceShort: false)),
            ],
          );
        },
      );

  /// Lets a (non-flexible) AppButton shrink instead of overflowing.
  static Widget fit(Widget button) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.center,
        child: button,
      );
}
