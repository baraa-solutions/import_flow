import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Highlighted box presenting declared CIF base amounts and formula breakdown.
class ConsultationCalcCifBox extends StatelessWidget {
  final double totalFobForeign;
  final String customsCurrency;
  final double totalFreightEgp;
  final double totalCandFEgp;
  final double totalInsuranceEgp;
  final double totalCifEgp;
  final double totalCifForeign;
  final double? exchangeRate;

  const ConsultationCalcCifBox({
    super.key,
    required this.totalFobForeign,
    required this.customsCurrency,
    required this.totalFreightEgp,
    required this.totalCandFEgp,
    required this.totalInsuranceEgp,
    required this.totalCifEgp,
    required this.totalCifForeign,
    required this.exchangeRate,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final egpLabel = l.financialSettlementCurrencyEgp;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark
                ? AppTheme.darkElevatedSurface
                : AppTheme.charcoal.withValues(alpha: 0.04),
            AppTheme.emerald.withValues(alpha: isDark ? 0.15 : 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.emerald.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          final infoCol = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified, color: AppTheme.emerald, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.declaredCifBaseLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.charcoal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l.cifFormulaBreakdown(
                  totalFobForeign.toStringAsFixed(2),
                  customsCurrency,
                  totalFreightEgp.toStringAsFixed(2),
                  totalCandFEgp.toStringAsFixed(2),
                  totalInsuranceEgp.toStringAsFixed(2),
                ),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
                ),
              ),
            ],
          );

          final numbersCol = Column(
            crossAxisAlignment:
                isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              CopyableText(
                '${totalCifEgp.toStringAsFixed(2)} $egpLabel',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.emerald,
                ),
              ),
              if (exchangeRate != null && exchangeRate! > 0)
                CopyableText(
                  '≈ ${totalCifForeign.toStringAsFixed(2)} $customsCurrency',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.cobalt,
                  ),
                ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                infoCol,
                const SizedBox(height: 10),
                numbersCol,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: infoCol),
              numbersCol,
            ],
          );
        },
      ),
    );
  }
}
