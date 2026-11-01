import 'package:flutter/material.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../../../models/financial_approval_model.dart';

class SwiftPaymentSummaryBanner extends StatelessWidget {
  final PaymentRequestModel pay;

  const SwiftPaymentSummaryBanner({
    super.key,
    required this.pay,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cobaltLight.withValues(alpha: 0.5),
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
                child: Text(
                  '${l10n.swiftRequestTitleLabel} ${pay.title}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              if (pay.importFileCode != null)
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => CopyHelper.copy(
                    context,
                    pay.importFileCode!,
                  ),
                  child: Tooltip(
                    message: l10n.swiftCopyFieldTooltip,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.copy_rounded,
                            color: AppTheme.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            pay.importFileCode!,
                            style: const TextStyle(
                              color: AppTheme.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.swiftBeneficiaryLabel} ${pay.beneficiaryName ?? pay.supplierName}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  '${l10n.swiftBankLabel} ${pay.bankName ?? "-"} (${pay.swiftCode ?? "-"})',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.swiftRequestDateLabel}: ${pay.requestDate.isNotEmpty ? pay.requestDate : "-"}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.charcoal,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${l10n.swiftRequestedAmountLabel}: ${pay.requestedAmount.toStringAsFixed(2)} ${pay.currencyCode}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cobalt,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
