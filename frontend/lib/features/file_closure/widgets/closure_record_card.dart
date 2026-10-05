import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../../warehouse_receiving/widgets/ops_ui_kit.dart';
import '../models/file_closure_model.dart';
import 'file_closure_form_dialog.dart' show closureCompletedCount;

/// One closure certificate: header chips, checklist progress with the five
/// conditions as status chips, optional archival note and the action bar.
class ClosureRecordCard extends StatelessWidget {
  const ClosureRecordCard({
    super.key,
    required this.record,
    required this.shipmentName,
    required this.rawFileCode,
    required this.onView,
    required this.onEdit,
    required this.onPrint,
    required this.onDelete,
    required this.onCopyRow,
    required this.onClone,
  });

  final ImportFileClosureModel record;
  final String shipmentName;
  final String rawFileCode;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onPrint;
  final VoidCallback onDelete;
  final VoidCallback onCopyRow;
  final VoidCallback onClone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = record;
    final chk = r.closureChecklist;
    final done = closureCompletedCount(chk);
    final archived = r.isFullyVerified;
    final accent = AppTheme.severityForegroundOf(context, archived ? AppSeverity.success : AppSeverity.warning);

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 14),
      decoration: AppTheme.cardDecorationOf(context),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, l, archived),
                const SizedBox(height: 14),
                _checklist(context, l, chk, done),
                if (r.archivalNotes != null && r.archivalNotes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsetsDirectional.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAltOf(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.note_alt_outlined, size: 16, color: AppTheme.textSecondaryOf(context)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.fileClosureArchivalNotes(r.archivalNotes!),
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textSecondaryOf(context)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Divider(height: 1, color: AppTheme.borderOf(context)),
                const SizedBox(height: 10),
                _actions(context, l),
              ],
            ),
          ),
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: accent),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, AppLocalizations l, bool archived) {
    final r = record;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.emerald),
                ),
                child: CopyableText(r.closureCode, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.emerald)),
              ),
              CopyableText(
                shipmentName,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimaryOf(context)),
              ),
              OpsTagChip(label: rawFileCode, icon: Icons.folder_open_outlined),
              OpsStatusChip(
                label: archived ? l.fileClosureStatusBadgeClosed : l.closureStatusDraft,
                severity: archived ? AppSeverity.success : AppSeverity.warning,
                icon: archived ? Icons.verified_outlined : Icons.edit_note,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 15, color: AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 4),
              Flexible(
                child: CopyableText(
                  l.fileClosureVaultLabel(r.archiveLocation),
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _checklist(BuildContext context, AppLocalizations l, ClosureChecklistModel chk, int done) {
    final progressColor = done == 5 ? AppTheme.emerald : (done >= 3 ? AppTheme.cobalt : AppTheme.orange);
    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.fileClosureChecklistHeader,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.cobalt),
                ),
              ),
              Text(
                l.closureChecklistProgress('$done', '5'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: progressColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: done / 5.0,
              minHeight: 6,
              backgroundColor: AppTheme.borderOf(context),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 10),
          OpsActionWrap(
            children: [
              _chip(l.fileClosureChecklistDocsOriginals, chk.docsVerified),
              _chip(l.fileClosureChecklistCustomsCleared, chk.customsCleared),
              _chip(l.fileClosureChecklistWarehouseGrn, chk.warehouseReceived),
              _chip(l.fileClosureChecklistLandedCost, chk.landedCostSettled),
              _chip(l.fileClosureChecklistTasksClosed, chk.tasksClosed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool ok) => OpsStatusChip(
        label: label,
        severity: ok ? AppSeverity.success : AppSeverity.danger,
        icon: ok ? Icons.check_circle : Icons.cancel,
      );

  Widget _actions(BuildContext context, AppLocalizations l) {
    final r = record;
    return Row(
      children: [
        Expanded(
          child: OpsActionWrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              RowActionsPill(
                onView: onView,
                onEdit: onEdit,
                onPrint: onPrint,
                onDelete: onDelete,
                viewTooltip: l.fileClosureViewTooltip,
                editTooltip: l.fileClosureEditTooltip,
                printTooltip: l.fileClosurePrintTooltip,
                deleteTooltip: l.fileClosureDeleteTooltip,
              ),
              AppButton(
                key: Key('copyClosureRowBtn_${r.closureCode}'),
                label: l.fileClosureCopyCertTsvBtn,
                icon: Icons.copy_outlined,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
                onPressed: onCopyRow,
              ),
              IconButton(
                key: Key('cloneClosureBtn_${r.closureCode}'),
                icon: const Icon(Icons.difference_outlined, color: AppTheme.emerald, size: 18),
                tooltip: l.cloneFileClosureTooltip,
                onPressed: onClone,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_pin, size: 15, color: AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 4),
              Flexible(
                child: CopyableText(
                  l.fileClosureAuditorLabel(r.auditorName),
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

