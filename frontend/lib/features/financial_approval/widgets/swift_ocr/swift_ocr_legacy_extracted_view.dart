import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

class SwiftOcrLegacyExtractedView extends StatelessWidget {
  final Map<String, dynamic> extractedSwift;
  final Widget? matchingMatrixChild;

  const SwiftOcrLegacyExtractedView({
    super.key,
    required this.extractedSwift,
    this.matchingMatrixChild,
  });

  Widget _buildInfoField({
    required String label,
    required String value,
    required Color color,
    bool isBold = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.cloudWhite),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            const SizedBox(height: 2),
            CopyableText(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cobaltLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cobaltBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_balance, color: AppTheme.cobalt, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.swiftExtractorHeader,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.charcoal,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Ref: ${extractedSwift['transaction_reference'] ?? l10n.swiftStatusUnregistered}',
                          style: const TextStyle(
                            color: AppTheme.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildInfoField(
                      label: l10n.swiftColTransferredAmount,
                      value: '${extractedSwift['amount']} ${extractedSwift['currency']}',
                      color: AppTheme.emerald,
                      isBold: true,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoField(
                      label: l10n.swiftColSwiftDate,
                      value: extractedSwift['value_date_formatted'] ??
                          extractedSwift['value_date'] ??
                          '-',
                      color: AppTheme.charcoal,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoField(
                      label: l10n.swiftChargesLabel,
                      value: extractedSwift['charge_details'] ?? 'SHA',
                      color: AppTheme.emerald,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${l10n.swiftExtractedReceiverPrefix.replaceAll(':', '')}: ${extractedSwift['beneficiary_name'] ?? "-"}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${l10n.swiftCodeLabel.replaceAll(':', '')}: ${extractedSwift['beneficiary_bank_swift'] ?? "-"}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${l10n.swiftAccountLabel.replaceAll(':', '')}: ${extractedSwift['beneficiary_account_or_iban'] ?? "-"}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${l10n.swiftExtractedSenderPrefix.replaceAll(':', '')}: ${extractedSwift['ordering_customer_name'] ?? "-"} (${extractedSwift['ordering_account_or_iban'] ?? "-"})',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textStrong,
                  ),
                ),
                if (extractedSwift['pi_number'] != null ||
                    extractedSwift['payment_details'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.swiftRequestTitleLabel} ${extractedSwift['pi_number'] ?? extractedSwift['payment_details']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.cobalt,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (matchingMatrixChild != null) ...[
          const SizedBox(width: 14),
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.emeraldLight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.emeraldBorder),
              ),
              child: matchingMatrixChild!,
            ),
          ),
        ],
      ],
    );
  }
}
