import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/helpers/master_data_action_helper.dart';
import '../../../core/widgets/widgets.dart';
import '../models/currency_model.dart';
import '../widgets/currencies_exchange_rate_table.dart';
import '../widgets/currency_rate_update_dialog.dart';
import '../widgets/currency_form_dialog.dart';

import '../providers/currencies_provider.dart';
import '../../simulation/widgets/what_if_simulator_dialog.dart';


class CurrenciesScreen extends ConsumerStatefulWidget {
  const CurrenciesScreen({super.key});

  @override
  ConsumerState<CurrenciesScreen> createState() => _CurrenciesScreenState();
}

class _CurrenciesScreenState extends ConsumerState<CurrenciesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!ref.read(currenciesProvider).isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(currenciesProvider.notifier).fetchCurrencies();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyCurrenciesTsv(BuildContext context) {
    final l10n = context.l10n;
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    if (currencies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l10n.noCurrenciesFound, severity: AppSeverity.danger),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln([
      l10n.currenciesTsvHeaderIsoCode,
      l10n.currenciesTsvHeaderName,
      l10n.currenciesTsvHeaderSymbol,
      l10n.currenciesTsvHeaderIsBase,
      l10n.currenciesTsvHeaderCommercialRate,
      l10n.currenciesTsvHeaderCustomsRate,
      l10n.currenciesTsvHeaderStatus,
      l10n.currenciesTsvHeaderDecimals,
    ].join('\t'));

    for (final c in currencies) {
      buffer.writeln(_buildCurrencyRowSummary(l10n, c));
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.currenciesExportTsvSuccess,
    );
  }

  String _buildCurrencyRowSummary(AppLocalizations l10n, CurrencyModel c) {
    final statusStr = c.isActive ? l10n.statusActive : l10n.statusInactive;
    final isBaseStr = c.isBaseCurrency ? l10n.baseCurrencyRateLabel : (c.isActive ? l10n.statusActive : l10n.statusInactive);
    final commRateStr = c.isBaseCurrency
        ? '1.0000'
        : (c.latestCommercialRate != null ? c.latestCommercialRate!.toStringAsFixed(4) : l10n.rateNotSet);
    final custRateStr = c.isBaseCurrency
        ? '1.0000'
        : (c.latestCustomsRate != null ? c.latestCustomsRate!.toStringAsFixed(4) : l10n.rateNotSet);
    return '${c.currencyCode}\t${c.currencyName}\t${c.currencySymbol}\t$isBaseStr\t$commRateStr\t$custRateStr\t$statusStr\t${c.decimalPlaces}';
  }

  void _copySingleCurrencySummary(BuildContext context, CurrencyModel c) {
    final l10n = context.l10n;
    final summary = _buildCurrencyRowSummary(l10n, c);
    CopyHelper.copy(
      context,
      summary,
      customMessage: l10n.currencyCopySummarySuccess,
    );
  }

  Future<void> _syncOfficialCustomsExchangeRates(BuildContext context) async {
    final l10n = context.l10n;
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/integrations/nafeza/exchange-rates/sync');
      ref.read(currenciesProvider.notifier).fetchCurrencies();
      if (context.mounted) {
        final serverMsg = (Localizations.localeOf(context).languageCode == 'ar'
                ? res.data['message_ar']
                : res.data['message_en']) ??
            l10n.syncRatesSuccess;
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, serverMsg, severity: AppSeverity.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l10n.syncRatesFailed(e.toString()), severity: AppSeverity.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currenciesAsync = ref.watch(currenciesProvider);
    final density = ref.watch(displayDensityProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffoldBackground : AppTheme.cloudWhite,
      appBar: PageHeader(
        icon: Icons.currency_exchange,
        title: l10n.currenciesScreenTitle,
        subtitle: l10n.currenciesScreenSubtitle,
        actions: const [
          BackToDashboardButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ActionToolbar(
                primaryActions: [
                  AppButton(
                    label: l10n.addCurrencyBtn,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    icon: Icons.add,
                    onPressed: () => _showCurrencyDialog(context),
                  ),
                  AppButton(
                    label: l10n.updateExchangeRatesBtn,
                    variant: AppButtonVariant.success,
                    size: AppButtonSize.small,
                    icon: Icons.rate_review,
                    onPressed: () => CurrencyRateUpdateDialog.show(context),
                  ),
                  AppButton(
                    label: l10n.liveCurrencyConverterBtn,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    icon: Icons.currency_exchange,
                    onPressed: () => _showCurrencyConverterDialog(context),
                  ),
                ],
                moreActionItems: [
                  PopupMenuItem<String>(
                    value: 'gain_loss',
                    child: Row(
                      children: [
                        const Icon(Icons.trending_up, size: 16, color: AppTheme.orange),
                        const SizedBox(width: 8),
                        Text(l10n.currencyGainLossBtn),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'what_if',
                    child: Row(
                      children: [
                        const Icon(Icons.analytics_outlined, size: 16, color: AppTheme.crimson),
                        const SizedBox(width: 8),
                        Text(l10n.whatIfSimulatorBtn),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'sync_customs',
                    child: Row(
                      children: [
                        const Icon(Icons.sync, size: 16, color: AppTheme.charcoal),
                        const SizedBox(width: 8),
                        Text(l10n.syncOfficialCustomsRatesBtn),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  ...MasterDataActionHelper.buildStandardMoreActionItems(
                    context: context,
                    includeTsv: (currenciesAsync.valueOrNull ?? []).isNotEmpty,
                  ),
                ],
                onMoreActionSelected: (val) {
                  switch (val) {
                    case 'gain_loss':
                      _showGainLossCalculatorDialog(context);
                      break;
                    case 'what_if':
                      showDialog(
                        context: context,
                        builder: (context) => const WhatIfSimulatorDialog(),
                      );
                      break;
                    case 'sync_customs':
                      _syncOfficialCustomsExchangeRates(context);
                      break;
                    default:
                      MasterDataActionHelper.handleStandardAction(
                        context: context,
                        ref: ref,
                        actionValue: val,
                        moduleEndpoint: 'currencies',
                        entityNameAr: 'العملات وأسعار الصرف',
                        entityNameEn: 'Currencies & Exchange Rates',
                        entityFilePrefix: 'Currencies_Exchange_Rates',
                        onImportSuccess: () => ref.read(currenciesProvider.notifier).fetchCurrencies(),
                        onCopyTsv: () => _copyCurrenciesTsv(context),
                      );
                      break;
                  }
                },
                searchController: _searchController,
                searchHint: l10n.searchCurrenciesHint,
                onSearchChanged: (v) {
                  ref.read(currenciesProvider.notifier).fetchCurrencies(search: v);
                },
                quickDataActions: [
                  IconButton(
                    icon: Icon(Icons.refresh, size: density.buttonIconSize + 2),
                    tooltip: l10n.liveRefresh,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: density.buttonHeight,
                      minHeight: density.buttonHeight,
                    ),
                    onPressed: () => ref.read(currenciesProvider.notifier).fetchCurrencies(),
                  ),
                  if ((currenciesAsync.valueOrNull ?? []).isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.copy_rounded, size: density.buttonIconSize + 2, color: AppTheme.cobalt),
                      tooltip: l10n.currenciesExportTsvBtn,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: density.buttonHeight,
                        minHeight: density.buttonHeight,
                      ),
                      onPressed: () => _copyCurrenciesTsv(context),
                    ),
                ],
              ),
              const SizedBox(height: 8),

            // Table Content
            Expanded(
              child: currenciesAsync.when(
                loading: () => const AppLoadingState(),
                error: (err, stack) => AppErrorState(
                  message: l10n.currenciesFetchError(err.toString()),
                  onRetry: () => ref.read(currenciesProvider.notifier).fetchCurrencies(),
                ),
                data: (currencies) {
                  return CurrenciesExchangeRateTable(
                    currencies: currencies,
                    onEditCurrency: (c) => _showCurrencyDialog(context, currency: c),
                    onViewHistory: (c) => _showCurrencyRateHistoryDialog(context, ref, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showCurrencyDialog(BuildContext context, {CurrencyModel? currency}) {
    CurrencyFormDialog.show(context, currency: currency);
  }

  Widget _historyStatCard({
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

  void _showCurrencyRateHistoryDialog(BuildContext context, WidgetRef ref, CurrencyModel initialCurrency) {
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
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
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
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
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
                                            color: isLatest ? AppTheme.cobalt.withValues(alpha: 0.04) : AppTheme.surfaceOf(context),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            child: Row(
                                              children: [
                                                // Date Badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: isLatest ? AppTheme.cobalt : Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: isLatest ? AppTheme.cobalt : Colors.grey.shade300),
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
                                                          style: const TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.bold),
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
                                                            fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
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
                                                            fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.orange),
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

  // ─── Multi-Currency Conversion Dialog ─────────────────────────────────────

  void _showCurrencyConverterDialog(BuildContext context) {
    final l10n = context.l10n;
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController(text: '10000');
    String fromCurr = 'USD';
    String toCurr = 'EGP';
    String rateType = 'commercial';
    Map<String, dynamic>? resultData;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setSheetState) => SelectionArea(
          child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.currency_exchange, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Text(l10n.liveCurrencyConverterDialogTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SelectionArea(
            child: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.liveCurrencyConverterDialogSubtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: l10n.amountToConvertLabel,
                          hintText: l10n.amountToConvertHint,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: l10n.currencyCopyFieldTooltip,
                            onPressed: () => CopyHelper.copy(context, amountCtrl.text),
                          ),
                        ),
                        validator: (v) {
                          final val = double.tryParse(v ?? '');
                          if (val == null || val <= 0) return l10n.enterValidAmountError;
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SearchableDropdownField<String>(
                              value: fromCurr,
                              labelText: l10n.fromCurrencyLabel,
                              searchHintText: l10n.searchCurrenciesHint,
                              items: const [
                                SearchableDropdownItem(value: 'USD', label: 'USD'),
                                SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                                SearchableDropdownItem(value: 'GBP', label: 'GBP'),
                                SearchableDropdownItem(value: 'CNY', label: 'CNY'),
                                SearchableDropdownItem(value: 'SAR', label: 'SAR'),
                                SearchableDropdownItem(value: 'AED', label: 'AED'),
                                SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                              ],
                              onChanged: (v) {
                                if (v != null) setSheetState(() => fromCurr = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SearchableDropdownField<String>(
                              value: toCurr,
                              labelText: l10n.toCurrencyLabel,
                              searchHintText: l10n.searchCurrenciesHint,
                              items: const [
                                SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                                SearchableDropdownItem(value: 'USD', label: 'USD'),
                                SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                                SearchableDropdownItem(value: 'GBP', label: 'GBP'),
                                SearchableDropdownItem(value: 'CNY', label: 'CNY'),
                              ],
                              onChanged: (v) {
                                if (v != null) setSheetState(() => toCurr = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SearchableDropdownField<String>(
                        value: rateType,
                        labelText: l10n.appliedRateTypeLabel,
                        items: [
                          SearchableDropdownItem(value: 'commercial', label: l10n.rateTypeCommercialOption),
                          SearchableDropdownItem(value: 'customs', label: l10n.rateTypeCustomsOption),
                        ],
                        onChanged: (v) {
                          if (v != null) setSheetState(() => rateType = v);
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: l10n.convertCurrencyNowBtn,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.medium,
                          icon: Icons.calculate,
                          isLoading: isLoading,
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              setSheetState(() => isLoading = true);
                              final res = await ref.read(currenciesProvider.notifier).convertCurrency(
                                    amount: double.parse(amountCtrl.text.trim()),
                                    fromCurrency: fromCurr,
                                    toCurrency: toCurr,
                                    rateType: rateType,
                                  );
                              setSheetState(() {
                                resultData = res;
                                isLoading = false;
                              });
                            }
                          },
                        ),
                      ),
                      if (resultData != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.cobalt.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(l10n.convertedAmountLabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${resultData!['converted_amount']} ${resultData!['to_currency_code']}',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 17, color: AppTheme.cobalt),
                                        tooltip: l10n.copyValue,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => CopyHelper.copy(
                                          context,
                                          '${resultData!['converted_amount']} ${resultData!['to_currency_code']}',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 14),
                              Text(l10n.appliedRatePrefix(resultData!['applied_rate']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(l10n.baseEgpEquivalentPrefix(resultData!['base_currency_equivalent_egp']), style: const TextStyle(fontSize: 12)),
                              if (resultData!['summary_ar'] != null && Localizations.localeOf(context).languageCode == 'ar') ...[
                                const SizedBox(height: 6),
                                Text(resultData!['summary_ar'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.charcoal)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(l10n.closeBtn),
            ),
          ],
        ),
      ),
      ),
    ).then((_) {
      amountCtrl.dispose();
    });
  }

  // ─── FX Gain / Loss Engine Dialog ─────────────────────────────────────────

  void _showGainLossCalculatorDialog(BuildContext context) {
    final l10n = context.l10n;
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController(text: '50000');
    final initialRateCtrl = TextEditingController(text: '49.00');
    final settlementRateCtrl = TextEditingController(text: '47.50');
    String currencyCode = 'USD';
    Map<String, dynamic>? resultData;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setSheetState) => SelectionArea(
          child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.trending_up, color: AppTheme.orange),
              const SizedBox(width: 8),
              Text(l10n.fxGainLossDialogTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SelectionArea(
            child: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.fxGainLossDialogSubtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: l10n.foreignAmountLabel,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l10n.currencyCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, amountCtrl.text),
                                ),
                              ),
                              validator: (v) {
                                final val = double.tryParse(v ?? '');
                                if (val == null || val <= 0) return l10n.enterValidAmountError;
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SearchableDropdownField<String>(
                              value: currencyCode,
                              labelText: l10n.currencyLabel,
                              searchHintText: l10n.searchCurrenciesHint,
                              items: const [
                                SearchableDropdownItem(value: 'USD', label: 'USD'),
                                SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                                SearchableDropdownItem(value: 'GBP', label: 'GBP'),
                                SearchableDropdownItem(value: 'CNY', label: 'CNY'),
                              ],
                              onChanged: (v) {
                                if (v != null) setSheetState(() => currencyCode = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: initialRateCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: l10n.initialRateLabel,
                                hintText: l10n.initialRateHint,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l10n.currencyCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, initialRateCtrl.text),
                                ),
                              ),
                              validator: (v) {
                                final val = double.tryParse(v ?? '');
                                if (val == null || val <= 0) return l10n.enterValidRateError;
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: settlementRateCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: l10n.settlementRateLabel,
                                hintText: l10n.settlementRateHint,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l10n.currencyCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, settlementRateCtrl.text),
                                ),
                              ),
                              validator: (v) {
                                final val = double.tryParse(v ?? '');
                                if (val == null || val <= 0) return l10n.enterValidRateError;
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: l10n.calculateGainLossBtn,
                          variant: AppButtonVariant.warning,
                          size: AppButtonSize.medium,
                          icon: Icons.analytics,
                          isLoading: isLoading,
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              setSheetState(() => isLoading = true);
                              final res = await ref.read(currenciesProvider.notifier).calculateGainLoss(
                                    foreignAmount: double.parse(amountCtrl.text.trim()),
                                    currencyCode: currencyCode,
                                    initialRate: double.parse(initialRateCtrl.text.trim()),
                                    settlementRate: double.parse(settlementRateCtrl.text.trim()),
                                  );
                              setSheetState(() {
                                resultData = res;
                                isLoading = false;
                              });
                            }
                          },
                        ),
                      ),
                      if (resultData != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: (resultData!['is_gain'] as bool) ? AppTheme.emerald.withValues(alpha: 0.08) : AppTheme.crimson.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (resultData!['is_gain'] as bool) ? AppTheme.emerald.withValues(alpha: 0.4) : AppTheme.crimson.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  AppStatusBadge(
                                    label: resultData!['status_label'] ?? '',
                                    severity: (resultData!['is_gain'] as bool) ? AppSeverity.success : AppSeverity.danger,
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${resultData!['variance_egp']} EGP (${resultData!['percentage_change']}%)',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: (resultData!['is_gain'] as bool) ? AppTheme.emerald : AppTheme.crimson,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: Icon(
                                          Icons.copy_rounded,
                                          size: 17,
                                          color: (resultData!['is_gain'] as bool) ? AppTheme.emerald : AppTheme.crimson,
                                        ),
                                        tooltip: l10n.copyValue,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => CopyHelper.copy(
                                          context,
                                          '${resultData!['variance_egp']} EGP (${resultData!['percentage_change']}%)',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 14),
                              Text(l10n.initialCostAtBooking(resultData!['initial_amount_egp'], resultData!['initial_rate'])),
                              const SizedBox(height: 4),
                              Text(l10n.actualCostAtSettlement(resultData!['settlement_amount_egp'], resultData!['settlement_rate'])),
                              if (resultData!['summary_ar'] != null && Localizations.localeOf(context).languageCode == 'ar') ...[
                                const SizedBox(height: 8),
                                Text(
                                  resultData!['summary_ar'] ?? '',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(l10n.closeBtn),
            ),
          ],
        ),
      ),
      ),
    ).then((_) {
      amountCtrl.dispose();
      initialRateCtrl.dispose();
      settlementRateCtrl.dispose();
    });
  }
}


