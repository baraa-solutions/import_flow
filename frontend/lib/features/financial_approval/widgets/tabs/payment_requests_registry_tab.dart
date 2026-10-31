import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';
import '../../services/financial_export_service.dart';
import '../dialogs/clone_payment_review_dialog.dart';
import '../financial_ui.dart';
import '../payment_request_details_dialog.dart';

class PaymentRequestsRegistryTab extends ConsumerStatefulWidget {
  final void Function(PaymentRequestModel payment) onEditPayment;
  final void Function(PaymentRequestModel payment)? onViewPayment;
  final void Function(PaymentRequestModel payment)? onClonePayment;
  final VoidCallback? onOpenSwiftReconciliation;

  const PaymentRequestsRegistryTab({
    super.key,
    required this.onEditPayment,
    this.onViewPayment,
    this.onClonePayment,
    this.onOpenSwiftReconciliation,
  });

  @override
  ConsumerState<PaymentRequestsRegistryTab> createState() =>
      _PaymentRequestsRegistryTabState();
}

class _PaymentRequestsRegistryTabState
    extends ConsumerState<PaymentRequestsRegistryTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  Future<void> _confirmDeletePaymentRequest(PaymentRequestModel p) async {
    final confirm = await AppConfirmDialog.showDelete(
      context,
      title: context.l10n.confirmDeletePaymentTitle,
      message: context.l10n.confirmDeletePaymentMessage(p.paymentCode, p.title),
      entityName: '${p.paymentCode} - ${p.title}',
    );

    if (confirm == true) {
      try {
        await ref
            .read(paymentRequestsProvider.notifier)
            .softDeletePaymentRequest(p.paymentId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              context.l10n.paymentDeletedSuccess(p.paymentCode),
              severity: AppSeverity.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              context.l10n.deleteErrorMsg(ApiError.message(e)),
              severity: AppSeverity.danger,
            ),
          );
        }
      }
    }
  }

  void _showPaymentDetailsDialog(PaymentRequestModel pay) {
    if (widget.onViewPayment != null) {
      widget.onViewPayment!(pay);
      return;
    }
    PaymentRequestDetailsDialog.show(
      context,
      payment: pay,
      onOpenSwiftReconciliation: widget.onOpenSwiftReconciliation,
      onStatusChanged: () {
        ref.read(paymentRequestsProvider.notifier).fetchPaymentRequests();
      },
    );
  }

  void _openClonePayment(PaymentRequestModel p) {
    if (widget.onClonePayment != null) {
      widget.onClonePayment!(p);
      return;
    }
    ClonePaymentReviewDialog.show(
      context: context,
      ref: ref,
      payment: p,
      onCloned: (cloned) {
        widget.onEditPayment(cloned);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paymentsState = ref.watch(paymentRequestsProvider);

    return SelectionArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary metrics (shared compact strip)
            paymentsState.maybeWhen(
              data: (payments) {
                final pending = payments.where((p) {
                  final s = p.status.toLowerCase();
                  return s.contains('pending') || s == 'draft';
                }).length;
                final paid = payments
                    .where((p) => p.status.toLowerCase() == 'paid')
                    .length;
                final totalEgp = payments.fold<double>(
                    0.0, (sum, p) => sum + p.requestedAmountEgp);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FinancialUi.metrics([
                    MetricCardData(
                      icon: Icons.receipt_long_outlined,
                      title: l.swiftTotalRequestsMetric,
                      value: '${payments.length}',
                      color: AppTheme.cobalt,
                    ),
                    MetricCardData(
                      icon: Icons.hourglass_top_rounded,
                      title: l.statusPendingReview,
                      value: '$pending',
                      color: AppTheme.orange,
                    ),
                    MetricCardData(
                      icon: Icons.check_circle_outline,
                      title: l.paidStatus,
                      value: '$paid',
                      color: AppTheme.emerald,
                    ),
                    MetricCardData(
                      icon: Icons.monetization_on_outlined,
                      title: l.totalValueEgpMetric,
                      value: '${totalEgp.toStringAsFixed(2)} EGP',
                      color: AppTheme.emerald,
                    ),
                  ]),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),

            // Top Master Data Toolbar
            paymentsState.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (payments) {
                final filtered = payments.where((p) {
                  final matchQ = _searchQuery.isEmpty ||
                      p.paymentCode
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      p.supplierName
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      p.title
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      (p.importFileCode ?? '')
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase());
                  final matchS =
                      _statusFilter == 'All' || p.status == _statusFilter;
                  return matchQ && matchS;
                }).toList();

                return MasterDataToolbarWidget(
                  moduleEndpoint: 'financial-approval',
                  title: '${l.paymentRequestsLogTitle} (${filtered.length})',
                  onExportExcel: () => FinancialExportService
                      .exportPaymentRequestsListToExcel(
                          context: context, list: filtered),
                  onRefreshNeeded: () => ref
                      .read(paymentRequestsProvider.notifier)
                      .fetchPaymentRequests(),
                );
              },
            ),
            const SizedBox(height: 12),

            // Search & Filters Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: l.searchPaymentsHint,
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 220,
                  child: SearchableDropdownField<String>(
                    value: _statusFilter,
                    labelText: l.filterByStatus,
                    searchHintText: l.search,
                    items: [
                      SearchableDropdownItem(
                          value: 'All', label: l.allStatuses),
                      SearchableDropdownItem(
                          value: 'Draft', label: l.draftStatus),
                      SearchableDropdownItem(
                          value: 'Approved', label: l.approvedBudgetsMetric),
                      SearchableDropdownItem(
                          value: 'Paid', label: l.paidStatus),
                      SearchableDropdownItem(
                          value: 'Reconciled', label: l.reconciledStatus),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _statusFilter = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Standardized Saved Registry Table Container
            Expanded(
              child: paymentsState.when(
                loading: () => const FinancialStateView.loading(),
                error: (err, stack) => FinancialStateView.error(
                  message: l.faLoadFailed(ApiError.message(err)),
                  actionLabel: l.retry,
                  onAction: () => ref
                      .read(paymentRequestsProvider.notifier)
                      .fetchPaymentRequests(),
                ),
                data: (payments) {
                  final allFiles =
                      ref.watch(importFilesProvider).valueOrNull ?? [];
                  final isAr =
                      Localizations.localeOf(context).languageCode == 'ar';
                  final filtered = payments.where((p) {
                    final matchQ = _searchQuery.isEmpty ||
                        p.paymentCode
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ||
                        p.supplierName
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ||
                        p.title
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ||
                        (p.importFileCode ?? '')
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase());
                    final matchS =
                        _statusFilter == 'All' || p.status == _statusFilter;
                    return matchQ && matchS;
                  }).toList();

                  return EnterpriseDataTable<PaymentRequestModel>(
                    storageKey: 'financial_approval_payments_table',
                    data: filtered,
                    minWidth: 1250,
                    isScrollable: false,
                    showHeaderToolbar: false,
                    showPagination: true,
                    initialPageSize: 25,
                    emptyMessage: l.noMatchingPayments,
                    columns: [
                      EnterpriseColumn<PaymentRequestModel>(
                        id: 'actions',
                        title: l.actionsCol,
                        width: 150,
                        isSortable: false,
                        isSearchable: false,
                        cellBuilder: (ctx, p, _) => RowActionsPill(
                          onView: () => _showPaymentDetailsDialog(p),
                          onEdit: () => widget.onEditPayment(p),
                          onClone: () => _openClonePayment(p),
                          onPrint: () => FinancialExportService
                              .printPaymentRequestPdf(payment: p),
                          onDelete: () => _confirmDeletePaymentRequest(p),
                        ),
                      ),
                      EnterpriseColumn<PaymentRequestModel>(
                        id: 'payment_code',
                        title: l.paymentCodeCol,
                        width: 130,
                        searchValue: (p) => p.paymentCode,
                        exportValue: (p) => p.paymentCode,
                        cellBuilder: (ctx, p, _) => InkWell(
                          onTap: () => CopyHelper.copy(
                            context,
                            p.paymentCode,
                            customMessage:
                                '${l.paymentCodeCol}: ${p.paymentCode}',
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color:
                                      AppTheme.cobalt.withValues(alpha: 0.3)),
                            ),
                            child: LtrText(
                              p.paymentCode,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.cobalt,
                                  fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      EnterpriseColumn<PaymentRequestModel>(
                        id: 'import_file',
                        title: l.importFile,
                        width: 170,
                        searchValue: (p) =>
                            '${p.importFileCode ?? ""} ${p.importFileId ?? ""}',
                        exportValue: (p) => p.importFileCode ?? '',
                        cellBuilder: (ctx, p, _) {
                          final rawFileCode = p.importFileCode ??
                              (p.importFileId != null
                                  ? 'IMP-${p.importFileId}'
                                  : '');
                          final resolvedShipName =
                              DisplayNameResolver.resolveShipmentNameByCode(
                                  rawFileCode,
                                  shipments: allFiles,
                                  isArabic: isAr);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                resolvedShipName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.charcoal,
                                    fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (rawFileCode.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.charcoal
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    rawFileCode,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textStrong,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      EnterpriseColumn<PaymentRequestModel>(
                        id: 'beneficiary',
                        title: l.beneficiarySupplierLabel,
                        width: 180,
                        searchValue: (p) =>
                            '${p.beneficiaryName ?? p.supplierName} ${p.title}',
                        exportValue: (p) =>
                            '${p.beneficiaryName ?? p.supplierName} - ${p.title}',
                        cellBuilder: (ctx, p, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              p.beneficiaryName ?? p.supplierName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              p.title,
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      EnterpriseColumn<PaymentRequestModel>(
                        id: 'bank_swift',
                        title: l.bankSwiftCol,
                        width: 150,
                        searchValue: (p) =>
                            '${p.bankName ?? ""} ${p.swiftCode ?? ""}',
                        exportValue: (p) =>
                            '${p.bankName ?? "-"} ${p.swiftCode ?? ""}',
                        cellBuilder: (ctx, p, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(p.bankName ?? '-',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w500)),
                            if (p.swiftCode != null && p.swiftCode!.isNotEmpty)
                              Text('SWIFT: ${p.swiftCode}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.textStrong)),
                          ],
                        ),
                      ),
                      EnterpriseColumn<PaymentRequestModel>(
                        id: 'payment_type',
                        title: l.paymentTypeLabel,
                        width: 110,
                        searchValue: (p) => p.paymentType,
                        exportValue: (p) => p.paymentType,
                        cellBuilder: (ctx, p, _) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.orangeLight,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.orange),
                          ),
                          child: Text(p.paymentType,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.wcagOrange)),
                        ),
                      ),
                      EnterpriseColumn<PaymentRequestModel>(
                        id: 'requested_amount',
                        title: l.requestedAmountLabel,
                        width: 135,
                        isNumeric: true,
                        searchValue: (p) =>
                            '${p.requestedAmount} ${p.currencyCode}',
                        exportValue: (p) =>
                            '${p.requestedAmount.toStringAsFixed(2)} ${p.currencyCode}',
                        cellBuilder: (ctx, p, _) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.cobaltLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: LtrText(
                            '${p.requestedAmount.toStringAsFixed(2)} ${p.currencyCode}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.wcagCobalt,
                                fontSize: 12),
                          ),
                        ),
                      ),
                      EnterpriseColumn<PaymentRequestModel>(
                        id: 'equivalent_egp',
                        title: l.equivalentEgpCol,
                        width: 135,
                        isNumeric: true,
                        searchValue: (p) => '${p.requestedAmountEgp} EGP',
                        exportValue: (p) =>
                            '${p.requestedAmountEgp.toStringAsFixed(2)} EGP',
                        cellBuilder: (ctx, p, _) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkCardBackground
                                : AppTheme.emeraldLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: LtrText(
                            '${p.requestedAmountEgp.toStringAsFixed(2)} EGP',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.wcagEmerald,
                                fontSize: 12),
                          ),
                        ),
                      ),
                      EnterpriseColumn<PaymentRequestModel>(
                        id: 'request_due_date',
                        title: l.requestDueDateCol,
                        width: 140,
                        searchValue: (p) => '${p.requestDate} ${p.dueDate}',
                        exportValue: (p) => '${p.requestDate} / ${p.dueDate}',
                        cellBuilder: (ctx, p, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                                '${l.requestDateLabel}: ${p.requestDate.isNotEmpty ? p.requestDate : "-"}',
                                style: const TextStyle(fontSize: 11)),
                            Text('${l.dueDateLabel}: ${p.dueDate}',
                                style: const TextStyle(
                                    fontSize: 10, color: AppTheme.textStrong)),
                          ],
                        ),
                      ),
                      EnterpriseColumn<PaymentRequestModel>(
                        id: 'status',
                        title: l.statusCol,
                        width: 110,
                        searchValue: (p) => p.status,
                        exportValue: (p) => p.status,
                        cellBuilder: (ctx, p, _) =>
                            FinancialStatusChip(status: p.status),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
