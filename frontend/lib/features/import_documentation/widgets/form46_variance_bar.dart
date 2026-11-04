import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import 'idoc_ui_b.dart';

enum Form46VarianceSeverity {
  compliant, // < 2%
  moderate,  // 2 - 10%
  high,      // > 10%
}

class Form46VarianceResult {
  final double? baseline;
  final double? compared;
  final double? diffAmount;
  final double? diffPercentage;
  final Form46VarianceSeverity severity;

  const Form46VarianceResult({
    required this.baseline,
    required this.compared,
    required this.diffAmount,
    required this.diffPercentage,
    required this.severity,
  });

  static Form46VarianceResult compute(double? baseline, double? compared) {
    if (baseline == null || compared == null) {
      return Form46VarianceResult(
        baseline: baseline,
        compared: compared,
        diffAmount: null,
        diffPercentage: null,
        severity: Form46VarianceSeverity.compliant,
      );
    }

    final diff = compared - baseline;
    double pct = 0.0;
    if (baseline > 0) {
      pct = (diff / baseline) * 100.0;
    } else if (compared > 0) {
      pct = 100.0;
    }

    final absPct = pct.abs();
    Form46VarianceSeverity sev;
    if (absPct < 2.0) {
      sev = Form46VarianceSeverity.compliant;
    } else if (absPct <= 10.0) {
      sev = Form46VarianceSeverity.moderate;
    } else {
      sev = Form46VarianceSeverity.high;
    }

    return Form46VarianceResult(
      baseline: baseline,
      compared: compared,
      diffAmount: diff,
      diffPercentage: pct,
      severity: sev,
    );
  }
}

/// Strip/Card presenting the three comparison variance indicators:
/// 1. Revised vs Study (B vs A)
/// 2. Actual vs Study (C vs A)
/// 3. Actual vs Revised (C vs B)
class Form46VarianceBar extends StatelessWidget {
  const Form46VarianceBar({
    super.key,
    required this.studyTotal,
    required this.revisedTotal,
    required this.actualTotal,
  });

  final double? studyTotal;
  final double? revisedTotal;
  final double? actualTotal;

  static Color severityColor(Form46VarianceSeverity severity) {
    switch (severity) {
      case Form46VarianceSeverity.compliant:
        return AppTheme.emerald;
      case Form46VarianceSeverity.moderate:
        return AppTheme.orange;
      case Form46VarianceSeverity.high:
        return AppTheme.crimson;
    }
  }

  static String severityLabel(AppLocalizations l, Form46VarianceSeverity severity) {
    switch (severity) {
      case Form46VarianceSeverity.compliant:
        return l.form46VarianceStatusCompliant;
      case Form46VarianceSeverity.moderate:
        return l.form46VarianceStatusModerate;
      case Form46VarianceSeverity.high:
        return l.form46VarianceStatusHigh;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bVsA = Form46VarianceResult.compute(studyTotal, revisedTotal);
    final cVsA = Form46VarianceResult.compute(studyTotal, actualTotal);
    final cVsB = Form46VarianceResult.compute(revisedTotal, actualTotal);

    return SelectionArea(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAltOf(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.compare_arrows_rounded, size: 20, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l.form46VarianceBarTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 800;
                final cards = [
                  _VarianceCard(
                    title: l.form46VarianceBvsA,
                    subtitle: 'B → A',
                    result: bVsA,
                  ),
                  _VarianceCard(
                    title: l.form46VarianceCvsA,
                    subtitle: 'C → A',
                    result: cVsA,
                  ),
                  _VarianceCard(
                    title: l.form46VarianceCvsB,
                    subtitle: 'C → B',
                    result: cVsB,
                  ),
                ];

                if (isNarrow) {
                  return Column(
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        cards[i],
                        if (i < cards.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[2]),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VarianceCard extends StatelessWidget {
  const _VarianceCard({
    required this.title,
    required this.subtitle,
    required this.result,
  });

  final String title;
  final String subtitle;
  final Form46VarianceResult result;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final color = Form46VarianceBar.severityColor(result.severity);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final diff = result.diffAmount;
    final pct = result.diffPercentage;
    final hasData = diff != null && pct != null;

    final sign = hasData ? (diff >= 0 ? '+' : '') : '';
    final formattedAmount = hasData
        ? '$sign${IdocBFormat.money(diff)} ${l.egpCurrency}'
        : l.idocBMissing;
    final formattedPct = hasData
        ? '$sign${pct.toStringAsFixed(1)}%'
        : '—';

    final copySummary = '$title ($subtitle): $formattedAmount ($formattedPct)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkInputBackground : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasData ? color.withValues(alpha: 0.5) : Theme.of(context).dividerColor.withValues(alpha: 0.25),
          width: hasData ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 14),
                tooltip: l.customsDeclCopyValueTooltip,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => CopyHelper.copy(context, copySummary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: LtrText(
                  formattedAmount,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: hasData ? color : AppTheme.textMutedOf(context),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: LtrText(
                  formattedPct,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasData ? Form46VarianceBar.severityLabel(l, result.severity) : l.customsDeclVariancePending,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: hasData ? color : AppTheme.textMutedOf(context),
            ),
          ),
        ],
      ),
    );
  }
}
