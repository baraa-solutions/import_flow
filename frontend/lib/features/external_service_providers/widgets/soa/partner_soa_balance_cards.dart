import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

class PartnerSoaBalanceCards extends StatelessWidget {
  final dynamic soa;
  final bool isDark;
  final String Function(double) formatNumber;

  const PartnerSoaBalanceCards({
    super.key,
    required this.soa,
    required this.isDark,
    required this.formatNumber,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (soa.equivalentEgpTotal != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.currency_exchange, color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    Directionality.of(context) == TextDirection.rtl
                        ? 'إجمالي الرصيد المكافئ بالجنيه المصري (سعر البنك التجاري بتاريخ ${soa.asOfDate ?? "اليوم"}):'
                        : 'Total Equivalent Balance in EGP (Commercial rate as of ${soa.asOfDate ?? "today"}):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                ),
                Text(
                  '${formatNumber(soa.equivalentEgpTotal!)} ${l10n.soaCurrencyEgp}',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cobalt,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (soa.hasUnconvertedBalances) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Directionality.of(context) == TextDirection.rtl
                        ? 'تنبيه: توجد عملات أجنبية ليس لها سعر صرف مسجل بتاريخ اليوم، لم يتم تحويلها للجنيه المصري.'
                        : 'Notice: Some foreign currencies have no exchange rate recorded as of today and are not included in the EGP total.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.multiCurrencyBalancesHeader,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            Text(
              l10n.invoicesCountLabel(soa.totalInvoicesCount, soa.totalPaymentsCount),
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? AppTheme.darkTextSecondary : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 105,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: soa.currencyBalances.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, idx) {
              final cb = soa.currencyBalances[idx];
              final isPositive = cb.balanceDue > 0;
              return Container(
                width: 230,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isPositive
                        ? AppTheme.orange.withValues(alpha: 0.4)
                        : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cb.currency,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.cobalt,
                          ),
                        ),
                        Icon(
                          Icons.monetization_on_outlined,
                          size: 16,
                          color: isPositive ? AppTheme.orange : AppTheme.emerald,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.totalInvoicedLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.black54,
                          ),
                        ),
                        Text(
                          formatNumber(cb.totalInvoiced),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.totalPaidLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.black54,
                          ),
                        ),
                        Text(
                          formatNumber(cb.totalPaid),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.emerald,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.balanceDueLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                        ),
                        Text(
                          formatNumber(cb.balanceDue),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isPositive ? AppTheme.crimson : AppTheme.emerald,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
