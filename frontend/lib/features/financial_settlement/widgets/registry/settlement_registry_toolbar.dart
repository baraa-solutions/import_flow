import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/buttons/icon_action_button.dart';
import '../../models/financial_settlement_model.dart';
import '../settlement_ui.dart';
import 'settlement_export_helper.dart';

class SettlementRegistryToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final List<LandedCostSettlementModel> records;
  final Map<int, dynamic> importFilesMap;
  final VoidCallback onNewSettlement;
  final VoidCallback onSearchAndClone;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  const SettlementRegistryToolbar({
    super.key,
    required this.searchController,
    required this.records,
    required this.importFilesMap,
    required this.onNewSettlement,
    required this.onSearchAndClone,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SettlementPanel(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SettlementFit(
            child: AppButton(
              key: const Key('createSettlementBtn'),
              label: l10n.financialSettlementNewSettlementBtn,
              icon: Icons.add_chart,
              variant: AppButtonVariant.primary,
              onPressed: onNewSettlement,
            ),
          ),
          SettlementFit(
            child: AppButton(
              key: const Key('searchAndCloneSettlementBtn'),
              label: l10n.searchAndCloneFinancialSettlementBtn,
              icon: Icons.difference_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: onSearchAndClone,
            ),
          ),
          SizedBox(
            width: 240,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: l10n.financialSettlementSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchController,
                  builder: (context, value, _) {
                    return value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: onClearSearch,
                          )
                        : const SizedBox.shrink();
                  },
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: const OutlineInputBorder(),
              ),
              onChanged: onSearchChanged,
            ),
          ),
          SettlementFit(
            child: AppButton(
              key: const Key('copySettlementTableTsvBtn'),
              label: l10n.financialSettlementExportTsvBtn,
              icon: Icons.table_chart_outlined,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () {
                if (records.isNotEmpty) {
                  SettlementExportHelper.copySettlementRecordsTsv(context, records, importFilesMap);
                }
              },
            ),
          ),
          IconActionButton(
            key: const Key('exportSettlementExcelBtn'),
            icon: Icons.description_outlined,
            color: AppTheme.emerald,
            tooltip: l10n.exportFinancialSettlementExcelTooltip,
            iconSize: 20,
            onTap: () {
              if (records.isNotEmpty) {
                SettlementExportHelper.exportSettlementsExcel(context, records, l10n, importFilesMap);
              }
            },
          ),
          IconActionButton(
            key: const Key('exportSettlementPdfBtn'),
            icon: Icons.picture_as_pdf_outlined,
            color: AppTheme.crimson,
            tooltip: l10n.exportFinancialSettlementPdfTooltip,
            iconSize: 20,
            onTap: () {
              if (records.isNotEmpty) {
                SettlementExportHelper.exportSettlementsPdf(context, records, l10n, importFilesMap);
              }
            },
          ),
        ],
      ),
    );
  }
}
