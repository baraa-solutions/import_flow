import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_documentation_model.dart';

/// 20-Field comparison checklist table between system record and draft B/L extracted values.
/// Allows in-place draft field editing, status switching (Correct, Incorrect, N/A),
/// required correction entries, responsible party selection, and reason notes.
class DraftBlChecklistTable extends StatelessWidget {
  final List<DraftBLChecklistItemModel> checklist;
  final void Function(
    int idx, {
    dynamic draftValue,
    String? status,
    String? correction,
    String? reason,
    String? respParty,
  }) onUpdateRow;

  const DraftBlChecklistTable({
    super.key,
    required this.checklist,
    required this.onUpdateRow,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    if (checklist.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            l.draftBlSelectFileToStartChecklist,
            style: TextStyle(color: AppTheme.textMutedOf(context)),
          ),
        ),
      );
    }

    return SelectionArea(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 70,
          headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAltOf(context)),
          columns: [
            DataColumn(label: Text(l.draftBlChecklistColField, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text(l.draftBlChecklistColSystemValue, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text(l.draftBlChecklistColDraftValue, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text(l.draftBlChecklistColStatus, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text(l.draftBlChecklistColRequiredAction, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text(l.draftBlChecklistColResponsibleParty, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text(l.draftBlChecklistColReasonNotes, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: checklist.asMap().entries.map((entry) {
            final idx = entry.key;
            final itm = entry.value;
            final isCorrect = itm.status == 'Correct';
            final isNA = itm.status == 'N/A';

            return DataRow(
              color: WidgetStateProperty.resolveWith((_) {
                if (!isCorrect && !isNA) {
                  return AppTheme.severityBackgroundOf(context, AppSeverity.danger).withValues(alpha: 0.5);
                }
                return null;
              }),
              cells: [
                // 1. Field Label
                DataCell(
                  SizedBox(
                    width: 170,
                    child: CopyableText(
                      isAr ? itm.fieldLabelAr : itm.fieldLabelEn,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),

                // 2. System Value
                DataCell(
                  SizedBox(
                    width: 190,
                    child: CopyableText(
                      itm.systemValue?.toString() ?? l.unspecified,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                // 3. Draft Value (Editable in-place)
                DataCell(
                  SizedBox(
                    width: 220,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('draft_${itm.fieldKey}'),
                            initialValue: itm.draftValue?.toString() ?? '',
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: l.draftBlEnterDraftValueHint,
                              hintStyle: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: (itm.draftValue != null && itm.draftValue.toString().isNotEmpty)
                                      ? (isCorrect ? AppTheme.emeraldBorder : AppTheme.orange)
                                      : AppTheme.borderOf(context),
                                ),
                              ),
                              filled: true,
                              fillColor: AppTheme.surfaceOf(context),
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isCorrect
                                  ? AppTheme.severityForegroundOf(context, AppSeverity.success)
                                  : AppTheme.textPrimaryOf(context),
                            ),
                            onChanged: (val) {
                              onUpdateRow(idx, draftValue: val);
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.content_copy, size: 14, color: AppTheme.cobalt),
                          tooltip: l.draftBlCopySystemValueTooltip,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () {
                            onUpdateRow(
                              idx,
                              draftValue: itm.systemValue,
                              status: 'Correct',
                              correction: null,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Status Dropdown
                DataCell(
                  DropdownButton<String>(
                    value: itm.status,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: 'Correct',
                        child: Text(
                          '✅ ${l.draftBlStatusCorrect}',
                          style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Incorrect',
                        child: Text(
                          '❌ ${l.draftBlStatusIncorrect}',
                          style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'N/A',
                        child: Text(
                          '⚪ ${l.draftBlStatusNA}',
                          style: TextStyle(color: AppTheme.textMutedOf(context), fontSize: 12),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) onUpdateRow(idx, status: v);
                    },
                  ),
                ),

                // 5. Required Action / Correction
                DataCell(
                  SizedBox(
                    width: 180,
                    child: TextFormField(
                      initialValue: itm.requiredCorrection ?? '',
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: isCorrect ? l.draftBlMatchedHint : l.draftBlEnterCorrectionHint,
                        hintStyle: TextStyle(
                          fontSize: 11,
                          color: isCorrect ? AppTheme.emerald : AppTheme.textMutedOf(context),
                        ),
                        contentPadding: const EdgeInsets.all(6),
                        border: const OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 11.5),
                      onChanged: (v) => onUpdateRow(idx, correction: v),
                    ),
                  ),
                ),

                // 6. Responsible Party
                DataCell(
                  SizedBox(
                    width: 130,
                    child: SearchableDropdownField<String>(
                      value: itm.responsibleParty ?? 'Shipping Provider',
                      labelText: l.draftBlPartyShippingLine,
                      items: [
                        SearchableDropdownItem(value: 'Shipping Provider', label: l.draftBlPartyShippingLine),
                        SearchableDropdownItem(value: 'Supplier', label: l.draftBlPartySupplier),
                        SearchableDropdownItem(value: 'Importer', label: l.draftBlPartyImporter),
                        SearchableDropdownItem(value: 'Customs Broker', label: l.draftBlPartyCustomsBroker),
                      ],
                      onChanged: (v) {
                        if (v != null) onUpdateRow(idx, respParty: v);
                      },
                    ),
                  ),
                ),

                // 7. Reason & Notes
                DataCell(
                  SizedBox(
                    width: 160,
                    child: TextFormField(
                      initialValue: itm.displayReason(l),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: l.draftBlEnterReasonHint,
                        contentPadding: const EdgeInsets.all(6),
                        border: const OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 11.5),
                      onChanged: (v) => onUpdateRow(idx, reason: v),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
