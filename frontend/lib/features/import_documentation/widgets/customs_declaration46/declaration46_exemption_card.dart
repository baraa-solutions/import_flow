import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/density_provider.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../services/customs_declaration46_calculator.dart';
import '../idoc_ui_b.dart';

class Declaration46ExemptionCard extends StatelessWidget {
  final bool hasExemption;
  final double? appliedDutyRate;
  final String miss;

  const Declaration46ExemptionCard({
    super.key,
    required this.hasExemption,
    required this.appliedDutyRate,
    required this.miss,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final String exemptionTitle = hasExemption
        ? l.customsDeclEur1ExemptionTitle
        : l.customsDeclMfnExemptionTitle(appliedDutyRate.fixedOrMissing(1, miss));

    final List<String> exemptionConditions = hasExemption
        ? [
            l.customsDeclEur1Condition1,
            l.customsDeclEur1Condition2,
            l.customsDeclEur1Condition3,
          ]
        : [
            l.customsDeclMfnCondition1,
            l.customsDeclMfnCondition2,
          ];

    return IdocBSectionCard(
      icon: hasExemption ? Icons.verified : Icons.info_outline,
      accent: hasExemption ? AppTheme.emerald : AppTheme.cobalt,
      title: l.customsDeclExemptionHeader,
      trailing: IdocBStatusChip(
        label: hasExemption ? l.idocBExemptionApplied : l.idocBExemptionNone,
        severity: hasExemption ? AppSeverity.success : AppSeverity.info,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.severityBackgroundOf(context, hasExemption ? AppSeverity.success : AppSeverity.info),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_offer,
                  size: 18,
                  color: hasExemption ? AppTheme.emerald : AppTheme.cobalt,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CopyableText(
                    exemptionTitle,
                    isSelectable: false,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l.customsDeclExemptionConditionsHeader,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: DisplayDensityMode.clampFontSize(12.5),
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 8),
          ...exemptionConditions.map((cond) => Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: hasExemption ? AppTheme.emerald : AppTheme.textMutedOf(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CopyableText(
                        cond,
                        isSelectable: false,
                        style: TextStyle(
                          fontSize: DisplayDensityMode.clampFontSize(12.0),
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
