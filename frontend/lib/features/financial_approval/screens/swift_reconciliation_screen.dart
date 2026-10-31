import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../widgets/financial_ui.dart';
import '../providers/financial_approval_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../widgets/swift_reconciliation/swift_upload_step_card.dart';
import '../widgets/swift_reconciliation/swift_manual_audit_table.dart';

export '../widgets/swift_reconciliation/swift_reconciliation_common.dart'
    show kSampleSwiftMT103, SwiftVarianceBadge, SwiftCopyBadge;
export '../widgets/swift_reconciliation/swift_upload_step_card.dart'
    show SwiftUploadStepCard;
export '../widgets/swift_reconciliation/swift_manual_audit_table.dart'
    show SwiftManualAuditTable;
export '../widgets/swift_reconciliation/swift_discrepancy_dialog.dart'
    show SwiftDiscrepancyDialog;
export '../widgets/swift_reconciliation/swift_mt103_preview_card.dart'
    show SwiftMt103PreviewDialog;

/// Stage review screen and coordinator for bank SWIFT (MT103) reconciliations.
/// Manages DedicatedStageScaffold integration, KPI summary metrics,
/// intelligent document OCR extraction, and manual audit table.
class SwiftReconciliationScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const SwiftReconciliationScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<SwiftReconciliationScreen> createState() =>
      _SwiftReconciliationScreenState();
}

class _SwiftReconciliationScreenState
    extends ConsumerState<SwiftReconciliationScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!ref.read(paymentRequestsProvider).isLoading) {
        ref.read(paymentRequestsProvider.notifier).fetchPaymentRequests();
      }
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
      if (!ref.read(currenciesProvider).isLoading) {
        ref.read(currenciesProvider.notifier).fetchCurrencies();
      }
    });
  }

  void _refreshData() {
    ref.read(paymentRequestsProvider.notifier).fetchPaymentRequests();
    ref.read(importFilesProvider.notifier).fetchImportFiles();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final paymentsState = ref.watch(paymentRequestsProvider);
    final paymentsList = paymentsState.valueOrNull ?? [];

    if (paymentsState.isLoading && paymentsList.isEmpty) {
      return const SelectionArea(child: AppLoadingState());
    }

    // Calculate operational KPI metrics
    final totalRequests = paymentsList.where((p) => p.isActive).length;
    final pendingSwift = paymentsList
        .where((p) =>
            p.isActive &&
            (p.swiftReferenceNo == null || p.swiftReferenceNo!.isEmpty))
        .length;
    final matchedSwift = paymentsList
        .where((p) => p.isActive && p.swiftVarianceStatus == 'Matched')
        .length;
    final discrepancySwift = paymentsList
        .where((p) =>
            p.isActive &&
            (p.swiftVarianceStatus == 'Deficit' ||
                p.swiftVarianceStatus == 'Surplus'))
        .length;

    final reconciledItems = paymentsList
        .where((p) => p.isActive && p.swiftProcessingDays != null)
        .toList();
    final avgDays = reconciledItems.isNotEmpty
        ? (reconciledItems
                    .map((p) => p.swiftProcessingDays!)
                    .reduce((a, b) => a + b) /
                reconciledItems.length)
            .toStringAsFixed(1)
        : '0.0';

    final content = SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI metrics strip
            FinancialUi.metrics([
              MetricCardData(
                title: l10n.swiftTotalRequestsMetric,
                value: totalRequests.toString(),
                icon: Icons.receipt_long,
                color: AppTheme.cobalt,
              ),
              MetricCardData(
                title: l10n.swiftPendingSwiftMetric,
                value: pendingSwift.toString(),
                icon: Icons.hourglass_top,
                color: AppTheme.orange,
              ),
              MetricCardData(
                title: l10n.swiftMatchedSwiftMetric,
                value: matchedSwift.toString(),
                icon: Icons.check_circle_outline,
                color: AppTheme.emerald,
              ),
              MetricCardData(
                title: l10n.swiftVariancesMetric,
                value: discrepancySwift.toString(),
                icon: Icons.compare_arrows,
                color: AppTheme.crimson,
              ),
              MetricCardData(
                title: l10n.swiftAvgProcessingTimeMetric,
                value: l10n.swiftDaysCount(avgDays),
                icon: Icons.speed,
                color: AppTheme.emerald,
              ),
            ]),
            const SizedBox(height: 16),

            // Smart AI SWIFT MT103 Extractor & Auto-Reconciler Tool
            SwiftUploadStepCard(
              paymentsList: paymentsList,
              onReconciliationCompleted: _refreshData,
            ),
            const SizedBox(height: 16),

            // Table of Payment Requests & SWIFTs with filters & multi-format export
            SwiftManualAuditTable(
              payments: paymentsList,
              onReconciled: _refreshData,
            ),
          ],
        ),
      ),
    );

    if (widget.isEmbedded) {
      return Container(
        color: AppTheme.charcoalSurface,
        child: content,
      );
    }

    return SelectionArea(
      child: DedicatedStageScaffold(
        stageCode: 'STEP_04_SWIFT',
        titleAr: 'مطابقة وإدارة سويفت التحويلات البنكية (SWIFT MT103)',
        titleEn: 'SWIFT MT103 Bank Reconciliation',
        headerIcon: Icons.account_balance,
        headerColor: AppTheme.cobalt,
        onShipmentStatusChanged: _refreshData,
        headerActions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.white),
            tooltip: l10n.swiftRefreshBtn,
            onPressed: _refreshData,
          ),
        ],
        body: content,
      ),
    );
  }
}
