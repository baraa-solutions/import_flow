import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/master_data_toolbar.dart';
import '../../models/financial_settlement_model.dart';
import '../actual_landed_cost_dialog.dart';
import '../final_settlement_invoices_dialog.dart';
import '../settlement_registry_card.dart';
import '../settlement_ui.dart';
import 'settlement_export_helper.dart';
import 'settlement_registry_toolbar.dart';

class SettlementRegistryView extends StatelessWidget {
  final AsyncValue<List<LandedCostSettlementModel>> recordsState;
  final Map<int, dynamic> importFilesMap;
  final TextEditingController searchController;
  final VoidCallback onReload;
  final VoidCallback onNewSettlement;
  final VoidCallback onSearchAndClone;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final void Function(int settlementId, String settlementCode) onOpenJournal;
  final void Function(LandedCostSettlementModel) onClone;

  const SettlementRegistryView({
    super.key,
    required this.recordsState,
    required this.importFilesMap,
    required this.searchController,
    required this.onReload,
    required this.onNewSettlement,
    required this.onSearchAndClone,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onOpenJournal,
    required this.onClone,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SelectionArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 32),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MasterDataToolbarWidget(
                    moduleEndpoint: 'financial-settlement',
                    title: 'Financial_Settlement',
                    onRefreshNeeded: onReload,
                  ),
                  const SizedBox(height: 12),
                  SettlementRegistryToolbar(
                    searchController: searchController,
                    records: recordsState.valueOrNull ?? [],
                    importFilesMap: importFilesMap,
                    onNewSettlement: onNewSettlement,
                    onSearchAndClone: onSearchAndClone,
                    onSearchChanged: onSearchChanged,
                    onClearSearch: onClearSearch,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            recordsState.when(
              loading: () => SliverFillRemaining(
                hasScrollBody: false,
                child: SettlementStateView.loading(message: l10n.settlementRegistryLoading),
              ),
              error: (err, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: SettlementStateView.error(
                  message: '${l10n.financialSettlementFetchError} ${ApiErrorText.of(l10n, err)}',
                  actionLabel: l10n.settlementRetry,
                  onAction: onReload,
                ),
              ),
              data: (records) {
                if (records.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: SettlementStateView.empty(
                      message: l10n.financialSettlementEmptyRecords,
                      icon: Icons.calculate_outlined,
                      actionLabel: l10n.settlementRegistryEmptyAction,
                      onAction: onNewSettlement,
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) {
                      final r = records[idx];
                      final matchingFile = importFilesMap[r.importFileId];
                      final fileCode = matchingFile?.importFileCode ?? 'IMP-${r.importFileId}';
                      return SettlementRegistryCard(
                        record: r,
                        importFileTitle: SettlementExportHelper.fileTitle(r, importFilesMap),
                        onOpenJournal: () => onOpenJournal(r.settlementId, r.settlementCode),
                        onCopyBreakdown: () => SettlementExportHelper.copySettlementBreakdownTsv(ctx, r, importFilesMap),
                        onCopyRow: () => SettlementExportHelper.copySettlementRowTsv(ctx, r, l10n, importFilesMap),
                        onClone: () => onClone(r),
                        onOpenInvoices: () => FinalSettlementInvoicesDialog.show(
                          ctx,
                          importFileId: r.importFileId,
                          importFileCode: fileCode,
                        ),
                        onOpenActualCost: () => ActualLandedCostDialog.show(
                          ctx,
                          importFileId: r.importFileId,
                          importFileCode: fileCode,
                        ),
                      );
                    },
                    childCount: records.length,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
