import 'package:flutter/material.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../models/cbm_calculator_model.dart';

class CbmDetailHeaderOverview extends StatelessWidget {
  final CBMCalculationModel calc;
  final String? rawFileCode;
  final String? resolvedShipmentTitle;
  final bool isDark;

  const CbmDetailHeaderOverview({
    super.key,
    required this.calc,
    required this.rawFileCode,
    required this.resolvedShipmentTitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkElevatedSurface
            : AppTheme.emeraldLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.emeraldBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  calc.title ?? l.calculationSessionTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
                if (calc.notes != null && calc.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    l.cbmCargoNotes(calc.notes!),
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  l.cbmCreationDate(calc.createdAt != null
                      ? calc.createdAt.toString().substring(0, 16)
                      : "—"),
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (rawFileCode != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkCardBackground
                          : AppTheme.charcoal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      resolvedShipmentTitle != null && resolvedShipmentTitle != rawFileCode
                          ? '$resolvedShipmentTitle ($rawFileCode)'
                          : l.cbmSessionImportFile(rawFileCode!),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                  ),
                if (calc.poNumber != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    l.cbmSessionLinkedPo(calc.poNumber!),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.emerald,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  l.cbmStrategy(calc.shippingMethodLabel(l)),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cobalt,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
