import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/partner_model.dart';
import 'partner_details_fields.dart';

class PartnerFinancialTermsSection extends StatelessWidget {
  final PartnerModel partner;

  const PartnerFinancialTermsSection({
    super.key,
    required this.partner,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PartnerDetailsFields.buildSectionHeader(
            context, Icons.payments_outlined, l10n.creditTermsSection),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.emerald.withValues(alpha: 0.1)
                : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isDark
                    ? AppTheme.emerald.withValues(alpha: 0.3)
                    : const Color(0xFFBBF7D0)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: PartnerDetailsFields.buildSimpleInfoField(
                      context: context,
                      label: l10n.paymentTermsDetailLabel,
                      value: (partner.paymentTerms != null &&
                              partner.paymentTerms!.isNotEmpty)
                          ? partner.paymentTerms!
                          : partner.paymentType,
                      icon: Icons.credit_score_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PartnerDetailsFields.buildSimpleInfoField(
                      context: context,
                      label: l10n.creditLimitDetailLabel,
                      value:
                          '${partner.creditLimit.toStringAsFixed(2)} ${l10n.soaCurrencyEgp}',
                      icon: Icons.monetization_on_outlined,
                    ),
                  ),
                  if (partner.defaultFreeDays != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: PartnerDetailsFields.buildSimpleInfoField(
                        context: context,
                        label: l10n.defaultFreeDaysLabel,
                        value: l10n.partnerFreeDaysBadge(partner.defaultFreeDays!),
                        icon: Icons.timer_outlined,
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  Expanded(
                    child: PartnerDetailsFields.buildSimpleInfoField(
                      context: context,
                      label: l10n.ratingDetailLabel,
                      value: '⭐ ${partner.rating.toStringAsFixed(1)} / 5.0',
                      icon: Icons.star_rate_rounded,
                    ),
                  ),
                ],
              ),
              if (partner.bankCode != null || partner.branchName != null) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PartnerDetailsFields.buildSimpleInfoField(
                        context: context,
                        label: l10n.bankCodeDetailLabel,
                        value: partner.bankCode ?? '-',
                        icon: Icons.account_balance,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PartnerDetailsFields.buildSimpleInfoField(
                        context: context,
                        label: l10n.branchNameDetailLabel,
                        value: partner.branchName ?? '-',
                        icon: Icons.storefront_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
