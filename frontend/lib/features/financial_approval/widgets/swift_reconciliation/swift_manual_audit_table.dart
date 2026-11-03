import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../financial_ui.dart';
import '../../models/financial_approval_model.dart';
import '../../services/financial_export_service.dart';
import 'audit/swift_audit_export_helper.dart';
import 'audit/swift_audit_filter_bar.dart';
import 'audit/swift_audit_table_columns.dart';

/// Interactive manual audit table, search filter bar, and multi-format export
/// for SWIFT payment reconciliations.
class SwiftManualAuditTable extends ConsumerStatefulWidget {
  final List<PaymentRequestModel> payments;
  final VoidCallback? onReconciled;

  const SwiftManualAuditTable({
    super.key,
    required this.payments,
    this.onReconciled,
  });

  @override
  ConsumerState<SwiftManualAuditTable> createState() =>
      _SwiftManualAuditTableState();
}

class _SwiftManualAuditTableState extends ConsumerState<SwiftManualAuditTable> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'ALL'; // ALL, PENDING, MATCHED, DEFICIT

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Filter payments
    final filtered = widget.payments.where((pay) {
      if (!pay.isActive) return false;
      final q = _searchController.text.trim().toLowerCase();
      final matchQuery = q.isEmpty ||
          pay.paymentCode.toLowerCase().contains(q) ||
          pay.title.toLowerCase().contains(q) ||
          pay.supplierName.toLowerCase().contains(q) ||
          (pay.importFileCode != null &&
              pay.importFileCode!.toLowerCase().contains(q)) ||
          (pay.swiftReferenceNo != null &&
              pay.swiftReferenceNo!.toLowerCase().contains(q));

      if (!matchQuery) return false;

      if (_selectedStatusFilter == 'PENDING') {
        return pay.swiftReferenceNo == null || pay.swiftReferenceNo!.isEmpty;
      } else if (_selectedStatusFilter == 'MATCHED') {
        return pay.swiftVarianceStatus == 'Matched';
      } else if (_selectedStatusFilter == 'DEFICIT') {
        return pay.swiftVarianceStatus == 'Deficit';
      } else if (_selectedStatusFilter == 'SURPLUS') {
        return pay.swiftVarianceStatus == 'Surplus';
      }
      return true;
    }).toList();

    final totalRequests = widget.payments.where((p) => p.isActive).length;
    final pendingSwift = widget.payments
        .where((p) =>
            p.isActive &&
            (p.swiftReferenceNo == null || p.swiftReferenceNo!.isEmpty))
        .length;
    final matchedSwift = widget.payments
        .where((p) => p.isActive && p.swiftVarianceStatus == 'Matched')
        .length;
    final discrepancySwift = widget.payments
        .where((p) =>
            p.isActive &&
            (p.swiftVarianceStatus == 'Deficit' ||
                p.swiftVarianceStatus == 'Surplus'))
        .length;

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter & Search Toolbar
          SwiftAuditFilterBar(
            searchController: _searchController,
            selectedStatusFilter: _selectedStatusFilter,
            totalRequests: totalRequests,
            pendingSwift: pendingSwift,
            matchedSwift: matchedSwift,
            discrepancySwift: discrepancySwift,
            onStatusFilterChanged: (v) =>
                setState(() => _selectedStatusFilter = v),
            onSearchChanged: () => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Table of Payment Requests & SWIFTs
          Container(
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: AppTheme.charcoalSurface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(8)),
                    border: Border(
                        bottom: BorderSide(color: AppTheme.cloudWhite)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.table_chart,
                              color: AppTheme.charcoal, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l10n.swiftTableTitle(filtered.length),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(width: 16),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt,
                                  color: AppTheme.orange, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                l10n.swiftAutoSyncNotice,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.orange,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          FinancialUi.fit(AppButton(
                            label: l10n.swiftExportTsvBtn,
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.small,
                            icon: Icons.table_view,
                            onPressed: filtered.isEmpty
                                ? null
                                : () => SwiftAuditExportHelper.exportTsv(
                                      context: context,
                                      ref: ref,
                                      payments: filtered,
                                    ),
                          )),
                          FinancialUi.fit(AppButton(
                            label: l10n.swiftExportExcelBtn,
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.small,
                            icon: Icons.file_download,
                            onPressed: filtered.isEmpty
                                ? null
                                : () => FinancialExportService
                                        .exportSwiftReconciliationToExcel(
                                      context: context,
                                      payments: filtered,
                                    ),
                          )),
                          FinancialUi.fit(AppButton(
                            label: l10n.swiftCopySummaryBtn,
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.small,
                            icon: Icons.copy_all,
                            onPressed: filtered.isEmpty
                                ? null
                                : () => SwiftAuditExportHelper
                                    .copyFilteredSummary(
                                      context: context,
                                      payments: filtered,
                                    ),
                          )),
                        ],
                      ),
                    ],
                  ),
                ),
                EnterpriseDataTable<PaymentRequestModel>(
                  storageKey: 'swift_reconciliation_table',
                  data: filtered,
                  minWidth: 1400,
                  rowHeight: 68,
                  isScrollable: false,
                  showHeaderToolbar: false,
                  showPagination: true,
                  initialPageSize: 25,
                  emptyMessage: l10n.swiftNoMatchingPayments,
                  columns: SwiftAuditTableColumns.buildColumns(
                    context: context,
                    ref: ref,
                    l10n: l10n,
                    onReconciled: widget.onReconciled,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
