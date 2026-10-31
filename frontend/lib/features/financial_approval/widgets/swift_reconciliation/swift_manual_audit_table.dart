import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../financial_ui.dart';
import '../../models/financial_approval_model.dart';
import '../../services/financial_export_service.dart';
import '../../../import_files/providers/import_files_provider.dart';
import 'swift_discrepancy_dialog.dart';
import 'swift_mt103_preview_card.dart';
import 'swift_reconciliation_common.dart';

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

  void _exportTsv(List<PaymentRequestModel> payments) {
    final l10n = context.l10n;
    final buffer = StringBuffer();
    // Header
    buffer.writeln([
      l10n.swiftTsvHeaderPaymentCode,
      l10n.swiftTsvHeaderImportFile,
      l10n.swiftTsvHeaderBeneficiary,
      l10n.swiftTsvHeaderBank,
      l10n.swiftTsvHeaderRequestDate,
      l10n.swiftTsvHeaderSwiftReceiptDate,
      l10n.swiftTsvHeaderProcessingDays,
      l10n.swiftTsvHeaderRequestedAmount,
      l10n.swiftTsvHeaderTransferredAmount,
      l10n.swiftTsvHeaderVariance,
      l10n.swiftTsvHeaderSwiftRef,
      l10n.swiftTsvHeaderStatus,
    ].join('\t'));

    final allFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    for (final p in payments) {
      final days =
          p.swiftProcessingDays != null ? '${p.swiftProcessingDays}' : '-';
      final transferred = p.swiftTransferredAmount != null
          ? '${p.swiftTransferredAmount} ${p.swiftTransferredCurrency ?? p.currencyCode}'
          : '-';
      final variance = p.swiftVarianceAmount != null
          ? '${p.swiftVarianceAmount} ${p.swiftTransferredCurrency ?? p.currencyCode}'
          : '-';
      final status = p.swiftVarianceStatus ??
          (p.swiftReferenceNo != null && p.swiftReferenceNo!.isNotEmpty
              ? l10n.swiftBadgeMatchedFull
              : l10n.swiftBadgePending);
      final resolvedShipTitle = DisplayNameResolver.resolveShipmentTitleByCode(
        p.importFileCode,
        shipments: allFiles,
        isArabic: isAr,
      );

      buffer.writeln([
        p.paymentCode,
        resolvedShipTitle,
        p.beneficiaryName ?? p.supplierName,
        p.bankName ?? '-',
        p.requestDate,
        p.swiftReceiptDate ?? '-',
        days,
        '${p.requestedAmount} ${p.currencyCode}',
        transferred,
        variance,
        p.swiftReferenceNo ?? '-',
        status,
      ].join('\t'));
    }

    CopyHelper.copy(context, buffer.toString(),
        customMessage: l10n.swiftExportTsvSuccess);
  }

  void _copyFilteredSummary(List<PaymentRequestModel> payments) {
    final l10n = context.l10n;
    final matchedCount =
        payments.where((p) => p.swiftVarianceStatus == 'Matched').length;
    final pendingCount = payments
        .where((p) => p.swiftReferenceNo == null || p.swiftReferenceNo!.isEmpty)
        .length;
    final varianceCount = payments
        .where((p) =>
            p.swiftVarianceStatus == 'Deficit' ||
            p.swiftVarianceStatus == 'Surplus')
        .length;

    final summary = '''
${l10n.swiftScreenTitle}
${l10n.swiftTableTitle(payments.length)}
${l10n.swiftTotalRequestsMetric}: ${payments.length}
${l10n.swiftMatchedSwiftMetric}: $matchedCount
${l10n.swiftPendingSwiftMetric}: $pendingCount
${l10n.swiftVariancesMetric}: $varianceCount
'''
        .trim();

    CopyHelper.copy(context, summary,
        customMessage: l10n.swiftCopySummarySuccess);
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppTheme.white : AppTheme.charcoal)),
      selected: isSelected,
      selectedColor: AppTheme.cobalt,
      backgroundColor: AppTheme.charcoalSurface,
      onSelected: (selected) {
        if (selected) setState(() => _selectedStatusFilter = value);
      },
    );
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
          Container(
            padding: const EdgeInsets.all(12),
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
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, val, child) {
                      return TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: l10n.swiftSearchPlaceholder,
                          prefixIcon: const Icon(Icons.search,
                              color: AppTheme.cobalt),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (val.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.copy,
                                    size: 16, color: AppTheme.cobalt),
                                tooltip: l10n.swiftCopyBtn,
                                onPressed: () => CopyHelper.copy(
                                    context, _searchController.text),
                              ),
                            ],
                          ),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() {}),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Filter Chips
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip(
                        l10n.swiftFilterAll(totalRequests), 'ALL'),
                    _buildFilterChip(
                        l10n.swiftFilterPending(pendingSwift), 'PENDING'),
                    _buildFilterChip(
                        l10n.swiftFilterMatched(matchedSwift), 'MATCHED'),
                    _buildFilterChip(
                        l10n.swiftFilterVariances(discrepancySwift), 'DEFICIT'),
                  ],
                ),
              ],
            ),
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
                                : () => _exportTsv(filtered),
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
                                : () => _copyFilteredSummary(filtered),
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
                  columns: [
                    EnterpriseColumn<PaymentRequestModel>(
                      id: 'actions',
                      title: l10n.swiftColActions,
                      width: 320,
                      isSortable: false,
                      isSearchable: false,
                      cellBuilder: (ctx, pay, _) {
                        final isReconciled = pay.swiftReferenceNo != null &&
                            pay.swiftReferenceNo!.isNotEmpty;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FinancialUi.fit(AppButton(
                              label: isReconciled
                                  ? l10n.swiftEditBtn
                                  : l10n.swiftRegisterBtn,
                              variant: AppButtonVariant.primary,
                              size: AppButtonSize.small,
                              icon: isReconciled
                                  ? Icons.edit
                                  : Icons.account_balance,
                              onPressed: () => SwiftDiscrepancyDialog.show(
                                context,
                                pay: pay,
                                onReconciled: widget.onReconciled,
                              ),
                            )),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.visibility,
                                  color: AppTheme.charcoal, size: 18),
                              tooltip: l10n.swiftDetailsBtn,
                              onPressed: () => SwiftMt103PreviewDialog.show(
                                context,
                                pay: pay,
                                onReconciled: widget.onReconciled,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy,
                                  color: AppTheme.cobalt, size: 16),
                              tooltip: l10n.swiftCopyDossierBtn,
                              onPressed: () => copyPaymentDossier(
                                context: context,
                                ref: ref,
                                pay: pay,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    EnterpriseColumn<PaymentRequestModel>(
                      id: 'payment_code',
                      title: l10n.swiftColPaymentCode,
                      width: 210,
                      searchValue: (pay) =>
                          '${pay.paymentCode} ${pay.importFileCode ?? ""}',
                      exportValue: (pay) => pay.paymentCode,
                      cellBuilder: (ctx, pay, _) {
                        final allFiles =
                            ref.watch(importFilesProvider).valueOrNull ?? [];
                        final isAr = Localizations.localeOf(context)
                                .languageCode ==
                            'ar';
                        final shipName =
                            DisplayNameResolver.resolveShipmentNameByCode(
                          pay.importFileCode,
                          shipments: allFiles,
                          isArabic: isAr,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LtrText(
                                  pay.paymentCode,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.cobalt,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                SwiftCopyBadge(
                                  text: pay.paymentCode,
                                  tooltip: l10n.swiftCopyBtn,
                                ),
                              ],
                            ),
                            if (pay.importFileCode != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      shipName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.charcoal,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.charcoal
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        pay.importFileCode!,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: AppTheme.textStrong,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    SwiftCopyBadge(
                                      text: pay.importFileCode!,
                                      tooltip: l10n.swiftCopyBtn,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    EnterpriseColumn<PaymentRequestModel>(
                      id: 'beneficiary',
                      title: l10n.swiftColBeneficiaryBank,
                      width: 180,
                      searchValue: (pay) =>
                          '${pay.beneficiaryName ?? pay.supplierName} ${pay.bankName ?? ""}',
                      exportValue: (pay) =>
                          '${pay.beneficiaryName ?? pay.supplierName} - ${pay.bankName ?? ""}',
                      cellBuilder: (ctx, pay, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            pay.beneficiaryName ?? pay.supplierName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            pay.bankName ?? l10n.swiftUnspecifiedBank,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    EnterpriseColumn<PaymentRequestModel>(
                      id: 'request_date',
                      title: l10n.swiftColRequestDate,
                      width: 115,
                      isNumeric: true,
                      searchValue: (pay) => pay.requestDate,
                      exportValue: (pay) => pay.requestDate,
                      cellBuilder: (ctx, pay, _) => Text(
                        pay.requestDate.isNotEmpty ? pay.requestDate : '-',
                      ),
                    ),
                    EnterpriseColumn<PaymentRequestModel>(
                      id: 'swift_date',
                      title: l10n.swiftColSwiftDate,
                      width: 115,
                      isNumeric: true,
                      searchValue: (pay) => pay.swiftReceiptDate ?? '',
                      exportValue: (pay) => pay.swiftReceiptDate ?? '-',
                      cellBuilder: (ctx, pay, _) {
                        final isReconciled = pay.swiftReferenceNo != null &&
                            pay.swiftReferenceNo!.isNotEmpty;
                        return Text(
                          pay.swiftReceiptDate ?? l10n.swiftPendingSwiftBadge,
                          style: TextStyle(
                            fontWeight: isReconciled
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isReconciled
                                ? AppTheme.charcoal
                                : AppTheme.textMuted,
                          ),
                        );
                      },
                    ),
                    EnterpriseColumn<PaymentRequestModel>(
                      id: 'processing_time',
                      title: l10n.swiftColProcessingTime,
                      width: 130,
                      cellBuilder: (ctx, pay, _) {
                        if (pay.swiftProcessingDays == null) {
                          return Text(
                            l10n.swiftProcessingPending,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          );
                        }
                        final days = pay.swiftProcessingDays!;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: days <= 3
                                ? AppTheme.emeraldLight
                                : (days <= 7
                                    ? AppTheme.orangeLight
                                    : AppTheme.crimsonLight),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: days <= 3
                                  ? AppTheme.emeraldBorder
                                  : (days <= 7
                                      ? AppTheme.orange
                                      : AppTheme.crimsonBorder),
                            ),
                          ),
                          child: Text(
                            '⚡ ${l10n.swiftDaysCount(days.toString())}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: days <= 3
                                  ? AppTheme.wcagEmerald
                                  : (days <= 7
                                      ? AppTheme.wcagOrange
                                      : AppTheme.crimson),
                            ),
                          ),
                        );
                      },
                    ),
                    EnterpriseColumn<PaymentRequestModel>(
                      id: 'requested_amount',
                      title: l10n.swiftColRequestedAmount,
                      width: 135,
                      isNumeric: true,
                      searchValue: (pay) =>
                          '${pay.requestedAmount} ${pay.currencyCode}',
                      exportValue: (pay) =>
                          '${pay.requestedAmount.toStringAsFixed(2)} ${pay.currencyCode}',
                      cellBuilder: (ctx, pay, _) => Text(
                        '${pay.requestedAmount.toStringAsFixed(2)} ${pay.currencyCode}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    EnterpriseColumn<PaymentRequestModel>(
                      id: 'transferred_amount',
                      title: l10n.swiftColTransferredAmount,
                      width: 135,
                      isNumeric: true,
                      searchValue: (pay) =>
                          pay.swiftTransferredAmount?.toString() ?? '',
                      exportValue: (pay) => pay.swiftTransferredAmount != null
                          ? '${pay.swiftTransferredAmount!.toStringAsFixed(2)} ${pay.swiftTransferredCurrency ?? pay.currencyCode}'
                          : '-',
                      cellBuilder: (ctx, pay, _) =>
                          pay.swiftTransferredAmount != null
                              ? Text(
                                  '${pay.swiftTransferredAmount!.toStringAsFixed(2)} ${pay.swiftTransferredCurrency ?? pay.currencyCode}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.emerald,
                                  ),
                                )
                              : const Text('-',
                                  style:
                                      TextStyle(color: AppTheme.textMuted)),
                    ),
                    EnterpriseColumn<PaymentRequestModel>(
                      id: 'variance_status',
                      title: l10n.swiftColVarianceStatus,
                      width: 130,
                      searchValue: (pay) => pay.swiftVarianceStatus ?? '',
                      exportValue: (pay) =>
                          '${pay.swiftVarianceStatus ?? "-"} ${pay.swiftVarianceAmount != null ? pay.swiftVarianceAmount!.toStringAsFixed(2) : ""}',
                      cellBuilder: (ctx, pay, _) => SwiftVarianceBadge(
                        status: pay.swiftVarianceStatus,
                        variance: pay.swiftVarianceAmount,
                        currency: pay.currencyCode,
                      ),
                    ),
                    EnterpriseColumn<PaymentRequestModel>(
                      id: 'swift_ref',
                      title: l10n.swiftColSwiftRef,
                      width: 150,
                      searchValue: (pay) => pay.swiftReferenceNo ?? '',
                      exportValue: (pay) => pay.swiftReferenceNo ?? '-',
                      cellBuilder: (ctx, pay, _) {
                        if (pay.swiftReferenceNo != null &&
                            pay.swiftReferenceNo!.isNotEmpty) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.cobaltLight,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: AppTheme.cobaltBorder),
                                ),
                                child: Text(
                                  pay.swiftReferenceNo!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: AppTheme.cobalt,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              SwiftCopyBadge(
                                text: pay.swiftReferenceNo!,
                                tooltip: l10n.swiftCopyBtn,
                              ),
                            ],
                          );
                        }
                        return Text(
                          l10n.swiftUnregistered,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
