import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../models/customs_clearance_quotation_model.dart';
import '../providers/customs_clearance_quotations_provider.dart';
import '../services/customs_clearance_quotations_export_service.dart';
import 'quotation_dialogs.dart';
import 'rfq_card.dart';

class RfqTabView extends ConsumerStatefulWidget {
  final void Function(int? rfqId) onSmartExtract;

  const RfqTabView({super.key, required this.onSmartExtract});

  @override
  ConsumerState<RfqTabView> createState() => _RfqTabViewState();
}

class _RfqTabViewState extends ConsumerState<RfqTabView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedStatusFilter = 'ALL';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MetricCardData> _rfqMetrics(List<CustomsClearanceRFQModel> rfqs, AppLocalizations l10n) => [
        MetricCardData(
          title: l10n.ccqMetricRfqs,
          value: '${rfqs.length}',
          icon: Icons.compare_arrows_rounded,
          color: AppTheme.cobalt,
        ),
        MetricCardData(
          title: l10n.clearanceQuotesStatusDraft,
          value: '${rfqs.where((r) => r.status == 'Draft').length}',
          icon: Icons.edit_note_rounded,
          color: AppTheme.orange,
        ),
        MetricCardData(
          title: l10n.clearanceQuotesStatusReceived,
          value: '${rfqs.where((r) => r.status == 'Quotations Received').length}',
          icon: Icons.request_quote_outlined,
          color: AppTheme.charcoal,
        ),
        MetricCardData(
          title: l10n.clearanceQuotesStatusAwarded,
          value: '${rfqs.where((r) => r.status == 'Awarded').length}',
          icon: Icons.verified_outlined,
          color: AppTheme.emerald,
        ),
      ];

  Widget _exportIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback? onPressed,
  }) =>
      IconButton(
        icon: Icon(icon, size: 20, color: onPressed == null ? null : color),
        tooltip: tooltip,
        onPressed: onPressed,
      );

  Widget _rfqToolbar(List<CustomsClearanceRFQModel> filtered, AppLocalizations l10n) {
    final disabled = filtered.isEmpty;
    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
      decoration: AppTheme.toolbarDecorationOf(context),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: l10n.clearanceQuotesSearchHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: 220,
                child: SearchableDropdownField<String>(
                  key: const Key('quotationStatusFilter'),
                  value: _selectedStatusFilter,
                  labelText: l10n.clearanceQuotesStatusAll,
                  items: [
                    SearchableDropdownItem(value: 'ALL', label: l10n.clearanceQuotesStatusAll),
                    SearchableDropdownItem(value: 'Draft', label: l10n.clearanceQuotesStatusDraft),
                    SearchableDropdownItem(value: 'Quotations Received', label: l10n.clearanceQuotesStatusReceived),
                    SearchableDropdownItem(value: 'Awarded', label: l10n.clearanceQuotesStatusAwarded),
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
                label: l10n.clearanceQuotesSmartExtractorBtn,
                icon: Icons.auto_awesome,
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                onPressed: () => widget.onSmartExtract(null),
              ),
              AppButton(
                label: l10n.clearanceQuotesCreateRfqBtn,
                icon: Icons.add_circle_outline_rounded,
                size: AppButtonSize.small,
                onPressed: () => showCreateRfqDialog(context, ref),
              ),
              _exportIcon(
                icon: Icons.table_view_rounded,
                color: AppTheme.cobalt,
                tooltip: l10n.clearanceQuotesExportTsvBtn,
                onPressed: disabled
                    ? null
                    : () => CustomsClearanceQuotationsExportService.exportRfqsTsv(context, filtered),
              ),
              _exportIcon(
                icon: Icons.grid_on_rounded,
                color: AppTheme.emerald,
                tooltip: l10n.clearanceQuotesExportExcelBtn,
                onPressed: disabled
                    ? null
                    : () => CustomsClearanceQuotationsExportService.exportRfqsExcel(context, filtered),
              ),
              _exportIcon(
                icon: Icons.picture_as_pdf_rounded,
                color: AppTheme.crimson,
                tooltip: l10n.clearanceQuotesPrintPdfBtn,
                onPressed: disabled
                    ? null
                    : () => CustomsClearanceQuotationsExportService.printOrSaveRfqsPdf(context, filtered),
              ),
              _exportIcon(
                icon: Icons.copy_all_rounded,
                color: AppTheme.charcoal,
                tooltip: l10n.clearanceQuotesCopyDossierBtn,
                onPressed: disabled
                    ? null
                    : () => CustomsClearanceQuotationsExportService.copyRfqDossier(context, filtered),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rfqsState = ref.watch(customsClearanceQuotationsProvider);

    return rfqsState.when(
      loading: () => const CcStateView.loading(),
      error: (e, _) => CcStateView.error(
        message: '${l10n.clearanceQuotesErrorLoadingRfqs} ${ApiErrorText.of(l10n, e)}',
        actionLabel: l10n.retry,
        onAction: () => ref.read(customsClearanceQuotationsProvider.notifier).fetchRFQs(),
      ),
      data: (rfqs) {
        final q = _searchCtrl.text.trim().toLowerCase();
        final filtered = rfqs.where((r) {
          final matchesQuery = q.isEmpty ||
              r.rfqCode.toLowerCase().contains(q) ||
              r.title.toLowerCase().contains(q) ||
              r.portName.toLowerCase().contains(q);
          final matchesStatus = _selectedStatusFilter == 'ALL' || r.status == _selectedStatusFilter;
          return matchesQuery && matchesStatus;
        }).toList();

        final Widget content;
        if (filtered.isEmpty) {
          content = CcStateView.empty(
            message: l10n.clearanceQuotesNoRfqsFound,
            icon: rfqs.isEmpty ? Icons.inventory_2_outlined : Icons.search_off,
            actionLabel: rfqs.isEmpty ? l10n.clearanceQuotesCreateRfqBtn : null,
            onAction: rfqs.isEmpty ? () => showCreateRfqDialog(context, ref) : null,
          );
        } else {
          content = ListView.builder(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
            itemCount: filtered.length,
            itemBuilder: (ctx, idx) {
              final rfq = filtered[idx];
              return RfqCard(
                key: ValueKey('rfqCard_${rfq.rfqId}'),
                rfq: rfq,
                onSmartExtract: () => widget.onSmartExtract(rfq.rfqId),
                onAddQuote: () => showAddQuotationDialog(context, ref, rfq.rfqId),
                onAward: (quotationId) => confirmAwardQuotation(context, ref, rfq.rfqId, quotationId),
                onDeleteQuote: (quotationId) => confirmDeleteQuotation(context, ref, quotationId),
              );
            },
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8),
              child: CcUi.metrics(_rfqMetrics(rfqs, l10n)),
            ),
            _rfqToolbar(filtered, l10n),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}
