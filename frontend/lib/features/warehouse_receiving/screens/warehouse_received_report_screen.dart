import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../providers/warehouse_receiving_provider.dart';
import '../services/warehouse_received_report_export_service.dart';
import '../widgets/ops_ui_kit.dart';
import '../widgets/received_report_table.dart';

class WarehouseReceivedReportScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const WarehouseReceivedReportScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<WarehouseReceivedReportScreen> createState() => _WarehouseReceivedReportScreenState();
}

class _WarehouseReceivedReportScreenState extends ConsumerState<WarehouseReceivedReportScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!ref.read(warehouseReceivingProvider).isLoading) {
        ref.read(warehouseReceivingProvider.notifier).fetchRecords();
      }
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final recordsAsync = ref.watch(warehouseReceivingProvider);

    final tabs = [
      VerticalNavTabItem(
        icon: Icons.inventory_2_outlined,
        titleEn: l.whReportTabTitle,
        titleAr: l.whReportTabTitle,
      ),
    ];

    final bodyContent = SelectionArea(
      child: recordsAsync.when(
        loading: () => const OpsLoadingView(),
        error: (err, stack) => OpsStateView.error(
          message: l.whReportErrorFetchingData(err),
          actionLabel: l.warehouseReceivingRefreshTooltip,
          onAction: () => ref.read(warehouseReceivingProvider.notifier).fetchRecords(),
        ),
        data: (records) {
          final shipments = ref.watch(importFilesProvider).valueOrNull ?? [];
          final fileCodeById = {
            for (final f in shipments) f.importFileId: f.importFileCode,
          };
          final allItems = WarehouseReceivedReportItem.fromReceivingRecords(
            records,
            fileCodeById: fileCodeById,
          );

          final filtered = allItems.where((i) {
            if (_searchCtrl.text.trim().isEmpty) return true;
            final q = _searchCtrl.text.trim().toLowerCase();
            return i.importFileCode.toLowerCase().contains(q) ||
                i.poNumber.toLowerCase().contains(q) ||
                i.itemCode.toLowerCase().contains(q) ||
                i.itemName.toLowerCase().contains(q) ||
                i.warehouseName.toLowerCase().contains(q);
          }).toList();

          final totalInvoiced = filtered.fold<int>(0, (s, i) => s + i.invoicedQty);
          final totalReceived = filtered.fold<int>(0, (s, i) => s + i.receivedQty);
          final totalDamaged = filtered.fold<int>(0, (s, i) => s + i.damagedQty);
          final totalShortage = filtered.fold<int>(0, (s, i) => s + i.shortageQty);
          final totalVariance = filtered.fold<int>(0, (s, i) => s + i.varianceQty);

          final exportButtons = OpsActionWrap(
            children: [
              AppButton(
                label: l.whReportExportTsvBtn,
                icon: Icons.table_chart_outlined,
                size: AppButtonSize.small,
                variant: AppButtonVariant.ghost,
                onPressed: () => WarehouseReceivedReportExportService.saveReportTsvToFile(context, filtered),
              ),
              AppButton(
                label: l.whReportExportExcelBtn,
                icon: Icons.file_download_outlined,
                size: AppButtonSize.small,
                variant: AppButtonVariant.success,
                onPressed: () => WarehouseReceivedReportExportService.saveReportCsvToFile(context, filtered),
              ),
              AppButton(
                label: l.whReportPrintPdfBtn,
                icon: Icons.picture_as_pdf_outlined,
                size: AppButtonSize.small,
                variant: AppButtonVariant.ghost,
                onPressed: () => WarehouseReceivedReportExportService.printOrSaveReportPdf(context, filtered),
              ),
              AppButton(
                label: l.whReportCopyDossierBtn,
                icon: Icons.copy_all_outlined,
                size: AppButtonSize.small,
                variant: AppButtonVariant.ghost,
                onPressed: () => WarehouseReceivedReportExportService.copyDossierToClipboard(context, filtered),
              ),
            ],
          );

          return SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OpsInfoBanner(
                  icon: Icons.assessment_outlined,
                  title: l.whReportInfoBannerTitle,
                  message: l.whReportInfoBannerSubtitle,
                  actions: exportButtons,
                ),
                const SizedBox(height: 12),
                MetricCardStrip(
                  metrics: [
                    MetricCardData(
                      title: l.whReportKpiInvoicedQty,
                      shortTitle: l.whReportKpiInvoicedQty,
                      value: l.whReportUnitsValue(totalInvoiced),
                      icon: Icons.receipt_long,
                      color: AppTheme.cobalt,
                    ),
                    MetricCardData(
                      title: l.whReportKpiReceivedQty,
                      shortTitle: l.whReportKpiReceivedQty,
                      value: l.whReportUnitsValue(totalReceived),
                      icon: Icons.inventory,
                      color: AppTheme.emerald,
                    ),
                    MetricCardData(
                      title: l.whReportKpiDamagedQty,
                      shortTitle: l.whReportKpiDamagedQty,
                      value: l.whReportUnitsValue(totalDamaged),
                      icon: Icons.broken_image,
                      color: AppTheme.crimson,
                    ),
                    MetricCardData(
                      title: l.whReportKpiShortageQty,
                      shortTitle: l.whReportKpiShortageQty,
                      value: l.whReportUnitsValue(totalShortage),
                      icon: Icons.remove_circle_outline,
                      color: AppTheme.orange,
                    ),
                    MetricCardData(
                      title: l.whReportKpiVarianceQty,
                      shortTitle: l.whReportKpiVarianceQty,
                      value: '${totalVariance >= 0 ? "+" : ""}${l.whReportUnitsValue(totalVariance)}',
                      icon: Icons.compare_arrows,
                      color: totalVariance == 0 ? AppTheme.emerald : AppTheme.crimson,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: AppTheme.cardDecorationOf(context),
                  padding: const EdgeInsetsDirectional.all(10),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: l.whReportSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchCtrl,
                        builder: (context, value, _) {
                          if (value.text.isEmpty) return const SizedBox.shrink();
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                tooltip: l.whReportCopyFieldTooltip,
                                onPressed: () => CopyHelper.copy(
                                  context,
                                  _searchCtrl.text,
                                  customMessage: l.whReportSearchCopied,
                                ),
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
                const SizedBox(height: 12),
                OpsSectionCard(
                  title: l.whReportTableSectionHeader,
                  icon: Icons.fact_check,
                  child: filtered.isEmpty
                      ? OpsStateView.empty(
                          compact: true,
                          icon: Icons.inventory_2_outlined,
                          message: l.whReportNoDataFound,
                        )
                      : ReceivedReportTable(items: filtered, shipments: shipments),
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
      titleEn: l.whReportScaffoldTitle,
      titleAr: l.whReportScaffoldTitle,
      headerIcon: Icons.inventory_2_outlined,
      headerColor: AppTheme.cobalt,
      tabs: tabs,
      selectedIndex: 0,
      onTabSelected: (_) {},
      headerActions: [
        IconButton(
          icon: Icon(Icons.refresh, color: AppTheme.white.withOpacity(0.7), size: density.buttonIconSize),
          tooltip: l.warehouseReceivingRefreshTooltip,
          onPressed: () {
            ref.read(warehouseReceivingProvider.notifier).fetchRecords();
            ref.read(importFilesProvider.notifier).fetchImportFiles();
          },
        ),
      ],
      body: bodyContent,
    );
  }
}
