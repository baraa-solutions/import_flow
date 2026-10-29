import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/widgets/widgets.dart';
import '../models/currency_model.dart';
import '../providers/currencies_provider.dart';

/// Data table widget displaying active currencies and their latest commercial & customs exchange rates.
class CurrenciesExchangeRateTable extends ConsumerWidget {
  final List<CurrencyModel> currencies;
  final void Function(CurrencyModel currency)? onEditCurrency;
  final void Function(CurrencyModel currency)? onViewHistory;

  const CurrenciesExchangeRateTable({
    super.key,
    required this.currencies,
    this.onEditCurrency,
    this.onViewHistory,
  });

  /// Copy a list of currencies as TSV to the clipboard.
  static void copyCurrenciesTsv(BuildContext context, List<CurrencyModel> currencies) {
    final l10n = context.l10n;
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
      buffer.writeln(buildCurrencyRowSummary(l10n, c));
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.currenciesExportTsvSuccess,
    );
  }

  /// Builds a TSV row representation of a single currency.
  static String buildCurrencyRowSummary(AppLocalizations l10n, CurrencyModel c) {
    final statusStr = c.isActive ? l10n.statusActive : l10n.statusInactive;
    final isBaseStr = c.isBaseCurrency
        ? l10n.baseCurrencyRateLabel
        : (c.isActive ? l10n.statusActive : l10n.statusInactive);
    final commRateStr = c.isBaseCurrency
        ? '1.0000'
        : (c.latestCommercialRate != null
            ? c.latestCommercialRate!.toStringAsFixed(4)
            : l10n.rateNotSet);
    final custRateStr = c.isBaseCurrency
        ? '1.0000'
        : (c.latestCustomsRate != null
            ? c.latestCustomsRate!.toStringAsFixed(4)
            : l10n.rateNotSet);
    return '${c.currencyCode}\t${c.currencyName}\t${c.currencySymbol}\t$isBaseStr\t$commRateStr\t$custRateStr\t$statusStr\t${c.decimalPlaces}';
  }

  /// Copy summary of a single currency row to clipboard.
  static void copySingleCurrencySummary(BuildContext context, CurrencyModel c) {
    final l10n = context.l10n;
    final summary = buildCurrencyRowSummary(l10n, c);
    CopyHelper.copy(
      context,
      summary,
      customMessage: l10n.currencyCopySummarySuccess,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return SelectionArea(
      child: EnterpriseDataTable<CurrencyModel>(
        storageKey: 'currencies_enterprise_table',
        data: currencies,
        minWidth: 1050,
        isScrollable: true,
        showHeaderToolbar: false,
        showPagination: true,
        initialPageSize: 25,
        emptyMessage: l10n.noCurrenciesFound,
        emptyIcon: Icons.currency_exchange,
        columns: _buildCurrencyColumns(context, ref, l10n),
      ),
    );
  }

  List<EnterpriseColumn<CurrencyModel>> _buildCurrencyColumns(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return [
      EnterpriseColumn<CurrencyModel>(
        id: 'actions',
        title: l10n.actionsCol,
        width: 190,
        isSortable: false,
        isSearchable: false,
        isLocked: true,
        cellBuilder: (ctx, c, _) {
          final isActive = c.isActive;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.copy_all_rounded, size: 17, color: AppTheme.charcoal),
                tooltip: l10n.currencyCopySummaryBtn,
                onPressed: () => copySingleCurrencySummary(context, c),
              ),
              const SizedBox(width: 4),
              RowActionsPill(
                onView: () => onViewHistory?.call(c),
                onEdit: () => onEditCurrency?.call(c),
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
                          ref
                              .read(currenciesProvider.notifier)
                              .toggleActive(c.currencyId!, isActive);
                        }
                      },
                deleteTooltip: c.isBaseCurrency
                    ? l10n.cannotDeactivateBaseCurrencyTooltip
                    : (isActive
                        ? l10n.deactivateCurrencyTooltip
                        : l10n.activateCurrencyTooltip),
              ),
            ],
          );
        },
      ),
      EnterpriseColumn<CurrencyModel>(
        id: 'currency_code',
        title: l10n.isoCodeCol,
        width: 110,
        sortComparator: (a, b) => a.currencyCode.compareTo(b.currencyCode),
        searchValue: (c) => c.currencyCode,
        exportValue: (c) => c.currencyCode,
        cellBuilder: (ctx, c, _) => Row(
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
                  color: (c.isBaseCurrency ? AppTheme.emerald : AppTheme.cobalt)
                      .withValues(alpha: 0.1),
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
                      color: (c.isBaseCurrency ? AppTheme.emerald : AppTheme.cobalt)
                          .withValues(alpha: 0.7),
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
      EnterpriseColumn<CurrencyModel>(
        id: 'currency_name',
        title: l10n.currencyNameCol,
        flex: 3,
        sortComparator: (a, b) => a.currencyName.compareTo(b.currencyName),
        searchValue: (c) => c.currencyName,
        exportValue: (c) => c.currencyName,
        cellBuilder: (ctx, c, _) {
          final isActive = c.isActive;
          return InkWell(
            onTap: () => onViewHistory?.call(c),
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
                        decoration:
                            isActive ? TextDecoration.none : TextDecoration.lineThrough,
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
          );
        },
      ),
      EnterpriseColumn<CurrencyModel>(
        id: 'currency_symbol',
        title: l10n.currencySymbolCol,
        width: 90,
        sortComparator: (a, b) => a.currencySymbol.compareTo(b.currencySymbol),
        searchValue: (c) => c.currencySymbol,
        exportValue: (c) => c.currencySymbol,
        cellBuilder: (ctx, c, _) => Text(
          c.currencySymbol,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      EnterpriseColumn<CurrencyModel>(
        id: 'latest_commercial_rate',
        title: l10n.commercialRateBankCol,
        flex: 2,
        isNumeric: true,
        sortComparator: (a, b) =>
            (a.latestCommercialRate ?? 0).compareTo(b.latestCommercialRate ?? 0),
        searchValue: (c) =>
            c.isBaseCurrency ? '1.0000' : (c.latestCommercialRate?.toStringAsFixed(4) ?? ''),
        exportValue: (c) => c.isBaseCurrency
            ? '1.0000'
            : (c.latestCommercialRate != null
                ? c.latestCommercialRate!.toStringAsFixed(4)
                : l10n.rateNotSet),
        cellBuilder: (ctx, c, _) => c.isBaseCurrency
            ? Text(
                l10n.baseCurrencyRateLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
              )
            : Text(
                c.latestCommercialRate != null
                    ? l10n.rateToEgpFormatted(
                        c.currencyCode, c.latestCommercialRate!.toStringAsFixed(4))
                    : l10n.rateNotSet,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
              ),
      ),
      EnterpriseColumn<CurrencyModel>(
        id: 'latest_customs_rate',
        title: l10n.customsRateOfficialCol,
        flex: 2,
        isNumeric: true,
        sortComparator: (a, b) =>
            (a.latestCustomsRate ?? 0).compareTo(b.latestCustomsRate ?? 0),
        searchValue: (c) =>
            c.isBaseCurrency ? '1.0000' : (c.latestCustomsRate?.toStringAsFixed(4) ?? ''),
        exportValue: (c) => c.isBaseCurrency
            ? '1.0000'
            : (c.latestCustomsRate != null
                ? c.latestCustomsRate!.toStringAsFixed(4)
                : l10n.rateNotSet),
        cellBuilder: (ctx, c, _) => c.isBaseCurrency
            ? Text(
                l10n.baseCurrencyRateLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
              )
            : Text(
                c.latestCustomsRate != null
                    ? l10n.rateToEgpFormatted(
                        c.currencyCode, c.latestCustomsRate!.toStringAsFixed(4))
                    : l10n.rateNotSet,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange),
              ),
      ),
      EnterpriseColumn<CurrencyModel>(
        id: 'status',
        title: l10n.statusCol,
        width: 95,
        sortComparator: (a, b) => (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0),
        searchValue: (c) => c.isActive ? l10n.statusActive : l10n.statusInactive,
        exportValue: (c) => c.isActive ? l10n.statusActive : l10n.statusInactive,
        cellBuilder: (ctx, c, _) {
          final isActive = c.isActive;
          return AppStatusBadge(
            label: isActive ? l10n.statusActive : l10n.statusInactive,
            severity: isActive ? AppSeverity.success : AppSeverity.danger,
            size: AppStatusBadgeSize.small,
          );
        },
      ),
    ];
  }
}
