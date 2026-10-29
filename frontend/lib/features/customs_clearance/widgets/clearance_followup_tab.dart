import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/localization/app_localizations.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/customs_clearance_model.dart';
import 'clearance_card.dart';
import 'customs_ui.dart';

/// Tab 0: Customs Clearance Follow-up view decomposed into an isolated widget.
/// Manages its own [_searchController] and disposes it on unmount to eliminate memory leaks.
class ClearanceFollowupTab extends ConsumerStatefulWidget {
  final List<CustomsClearanceModel> records;
  final VoidCallback onRefresh;
  final VoidCallback onAddNew;
  final void Function(List<CustomsClearanceModel> records) onCloneFromList;
  final void Function(CustomsClearanceModel record) onViewDetails;
  final void Function(CustomsClearanceModel record) onBrokerAuth;
  final void Function(CustomsClearanceModel record) onDeliveryOrder;
  final void Function(CustomsClearanceModel record) onDeclaration46;
  final void Function(CustomsClearanceModel record) onInspection;
  final void Function(CustomsClearanceModel record) onAssessDuties;
  final void Function(CustomsClearanceModel record) onEdit;
  final void Function(CustomsClearanceModel record) onCloneRecord;
  final void Function(CustomsClearanceModel record) onUnderBond;
  final void Function(CustomsClearanceModel record) onPayDuty;
  final void Function(CustomsClearanceModel record) onRelease;
  final void Function(CustomsClearanceModel record) onExpenses;
  final void Function(CustomsClearanceModel record) onFollowups;

  const ClearanceFollowupTab({
    super.key,
    required this.records,
    required this.onRefresh,
    required this.onAddNew,
    required this.onCloneFromList,
    required this.onViewDetails,
    required this.onBrokerAuth,
    required this.onDeliveryOrder,
    required this.onDeclaration46,
    required this.onInspection,
    required this.onAssessDuties,
    required this.onEdit,
    required this.onCloneRecord,
    required this.onUnderBond,
    required this.onPayDuty,
    required this.onRelease,
    required this.onExpenses,
    required this.onFollowups,
  });

  @override
  ConsumerState<ClearanceFollowupTab> createState() => _ClearanceFollowupTabState();
}

class _ClearanceFollowupTabState extends ConsumerState<ClearanceFollowupTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MetricCardData> _metricsFor(List<CustomsClearanceModel> records, AppLocalizations l) {
    final assessed = records.where((r) => CcStatus.isAssessed(r)).length;
    final paid = records.where((r) => CcStatus.isPaid(r)).length;
    final outstanding = records.where((r) => !CcStatus.isPaid(r)).length;
    final released = records.where((r) => CcStatus.isReleased(r)).length;
    return [
      MetricCardData(
        title: l.ccMetricAssessed,
        value: '$assessed',
        icon: Icons.calculate_outlined,
        color: AppTheme.cobalt,
      ),
      MetricCardData(
        title: l.ccMetricPaid,
        value: '$paid',
        icon: Icons.payments_outlined,
        color: AppTheme.emerald,
      ),
      MetricCardData(
        title: l.ccMetricOutstanding,
        value: '$outstanding',
        icon: Icons.hourglass_bottom_rounded,
        color: AppTheme.orange,
      ),
      MetricCardData(
        title: l.ccMetricReleased,
        value: '$released',
        icon: Icons.verified_outlined,
        color: AppTheme.charcoal,
      ),
    ];
  }

  List<String> _tableHeaders(AppLocalizations l) => [
        l.customsClearanceColClearanceCode,
        l.importFile,
        l.customsClearanceColDecl46,
        l.customsClearanceOfficeLabel,
        l.customsClearanceChannelLabel,
        l.customsClearanceDeliveryOrderLabel,
        l.customsClearanceColActualDuty,
        l.customsClearanceColEstimatedDuty,
        l.customsClearanceColDutyVariance,
        l.customsClearanceColPaymentStatus,
        l.status,
      ];

  List<String> _tableRow(CustomsClearanceModel r, List<ImportFileModel> files, AppLocalizations l) {
    final rawCode = 'IMP-${r.importFileId}';
    final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: files, isArabic: l.isArabic);
    final actual = CcFormat.fixed(r.effectiveDutyTotal);
    final est = CcFormat.fixed(r.estimatedDutyTotal);
    final variance = CcFormat.signedFixed(r.dutyVarianceAmount);
    return [
      r.clearanceCode,
      shipTitle,
      r.declaration46No ?? '-',
      r.customsOfficeName,
      CcUi.channelStyle(l, r.channelType).label,
      r.deliveryOrderNumber ?? '-',
      actual,
      est,
      variance,
      CcStatus.isPaid(r) ? l.customsClearanceStatusPaid : l.customsClearanceStatusPendingPayment,
      CcUi.statusStyle(l, r.status).label,
    ];
  }

  void _copyClearanceRowTsv(CustomsClearanceModel record, AppLocalizations l) {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    TableCopyHelper.copyRow(
      context,
      _tableRow(record, files, l),
      headers: _tableHeaders(l),
      includeHeaders: true,
      customMessage: l.copyCustomsClearanceRowSuccess,
    );
  }

  void _copyClearanceTableTsv(List<CustomsClearanceModel> records, AppLocalizations l) {
    if (records.isEmpty) return;
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    TableCopyHelper.copyTable(
      context,
      _tableHeaders(l),
      records.map((r) => _tableRow(r, files, l)).toList(),
      customMessage: l.copyCustomsClearanceTableSuccess,
    );
  }

  Future<void> _exportClearanceExcel(List<CustomsClearanceModel> records, AppLocalizations l) async {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'Customs Clearance',
      importFileNameOrCode: 'Registry',
      headers: _tableHeaders(l),
      rows: records.map((r) => _tableRow(r, files, l)).toList(),
    );
  }

  Future<void> _exportClearancePdf(List<CustomsClearanceModel> records, AppLocalizations l) async {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final headers = [
      l.customsClearanceColClearanceCode,
      l.importFile,
      l.customsClearanceColDecl46,
      l.customsClearanceOfficeLabel,
      l.customsClearanceChannelLabel,
      l.customsClearanceDeliveryOrderLabel,
      l.customsClearanceColActualDuty,
      l.customsClearanceColPaymentStatus,
      l.status,
    ];

    final rows = records.map((r) {
      final row = _tableRow(r, files, l);
      return [...row.sublist(0, 7), row[9], row[10]];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      stageName: 'Customs Clearance',
      importFileNameOrCode: 'Registry',
      headers: headers,
      rows: rows,
      headerContext: TableExportHeaderContext(
        title: l.ccExportRegistryTitle,
        subtitle: l.ccExportRegistrySubtitle,
        metadata: {
          l.ccExportMetaTotal: records.length.toString(),
          l.ccExportMetaPaid: records.where((r) => CcStatus.isPaid(r)).length.toString(),
          l.ccExportMetaRelease: records.where((r) => CcStatus.isReleased(r)).length.toString(),
        },
      ),
    );
  }

  Widget _buildToolbar(List<CustomsClearanceModel> records, List<CustomsClearanceModel> filtered, AppLocalizations l) {
    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
      decoration: AppTheme.toolbarDecorationOf(context),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppSearchField(
                controller: _searchController,
                width: 260,
                hint: l.customsClearanceSearchHint,
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(
                width: 220,
                child: SearchableDropdownField<String>(
                  key: const Key('clearanceStatusFilter'),
                  value: _selectedStatusFilter,
                  labelText: l.customsClearanceFilterAll,
                  items: [
                    SearchableDropdownItem(value: 'All', label: l.customsClearanceFilterAll),
                    SearchableDropdownItem(value: 'Inspection In Progress', label: l.customsClearanceFilterInspection),
                    SearchableDropdownItem(value: 'Inspection & Sampling Recorded', label: l.customsClearanceStatusInspectionRecorded),
                    SearchableDropdownItem(value: 'Duty Requested', label: l.customsClearanceFilterDutyRequested),
                    SearchableDropdownItem(value: 'Customs Duties Assessed - Ready for Payment', label: l.customsClearanceStatusDutiesAssessed),
                    SearchableDropdownItem(value: 'Duty Paid', label: l.customsClearanceFilterDutyPaid),
                    SearchableDropdownItem(value: 'Duty Paid - Ready for Final Release', label: l.customsClearanceStatusDutyPaidReady),
                    SearchableDropdownItem(value: 'Under Bond Released', label: l.customsClearanceStatusUnderBondReleased),
                    SearchableDropdownItem(value: 'Lab Non-Conforming - Rejected', label: l.customsClearanceStatusLabRejected),
                    SearchableDropdownItem(value: 'Final Release Granted', label: l.customsClearanceFilterFinalRelease),
                    SearchableDropdownItem(value: 'Invoices Logged & Verified', label: l.customsClearanceStatusInvoicesVerified),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatusFilter = val);
                  },
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppButton(
                key: const Key('createClearanceBtn'),
                label: l.customsClearanceNewRecordButton,
                icon: Icons.add,
                size: AppButtonSize.small,
                onPressed: widget.onAddNew,
              ),
              AppButton(
                key: const Key('searchAndCloneClearanceBtn'),
                label: l.searchAndCloneCustomsClearanceBtn,
                icon: Icons.difference_outlined,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => widget.onCloneFromList(records),
              ),
              IconButton(
                key: const Key('copyClearanceTableTsvBtn'),
                icon: const Icon(Icons.copy_all_outlined, size: 20, color: AppTheme.cobalt),
                tooltip: l.copyCustomsClearanceTableSuccess,
                onPressed: () => _copyClearanceTableTsv(filtered, l),
              ),
              IconButton(
                key: const Key('exportClearanceExcelBtn'),
                icon: const Icon(Icons.table_view_outlined, size: 20, color: AppTheme.emerald),
                tooltip: l.exportCustomsClearanceExcelTooltip,
                onPressed: () => _exportClearanceExcel(filtered, l),
              ),
              IconButton(
                key: const Key('exportClearancePdfBtn'),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: AppTheme.crimson),
                tooltip: l.exportCustomsClearancePdfTooltip,
                onPressed: () => _exportClearancePdf(filtered, l),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.cobalt, size: 20),
                tooltip: l.customsDeclRefreshTooltip,
                onPressed: widget.onRefresh,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final records = widget.records;
    final query = _searchController.text.trim().toLowerCase();
    final filtered = records.where((r) {
      if (_selectedStatusFilter != 'All' && r.status != _selectedStatusFilter) return false;
      if (query.isEmpty) return true;
      return r.clearanceCode.toLowerCase().contains(query) ||
          (r.declaration46No ?? '').toLowerCase().contains(query) ||
          (r.deliveryOrderNumber ?? '').toLowerCase().contains(query) ||
          r.customsOfficeName.toLowerCase().contains(query);
    }).toList();

    final Widget body;
    if (records.isEmpty) {
      body = AppEmptyState(
        message: l.customsClearanceEmptyRecords,
        icon: Icons.gavel_rounded,
        actionLabel: l.customsClearanceNewRecordButton,
        onAction: widget.onAddNew,
      );
    } else if (filtered.isEmpty) {
      body = AppEmptyState(
        message: l.customsClearanceEmptyRecords,
        icon: Icons.search_off,
      );
    } else {
      body = ListView.builder(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final record = filtered[index];
          return ClearanceCard(
            key: ValueKey('clearanceCard_${record.clearanceCode}'),
            record: record,
            actions: ClearanceCardActions(
              onView: () => widget.onViewDetails(record),
              onBrokerAuth: () => widget.onBrokerAuth(record),
              onDeliveryOrder: () => widget.onDeliveryOrder(record),
              onDeclaration46: () => widget.onDeclaration46(record),
              onInspection: () => widget.onInspection(record),
              onAssessDuties: () => widget.onAssessDuties(record),
              onEdit: () => widget.onEdit(record),
              onCopyRow: () => _copyClearanceRowTsv(record, l),
              onClone: () => widget.onCloneRecord(record),
              onUnderBond: () => widget.onUnderBond(record),
              onPayDuty: () => widget.onPayDuty(record),
              onRelease: () => widget.onRelease(record),
              onExpenses: () => widget.onExpenses(record),
              onFollowups: () => widget.onFollowups(record),
            ),
          );
        },
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 8),
          child: CcUi.metrics(_metricsFor(records, l)),
        ),
        _buildToolbar(records, filtered, l),
        Expanded(child: body),
      ],
    );
  }
}
