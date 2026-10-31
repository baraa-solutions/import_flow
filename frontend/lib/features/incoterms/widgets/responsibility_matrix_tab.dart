import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/incoterm_model.dart';
import '../providers/incoterms_provider.dart';

/// تبويب مصفوفة المسؤوليات للشروط الدولية
class ResponsibilityMatrixTab extends ConsumerStatefulWidget {
  const ResponsibilityMatrixTab({super.key});

  @override
  ConsumerState<ResponsibilityMatrixTab> createState() => _ResponsibilityMatrixTabState();
}

class _ResponsibilityMatrixTabState extends ConsumerState<ResponsibilityMatrixTab> {
  int? _selectedIncotermId;

  static String _getCategoryLabel(AppLocalizations l10n, String category) {
    switch (category) {
      case 'Freight':
        return l10n.costCategoryFreight;
      case 'Customs':
        return l10n.costCategoryCustoms;
      case 'Port':
        return l10n.costCategoryPort;
      case 'Bank':
        return l10n.costCategoryBank;
      default:
        return l10n.costCategoryOther;
    }
  }

  void _copyMatrixTsv(BuildContext context, List<IncotermResponsibilityModel> matrix) {
    final l10n = context.l10n;
    final headers = [
      l10n.matrixTsvHeaderIncoterm,
      l10n.matrixTsvHeaderCostItem,
      l10n.matrixTsvHeaderCategory,
      l10n.matrixTsvHeaderResponsible,
      l10n.matrixTsvHeaderIncluded,
      l10n.matrixTsvHeaderNotes,
    ];
    final rows = matrix.map((r) {
      final party = r.responsibleParty == 'Importer'
          ? l10n.partyBuyerImporter
          : (r.responsibleParty == 'Exporter' ? l10n.partySellerExporter : l10n.partyShared);
      return [
        r.incotermCode ?? '',
        r.costItemName ?? '',
        _getCategoryLabel(l10n, r.costCategory ?? ''),
        party,
        r.includedInIncoterm ? l10n.includedInPriceYes : l10n.includedInPriceNo,
        r.notes ?? '',
      ];
    });
    final tsv = [
      headers.join('\t'),
      ...rows.map((r) => r.map((c) => c.toString().replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t')),
    ].join('\n');
    CopyHelper.copy(context, tsv, customMessage: l10n.matrixExportTsvSuccess);
  }

  String _buildMatrixRowSummary(AppLocalizations l10n, IncotermResponsibilityModel r) {
    final party = r.responsibleParty == 'Importer'
        ? l10n.partyBuyerImporter
        : (r.responsibleParty == 'Exporter' ? l10n.partySellerExporter : l10n.partyShared);
    final inc = r.includedInIncoterm ? l10n.includedInPriceYes : l10n.includedInPriceNo;
    return '${r.incotermCode ?? ""}\t${r.costItemName ?? ""}\t${_getCategoryLabel(l10n, r.costCategory ?? "")}\t$party\t$inc\t${r.notes ?? ""}';
  }

  void _showEditResponsibilityDialog(BuildContext context, WidgetRef ref, IncotermResponsibilityModel r) {
    final l10n = context.l10n;
    String selectedParty = r.responsibleParty;
    bool isIncluded = r.includedInIncoterm;
    final notesCtrl = TextEditingController(text: r.notes ?? '');
    bool isLoading = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => SelectionArea(
          child: AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.edit_note, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Text(l10n.editResponsibilityDialogTitle(r.incotermCode ?? '')),
              ],
            ),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.incotermPrefix(r.incotermCode ?? '—'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.cobalt),
                                tooltip: l10n.incotermsCopyFieldTooltip,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => CopyHelper.copy(context, r.incotermCode ?? ''),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.costItemPrefix(r.costItemName ?? '—', _getCategoryLabel(l10n, r.costCategory ?? '—')),
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.cobalt),
                                tooltip: l10n.incotermsCopyFieldTooltip,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => CopyHelper.copy(context, r.costItemName ?? ''),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: selectedParty,
                      labelText: l10n.matrixResponsiblePartyFieldLabel,
                      items: [
                        SearchableDropdownItem<String>(value: 'Importer', label: l10n.partyBuyerImporter),
                        SearchableDropdownItem<String>(value: 'Exporter', label: l10n.partySellerExporter),
                        SearchableDropdownItem<String>(value: 'Shared', label: l10n.partyShared),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedParty = val;
                            if (val == 'Exporter') {
                              isIncluded = true;
                            } else if (val == 'Importer') {
                              isIncluded = false;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(l10n.includedInSellerPriceTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text(l10n.includedInSellerPriceSubtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      value: isIncluded,
                      activeThumbColor: AppTheme.emerald,
                      onChanged: (val) => setDialogState(() => isIncluded = val),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.commentNotesLabel,
                        hintText: l10n.commentNotesHint,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                          tooltip: l10n.incotermsCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, notesCtrl.text),
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              AppButton(
                label: l10n.cancel,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
              ),
              AppButton(
                label: l10n.saveChanges,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                isLoading: isLoading,
                onPressed: () async {
                  setDialogState(() => isLoading = true);
                  final data = {
                    'responsible_party': selectedParty,
                    'included_in_incoterm': isIncluded,
                    'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  };

                  final error = await ref.read(responsibilityMatrixProvider.notifier).updateResponsibility(r.responsibilityId, data);
                  ref.read(responsibilityMatrixProvider.notifier).fetchAll();

                  setDialogState(() => isLoading = false);
                  if (ctx.mounted) {
                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        AppTheme.snackBar(context, error, severity: AppSeverity.danger),
                      );
                    } else {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        AppTheme.snackBar(context, l10n.updatedSuccessfully, severity: AppSeverity.success),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell({required Widget child}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Align(alignment: AlignmentDirectional.centerStart, child: child),
      );

  Widget _buildMatrixTable(List<IncotermResponsibilityModel> matrix) {
    final l10n = context.l10n;

    return Container(
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
                minWidth: MediaQuery.of(context).size.width > 1100 ? MediaQuery.of(context).size.width - 300 : 1000,
              ),
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(110),
                  1: FixedColumnWidth(100),
                  2: FlexColumnWidth(2),
                  3: FixedColumnWidth(120),
                  4: FixedColumnWidth(160),
                  5: FixedColumnWidth(100),
                  6: FlexColumnWidth(2),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: AppTheme.charcoal),
                    children: [
                      l10n.matrixActionsCol,
                      l10n.matrixIncotermCol,
                      l10n.matrixCostItemCol,
                      l10n.matrixCategoryCol,
                      l10n.matrixResponsibleCol,
                      l10n.matrixIncludedCol,
                      l10n.matrixNotesCol,
                    ]
                        .map((h) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Text(
                                h,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ))
                        .toList(),
                  ),
                  ...matrix.asMap().entries.map((entry) {
                    final r = entry.value;
                    final isEven = entry.key % 2 == 0;
                    final partySeverity = switch (r.responsibleParty) {
                      'Importer' => AppSeverity.info,
                      'Exporter' => AppSeverity.warning,
                      _ => AppSeverity.success,
                    };
                    final partyText = switch (r.responsibleParty) {
                      'Importer' => l10n.partyBuyerImporter,
                      'Exporter' => l10n.partySellerExporter,
                      _ => l10n.partyShared,
                    };
                    return TableRow(
                      decoration: BoxDecoration(
                        color: isEven
                            ? AppTheme.surfaceOf(context)
                            : (AppTheme.isDark(context) ? AppTheme.darkSurface : Colors.grey.shade50),
                      ),
                      children: [
                        _cell(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: l10n.matrixCopySummaryBtn,
                                child: InkWell(
                                  onTap: () => CopyHelper.copy(
                                    context,
                                    _buildMatrixRowSummary(l10n, r),
                                    customMessage: l10n.matrixCopySummarySuccess,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                                    margin: const EdgeInsetsDirectional.only(end: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.emerald.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                                    ),
                                    child: const Icon(
                                      Icons.copy_all_rounded,
                                      size: 15,
                                      color: AppTheme.emerald,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: AppTheme.cobalt, size: 20),
                                tooltip: l10n.editResponsibilityTooltip,
                                onPressed: () => _showEditResponsibilityDialog(context, ref, r),
                              ),
                            ],
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: r.incotermCode ?? '',
                            rowSummary: _buildMatrixRowSummary(l10n, r),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                r.incotermCode ?? '—',
                                style: const TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: r.costItemName ?? '',
                            rowSummary: _buildMatrixRowSummary(l10n, r),
                            child: Text(
                              r.costItemName ?? '—',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                            ),
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: _getCategoryLabel(l10n, r.costCategory ?? ''),
                            rowSummary: _buildMatrixRowSummary(l10n, r),
                            child: Text(
                              _getCategoryLabel(l10n, r.costCategory ?? ''),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: partyText,
                            rowSummary: _buildMatrixRowSummary(l10n, r),
                            child: AppStatusBadge(
                              label: partyText,
                              severity: partySeverity,
                              size: AppStatusBadgeSize.small,
                            ),
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: r.includedInIncoterm ? l10n.includedInPriceYes : l10n.includedInPriceNo,
                            rowSummary: _buildMatrixRowSummary(l10n, r),
                            child: Icon(
                              r.includedInIncoterm ? Icons.check_circle : Icons.remove_circle_outline,
                              color: r.includedInIncoterm ? AppTheme.emerald : Colors.grey.shade400,
                              size: 20,
                            ),
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: r.notes ?? '',
                            rowSummary: _buildMatrixRowSummary(l10n, r),
                            child: Text(
                              r.notes ?? '—',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final incotermsAsync = ref.watch(incotermsProvider);
    final matrixAsync = ref.watch(responsibilityMatrixProvider);

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Incoterm selector dropdown & header actions
          incotermsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (incoterms) {
              final active = incoterms.where((i) => i.isActive).toList();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(l10n.filterByIncotermLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 280,
                        child: SearchableDropdownField<int?>(
                          value: _selectedIncotermId,
                          hintText: l10n.allIncotermsOption,
                          items: [
                            SearchableDropdownItem<int?>(value: null, label: l10n.allIncotermsOption),
                            ...active.map((i) => SearchableDropdownItem<int?>(
                                  value: i.incotermId,
                                  label: '${i.incotermCode} - ${i.incotermName}',
                                )),
                          ],
                          onChanged: (val) => setState(() => _selectedIncotermId = val),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.table_chart_outlined, size: 18),
                        label: Text(l10n.matrixExportTsvBtn),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.cobalt,
                          side: const BorderSide(color: AppTheme.cobalt),
                        ),
                        onPressed: () {
                          final matrix = ref.read(responsibilityMatrixProvider).value ?? [];
                          final filtered = _selectedIncotermId == null
                              ? matrix
                              : matrix.where((r) => r.incotermId == _selectedIncotermId).toList();
                          _copyMatrixTsv(context, filtered);
                        },
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _selectedIncotermId == null
                            ? l10n.showingAllMatrixResponsibilities
                            : l10n.filteringResponsibilitiesForSelectedTerm,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Matrix table
          Expanded(
            child: matrixAsync.when(
              loading: () => const AppLoadingState(),
              error: (e, _) => AppErrorState(
                error: e,
                onRetry: () => ref.read(responsibilityMatrixProvider.notifier).fetchAll(),
              ),
              data: (matrix) {
                final filtered = _selectedIncotermId == null
                    ? matrix
                    : matrix.where((r) => r.incotermId == _selectedIncotermId).toList();
                if (filtered.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.table_chart_outlined,
                    message: l10n.noMatrixDataFound,
                  );
                }
                return _buildMatrixTable(filtered);
              },
            ),
          ),
        ],
      ),
    );
  }
}
