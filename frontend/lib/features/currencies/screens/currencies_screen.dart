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

import '../providers/currencies_provider.dart';
import '../../simulation/widgets/what_if_simulator_dialog.dart';


class CurrenciesScreen extends ConsumerStatefulWidget {
  const CurrenciesScreen({super.key});

  @override
  ConsumerState<CurrenciesScreen> createState() => _CurrenciesScreenState();
}

class _CurrenciesScreenState extends ConsumerState<CurrenciesScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _pageSize = 25;

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

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: PageHeader(
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
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, density.buttonHeight),
                      padding: density.buttonPadding,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: Icon(Icons.add, size: density.buttonIconSize),
                    label: Text(
                      l10n.addCurrencyBtn,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                    ),
                    onPressed: () => _showCurrencyDialog(context),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, density.buttonHeight),
                      padding: density.buttonPadding,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: Icon(Icons.rate_review, size: density.buttonIconSize),
                    label: Text(
                      l10n.updateExchangeRatesBtn,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                    ),
                    onPressed: () => _showAddRateDialog(context),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, density.buttonHeight),
                      padding: density.buttonPadding,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: Icon(Icons.currency_exchange, size: density.buttonIconSize),
                    label: Text(
                      l10n.liveCurrencyConverterBtn,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                    ),
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
                    case 'export_excel':
                      final currencies = currenciesAsync.valueOrNull ?? [];
                      if (currencies.isNotEmpty) {
                        MasterDataExportService.exportCurrenciesToExcel(context, currencies);
                      }
                      break;
                    case 'export_pdf':
                      MasterDataActionHelper.downloadFile(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'currencies',
                        actionEndpoint: 'export-pdf',
                        defaultFileName: 'Currencies_Report.pdf',
                        dialogTitle: 'تصدير العملات PDF',
                      );
                      break;
                    case 'copy_tsv':
                      _copyCurrenciesTsv(context);
                      break;
                    case 'download_template':
                      MasterDataActionHelper.downloadFile(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'currencies',
                        actionEndpoint: 'excel-template',
                        defaultFileName: 'Currencies_Template.xlsx',
                        dialogTitle: 'تنزيل نموذج العملات',
                      );
                      break;
                    case 'import_excel':
                      MasterDataActionHelper.importExcel(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'currencies',
                        onImportSuccess: () => ref.read(currenciesProvider.notifier).fetchCurrencies(),
                      );
                      break;
                  }
                },
                searchController: _searchController,
                searchHint: l10n.searchCurrenciesHint,
                onSearchChanged: (v) {
                  setState(() {
                    _currentPage = 1;
                  });
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
                  if (currencies.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.currency_exchange,
                      message: l10n.noCurrenciesFound,
                    );
                  }

                  final totalItems = currencies.length;
                  final totalPages = (totalItems / _pageSize).ceil();
                  final safeCurrentPage = _currentPage > totalPages && totalPages > 0 ? totalPages : _currentPage;
                  final startIndex = (safeCurrentPage - 1) * _pageSize;
                  final endIndex = (startIndex + _pageSize < totalItems) ? startIndex + _pageSize : totalItems;
                  final pagedCurrencies = totalItems > 0 && startIndex < totalItems
                      ? currencies.sublist(startIndex, endIndex)
                      : <CurrencyModel>[];

                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceOf(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderOf(context)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: MediaQuery.of(context).size.width > 1150
                                  ? MediaQuery.of(context).size.width - 300
                                  : 1050,
                            ),
                            child: Table(
                              columnWidths: const {
                                0: FixedColumnWidth(190),
                                1: FixedColumnWidth(110),
                                2: FlexColumnWidth(3),
                                3: FixedColumnWidth(90),
                                4: FlexColumnWidth(2.5),
                                5: FlexColumnWidth(2.5),
                                6: FixedColumnWidth(90),
                              },
                              children: [
                                // Header
                                TableRow(
                                  decoration: const BoxDecoration(color: AppTheme.charcoal),
                                  children: [
                                    l10n.actionsCol,
                                    l10n.isoCodeCol,
                                    l10n.currencyNameCol,
                                    l10n.currencySymbolCol,
                                    l10n.commercialRateBankCol,
                                    l10n.customsRateOfficialCol,
                                    l10n.statusCol,
                                  ]
                                      .map((h) => Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            child: Text(
                                              h,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),

                                // Data Rows
                                ...pagedCurrencies.asMap().entries.map((entry) {
                                  final c = entry.value;
                                  final isEven = entry.key % 2 == 0;
                                  final isActive = c.isActive;
                                  final rowSummary = _buildCurrencyRowSummary(l10n, c);

                                  return TableRow(
                                    decoration: BoxDecoration(
                                      color: isEven ? Colors.white : Colors.grey.shade50,
                                    ),
                                    children: [
                                      // Actions
                                      _cell(
                                        value: c.currencyCode,
                                        rowSummary: rowSummary,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.copy_all_rounded, size: 17, color: AppTheme.charcoal),
                                              tooltip: l10n.currencyCopySummaryBtn,
                                              onPressed: () => _copySingleCurrencySummary(context, c),
                                            ),
                                            const SizedBox(width: 4),
                                            RowActionsPill(
                                              onView: () => _showCurrencyRateHistoryDialog(context, ref, c),
                                              onEdit: () => _showCurrencyDialog(context, currency: c),
                                              onPrint: () => MasterDataExportService.printOrSaveCurrencyPdf(c),
                                              onDelete: c.isBaseCurrency
                                                  ? null
                                                  : () async {
                                                      final confirm = await AppConfirmDialog.showToggleActive(
                                                        context,
                                                        isCurrentlyActive: isActive,
                                                        message: isActive
                                                            ? l10n.confirmDeactivateCurrency(c.currencyCode, c.currencyName)
                                                            : l10n.confirmActivateCurrency(c.currencyCode, c.currencyName),
                                                      );
                                                      if (confirm == true && c.currencyId != null) {
                                                        ref.read(currenciesProvider.notifier).toggleActive(c.currencyId!, isActive);
                                                      }
                                                    },
                                              deleteTooltip: c.isBaseCurrency
                                                  ? l10n.cannotDeactivateBaseCurrencyTooltip
                                                  : (isActive ? l10n.deactivateCurrencyTooltip : l10n.activateCurrencyTooltip),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // ISO Code
                                      _cell(
                                        value: c.currencyCode,
                                        rowSummary: rowSummary,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () => CopyHelper.copy(
                                                context,
                                                c.currencyCode,
                                                customMessage: '${l10n.currencyCodeBadgeLabel}: ${c.currencyCode}',
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: (c.isBaseCurrency ? AppTheme.emerald : AppTheme.cobalt).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      c.currencyCode,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                        color: c.isBaseCurrency ? AppTheme.emerald : AppTheme.cobalt,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons.copy_rounded,
                                                      size: 11,
                                                      color: (c.isBaseCurrency ? AppTheme.emerald : AppTheme.cobalt).withValues(alpha: 0.7),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (c.isBaseCurrency)
                                              Padding(
                                                padding: const EdgeInsetsDirectional.only(start: 4),
                                                child: Tooltip(
                                                  message: l10n.baseCurrencyTooltip,
                                                  child: const Icon(Icons.star, size: 14, color: AppTheme.emerald),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // Currency Name
                                      _cell(
                                        value: c.currencyName,
                                        rowSummary: rowSummary,
                                        child: InkWell(
                                          onTap: () => _showCurrencyRateHistoryDialog(context, ref, c),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    c.currencyName,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: isActive ? AppTheme.cobalt : Colors.grey.shade700,
                                                      decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Tooltip(
                                                  message: l10n.viewRateHistoryTooltip,
                                                  child: Icon(
                                                    Icons.history_edu,
                                                    size: 16,
                                                    color: AppTheme.cobalt.withValues(alpha: 0.7),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Symbol
                                      _cell(
                                        value: c.currencySymbol,
                                        rowSummary: rowSummary,
                                        child: Text(
                                          c.currencySymbol,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                      ),

                                      // Commercial Rate
                                      _cell(
                                        value: c.isBaseCurrency
                                            ? '1.0000'
                                            : (c.latestCommercialRate != null
                                                ? c.latestCommercialRate!.toStringAsFixed(4)
                                                : l10n.rateNotSet),
                                        rowSummary: rowSummary,
                                        child: c.isBaseCurrency
                                            ? Text(l10n.baseCurrencyRateLabel,
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald))
                                            : Text(
                                                c.latestCommercialRate != null
                                                    ? l10n.rateToEgpFormatted(
                                                        c.currencyCode, c.latestCommercialRate!.toStringAsFixed(4))
                                                    : l10n.rateNotSet,
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                              ),
                                      ),

                                      // Customs Rate
                                      _cell(
                                        value: c.isBaseCurrency
                                            ? '1.0000'
                                            : (c.latestCustomsRate != null
                                                ? c.latestCustomsRate!.toStringAsFixed(4)
                                                : l10n.rateNotSet),
                                        rowSummary: rowSummary,
                                        child: c.isBaseCurrency
                                            ? Text(l10n.baseCurrencyRateLabel,
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald))
                                            : Text(
                                                c.latestCustomsRate != null
                                                    ? l10n.rateToEgpFormatted(
                                                        c.currencyCode, c.latestCustomsRate!.toStringAsFixed(4))
                                                    : l10n.rateNotSet,
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange),
                                              ),
                                      ),

                                      // Status
                                      _cell(
                                        value: isActive ? l10n.statusActive : l10n.statusInactive,
                                        rowSummary: rowSummary,
                                        child: AppStatusBadge(
                                          label: isActive ? l10n.statusActive : l10n.statusInactive,
                                          severity: isActive ? AppSeverity.success : AppSeverity.danger,
                                          size: AppStatusBadgeSize.small,
                                        ),
                                      ),

                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                      // Integrated Compact Pagination Footer
                      CompactTablePaginationFooter(
                        currentPage: safeCurrentPage,
                        totalPages: totalPages == 0 ? 1 : totalPages,
                        totalCount: totalItems,
                        pageSize: _pageSize,
                        isMobile: MediaQuery.sizeOf(context).width < 768,
                        onPageChanged: (newPage) => setState(() => _currentPage = newPage),
                      ),
                    ],
                  ),
                ),
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

  Widget _cell({
    required Widget child,
    required String value,
    String? rowSummary,
  }) =>
      CopyableTableCell(
        value: value,
        rowSummary: rowSummary,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Align(alignment: AlignmentDirectional.centerStart, child: child),
        ),
      );

  void _showCurrencyDialog(BuildContext context, {CurrencyModel? currency}) {
    final l10n = context.l10n;
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(text: currency?.currencyCode ?? '');
    final nameCtrl = TextEditingController(text: currency?.currencyName ?? '');
    final symbolCtrl = TextEditingController(text: currency?.currencySymbol ?? '');

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(currency == null
              ? l10n.addCurrencyDialogTitle
              : l10n.editCurrencyDialogTitle(currency.currencyCode)),
          content: SelectionArea(
            child: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeCtrl,
                      enabled: currency == null,
                      maxLength: 3,
                      decoration: InputDecoration(
                        labelText: l10n.isoCodeLabel,
                        hintText: l10n.isoCodeHint,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l10n.currencyCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, codeCtrl.text),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().length != 3
                          ? l10n.isoCodeLengthError
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.currencyNameLabel,
                        hintText: l10n.currencyNameHint,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l10n.currencyCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, nameCtrl.text),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.requiredField : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: symbolCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.currencySymbolLabel,
                        hintText: l10n.currencySymbolHint,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l10n.currencyCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, symbolCtrl.text),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.requiredField : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            if (currency != null)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: AppTheme.crimson),
                tooltip: l10n.exportCurrencyPdfBtn,
                onPressed: () => MasterDataExportService.printOrSaveCurrencyPdf(currency),
              ),
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSubmitting = true);
                        try {
                          if (currency == null) {
                            final newModel = CurrencyModel(
                              currencyCode: codeCtrl.text.trim().toUpperCase(),
                              currencyName: nameCtrl.text.trim(),
                              currencySymbol: symbolCtrl.text.trim(),
                            );
                            final ok = await ref
                                .read(currenciesProvider.notifier)
                                .createCurrency(newModel);
                            if (ok && context.mounted) Navigator.pop(dialogCtx);
                          } else {
                            final updateData = {
                              'currency_name': nameCtrl.text.trim(),
                              'currency_symbol': symbolCtrl.text.trim(),
                            };
                            final ok = await ref
                                .read(currenciesProvider.notifier)
                                .updateCurrency(
                                    currency.currencyId!, updateData);
                            if (ok && context.mounted) Navigator.pop(dialogCtx);
                          }
                        } finally {
                          if (context.mounted) {
                            setDialogState(() => isSubmitting = false);
                          }
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(currency == null
                      ? l10n.createCurrencySubmitBtn
                      : l10n.saveChangesSubmitBtn),
            ),
          ],
        ),
      ),
    ).then((_) {
      codeCtrl.dispose();
      nameCtrl.dispose();
      symbolCtrl.dispose();
    });
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
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showAddRateDialog(context, preSelectedCurrencyId: currency.currencyId);
                          },
                          icon: const Icon(Icons.add_chart, size: 16, color: Colors.white),
                          label: Text(l10n.recordNewExchangeRateBtn,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
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
                                      _showAddRateDialog(context, preSelectedCurrencyId: currency.currencyId);
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
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    l10n.rateSourcePrefix(rate.createdBy ?? "System"),
                                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                                                  ),
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

  void _showAddRateDialog(BuildContext context, {int? preSelectedCurrencyId}) {
    final l10n = context.l10n;
    final formKey = GlobalKey<FormState>();
    final currencies = ref.read(currenciesProvider).valueOrNull?.where((c) => !c.isBaseCurrency).toList() ?? [];
    if (currencies.isEmpty) return;

    int selectedCurrencyId = preSelectedCurrencyId ?? currencies.first.currencyId!;
    final commCtrl = TextEditingController();
    final custCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.updateExchangeRatesDialogTitle),
          content: SelectionArea(
            child: SizedBox(
              width: 450,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SearchableDropdownField<int?>(
                      value: selectedCurrencyId,
                      labelText: l10n.selectForeignCurrencyLabel,
                      searchHintText: l10n.searchCurrenciesHint,
                      items: currencies
                          .map((c) => SearchableDropdownItem<int?>(
                                value: c.currencyId,
                                label: '${c.currencyCode} — ${c.currencyName} (${c.currencySymbol})',
                                searchValue: '${c.currencyCode} ${c.currencyName}',
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedCurrencyId = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: commCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.commercialRateInputLabel,
                        hintText: l10n.rateInputHint,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l10n.currencyCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, commCtrl.text),
                        ),
                      ),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n <= 0) return l10n.enterValidRateError;
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: custCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.customsRateInputLabel,
                        hintText: l10n.rateInputHint,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l10n.currencyCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, custCtrl.text),
                        ),
                      ),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n <= 0) return l10n.enterValidRateError;
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppDatePickerField(
                      value: selectedDate,
                      label: l10n.effectiveDateLabel(selectedDate.toIso8601String().split('T').first),
                      onChanged: (picked) {
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSubmitting = true);
                        try {
                          final rateModel = ExchangeRateModel(
                            currencyId: selectedCurrencyId,
                            commercialRate: double.parse(commCtrl.text.trim()),
                            customsRate: double.parse(custCtrl.text.trim()),
                            effectiveDate: selectedDate.toIso8601String().split('T').first,
                          );
                          final ok = await ref.read(currenciesProvider.notifier).addExchangeRate(rateModel);
                          if (ok && context.mounted) Navigator.pop(dialogCtx);
                        } finally {
                          if (context.mounted) {
                            setDialogState(() => isSubmitting = false);
                          }
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.saveRateSubmitBtn),
            ),
          ],
        ),
      ),
    ).then((_) {
      commCtrl.dispose();
      custCtrl.dispose();
    });
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
        builder: (context, setSheetState) => AlertDialog(
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
                            child: DropdownButtonFormField<String>(
                              initialValue: fromCurr,
                              decoration: InputDecoration(labelText: l10n.fromCurrencyLabel, border: const OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'USD', child: Text('USD')),
                                DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                                DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                                DropdownMenuItem(value: 'CNY', child: Text('CNY')),
                                DropdownMenuItem(value: 'SAR', child: Text('SAR')),
                                DropdownMenuItem(value: 'AED', child: Text('AED')),
                                DropdownMenuItem(value: 'EGP', child: Text('EGP')),
                              ],
                              onChanged: (v) => setSheetState(() => fromCurr = v!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: toCurr,
                              decoration: InputDecoration(labelText: l10n.toCurrencyLabel, border: const OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'EGP', child: Text('EGP')),
                                DropdownMenuItem(value: 'USD', child: Text('USD')),
                                DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                                DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                                DropdownMenuItem(value: 'CNY', child: Text('CNY')),
                              ],
                              onChanged: (v) => setSheetState(() => toCurr = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: rateType,
                        decoration: InputDecoration(labelText: l10n.appliedRateTypeLabel, border: const OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(value: 'commercial', child: Text(l10n.rateTypeCommercialOption)),
                          DropdownMenuItem(value: 'customs', child: Text(l10n.rateTypeCustomsOption)),
                        ],
                        onChanged: (v) => setSheetState(() => rateType = v!),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cobalt,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(45),
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
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
                        icon: isLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.calculate, color: Colors.white),
                        label: Text(l10n.convertCurrencyNowBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
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
        builder: (context, setSheetState) => AlertDialog(
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
                            child: DropdownButtonFormField<String>(
                              initialValue: currencyCode,
                              decoration: InputDecoration(labelText: l10n.currencyLabel, border: const OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'USD', child: Text('USD')),
                                DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                                DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                                DropdownMenuItem(value: 'CNY', child: Text('CNY')),
                              ],
                              onChanged: (v) => setSheetState(() => currencyCode = v!),
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
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(45),
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
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
                        icon: isLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.analytics, color: Colors.white),
                        label: Text(l10n.calculateGainLossBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (resultData!['is_gain'] as bool) ? AppTheme.emerald : AppTheme.crimson,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      resultData!['status_label'] ?? '',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
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
    ).then((_) {
      amountCtrl.dispose();
      initialRateCtrl.dispose();
      settlementRateCtrl.dispose();
    });
  }
}


