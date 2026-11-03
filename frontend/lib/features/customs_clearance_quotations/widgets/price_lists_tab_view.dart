import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../customs_consultation/widgets/price_list_form_dialog.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../models/customs_clearance_quotation_model.dart';
import '../providers/customs_clearance_quotations_provider.dart';
import '../services/customs_clearance_quotations_export_service.dart';
import 'quotation_dialogs.dart';

class PriceListsTabView extends ConsumerWidget {
  const PriceListsTabView({super.key});

  Widget _exportIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback? onPressed,
  }) =>
      IconButton(
        icon: Icon(icon, size: 20, color: onPressed == null ? null : color),
        tooltip: tooltip,
        onPressed: onPressed,
      );

  Widget _priceListHeader(BuildContext context, WidgetRef ref, List<ClearancePriceListItemModel> items, AppLocalizations l10n) {
    final disabled = items.isEmpty;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.clearanceQuotesPriceListTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                CcStatusChip(
                  label: '${l10n.ccqMetricPriceItems}: ${items.length}',
                  severity: AppSeverity.info,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.clearanceQuotesPriceListSubtitle,
              style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _exportIcon(
              icon: Icons.table_view_rounded,
              color: AppTheme.cobalt,
              tooltip: l10n.clearanceQuotesExportTsvBtn,
              onPressed: disabled
                  ? null
                  : () => CustomsClearanceQuotationsExportService.exportPriceListTsv(context, items),
            ),
            _exportIcon(
              icon: Icons.grid_on_rounded,
              color: AppTheme.emerald,
              tooltip: l10n.clearanceQuotesExportExcelBtn,
              onPressed: disabled
                  ? null
                  : () => CustomsClearanceQuotationsExportService.exportPriceListExcel(context, items),
            ),
            _exportIcon(
              icon: Icons.picture_as_pdf_rounded,
              color: AppTheme.crimson,
              tooltip: l10n.clearanceQuotesPrintPdfBtn,
              onPressed: disabled
                  ? null
                  : () => CustomsClearanceQuotationsExportService.printOrSavePriceListPdf(context, items),
            ),
            AppButton(
              label: l10n.clearanceQuotesManagePriceListBtn,
              icon: Icons.auto_awesome,
              variant: AppButtonVariant.success,
              size: AppButtonSize.small,
              onPressed: () {
                final partners = ref.read(partnersProvider).value ?? [];
                final brokersList = partners
                    .where((p) =>
                        p.partnerType == 'Customs Broker' ||
                        p.partnerType == 'مستخلص جمركي' ||
                        p.partnerType == 'Customs Clearance')
                    .toList();
                showPriceListFormDialog(
                  context,
                  ref,
                  brokersList: brokersList.isNotEmpty ? brokersList : partners,
                );
              },
            ),
            AppButton(
              label: l10n.clearanceQuotesAddPriceItemBtn,
              icon: Icons.add,
              size: AppButtonSize.small,
              onPressed: () => showAddPriceItemDialog(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  Widget _priceListTable(BuildContext context, WidgetRef ref, List<ClearancePriceListItemModel> items, AppLocalizations l10n) {
    return EnterpriseDataTable<ClearancePriceListItemModel>(
      storageKey: 'clearance_price_list_table',
      data: items,
      columns: [
        EnterpriseColumn<ClearancePriceListItemModel>(
          id: 'actions',
          title: l10n.clearanceQuotesColPriceDelete,
          width: 80,
          isSortable: false,
          isSearchable: false,
          isLocked: true,
          cellBuilder: (context, item, _) {
            final category =
                DomainEnums.label(l10n, DomainEnumType.clearanceServiceCategory, item.serviceCategory);
            final rowSummary =
                '${item.providerName} | ${item.portName} | $category | ${item.containerType} | ${item.unitPrice.toStringAsFixed(2)} ${item.currency}';
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                  tooltip: l10n.copy,
                  onPressed: () => CopyHelper.copy(context, rowSummary),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 18),
                  tooltip: l10n.delete,
                  onPressed: () async {
                    final confirmed = await AppConfirmDialog.showDelete(
                      context,
                      entityName: item.providerName,
                    );
                    if (confirmed) {
                      await ref.read(clearancePriceListProvider.notifier).deletePriceItem(item.priceItemId);
                    }
                  },
                ),
              ],
            );
          },
        ),
        EnterpriseColumn<ClearancePriceListItemModel>(
          id: 'provider_name',
          title: l10n.clearanceQuotesColBroker,
          isSortable: true,
          isSearchable: true,
          searchValue: (item) => item.providerName,
          exportValue: (item) => item.providerName,
          cellBuilder: (context, item, _) {
            final category =
                DomainEnums.label(l10n, DomainEnumType.clearanceServiceCategory, item.serviceCategory);
            final rowSummary =
                '${item.providerName} | ${item.portName} | $category | ${item.containerType} | ${item.unitPrice.toStringAsFixed(2)} ${item.currency}';
            return CopyableTableCell(
              value: item.providerName,
              rowSummary: rowSummary,
              child: Text(item.providerName, style: const TextStyle(fontWeight: FontWeight.bold)),
            );
          },
        ),
        EnterpriseColumn<ClearancePriceListItemModel>(
          id: 'port_name',
          title: l10n.clearanceQuotesColPricePort,
          isSortable: true,
          isSearchable: true,
          searchValue: (item) => item.portName,
          exportValue: (item) => item.portName,
          cellBuilder: (context, item, _) {
            final category =
                DomainEnums.label(l10n, DomainEnumType.clearanceServiceCategory, item.serviceCategory);
            final rowSummary =
                '${item.providerName} | ${item.portName} | $category | ${item.containerType} | ${item.unitPrice.toStringAsFixed(2)} ${item.currency}';
            return CopyableTableCell(
              value: item.portName,
              rowSummary: rowSummary,
              child: Text(item.portName),
            );
          },
        ),
        EnterpriseColumn<ClearancePriceListItemModel>(
          id: 'service_category',
          title: l10n.clearanceQuotesColPriceServiceType,
          isSortable: true,
          isSearchable: true,
          searchValue: (item) =>
              DomainEnums.label(l10n, DomainEnumType.clearanceServiceCategory, item.serviceCategory),
          exportValue: (item) =>
              DomainEnums.label(l10n, DomainEnumType.clearanceServiceCategory, item.serviceCategory),
          cellBuilder: (context, item, _) {
            final category =
                DomainEnums.label(l10n, DomainEnumType.clearanceServiceCategory, item.serviceCategory);
            final rowSummary =
                '${item.providerName} | ${item.portName} | $category | ${item.containerType} | ${item.unitPrice.toStringAsFixed(2)} ${item.currency}';
            return CopyableTableCell(
              value: category,
              rowSummary: rowSummary,
              child: Text(category),
            );
          },
        ),
        EnterpriseColumn<ClearancePriceListItemModel>(
          id: 'container_type',
          title: l10n.clearanceQuotesColPriceContainerType,
          isSortable: true,
          isSearchable: true,
          searchValue: (item) => item.containerType,
          exportValue: (item) => item.containerType,
          cellBuilder: (context, item, _) {
            final category =
                DomainEnums.label(l10n, DomainEnumType.clearanceServiceCategory, item.serviceCategory);
            final rowSummary =
                '${item.providerName} | ${item.portName} | $category | ${item.containerType} | ${item.unitPrice.toStringAsFixed(2)} ${item.currency}';
            return CopyableTableCell(
              value: item.containerType,
              rowSummary: rowSummary,
              child: Text(item.containerType),
            );
          },
        ),
        EnterpriseColumn<ClearancePriceListItemModel>(
          id: 'unit_price',
          title: l10n.clearanceQuotesColPriceStandardRate,
          isSortable: true,
          isNumeric: true,
          searchValue: (item) => '${item.unitPrice} ${item.currency}',
          exportValue: (item) => '${item.unitPrice} ${item.currency}',
          cellBuilder: (context, item, _) {
            final category =
                DomainEnums.label(l10n, DomainEnumType.clearanceServiceCategory, item.serviceCategory);
            final price = '${CcFormat.money(item.unitPrice)} ${item.currency}';
            final rowSummary =
                '${item.providerName} | ${item.portName} | $category | ${item.containerType} | ${item.unitPrice.toStringAsFixed(2)} ${item.currency}';
            return CopyableTableCell(
              value: price,
              rowSummary: rowSummary,
              child: LtrText(
                price,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.successForeground,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            );
          },
        ),
        EnterpriseColumn<ClearancePriceListItemModel>(
          id: 'notes',
          title: l10n.clearanceQuotesColPriceNotes,
          isSortable: false,
          isSearchable: true,
          searchValue: (item) => item.notes ?? '',
          exportValue: (item) => item.notes ?? '',
          cellBuilder: (context, item, _) {
            final category =
                DomainEnums.label(l10n, DomainEnumType.clearanceServiceCategory, item.serviceCategory);
            final notes = item.notes ?? '-';
            final rowSummary =
                '${item.providerName} | ${item.portName} | $category | ${item.containerType} | ${item.unitPrice.toStringAsFixed(2)} ${item.currency}';
            return CopyableTableCell(
              value: notes,
              rowSummary: rowSummary,
              child: Text(notes),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final priceListState = ref.watch(clearancePriceListProvider);

    return priceListState.when(
      loading: () => const CcStateView.loading(),
      error: (e, _) => CcStateView.error(
        message: '${l10n.clearanceQuotesErrorLoadingPriceList} ${ApiErrorText.of(l10n, e)}',
        actionLabel: l10n.retry,
        onAction: () => ref.read(clearancePriceListProvider.notifier).fetchPriceList(),
      ),
      data: (items) {
        return Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _priceListHeader(context, ref, items, l10n),
              const SizedBox(height: 12),
              Expanded(
                child: items.isEmpty
                    ? CcStateView.empty(
                        message: l10n.clearanceQuotesNoPriceItemsFound,
                        icon: Icons.price_change_outlined,
                        actionLabel: l10n.clearanceQuotesAddPriceItemBtn,
                        onAction: () => showAddPriceItemDialog(context, ref),
                      )
                    : _priceListTable(context, ref, items, l10n),
              ),
            ],
          ),
        );
      },
    );
  }
}
