import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/financial_settlement_model.dart';
import 'settlement_ui.dart';

/// Modal dialog that allows searching and selecting a previous Landed Cost Financial Settlement
/// to clone into a new draft following the 5-Task Enterprise Protocol.
class SearchAndCloneFinancialSettlementDialog extends ConsumerStatefulWidget {
  final List<LandedCostSettlementModel> records;
  final ValueChanged<LandedCostSettlementModel> onSelectRecord;

  const SearchAndCloneFinancialSettlementDialog({
    super.key,
    required this.records,
    required this.onSelectRecord,
  });

  @override
  ConsumerState<SearchAndCloneFinancialSettlementDialog> createState() =>
      _SearchAndCloneFinancialSettlementDialogState();
}

class _SearchAndCloneFinancialSettlementDialogState
    extends ConsumerState<SearchAndCloneFinancialSettlementDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = (screenWidth - 32).clamp(360.0, 920.0);
    final dialogHeight = (screenHeight * 0.82).clamp(420.0, 780.0);
    final allFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final importFilesMap = {for (final f in allFiles) f.importFileId: f};

    final query = _searchController.text.trim().toLowerCase();
    final filteredRecords = widget.records.where((rec) {
      if (_statusFilter != 'All' && rec.status != _statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;

      final codeMatch = rec.settlementCode.toLowerCase().contains(query);
      final accountantMatch = rec.accountantName.toLowerCase().contains(query);
      final matchingFile = importFilesMap[rec.importFileId];
      final fileCodeMatch = (matchingFile?.primaryNameWithCode ?? 'imp-${rec.importFileId}')
          .toLowerCase()
          .contains(query);
      final compMatch = (matchingFile?.companyName ?? '').toLowerCase().contains(query);

      return codeMatch || accountantMatch || fileCodeMatch || compMatch;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SelectionArea(
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettlementDialogHeader(
              icon: Icons.calculate_outlined,
              title: l.cloneFinancialSettlementDialogTitle,
              subtitle: l.cloneFinancialSettlementDialogSubtitle,
              onClose: () => Navigator.of(context).pop(),
              closeTooltip: l.cancel,
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l.financialSettlementSearchHint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchController,
                        builder: (context, val, _) => val.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : const SizedBox.shrink(),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildFilterChip('All', l.settlementFilterAll),
                      _buildFilterChip('Draft', l.financialSettlementStatusDraft),
                      _buildFilterChip('Calculated', l.financialSettlementStatusCalculated),
                      _buildFilterChip('Approved', l.financialSettlementStatusApproved),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            Expanded(
              child: filteredRecords.isEmpty
                  ? SettlementStateView.empty(
                      message: l.financialSettlementEmptyRecords,
                      icon: Icons.search_off,
                    )
                  : ListView.separated(
                      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
                      itemCount: filteredRecords.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final rec = filteredRecords[index];
                        final matchingFile = importFilesMap[rec.importFileId];
                        final fileCode = matchingFile?.primaryNameWithCode ?? 'IMP-${rec.importFileId}';
                        final compName = matchingFile?.companyName ?? '';
                        final fileTitle = compName.isNotEmpty ? '$fileCode - $compName' : fileCode;
                        final currencyStr = l.financialSettlementCurrencyEgp;

                        return SettlementPanel(
                          filled: true,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cobalt.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: CopyableText(
                                            rec.settlementCode,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.cobalt,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        _buildStatusBadge(context, rec.status),
                                        Text(
                                          l.financialSettlementAccountantLabel(rec.accountantName),
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textStrong),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      fileTitle,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.charcoal,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          '${l.financialSettlementMetricFobTotal}: ${formatSettlementMoney(rec.totalFobEgp)} $currencyStr',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textStrong),
                                        ),
                                        Text(
                                          '${l.financialSettlementMetricExpensesTotal}: ${formatSettlementMoney(rec.totalExpensesEgp)} $currencyStr',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${l.financialSettlementMetricLandedCostTotal}: ${formatSettlementMoney(rec.totalLandedCostEgp)} $currencyStr',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.emerald,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '${l.financialSettlementMetricMarkupFactor}: ${rec.averageMarkupFactor.toStringAsFixed(3)}x',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.cobalt,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SettlementFit(child: AppButton(
                                key: Key('selectSettlementToCloneBtn_${rec.settlementCode}'),
                                label: l.cloneFinancialSettlementTooltip,
                                icon: Icons.copy_all,
                                variant: AppButtonVariant.primary,
                                size: AppButtonSize.small,
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onSelectRecord(rec);
                                },
                              )),
                            ],
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

  Widget _buildFilterChip(String filterValue, String label) {
    final isSelected = _statusFilter == filterValue;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.white : AppTheme.charcoal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.cobalt,
      backgroundColor: SettlementTokens.tableHeadFill,
      onSelected: (val) {
        if (val) setState(() => _statusFilter = filterValue);
      },
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) =>
      settlementStatusChip(context, status, dense: true);
}
