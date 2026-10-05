import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../customs_consultation/models/customs_consultation_model.dart';
import '../../customs_consultation/providers/customs_consultation_provider.dart';
import 'su_ui.dart';

/// View / edit dialog of a customs consultation checklist (opened from the
/// shipment-updates screen). Print / save-PDF are delegated to the screen.
class SuConsultationDetailsDialog extends ConsumerStatefulWidget {
  const SuConsultationDetailsDialog({
    super.key,
    required this.session,
    required this.initialEditMode,
    required this.onPrint,
    required this.onSavePdf,
  });

  final CustomsConsultationModel session;
  final bool initialEditMode;
  final VoidCallback onPrint;
  final VoidCallback onSavePdf;

  static Future<void> show(
    BuildContext context, {
    required CustomsConsultationModel session,
    required bool initialEditMode,
    required VoidCallback onPrint,
    required VoidCallback onSavePdf,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SuConsultationDetailsDialog(
        session: session,
        initialEditMode: initialEditMode,
        onPrint: onPrint,
        onSavePdf: onSavePdf,
      ),
    );
  }

  @override
  ConsumerState<SuConsultationDetailsDialog> createState() => _SuConsultationDetailsDialogState();
}

class _SuConsultationDetailsDialogState extends ConsumerState<SuConsultationDetailsDialog> {
  late bool _isEditing;
  bool _isSaving = false;
  late String _selectedStatus;
  late final List<CustomsChecklistItemModel> _items;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.initialEditMode;
    _selectedStatus = widget.session.overallStatus;
    _items = widget.session.checklistItems
        .map((item) => CustomsChecklistItemModel(
              itemId: item.itemId,
              consultationId: item.consultationId,
              documentType: item.documentType,
              hsCode: item.hsCode,
              isRequired: item.isRequired,
              isBlockingShipment: item.isBlockingShipment,
              responsibleParty: item.responsibleParty,
              regulatoryAgency: item.regulatoryAgency,
              status: item.status,
              remarks: item.remarks,
            ))
        .toList();
  }

  bool _isApproved(String status) {
    final s = status.toLowerCase();
    return s == 'approved' ||
        s == 'verified' ||
        s == 'completed' ||
        s == 'received' ||
        s == 'obtained' ||
        s.contains('معتمد') ||
        s.contains('مستوفى');
  }

  Future<void> _save() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final successBar = AppTheme.snackBar(
      context,
      l.shipmentUpdateConsultSaveSuccess(widget.session.consultationCode),
      severity: AppSeverity.success,
    );
    setState(() => _isSaving = true);
    try {
      final payload = {
        'overall_status': _selectedStatus,
        'checklist_items': _items.map((item) => item.toJson()).toList(),
      };
      await ref.read(customsConsultationsProvider.notifier).updateConsultation(widget.session.consultationId, payload);
      nav.pop();
      messenger.showSnackBar(successBar);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        AppTheme.snackBar(
          context,
          l.shipmentUpdateConsultSaveError(ApiErrorText.of(l, e)),
          severity: AppSeverity.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = widget.session;
    final approvedCount = _items.where((i) => i.status == 'Approved' || i.status == 'Verified').length;
    final totalCount = _items.length;
    final blockingCount =
        _items.where((i) => i.isBlockingShipment && i.status != 'Approved' && i.status != 'Verified').length;
    final readinessPct = totalCount > 0 ? (approvedCount / totalCount * 100) : 0.0;

    return SelectionArea(
      child: CcStageDialogShell(
        title: _isEditing
            ? l.shipmentUpdateConsultDialogEditTitle(session.consultationCode)
            : l.shipmentUpdateConsultDialogViewTitle(session.consultationCode),
        icon: Icons.assignment_turned_in,
        maxWidth: 900,
        chips: [CcHeaderChip(Icons.confirmation_number_outlined, session.consultationCode, ltr: true)],
        headerActions: [
          IconButton(
            icon: Icon(
              _isEditing ? Icons.visibility_rounded : Icons.edit_rounded,
              color: AppTheme.white.withValues(alpha: 0.78),
            ),
            tooltip: _isEditing ? l.shipmentUpdateConsultSwitchViewTooltip : l.shipmentUpdateConsultSwitchEditTooltip,
            onPressed: _isSaving ? null : () => setState(() => _isEditing = !_isEditing),
          ),
        ],
        footerLeading: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            CcUi.fit(AppButton(
              label: l.shipmentUpdateBtnPrintPdf,
              icon: Icons.print_rounded,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.small,
              onPressed: widget.onPrint,
            )),
            CcUi.fit(AppButton(
              label: l.shipmentUpdateBtnSavePdf,
              icon: Icons.save_alt_rounded,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.small,
              onPressed: widget.onSavePdf,
            )),
          ],
        ),
        showCancel: _isEditing,
        confirmLabel: _isEditing ? l.shipmentUpdateConsultSaveBtn : l.shipmentUpdateConsultCloseBtn,
        loadingLabel: l.shipmentUpdateConsultSavingBtn,
        confirmIcon: _isEditing ? Icons.save : Icons.close,
        confirmVariant: _isEditing ? AppButtonVariant.success : AppButtonVariant.secondary,
        isSubmitting: _isSaving,
        onConfirm: _isEditing ? _save : () => Navigator.of(context).pop(),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryOf(context)),
            ),
            const SizedBox(height: 10),
            _summaryBar(l, session),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SuMetricBadge(
                  title: l.shipmentUpdateConsultReadinessRateLabel,
                  value: '${readinessPct.toStringAsFixed(0)}%',
                  severity: SuUi.readinessSeverity(readinessPct),
                ),
                SuMetricBadge(
                  title: l.shipmentUpdateConsultTotalDocsLabel,
                  value: '$totalCount',
                  severity: AppSeverity.info,
                ),
                SuMetricBadge(
                  title: l.shipmentUpdateConsultApprovedLabel,
                  value: '$approvedCount',
                  severity: AppSeverity.success,
                ),
                SuMetricBadge(
                  title: l.shipmentUpdateConsultBlockingLabel,
                  value: '$blockingCount',
                  severity: blockingCount > 0 ? AppSeverity.danger : AppSeverity.success,
                ),
              ],
            ),
            const SizedBox(height: 16),
            CcSectionCard(
              title: l.shipmentUpdateConsultChecklistSectionTitle,
              icon: Icons.fact_check_outlined,
              accent: _isEditing ? AppTheme.orange : AppTheme.cobalt,
              trailing: _isEditing
                  ? CcStatusChip(label: l.shipmentUpdateConsultEditModeBanner, severity: AppSeverity.warning)
                  : null,
              margin: EdgeInsets.zero,
              child: _checklistTable(l),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryBar(AppLocalizations l, CustomsConsultationModel session) {
    final sev = _isEditing ? AppSeverity.warning : AppSeverity.info;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: AppTheme.severityBackgroundOf(context, sev),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.severityForegroundOf(context, sev).withValues(alpha: 0.35)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(l.shipmentUpdateConsultBrokerPrefix(session.brokerName), style: const TextStyle(fontSize: 12)),
          Text(
            l.shipmentUpdateConsultEstDuties(session.estimatedDutiesEgp.toStringAsFixed(2)),
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson, fontSize: 12),
          ),
          if (_isEditing)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.shipmentUpdateConsultOverallStatusLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 200,
                  child: SearchableDropdownField<String>(
                    value: _selectedStatus,
                    items: [
                      SearchableDropdownItem(value: 'In Progress', label: l.shipmentUpdateConsultStatusInProgress),
                      SearchableDropdownItem(value: 'Clearance Ready', label: l.shipmentUpdateConsultStatusClearanceReady),
                      SearchableDropdownItem(value: 'Blocked', label: l.shipmentUpdateConsultStatusBlocked),
                      SearchableDropdownItem(value: 'Action Required', label: l.shipmentUpdateConsultStatusActionRequired),
                      SearchableDropdownItem(value: 'Completed', label: l.shipmentUpdateConsultStatusCompleted),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatus = val);
                    },
                  ),
                ),
              ],
            )
          else
            Text(
              l.shipmentUpdateConsultStatus(SuUi.customsStatusLabel(l, widget.session.overallStatus)),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _headCell(String text) => Padding(
        padding: const EdgeInsetsDirectional.all(8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      );

  Widget _checklistTable(AppLocalizations l) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 680),
        child: Table(
          border: TableBorder.all(color: AppTheme.borderOf(context)),
          columnWidths: const {
            0: FlexColumnWidth(2.8),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.6),
            3: FlexColumnWidth(2.2),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: AppTheme.charcoalSurface),
              children: [
                _headCell(l.shipmentUpdateConsultColDocType),
                _headCell(l.shipmentUpdateConsultColResponsibleParty),
                _headCell(l.shipmentUpdateConsultColStatus),
                _headCell(l.shipmentUpdateConsultColRemarks),
              ],
            ),
            ..._items.asMap().entries.map((entry) => _docRow(l, entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  TableRow _docRow(AppLocalizations l, int idx, CustomsChecklistItemModel doc) {
    final statusLower = doc.status.toLowerCase();
    final approved = _isApproved(doc.status);
    final rejected = statusLower == 'rejected' || statusLower.contains('مرفوض');
    final blocking = doc.isBlockingShipment && !approved;

    Widget statusIcon;
    if (approved) {
      statusIcon = const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 14);
    } else if (rejected) {
      statusIcon = const Icon(Icons.cancel_rounded, color: AppTheme.crimson, size: 14);
    } else if (blocking) {
      statusIcon = Tooltip(
        message: l.shipmentUpdateConsultBlockingTooltip,
        child: const Icon(Icons.block, color: AppTheme.crimson, size: 14),
      );
    } else {
      statusIcon = const Icon(Icons.hourglass_top_rounded, color: AppTheme.orange, size: 14);
    }

    return TableRow(
      decoration: BoxDecoration(color: idx % 2 == 1 ? AppTheme.surfaceAltOf(context) : AppTheme.surfaceOf(context)),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  statusIcon,
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      doc.documentType,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        color: blocking ? AppTheme.crimson : AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
              if (doc.hsCode != null && doc.hsCode!.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 2),
                  child: LtrText(
                    l.shipmentUpdateConsultHsCodesPrefix(doc.hsCode!),
                    style: const TextStyle(fontSize: 10, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.all(8),
          child: Text(doc.responsibleParty, style: const TextStyle(fontSize: 11)),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.all(6),
          child: _isEditing
              ? SearchableDropdownField<String>(
                  value: doc.status,
                  items: [
                    SearchableDropdownItem(value: 'Approved', label: l.shipmentUpdateDocStatusApproved),
                    SearchableDropdownItem(value: 'Pending', label: l.shipmentUpdateDocStatusPending),
                    SearchableDropdownItem(value: 'Received', label: l.shipmentUpdateDocStatusReceived),
                    SearchableDropdownItem(value: 'Verified', label: l.shipmentUpdateDocStatusVerified),
                    SearchableDropdownItem(value: 'Rejected', label: l.shipmentUpdateDocStatusRejected),
                  ],
                  onChanged: (newSt) {
                    if (newSt == null) return;
                    setState(() {
                      _items[idx] = CustomsChecklistItemModel(
                        itemId: doc.itemId,
                        consultationId: doc.consultationId,
                        documentType: doc.documentType,
                        hsCode: doc.hsCode,
                        isRequired: doc.isRequired,
                        isBlockingShipment: doc.isBlockingShipment,
                        responsibleParty: doc.responsibleParty,
                        regulatoryAgency: doc.regulatoryAgency,
                        status: newSt,
                        remarks: doc.remarks,
                      );
                    });
                  },
                )
              : Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SuDocStatusChip(status: doc.status),
                ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.all(8),
          child: Text(doc.remarks ?? '-', style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}
