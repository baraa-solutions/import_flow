import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/master_data_action_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../../simulation/widgets/what_if_simulator_dialog.dart';
import '../providers/currencies_provider.dart';
import '../widgets/currencies_exchange_rate_table.dart';
import '../widgets/currency_converter_dialog.dart';
import '../widgets/currency_form_dialog.dart';
import '../widgets/currency_gain_loss_dialog.dart';
import '../widgets/currency_rate_history_dialog.dart';
import '../widgets/currency_rate_update_dialog.dart';

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
      final statusStr = c.isActive ? l10n.statusActive : l10n.statusInactive;
      final isBaseStr =
          c.isBaseCurrency ? l10n.baseCurrencyRateLabel : (c.isActive ? l10n.statusActive : l10n.statusInactive);
      final commRateStr = c.isBaseCurrency
          ? '1.0000'
          : (c.latestCommercialRate != null ? c.latestCommercialRate!.toStringAsFixed(4) : l10n.rateNotSet);
      final custRateStr = c.isBaseCurrency
          ? '1.0000'
          : (c.latestCustomsRate != null ? c.latestCustomsRate!.toStringAsFixed(4) : l10n.rateNotSet);
      buffer.writeln(
          '${c.currencyCode}\t${c.currencyName}\t${c.currencySymbol}\t$isBaseStr\t$commRateStr\t$custRateStr\t$statusStr\t${c.decimalPlaces}');
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.currenciesExportTsvSuccess,
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
                    onPressed: () => CurrencyFormDialog.show(context),
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
                    onPressed: () => CurrencyConverterDialog.show(context, ref),
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
                      CurrencyGainLossDialog.show(context, ref);
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
                      onEditCurrency: (c) => CurrencyFormDialog.show(context, currency: c),
                      onViewHistory: (c) => CurrencyRateHistoryDialog.show(context, ref, c),
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
}
