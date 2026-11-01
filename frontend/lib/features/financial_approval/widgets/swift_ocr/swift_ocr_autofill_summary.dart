import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

class SwiftOcrAutofillSummary extends StatelessWidget {
  final Map<String, dynamic> autoFillSummary;
  final bool isDark;

  const SwiftOcrAutofillSummary({
    super.key,
    required this.autoFillSummary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.emeraldLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? AppTheme.emerald.withValues(alpha: 0.4)
              : AppTheme.emeraldBorder,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.emerald, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  '${l10n.requestedAmountLabel}: ${autoFillSummary['amount']} ${autoFillSummary['currency']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
                Text(
                  '${l10n.beneficiarySupplierLabel}: ${autoFillSummary['beneficiary_name'] ?? "-"}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
                Text(
                  '${l10n.paymentCodeCol}: ${autoFillSummary['transaction_reference'] ?? "-"}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
                Text(
                  '${l10n.swiftCodeLabel}: ${autoFillSummary['beneficiary_bank_swift'] ?? "-"}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
                Text(
                  '${l10n.ibanAccountLabel}: ${autoFillSummary['beneficiary_account_or_iban'] ?? "-"}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
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
