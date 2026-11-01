import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/master_data_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../models/currency_model.dart';
import '../providers/currencies_provider.dart';
import 'currency_rate_update_dialog.dart';

class CurrencyRateHistoryDialog {
  static void show(BuildContext context, WidgetRef ref, CurrencyModel initialCurrency) {
    if (initialCurrency.currencyId == null) return;
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SelectionArea(
          child: Container(
            width: 850,
            constraints: const BoxConstraints(maxHeight: 720),
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<CurrencyModel?>(
              future: ref.read(currenciesProvider.notifier).fetchCurrencyHistory(initialCurrency.currencyId!),
              builder: (context, snapshot) {
                final currency = snapshot.data ?? initialCurrency;
                final isLoading = snapshot.connectionState == ConnectionState.waiting;
                final rates = currency.exchangeRates ?? [];

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dialog Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: (currency.isBaseCurrency ? AppTheme.emerald : AppTheme.cobalt),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${currency.currencyCode} (${currency.currencySymbol})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.exchangeRateHistoryTitle(currency.currencyName),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.charcoal,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currency.isBaseCurrency
                                      ? l10n.baseCurrencySystemDesc
                                      : l10n.rateHistorySubtitle,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf, color: AppTheme.crimson),
                              tooltip: l10n.exportCurrencyPdfBtn,
                              onPressed: () => MasterDataExportService.printOrSaveCurrencyPdf(currency),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_all_rounded, color: AppTheme.charcoal),
                              tooltip: l10n.currencyCopySummaryBtn,
                              onPressed: () => _copySingleCurrencySummary(context, currency),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 1),

                    // Top Stats Cards
                    Row(
                      children: [
                        Expanded(
                          child: _historyStatCard(
                            title: l10n.currentCommercialRateStat,
                            value: currency.isBaseCurrency
                                ? '1.0000 EGP'
                                : (currency.latestCommercialRate != null
                                    ? '${currency.latestCommercialRate!.toStringAsFixed(4)} EGP'
                                    : l10n.notSetLabel),
                            icon: Icons.account_balance,
                            color: AppTheme.cobalt,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _historyStatCard(
                            title: l10n.currentCustomsRateStat,
                            value: currency.isBaseCurrency
                                ? '1.0000 EGP'
                                : (currency.latestCustomsRate != null
                                    ? '${currency.latestCustomsRate!.toStringAsFixed(4)} EGP'
                                    : l10n.notSetLabel),
                            icon: Icons.gavel,
                            color: AppTheme.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _historyStatCard(
                            title: l10n.rateSpreadStat,
                            value: (currency.latestCommercialRate != null && currency.latestCustomsRate != null)
                                ? '${(currency.latestCommercialRate! - currency.latestCustomsRate!).toStringAsFixed(4)} EGP'
                                : '0.0000 EGP',
                            icon: Icons.compare_arrows,
                            color: AppTheme.emerald,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _historyStatCard(
                            title: l10n.historicalUpdatesCountStat,
                            value: l10n.recordsCountBadge(rates.length),
                            icon: Icons.history,
                            color: AppTheme.charcoal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Action Button
                    if (!currency.isBaseCurrency)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.exchangeRateTimelineHeader,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.charcoal,
                            ),
                          ),
                          AppButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              CurrencyRateUpdateDialog.show(context, preSelectedCurrencyId: currency.currencyId);
                            },
                            icon: Icons.add_chart,
                            label: l10n.recordNewExchangeRateBtn,
                            variant: AppButtonVariant.success,
                            size: AppButtonSize.small,
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),

                    // History Table
                    Expanded(
                      child: isLoading
                          ? const AppLoadingState()
                          : (currency.isBaseCurrency
                              ? Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green.shade200),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 48),
                                        const SizedBox(height: 12),
                                        Text(
                                          l10n.baseCurrencyNoticeTitle,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.charcoal,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          l10n.baseCurrencyNoticeSubtitle,
                                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : (rates.isEmpty
                                  ? AppEmptyState(
                                      icon: Icons.history_toggle_off,
                                      message: l10n.noRateHistoryForCurrency(currency.currencyCode),
                                      actionLabel: l10n.recordFirstExchangeRateBtn,
                                      onAction: () {
                                        Navigator.pop(ctx);
                                        CurrencyRateUpdateDialog.show(context, preSelectedCurrencyId: currency.currencyId);
                                      },
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceOf(context),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.borderOf(context)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: ListView.separated(
                                          itemCount: rates.length,
                                          separatorBuilder: (_, __) => const Divider(height: 1),
                                          itemBuilder: (context, idx) {
                                            final rate = rates[idx];
                                            final diff = rate.commercialRate - rate.customsRate;
                                            final diffPct = rate.customsRate > 0 ? (diff / rate.customsRate) * 100 : 0.0;
                                            final isLatest = idx == 0;

                                            return Container(
                                              color: isLatest
                                                  ? AppTheme.cobalt.withValues(alpha: 0.04)
                                                  : AppTheme.surfaceOf(context),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              child: Row(
                                                children: [
                                                  // Date Badge
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: isLatest ? AppTheme.cobalt : Colors.grey.shade100,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: isLatest ? AppTheme.cobalt : Colors.grey.shade300,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      children: [
                                                        Text(
                                                          rate.effectiveDate,
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                            color: isLatest ? Colors.white : AppTheme.charcoal,
                                                          ),
                                                        ),
                                                        if (isLatest)
                                                          Text(
                                                            l10n.currentActiveRateBadge,
                                                            style: const TextStyle(
                                                              fontSize: 9,
                                                              color: Colors.white70,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),

                                                  // Commercial Rate
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(l10n.commercialBankRateLabel,
                                                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          '${rate.commercialRate.toStringAsFixed(4)} EGP',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 13,
                                                            color: AppTheme.cobalt,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  // Customs Rate
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(l10n.customsExchangeRateLabel,
                                                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          '${rate.customsRate.toStringAsFixed(4)} EGP',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 13,
                                                            color: AppTheme.orange,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  // Variance / Spread
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(l10n.spreadVarianceLabel,
                                                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          '${diff >= 0 ? "+" : ""}${diff.toStringAsFixed(4)} (${diffPct >= 0 ? "+" : ""}${diffPct.toStringAsFixed(2)}%)',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                            color: diff.abs() > 0.5 ? AppTheme.crimson : AppTheme.emerald,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  // Source / Created By
                                                  AppStatusBadge(
                                                    label: l10n.rateSourcePrefix(rate.createdBy ?? "System"),
                                                    severity: AppSeverity.info,
                                                    size: AppStatusBadgeSize.small,
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ))),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static Widget _historyStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _copySingleCurrencySummary(BuildContext context, CurrencyModel c) {
    final l10n = context.l10n;
    final statusStr = c.isActive ? l10n.statusActive : l10n.statusInactive;
    final isBaseStr = c.isBaseCurrency
        ? l10n.baseCurrencyRateLabel
        : (c.isActive ? l10n.statusActive : l10n.statusInactive);
    final commRateStr = c.isBaseCurrency
        ? '1.0000'
        : (c.latestCommercialRate != null ? c.latestCommercialRate!.toStringAsFixed(4) : l10n.rateNotSet);
    final custRateStr = c.isBaseCurrency
        ? '1.0000'
        : (c.latestCustomsRate != null ? c.latestCustomsRate!.toStringAsFixed(4) : l10n.rateNotSet);
    final summary =
        '${c.currencyCode}\t${c.currencyName}\t${c.currencySymbol}\t$isBaseStr\t$commRateStr\t$custRateStr\t$statusStr\t${c.decimalPlaces}';

    CopyHelper.copy(
      context,
      summary,
      customMessage: l10n.currencyCopySummarySuccess,
    );
  }
}
