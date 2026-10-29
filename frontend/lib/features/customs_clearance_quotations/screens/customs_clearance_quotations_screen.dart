import '../../../core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../customs_consultation/widgets/price_list_form_dialog.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';
import '../models/customs_clearance_quotation_model.dart';
import '../providers/customs_clearance_quotations_provider.dart';
import '../services/customs_clearance_quotations_export_service.dart';
import '../widgets/quotation_dialogs.dart';
import '../widgets/rfq_card.dart';
import '../widgets/smart_clearance_extractor_dialog.dart';

// Other screens (customs consultation) open the smart extractor from here.
export '../widgets/smart_clearance_extractor_dialog.dart' show showSmartClearanceExtractorDialog;

class CustomsClearanceQuotationsScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const CustomsClearanceQuotationsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<CustomsClearanceQuotationsScreen> createState() =>
      _CustomsClearanceQuotationsScreenState();
}

class _CustomsClearanceQuotationsScreenState
    extends ConsumerState<CustomsClearanceQuotationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customsClearanceQuotationsProvider.notifier).fetchRFQs();
      ref.read(clearancePriceListProvider.notifier).fetchPriceList();
      ref.read(partnersProvider.notifier).fetchPartners();
      ref.read(importFilesProvider.notifier).fetchImportFiles();
      ref.read(transportLocationsProvider.notifier).fetchLocations();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(customsClearanceQuotationsProvider);
    ref.invalidate(clearancePriceListProvider);
    ref.invalidate(partnersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final tabBar = Container(
      color: AppTheme.surfaceOf(context),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.cobalt,
        indicatorWeight: 3,
        labelColor: AppTheme.cobalt,
        unselectedLabelColor: AppTheme.textSecondaryOf(context),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: [
          Tab(
            icon: const Icon(Icons.compare_arrows_rounded, size: 18),
            text: l10n.clearanceQuotesTabRfqs,
          ),
          Tab(
            icon: const Icon(Icons.price_change_rounded, size: 18),
            text: l10n.clearanceQuotesTabPriceLists,
          ),
        ],
      ),
    );

    final tabs = Expanded(
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildRFQsTab(),
          _buildPriceListsTab(),
        ],
      ),
    );

    if (widget.embedded) {
      return SelectionArea(
        child: Container(
          color: AppTheme.surfaceAltOf(context),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOf(context),
                  border: Border(bottom: BorderSide(color: AppTheme.borderOf(context))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.request_quote_rounded, color: AppTheme.cobalt, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.clearanceQuotesEmbeddedTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppTheme.charcoal),
                      tooltip: l10n.refresh,
                      onPressed: _refreshAll,
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      label: l10n.clearanceQuotesSmartExtractorBtn,
                      icon: Icons.auto_awesome,
                      variant: AppButtonVariant.success,
                      size: AppButtonSize.small,
                      onPressed: () => _showSmartExtractorDialog(null),
                    ),
                  ],
                ),
              ),
              tabBar,
              tabs,
            ],
          ),
        ),
      );
    }

    return SelectionArea(
      child: Scaffold(
        backgroundColor: AppTheme.surfaceAltOf(context),
        appBar: PageHeader(
          icon: Icons.request_quote_rounded,
          title: l10n.clearanceQuotesScreenTitle,
          subtitle: l10n.clearanceQuotesScreenSubtitle,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.white),
              tooltip: l10n.refresh,
              onPressed: _refreshAll,
            ),
          ],
        ),
        body: Column(children: [tabBar, tabs]),
      ),
    );
  }

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

  // ===========================================================================
  // TAB 1: RFQS & EVALUATOR
  // ===========================================================================

  /// Counts straight from the loaded RFQs (no extra calls, no new math).
  List<MetricCardData> _rfqMetrics(List<CustomsClearanceRFQModel> rfqs, AppLocalizations l10n) => [
        MetricCardData(
          title: l10n.ccqMetricRfqs,
          value: '${rfqs.length}',
          icon: Icons.compare_arrows_rounded,
          color: AppTheme.cobalt,
        ),
        MetricCardData(
          title: l10n.clearanceQuotesStatusDraft,
          value: '${rfqs.where((r) => r.status == 'Draft').length}',
          icon: Icons.edit_note_rounded,
          color: AppTheme.orange,
        ),
        MetricCardData(
          title: l10n.clearanceQuotesStatusReceived,
          value: '${rfqs.where((r) => r.status == 'Quotations Received').length}',
          icon: Icons.request_quote_outlined,
          color: AppTheme.charcoal,
        ),
        MetricCardData(
          title: l10n.clearanceQuotesStatusAwarded,
          value: '${rfqs.where((r) => r.status == 'Awarded').length}',
          icon: Icons.verified_outlined,
          color: AppTheme.emerald,
        ),
      ];

  Widget _buildRFQsTab() {
    final l10n = context.l10n;
    final rfqsState = ref.watch(customsClearanceQuotationsProvider);

    return rfqsState.when(
      loading: () => const CcStateView.loading(),
      error: (e, _) => CcStateView.error(
        message: '${l10n.clearanceQuotesErrorLoadingRfqs} ${ApiErrorText.of(l10n, e)}',
        actionLabel: l10n.retry,
        onAction: () => ref.read(customsClearanceQuotationsProvider.notifier).fetchRFQs(),
      ),
      data: (rfqs) {
        final q = _searchCtrl.text.trim().toLowerCase();
        final filtered = rfqs.where((r) {
          final matchesQuery = q.isEmpty ||
              r.rfqCode.toLowerCase().contains(q) ||
              r.title.toLowerCase().contains(q) ||
              r.portName.toLowerCase().contains(q);
          final matchesStatus = _selectedStatusFilter == 'ALL' || r.status == _selectedStatusFilter;
          return matchesQuery && matchesStatus;
        }).toList();

        final Widget content;
        if (filtered.isEmpty) {
          content = CcStateView.empty(
            message: l10n.clearanceQuotesNoRfqsFound,
            icon: rfqs.isEmpty ? Icons.inventory_2_outlined : Icons.search_off,
            actionLabel: rfqs.isEmpty ? l10n.clearanceQuotesCreateRfqBtn : null,
            onAction: rfqs.isEmpty ? () => showCreateRfqDialog(context, ref) : null,
          );
        } else {
          content = ListView.builder(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
            itemCount: filtered.length,
            itemBuilder: (ctx, idx) {
              final rfq = filtered[idx];
              return RfqCard(
                key: ValueKey('rfqCard_${rfq.rfqId}'),
                rfq: rfq,
                onSmartExtract: () => _showSmartExtractorDialog(rfq.rfqId),
                onAddQuote: () => showAddQuotationDialog(context, ref, rfq.rfqId),
                onAward: (quotationId) => confirmAwardQuotation(context, ref, rfq.rfqId, quotationId),
                onDeleteQuote: (quotationId) => confirmDeleteQuotation(context, ref, quotationId),
              );
            },
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8),
              child: CcUi.metrics(_rfqMetrics(rfqs, l10n)),
            ),
            _rfqToolbar(filtered, l10n),
            Expanded(child: content),
          ],
        );
      },
    );
  }

  Widget _rfqToolbar(List<CustomsClearanceRFQModel> filtered, AppLocalizations l10n) {
    final disabled = filtered.isEmpty;
    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
      decoration: AppTheme.toolbarDecorationOf(context),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: l10n.clearanceQuotesSearchHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: 220,
                child: SearchableDropdownField<String>(
                  key: const Key('quotationStatusFilter'),
                  value: _selectedStatusFilter,
                  labelText: l10n.clearanceQuotesStatusAll,
                  items: [
                    SearchableDropdownItem(value: 'ALL', label: l10n.clearanceQuotesStatusAll),
                    SearchableDropdownItem(value: 'Draft', label: l10n.clearanceQuotesStatusDraft),
                    SearchableDropdownItem(value: 'Quotations Received', label: l10n.clearanceQuotesStatusReceived),
                    SearchableDropdownItem(value: 'Awarded', label: l10n.clearanceQuotesStatusAwarded),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatusFilter = val);
                  },
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppButton(
                label: l10n.clearanceQuotesSmartExtractorBtn,
                icon: Icons.auto_awesome,
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                onPressed: () => _showSmartExtractorDialog(null),
              ),
              AppButton(
                label: l10n.clearanceQuotesCreateRfqBtn,
                icon: Icons.add_circle_outline_rounded,
                size: AppButtonSize.small,
                onPressed: () => showCreateRfqDialog(context, ref),
              ),
              _exportIcon(
                icon: Icons.table_view_rounded,
                color: AppTheme.cobalt,
                tooltip: l10n.clearanceQuotesExportTsvBtn,
                onPressed: disabled
                    ? null
                    : () => CustomsClearanceQuotationsExportService.exportRfqsTsv(context, filtered),
              ),
              _exportIcon(
                icon: Icons.grid_on_rounded,
                color: AppTheme.emerald,
                tooltip: l10n.clearanceQuotesExportExcelBtn,
                onPressed: disabled
                    ? null
                    : () => CustomsClearanceQuotationsExportService.exportRfqsExcel(context, filtered),
              ),
              _exportIcon(
                icon: Icons.picture_as_pdf_rounded,
                color: AppTheme.crimson,
                tooltip: l10n.clearanceQuotesPrintPdfBtn,
                onPressed: disabled
                    ? null
                    : () => CustomsClearanceQuotationsExportService.printOrSaveRfqsPdf(context, filtered),
              ),
              _exportIcon(
                icon: Icons.copy_all_rounded,
                color: AppTheme.charcoal,
                tooltip: l10n.clearanceQuotesCopyDossierBtn,
                onPressed: disabled
                    ? null
                    : () => CustomsClearanceQuotationsExportService.copyRfqDossier(context, filtered),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: PRICE LISTS MASTER
  // ===========================================================================

  Widget _buildPriceListsTab() {
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
              _priceListHeader(items, l10n),
              const SizedBox(height: 12),
              Expanded(
                child: items.isEmpty
                    ? CcStateView.empty(
                        message: l10n.clearanceQuotesNoPriceItemsFound,
                        icon: Icons.price_change_outlined,
                        actionLabel: l10n.clearanceQuotesAddPriceItemBtn,
                        onAction: () => showAddPriceItemDialog(context, ref),
                      )
                    : _priceListTable(items, l10n),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _priceListHeader(List<ClearancePriceListItemModel> items, AppLocalizations l10n) {
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

  Widget _priceListTable(List<ClearancePriceListItemModel> items, AppLocalizations l10n) {
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

  Future<void> _showSmartExtractorDialog(int? targetRfqId) async {
    await showSmartClearanceExtractorDialog(
      context,
      ref,
      targetRfqId: targetRfqId,
      onExtracted: (extracted) async {
        int? rfqId = targetRfqId;
        if (rfqId == null) {
          final rfqs = ref.read(customsClearanceQuotationsProvider).value ?? [];
          final activeRfqs = rfqs.where((r) => r.status != 'Awarded' && r.status != 'Cancelled').toList();
          if (activeRfqs.isNotEmpty) {
            rfqId = await showDialog<int>(
              context: context,
              builder: (ctx) {
                int? selected;
                return StatefulBuilder(
                  builder: (ctx, setPickerState) {
                    final l = ctx.l10n;
                    return Dialog(
                      backgroundColor: AppTheme.surfaceOf(ctx),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
                      child: SelectionArea(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.link_rounded, color: AppTheme.cobalt),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        l.isArabic ? 'ربط عرض السعر المستخرج بطلب أسعار' : 'Link Extracted Quote to RFQ',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l.isArabic
                                      ? 'اختر طلب عرض الأسعار المستهدف لإضافة هذا العرض إليه:'
                                      : 'Select the target RFQ to attach this quotation to:',
                                  style: TextStyle(color: AppTheme.textSecondaryOf(ctx), fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                SearchableDropdownField<int>(
                                  value: selected,
                                  labelText: l.isArabic ? 'طلب عرض السعر (RFQ)' : 'Target RFQ',
                                  searchHintText: l.searchPlaceholder,
                                  items: activeRfqs
                                      .map((r) => SearchableDropdownItem<int>(
                                            value: r.rfqId,
                                            label: '${r.rfqCode} - ${r.title}',
                                          ))
                                      .toList(),
                                  onChanged: (val) => setPickerState(() => selected = val),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    AppButton(
                                      label: l.cancel,
                                      variant: AppButtonVariant.secondary,
                                      size: AppButtonSize.small,
                                      onPressed: () => Navigator.pop(ctx, null),
                                    ),
                                    const SizedBox(width: 8),
                                    AppButton(
                                      label: l.confirm,
                                      variant: AppButtonVariant.primary,
                                      size: AppButtonSize.small,
                                      onPressed: selected != null ? () => Navigator.pop(ctx, selected) : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }
        }

        if (!mounted) return;
        if (rfqId != null) {
          showAddQuotationDialog(context, ref, rfqId, prefill: extracted);
        } else {
          showCreateRfqDialog(context, ref, initialPortName: extracted['port_name']?.toString());
        }
      },
    );
  }
}
