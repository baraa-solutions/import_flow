import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/customs_consultation_model.dart';

/// Customs tariff tax exemptions, trade agreement preferences, and regulatory
/// authority compliance notices card.
class DutiesCalcTaxesCard extends StatelessWidget {
  final List<CustomsItemCalcRow> calcLines;

  const DutiesCalcTaxesCard({
    super.key,
    required this.calcLines,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final relevantLines = calcLines
        .where(
          (line) =>
              line.hasExemption ||
              line.priorApprovalNote != null ||
              (line.regulatoryAuthority != null &&
                  line.regulatoryAuthority!.isNotEmpty),
        )
        .toList();

    if (relevantLines.isEmpty) {
      return const SizedBox.shrink();
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: relevantLines.map((line) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.wcagOrange, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.wcagOrange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${l.ccHSCode}: ${line.hsCode}${line.countryOfOrigin != null ? " - ${line.countryOfOrigin}" : ""}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.wcagOrange,
                        ),
                      ),
                    ),
                    if (line.hasExemption)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldBorder,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.wcagEmerald),
                        ),
                        child: Text(
                          line.appliedAgreementName ?? (l.ccExemption),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.wcagEmerald,
                          ),
                        ),
                      ),
                  ],
                ),
                if (line.exemptionConditionsNote != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    line.exemptionConditionsNote!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.charcoal,
                    ),
                  ),
                ],
                if (line.requiredDocument != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    line.requiredDocument!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.wcagCobalt,
                    ),
                  ),
                ],
                if (line.priorApprovalNote != null &&
                    line.priorApprovalNote!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    line.priorApprovalNote!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoal,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
