import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../l10n/container_eir_l10n.dart';
import '../models/demurrage_model.dart';
import '../providers/demurrage_provider.dart';
import 'container_eir_dialog.dart';
import 'demurrage_form_dialogs.dart';
import 'demurrage_tracking_card.dart';
import 'dual_clock_radar_dialog.dart';
import 'empty_container_return_dialog.dart';
import 'empty_return_form.dart';

/// Extension to conveniently access primary container number on DemurrageTrackingModel.
extension DemurrageTrackingModelContainerExt on DemurrageTrackingModel {
  String? get containerNumber {
    if (containers.isEmpty) return null;
    final first = containers.first;
    if (first is Map) {
      return (first['container_number'] ?? first['container_no'])?.toString();
    }
    return first?.toString();
  }
}

/// Helper dialog to display [EmptyReturnForm].
class EmptyReturnFormDialog {
  static Future<void> show({
    required BuildContext context,
    String? containerNumber,
    required Future<void> Function(EmptyReturnFormData data) onSubmit,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        backgroundColor: AppTheme.surfaceOf(ctx),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SelectionArea(
          child: Container(
            width: 580,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: EmptyReturnForm(
                containerNumber: containerNumber,
                onCancel: () => Navigator.of(ctx).pop(),
                onSubmit: (data) async {
                  await onSubmit(data);
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DemurrageTrackingsTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final VoidCallback onReload;

  const DemurrageTrackingsTab({
    super.key,
    this.initialImportFileId,
    required this.onReload,
  });

  @override
  ConsumerState<DemurrageTrackingsTab> createState() => _DemurrageTrackingsTabState();
}

class _DemurrageTrackingsTabState extends ConsumerState<DemurrageTrackingsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'All';

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyTrackingsTsv(List<DemurrageTrackingModel> trackings) {
    final l10n = context.l10n;
    final headers = [
      l10n.demurrageTsvHeaderTrackingCode,
      l10n.demurrageTsvHeaderBlNumber,
      l10n.demurrageTsvHeaderCarrier,
      l10n.demurrageTsvHeaderPort,
      l10n.demurrageTsvHeaderDischargeDate,
      l10n.demurrageTsvHeaderGateOutDate,
      l10n.demurrageTsvHeaderEmptyReturnDate,
      l10n.demurrageTsvHeaderContainersCount,
      l10n.demurrageTsvHeaderTotalDemurrageFx,
      l10n.demurrageTsvHeaderTotalDetentionFx,
      l10n.demurrageTsvHeaderTotalStorageEgp,
      l10n.demurrageTsvHeaderCurrency,
      l10n.demurrageTsvHeaderExchangeRate,
      l10n.demurrageTsvHeaderTotalCostEgp,
      l10n.demurrageTsvHeaderStatus,
      l10n.demurrageTsvHeaderPushedSettlement,
    ];

    final buffer = StringBuffer();
    buffer.writeln(headers.join('\t'));
    for (final t in trackings) {
      final row = [
        t.trackingCode,
        t.billOfLadingNo,
        t.carrierName,
        t.portName,
        t.dischargeDate,
        t.gateOutDate ?? l10n.notGatedOutYet,
        t.emptyReturnDate ?? l10n.notReturnedYet,
        t.containers.length.toString(),
        t.totalDemurrageFx.toStringAsFixed(2),
        t.totalDetentionFx.toStringAsFixed(2),
        t.totalStorageEgp.toStringAsFixed(2),
        t.currency,
        t.exchangeRate?.toStringAsFixed(2) ?? '-',
        t.totalCostEgp.toStringAsFixed(2),
        t.status,
        t.isPushedToSettlement ? l10n.lgxYes : l10n.lgxNo,
      ];
      buffer.writeln(row.join('\t'));
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.demurrageExportTsvSuccess,
    );
  }

  void _handlePushToSettlement(DemurrageTrackingModel item) async {
    final l10n = context.l10n;
    if (item.importFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l10n.demPushNeedsLinkedFile,
          severity: AppSeverity.warning,
        ),
      );
      return;
    }

    final confirmed = await DemurragePushToSettlementConfirmDialog.show(context, item);
    if (confirmed != true || !mounted) return;

    final res = await ref.read(demurrageProvider.notifier).pushToSettlement(
          item.trackingId,
          importFileId: item.importFileId,
        );
    if (!mounted) return;
    if (res != null && res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l10n.pushedToSettlementSuccessSnack, severity: AppSeverity.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          ApiErrorText.of(l10n, ref.read(demurrageProvider).errorObject, fallback: l10n.pushToSettlementErrorSnack),
          severity: AppSeverity.danger,
        ),
      );
    }
  }

  void _openEmptyReturn(DemurrageTrackingModel item) {
    EmptyReturnFormDialog.show(
      context: context,
      containerNumber: item.containerNumber,
      onSubmit: (data) async {
        final fileId = item.importFileId;
        if (fileId != null) {
          try {
            await ref.read(demurrageProvider.notifier).recordEmptyContainerReturn(
                  EmptyContainerReturnSubmitModel(
                    importFileId: fileId,
                    eirNumber: data.eirNumber,
                    emptyReturnDate: data.emptyReturnDate.toIso8601String().split('T').first,
                    depotName: data.depotName,
                    returnedContainers: item.containerNumber != null ? [item.containerNumber!] : null,
                    containerCondition: data.conditionStatus ?? 'SOUND_CLEAN',
                    notes: data.notes,
                  ),
                );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                AppTheme.snackBar(
                  context,
                  _isAr
                      ? 'تم توثيق تسليم الحاوية الفارغة بنجاح'
                      : 'Empty container return documented successfully',
                  severity: AppSeverity.success,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                AppTheme.snackBar(
                  context,
                  ApiErrorText.of(context.l10n, e, fallback: _isAr ? 'تعذر توثيق تسليم الحاوية' : 'Failed to record empty return'),
                  severity: AppSeverity.danger,
                ),
              );
            }
          }
        }
      },
    );
  }

  Widget _buildTrackingCard(DemurrageTrackingModel item) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DemurrageTrackingCard(
          item: item,
          onCopySummary: () {
            final summary = MasterDataExportService.generateDemurrageTrackingWhatsAppText(item, isAr: _isAr);
            CopyHelper.copy(context, summary, customMessage: l10n.demurrageCopySummarySuccess);
          },
          onPrintSlip: () => MasterDataExportService.printOrSaveDemurrageTrackingSlipPdf(context, item, isAr: _isAr),
          onOpenRadar: () => showDualClockRadarDialog(
            context,
            ref,
            trackingId: item.trackingId,
            billOfLadingNo: item.billOfLadingNo,
            carrierName: item.carrierName,
          ),
          onUpdateDates: () => UpdateTrackingDatesDialog.show(context, item),
          onReturnContainers: () => _openEmptyReturn(item),
          onPushToSettlement: () => _handlePushToSettlement(item),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                key: Key('returnEmptyContainerBtn_${item.trackingId}'),
                label: _isAr ? 'تسليم الحاوية الفارغة' : 'Return Empty',
                icon: Icons.assignment_return_outlined,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => _openEmptyReturn(item),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(List<DemurrageTrackingModel> filteredTrackings) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: AppTheme.toolbarDecorationOf(context),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, val, _) {
                return TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l10n.searchDemurrageHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: val.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 200,
            child: SearchableDropdownField<String>(
              labelText: l10n.statusFilterLabel,
              value: _selectedStatusFilter,
              items: [
                SearchableDropdownItem(value: 'All', label: l10n.allStatusesOption),
                SearchableDropdownItem(value: 'Free Time Active', label: l10n.statusFreeTimeActive),
                SearchableDropdownItem(value: 'Demurrage Incurred', label: l10n.statusDemurrageIncurred),
                SearchableDropdownItem(value: 'Detention Incurred', label: l10n.statusDetentionIncurred),
                SearchableDropdownItem(value: 'Pushed to Settlement', label: l10n.statusPushedToSettlement),
              ],
              onChanged: (v) => setState(() => _selectedStatusFilter = v ?? 'All'),
            ),
          ),
          CcUi.fit(AppButton(
            label: l10n.demurrageExportTsvBtn,
            icon: Icons.copy_all_rounded,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.small,
            onPressed: filteredTrackings.isEmpty ? null : () => _copyTrackingsTsv(filteredTrackings),
          )),
          CcUi.fit(AppButton(
            label: l10n.demurrageExportExcelBtn,
            icon: Icons.table_chart,
            variant: AppButtonVariant.success,
            size: AppButtonSize.small,
            onPressed: filteredTrackings.isEmpty
                ? null
                : () => MasterDataExportService.exportDemurrageTrackingsToExcel(
                      context,
                      filteredTrackings,
                      isAr: _isAr,
                    ),
          )),
          CcUi.fit(AppButton(
            label: l10n.demurrageExportPdfBtn,
            icon: Icons.picture_as_pdf,
            variant: AppButtonVariant.danger,
            size: AppButtonSize.small,
            onPressed: filteredTrackings.isEmpty
                ? null
                : () => MasterDataExportService.printOrSaveDemurrageTrackingsListPdf(
                      context,
                      filteredTrackings,
                      isAr: _isAr,
                    ),
          )),
          CcUi.fit(AppButton(
            label: l10n.startNewTrackingBtn,
            icon: Icons.add,
            size: AppButtonSize.small,
            onPressed: () => AddTrackingDialog.show(
              context,
              initialImportFileId: widget.initialImportFileId,
            ),
          )),
          CcUi.fit(AppButton(
            key: const Key('globalContainerEirLedgerBtn'),
            label: l10n.openContainerEirDialog,
            icon: Icons.assignment_turned_in,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            onPressed: () => ContainerEirDialog.showForFile(context, ref, importFileId: widget.initialImportFileId),
          )),
          CcUi.fit(AppButton(
            key: const Key('globalEmptyContainerReturnBtn'),
            label: l10n.demReturnContainersBtn,
            icon: Icons.assignment_turned_in_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => EmptyContainerReturnDialog.show(
              context,
              initialImportFileId: widget.initialImportFileId,
            ),
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(demurrageProvider);

    final filteredTrackings = state.trackings.where((t) {
      final matchesSearch = t.trackingCode.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          t.billOfLadingNo.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          t.carrierName.toLowerCase().contains(_searchController.text.toLowerCase());
      if (_selectedStatusFilter == 'All') return matchesSearch;
      return matchesSearch && t.status == _selectedStatusFilter;
    }).toList();

    final totalDemurrageEgp = state.trackings.fold<double>(0.0, (sum, t) => sum + t.totalCostEgp);
    final incurredCount = state.trackings.where((t) => t.status.contains('Incurred')).length;
    final activeCount = state.trackings.length;

    return RefreshIndicator(
      onRefresh: () async {
        if (!ref.read(demurrageProvider).isLoading) {
          await ref.read(demurrageProvider.notifier).loadInitialData();
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // KPI strip: short numeric values only
            CcUi.metrics([
              MetricCardData(
                title: l10n.totalActiveTrackingsMetric,
                value: '$activeCount',
                icon: Icons.all_inbox_rounded,
                color: AppTheme.cobalt,
              ),
              MetricCardData(
                title: l10n.incurredDemurrageShipmentsMetric,
                value: '$incurredCount',
                icon: Icons.warning_amber_rounded,
                color: AppTheme.crimson,
              ),
              MetricCardData(
                title: l10n.totalCalculatedDemurrageMetric,
                value: l10n.egpCurrencyAmount(CcFormat.money(totalDemurrageEgp)),
                icon: Icons.attach_money_rounded,
                color: AppTheme.orange,
              ),
            ]),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildToolbar(filteredTrackings),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: filteredTrackings.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: state.error != null && state.trackings.isEmpty
                          ? CcStateView.error(
                              message: ApiErrorText.of(l10n, state.errorObject ?? state.error, fallback: l10n.genericErrorSnack),
                              actionLabel: l10n.retry,
                              onAction: widget.onReload,
                            )
                          : CcStateView.empty(
                              message: l10n.noTrackingsFound,
                              actionLabel: l10n.startNewTrackingBtn,
                              onAction: () => AddTrackingDialog.show(
                                context,
                                initialImportFileId: widget.initialImportFileId,
                              ),
                            ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredTrackings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _buildTrackingCard(filteredTrackings[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
