import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../audit_logs/widgets/row_history_dialog.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/po_reconciliation_session_model.dart';
import '../idoc_ui.dart';

/// Top header card and input toolbar for PO Reconciliation.
/// Contains file selection, final document numbers, audit bar, and clone actions.
class PoReconciliationToolbar extends StatelessWidget {
  final int? selectedImportFileId;
  final List<ImportFileModel> importFiles;
  final TextEditingController finalInvNumberCtrl;
  final TextEditingController finalPLNumberCtrl;
  final int? activeSessionId;
  final String? activeSessionCode;
  final List<POReconciliationSessionModel> sessionsList;
  final ValueChanged<int?> onImportFileChanged;
  final VoidCallback onSearchAndClone;
  final String Function(String?) formatSessionDate;

  const PoReconciliationToolbar({
    super.key,
    required this.selectedImportFileId,
    required this.importFiles,
    required this.finalInvNumberCtrl,
    required this.finalPLNumberCtrl,
    required this.activeSessionId,
    required this.activeSessionCode,
    required this.sessionsList,
    required this.onImportFileChanged,
    required this.onSearchAndClone,
    required this.formatSessionDate,
  });

  Widget _buildActiveSessionAuditBar(BuildContext context) {
    if (activeSessionId == null) return const SizedBox.shrink();
    final session = sessionsList.where((s) => s.sessionId == activeSessionId).firstOrNull;

    final updater = session?.certifiedBy?.isNotEmpty == true
        ? session!.certifiedBy!
        : context.l10n.idocADocumentsReviewer;
    final updatedTime = formatSessionDate(session?.updatedAt ?? session?.createdAt);
    final isDraft = session?.overallStatus.toUpperCase() == 'DRAFT';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            color: isDark ? AppTheme.cobaltLight : AppTheme.textSecondaryOf(context),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDraft
                        ? AppTheme.severityBackgroundOf(context, AppSeverity.warning)
                        : AppTheme.severityBackgroundOf(context, AppSeverity.success),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDraft
                          ? AppTheme.severityForegroundOf(context, AppSeverity.warning)
                          : AppTheme.severityForegroundOf(context, AppSeverity.success),
                    ),
                  ),
                  child: Text(
                    isDraft
                        ? context.l10n.idocADraft3
                        : context.l10n.idocASavedApprovedStatus(activeSessionCode ?? ""),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDraft
                          ? AppTheme.severityForegroundOf(context, AppSeverity.warning)
                          : AppTheme.severityForegroundOf(context, AppSeverity.success),
                    ),
                  ),
                ),
                Text(
                  context.l10n.idocALastModifiedByOn(updater, updatedTime),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          IdocUi.fit(AppButton(
            label: context.l10n.idocAFullAuditLog,
            icon: Icons.manage_history_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () {
              RowHistoryDialog.show(
                context,
                entityType: 'POPackingReconciliationSession',
                entityId: activeSessionId!,
                entityTitle: activeSessionCode != null
                    ? '${context.l10n.idocASessionCodeAlt} $activeSessionCode'
                    : context.l10n.poRecHistorySectionTitle,
              );
            },
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Card(
      elevation: 2,
      color: AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 650;
                final titleRow = Row(
                  children: [
                    const Icon(Icons.fact_check, color: AppTheme.cobalt, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        activeSessionCode != null
                            ? l.poRecEditSessionTitle(activeSessionCode!)
                            : l.poRecNewSessionTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );

                final actionsRow = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (activeSessionCode != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.cobalt),
                        ),
                        child: Text(
                          activeSessionCode!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.cobalt,
                          ),
                        ),
                      ),
                    IdocUi.fit(AppButton(
                      key: const Key('editorSearchAndCloneBtn'),
                      label: l.searchAndClonePoReconBtn,
                      icon: Icons.copy_all,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: onSearchAndClone,
                    )),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleRow,
                      const SizedBox(height: 10),
                      actionsRow,
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleRow),
                    const SizedBox(width: 12),
                    actionsRow,
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              l.poRecHeaderDescription,
              style: TextStyle(
                color: AppTheme.textSecondaryOf(context),
                fontSize: 12.5,
              ),
            ),
            const Divider(height: 24),
            _buildActiveSessionAuditBar(context),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 750;
                final fileDropdown = SearchableDropdownField<int?>(
                  value: selectedImportFileId,
                  hintText: l.poRecSearchFileHint,
                  labelText: l.poRecImportFileLabel,
                  items: importFiles
                      .map((f) => SearchableDropdownItem<int?>(
                            value: f.importFileId,
                            label: '${f.primaryNameWithCode} - ${f.companyName}',
                          ))
                      .toList(),
                  onChanged: onImportFileChanged,
                  validator: (v) => v == null ? l.poRecSelectFileRequired : null,
                );
                final invField = TextFormField(
                  controller: finalInvNumberCtrl,
                  decoration: InputDecoration(
                    labelText: l.poRecFinalInvoiceNoLabel,
                    hintText: l.poRecFinalInvoiceNoHint,
                    prefixIcon: const Icon(Icons.receipt_long),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l.poRecRequired : null,
                );
                final plField = TextFormField(
                  controller: finalPLNumberCtrl,
                  decoration: InputDecoration(
                    labelText: l.poRecFinalPackingListNoLabel,
                    hintText: l.poRecFinalPackingListNoHint,
                    prefixIcon: const Icon(Icons.inventory_2),
                    border: const OutlineInputBorder(),
                  ),
                  validator: null,
                );

                if (isCompact) {
                  return Column(
                    children: [
                      fileDropdown,
                      const SizedBox(height: 12),
                      invField,
                      const SizedBox(height: 12),
                      plField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 3, child: fileDropdown),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: invField),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: plField),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
