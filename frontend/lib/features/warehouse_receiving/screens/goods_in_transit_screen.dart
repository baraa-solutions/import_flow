import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../inland_transport/widgets/inland_transport_dialog.dart';
import '../providers/goods_in_transit_provider.dart';
import '../services/goods_in_transit_export_service.dart';
import '../widgets/git_ledger_table.dart';
import '../widgets/ops_ui_kit.dart';

class GoodsInTransitScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const GoodsInTransitScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<GoodsInTransitScreen> createState() => _GoodsInTransitScreenState();
}

class _GoodsInTransitScreenState extends ConsumerState<GoodsInTransitScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedStatusFilter = 'In-Transit Only';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bookInland() async {
    final l = context.l10n;
    final allFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final eligibleFiles = allFiles.where((f) {
      if (!f.isActive) return false;
      final st = InlandStatus.codeOf(f.inlandTransportStatus);
      return !InlandStatus.isArrivedOrDelivered(st);
    }).toList();

    if (eligibleFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.wrNoFilesForBooking, severity: AppSeverity.warning),
      );
      return;
    }

    int? selectedFileId;
    final formKey = GlobalKey<FormState>();

    final chosen = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l.wrPickFileForBookingTitle),
          content: SizedBox(
            width: 450,
            child: Form(
              key: formKey,
              child: SearchableDropdownField<int>(
                key: const Key('gitPickFileForInlandField'),
                value: selectedFileId,
                labelText: l.settlementPickFileField,
                items: eligibleFiles.map((f) {
                  final label = f.companyName.isNotEmpty
                      ? '${f.primaryNameWithCode} - ${f.companyName}'
                      : f.primaryNameWithCode;
                  return SearchableDropdownItem<int>(
                    value: f.importFileId,
                    label: label,
                  );
                }).toList(),
                onChanged: (val) {
                  setDialogState(() {
                    selectedFileId = val;
                  });
                },
                validator: (v) =>
                    v == null ? l.financialSettlementImportFileValidator : null,
              ),
            ),
          ),
          actions: [
            AppButton(
              label: l.cancel,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(dialogCtx).pop(false),
            ),
            AppButton(
              key: const Key('gitPickFileForInlandContinueBtn'),
              label: l.settlementPickFileContinue,
              variant: AppButtonVariant.primary,
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogCtx).pop(true);
                }
              },
            ),
          ],
        ),
      ),
    );

    if (chosen != true || selectedFileId == null || !mounted) {
      return;
    }

    final target = eligibleFiles.firstWhere((f) => f.importFileId == selectedFileId);
    await InlandTransportDialog.show(context, target);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final gitAsync = ref.watch(goodsInTransitProvider);

    final tabs = [
      VerticalNavTabItem(
        icon: Icons.local_shipping_outlined,
        titleEn: l.gitLedgerTabTitle,
        titleAr: l.gitLedgerTabTitle,
      ),
    ];

    final bodyContent = SelectionArea(
      child: gitAsync.when(
        loading: () => const OpsLoadingView(),
        error: (err, stack) => OpsStateView.error(
          message: l.gitErrorFetchingData(err),
          actionLabel: l.gitRefreshTooltip,
          onAction: () => ref.invalidate(goodsInTransitProvider),
        ),
        data: (allItems) {
          final filteredItems = allItems.where((item) {
            if (_selectedStatusFilter == 'In-Transit Only' && item.isDeliveredToWarehouse) {
              return false;
            }
            if (_selectedStatusFilter == 'Delivered Only' && !item.isDeliveredToWarehouse) {
              return false;
            }
            if (_searchCtrl.text.trim().isEmpty) return true;
            final q = _searchCtrl.text.trim().toLowerCase();
            return item.importFileCode.toLowerCase().contains(q) ||
                item.poNumber.toLowerCase().contains(q) ||
                item.itemCode.toLowerCase().contains(q) ||
                item.itemName.toLowerCase().contains(q);
          }).toList();

          final activeItems = allItems.where((i) => !i.isDeliveredToWarehouse).toList();
          final uniqueFiles = activeItems.map((i) => i.importFileCode).toSet().length;
          final uniquePos = activeItems.map((i) => i.poNumber).toSet().length;
          final totalQty = activeItems.fold<double>(0.0, (s, i) => s + i.invoicedQty);
          final totalPkgs = activeItems.fold<int>(0, (s, i) => s + i.packagesCount);
          final totalContainers = activeItems.fold<int>(0, (s, i) => s + i.containersCount);
          final shipments = ref.watch(importFilesProvider).valueOrNull ?? [];

          final actionButtons = OpsActionWrap(
            children: [
              AppButton(
                label: l.gitCopyDossierBtn,
                icon: Icons.copy_all_outlined,
                size: AppButtonSize.small,
                variant: AppButtonVariant.ghost,
                onPressed: () => GoodsInTransitExportService.copyDossierToClipboard(context, filteredItems),
              ),
              AppButton(
                label: l.gitPrintPdfBtn,
                icon: Icons.picture_as_pdf_outlined,
                size: AppButtonSize.small,
                variant: AppButtonVariant.ghost,
                onPressed: () => GoodsInTransitExportService.printOrSaveGitPdf(context, filteredItems),
              ),
              AppButton(
                label: l.gitExportTsvBtn,
                icon: Icons.file_copy_outlined,
                size: AppButtonSize.small,
                variant: AppButtonVariant.ghost,
                onPressed: () => GoodsInTransitExportService.saveGitTsvToFile(context, filteredItems),
              ),
              AppButton(
                label: l.gitExportExcelBtn,
                icon: Icons.file_download_outlined,
                size: AppButtonSize.small,
                variant: AppButtonVariant.success,
                onPressed: () => GoodsInTransitExportService.saveGitCsvToFile(context, filteredItems),
              ),
              AppButton(
                key: const Key('inlandTransportScreenBtn'),
                label: l.wrInlandBookBtn,
                icon: Icons.local_shipping_rounded,
                size: AppButtonSize.small,
                onPressed: _bookInland,
              ),
            ],
          );

          return SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OpsInfoBanner(
                  icon: Icons.inventory_2_outlined,
                  title: l.gitInfoBannerTitle,
                  message: l.gitInfoBannerSubtitle,
                  actions: actionButtons,
                ),
                const SizedBox(height: 12),
                MetricCardStrip(
                  metrics: [
                    MetricCardData(
                      title: l.gitKpiInTransitShipments,
                      shortTitle: l.gitKpiInTransitShipments,
                      value: l.gitKpiShipmentsValue(uniqueFiles),
                      icon: Icons.folder_open,
                      color: AppTheme.cobalt,
                    ),
                    MetricCardData(
                      title: l.gitKpiPurchaseOrders,
                      shortTitle: l.gitKpiPurchaseOrders,
                      value: l.gitKpiPurchaseOrdersValue(uniquePos),
                      icon: Icons.receipt_long,
                      color: AppTheme.charcoal,
                    ),
                    MetricCardData(
                      title: l.gitKpiInvoicedQuantity,
                      shortTitle: l.gitKpiInvoicedQuantity,
                      value: l.gitKpiQuantityValue(totalQty.toStringAsFixed(0)),
                      icon: Icons.category,
                      color: AppTheme.orange,
                    ),
                    MetricCardData(
                      title: l.gitKpiPackagesCount,
                      shortTitle: l.gitKpiPackagesCount,
                      value: l.gitKpiPackagesValue(totalPkgs),
                      icon: Icons.all_inbox,
                      color: AppTheme.cobalt,
                    ),
                    MetricCardData(
                      title: l.gitKpiActiveContainers,
                      shortTitle: l.gitKpiActiveContainers,
                      value: l.gitKpiContainersValue(totalContainers),
                      icon: Icons.directions_boat,
                      color: AppTheme.emerald,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildFilterBar(l),
                const SizedBox(height: 12),
                OpsSectionCard(
                  title: l.gitTableSectionHeader,
                  icon: Icons.table_chart_outlined,
                  iconColor: AppTheme.emerald,
                  child: filteredItems.isEmpty
                      ? OpsStateView.empty(
                          compact: true,
                          icon: Icons.local_shipping_outlined,
                          message: l.gitNoDataFound,
                        )
                      : GitLedgerTable(items: filteredItems, shipments: shipments),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return VerticalStageScaffold(
      stageCode: 'PHASE-6: STEP_19',
      titleEn: l.gitLedgerScaffoldTitle,
      titleAr: l.gitLedgerScaffoldTitle,
      headerIcon: Icons.local_shipping,
      headerColor: AppTheme.emerald,
      tabs: tabs,
      selectedIndex: 0,
      onTabSelected: (_) {},
      headerActions: [
        IconButton(
          icon: Icon(Icons.refresh, color: AppTheme.white.withValues(alpha: 0.7), size: density.buttonIconSize),
          tooltip: l.warehouseReceivingRefreshTooltip,
          onPressed: () => ref.invalidate(goodsInTransitProvider),
        ),
      ],
      body: bodyContent,
    );
  }

  Widget _buildFilterBar(AppLocalizations l) {
    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: l.gitSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchCtrl,
                    builder: (context, value, _) {
                      if (value.text.isEmpty) return const SizedBox.shrink();
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                            tooltip: l.gitCopyFieldTooltip,
                            onPressed: () => CopyHelper.copy(context, _searchCtrl.text),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 200,
              child: SearchableDropdownField<String>(
                value: _selectedStatusFilter,
                items: [
                  SearchableDropdownItem(value: 'All', label: l.gitFilterAll),
                  SearchableDropdownItem(value: 'In-Transit Only', label: l.gitFilterInTransitOnly),
                  SearchableDropdownItem(value: 'Delivered Only', label: l.gitFilterDeliveredOnly),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStatusFilter = val);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.cobalt),
              tooltip: l.gitRefreshTooltip,
              onPressed: () => ref.read(goodsInTransitProvider.notifier).initLedger(),
            ),
          ],
        ),
      ),
    );
  }
}
