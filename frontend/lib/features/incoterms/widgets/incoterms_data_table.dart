import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/widgets/widgets.dart';
import '../models/incoterm_model.dart';
import '../providers/incoterms_provider.dart';
import 'incoterm_edit_dialog.dart';

/// Data table widget displaying Incoterms rules with search, actions, and clipboard export.
class IncotermsDataTable extends ConsumerWidget {
  final List<IncotermModel> incoterms;

  const IncotermsDataTable({
    super.key,
    required this.incoterms,
  });

  /// Copy a list of Incoterms as TSV to the clipboard.
  static void copyIncotermsTsv(BuildContext context, List<IncotermModel> incoterms) {
    final l10n = context.l10n;
    final headers = [
      l10n.incotermsTsvHeaderCode,
      l10n.incotermsTsvHeaderName,
      l10n.incotermsTsvHeaderVersion,
      l10n.incotermsTsvHeaderDescription,
      l10n.incotermsTsvHeaderStatus,
    ];
    final rows = incoterms.map((i) => [
      i.incotermCode,
      i.incotermName,
      i.version,
      i.description ?? '',
      i.isActive ? l10n.statusActive : l10n.statusInactive,
    ]);
    final tsv = [
      headers.join('\t'),
      ...rows.map((r) => r.map((c) => c.toString().replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t')),
    ].join('\n');
    CopyHelper.copy(context, tsv, customMessage: l10n.incotermsExportTsvSuccess);
  }

  /// Builds a multi-line formatted summary of an Incoterm rule.
  static String buildIncotermSummary(BuildContext context, WidgetRef ref, IncotermModel i) {
    final l10n = context.l10n;
    final matrix = ref.read(responsibilityMatrixProvider).value ?? [];
    final responsibilities = matrix
        .where((r) => r.incotermId == i.incotermId || r.incotermCode == i.incotermCode)
        .toList();

    final b = StringBuffer();
    b.writeln('📋 ${l10n.incotermsScreenTitle}');
    b.writeln('${l10n.incotermCodeBadgeLabel}${i.incotermCode}');
    b.writeln('${l10n.incotermNameCol}: ${i.incotermName}');
    b.writeln('${l10n.incotermVersionCol}: ${i.version}');
    b.writeln('${l10n.incotermStatusCol}: ${i.isActive ? l10n.statusActive : l10n.statusInactive}');
    if (i.description != null && i.description!.isNotEmpty) {
      b.writeln('${l10n.incotermDescriptionLabel}: ${i.description}');
    }
    if (responsibilities.isNotEmpty) {
      b.writeln('\n${l10n.incotermResponsibilitiesSectionTitle}');
      for (final r in responsibilities) {
        final party = r.responsibleParty == 'Importer'
            ? l10n.partyBuyerImporter
            : (r.responsibleParty == 'Exporter' ? l10n.partySellerExporter : l10n.partyShared);
        final inc = r.includedInIncoterm ? l10n.includedInPriceYes : l10n.includedInPriceNo;
        b.writeln('• ${r.costItemName}: $party ($inc)');
      }
    }
    return b.toString().trim();
  }

  /// Single line TSV-style summary for row copying.
  static String buildIncotermRowSummary(AppLocalizations l10n, IncotermModel i) {
    return '${i.incotermCode}\t${i.incotermName}\t${i.version}\t${i.description ?? ""}\t${i.isActive ? l10n.statusActive : l10n.statusInactive}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return SelectionArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width > 1100
                      ? MediaQuery.of(context).size.width - 300
                      : 980,
                ),
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(220),
                    1: FixedColumnWidth(110),
                    2: FlexColumnWidth(2),
                    3: FixedColumnWidth(120),
                    4: FixedColumnWidth(95),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: AppTheme.charcoal),
                      children: [
                        l10n.incotermActionsCol,
                        l10n.incotermCodeCol,
                        l10n.incotermNameCol,
                        l10n.incotermVersionCol,
                        l10n.incotermStatusCol,
                      ]
                          .map((h) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Text(h,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ))
                          .toList(),
                    ),
                    ...incoterms.asMap().entries.map((entry) {
                      final i = entry.value;
                      final isEven = entry.key % 2 == 0;
                      return TableRow(
                        decoration: BoxDecoration(
                          color: isEven
                              ? AppTheme.surfaceOf(context)
                              : (AppTheme.isDark(context)
                                  ? AppTheme.darkSurface
                                  : Colors.grey.shade50),
                        ),
                        children: [
                          _cell(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: l10n.incotermCopySummaryBtn,
                                  child: InkWell(
                                    onTap: () => CopyHelper.copy(
                                      context,
                                      buildIncotermSummary(context, ref, i),
                                      customMessage: l10n.incotermCopySummarySuccess,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 5),
                                      margin: const EdgeInsetsDirectional.only(end: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.emerald.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: AppTheme.emerald.withValues(alpha: 0.3)),
                                      ),
                                      child: const Icon(
                                        Icons.copy_all_rounded,
                                        size: 15,
                                        color: AppTheme.emerald,
                                      ),
                                    ),
                                  ),
                                ),
                                RowActionsPill(
                                  onView: () => IncotermEditDialog.show(context, incoterm: i),
                                  onEdit: () => IncotermEditDialog.show(context, incoterm: i),
                                  onPrint: () {
                                    final matrix =
                                        ref.read(responsibilityMatrixProvider).value ?? [];
                                    MasterDataExportService.printOrSaveIncotermPdf(i, matrix);
                                  },
                                  printTooltip: l10n.exportIncotermsPdfBtn,
                                  onDelete: () async {
                                    final confirm = await AppConfirmDialog.showToggleActive(
                                      context,
                                      isCurrentlyActive: i.isActive,
                                      message: i.isActive
                                          ? l10n.confirmDeactivateIncoterm(i.incotermCode)
                                          : l10n.confirmActivateIncoterm(i.incotermCode),
                                    );
                                    if (confirm == true) {
                                      await ref
                                          .read(incotermsProvider.notifier)
                                          .toggleActive(i.incotermId, i.isActive);
                                    }
                                  },
                                  deleteTooltip: i.isActive
                                      ? l10n.deactivateIncotermTooltip
                                      : l10n.activateIncotermTooltip,
                                ),
                              ],
                            ),
                          ),
                          _cell(
                            child: CopyableTableCell(
                              value: i.incotermCode,
                              rowSummary: buildIncotermRowSummary(l10n, i),
                              child: Tooltip(
                                message: l10n.incotermsCopyFieldTooltip,
                                child: InkWell(
                                  onTap: () => CopyHelper.copy(context, i.incotermCode),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cobalt.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          i.incotermCode,
                                          style: const TextStyle(
                                              color: AppTheme.cobalt,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.copy_rounded,
                                            size: 12, color: AppTheme.cobalt),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _cell(
                            child: CopyableTableCell(
                              value:
                                  '${i.incotermName}${i.description != null ? " - ${i.description}" : ""}',
                              rowSummary: buildIncotermRowSummary(l10n, i),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(i.incotermName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.charcoal)),
                                  if (i.description != null)
                                    Text(i.description!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          ),
                          _cell(
                            child: CopyableTableCell(
                              value: i.version,
                              rowSummary: buildIncotermRowSummary(l10n, i),
                              child: Text(i.version,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                          _cell(
                            child: CopyableTableCell(
                              value: i.isActive ? l10n.statusActive : l10n.statusInactive,
                              rowSummary: buildIncotermRowSummary(l10n, i),
                              child: AppStatusBadge(
                                label: i.isActive ? l10n.statusActive : l10n.statusInactive,
                                severity: i.isActive ? AppSeverity.success : AppSeverity.danger,
                                size: AppStatusBadgeSize.small,
                              ),
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
      ),
    );
  }

  Widget _cell({required Widget child}) => TableRowInkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Align(alignment: AlignmentDirectional.centerStart, child: child),
        ),
      );
}
