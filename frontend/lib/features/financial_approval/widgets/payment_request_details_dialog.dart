import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_error.dart';
import '../models/financial_approval_model.dart';
import '../providers/financial_approval_provider.dart';
import '../services/financial_export_service.dart';
import 'async_action_button.dart';
import 'financial_ui.dart';
import 'payment_email_share_dialog.dart';
import 'payment_whatsapp_share_dialog.dart';

class PaymentRequestDetailsDialog extends ConsumerStatefulWidget {
  final PaymentRequestModel payment;
  final VoidCallback? onOpenSwiftReconciliation;
  final VoidCallback? onStatusChanged;

  const PaymentRequestDetailsDialog({
    super.key,
    required this.payment,
    this.onOpenSwiftReconciliation,
    this.onStatusChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required PaymentRequestModel payment,
    VoidCallback? onOpenSwiftReconciliation,
    VoidCallback? onStatusChanged,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => PaymentRequestDetailsDialog(
        payment: payment,
        onOpenSwiftReconciliation: onOpenSwiftReconciliation,
        onStatusChanged: onStatusChanged,
      ),
    );
  }

  @override
  ConsumerState<PaymentRequestDetailsDialog> createState() =>
      _PaymentRequestDetailsDialogState();
}

class _PaymentRequestDetailsDialogState
    extends ConsumerState<PaymentRequestDetailsDialog> {
  late final TextEditingController _swiftController;

  @override
  void initState() {
    super.initState();
    _swiftController =
        TextEditingController(text: widget.payment.swiftReferenceNo ?? '');
  }

  @override
  void dispose() {
    _swiftController.dispose();
    super.dispose();
  }

  Widget _buildMetricBadge(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          CopyableText(
            value,
            style: TextStyle(
                fontSize: 14, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pay = widget.payment;

    return SelectionArea(
      child: AlertDialog(
      backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              l.paymentRequestDetailsTitle(pay.paymentCode),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          FinancialStatusChip(status: pay.status),
        ],
      ),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pay.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l.beneficiarySupplierDetails(
                    pay.beneficiaryName ?? pay.supplierName),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '${l.paymentTypeLabel}: ${FinancialUi.paymentTypeLabel(l, pay.paymentType)} | '
                '${l.requestDateLabel}: ${pay.requestDate.isNotEmpty ? pay.requestDate : "-"} | '
                '${l.dueDateLabel}: ${pay.dueDate}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                ),
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricBadge(
                      l.foreignAmountMetric,
                      '${pay.requestedAmount} ${pay.currencyCode}',
                      AppTheme.cobalt,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricBadge(
                      l.exchangeRateCol,
                      '${pay.exchangeRate} EGP',
                      AppTheme.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricBadge(
                      l.equivalentEgpCol,
                      '${pay.requestedAmountEgp.toStringAsFixed(2)} EGP',
                      AppTheme.emerald,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurface
                      : AppTheme.cobaltLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorder
                          : AppTheme.cobaltBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l.beneficiaryBankDetails}:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cobalt,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${l.bankNameLabel}: ${pay.bankName ?? "-"}'),
                    Text('${l.swiftCodeLabel}: ${pay.swiftCode ?? "-"}'),
                    Text('${l.ibanAccountLabel}: ${pay.ibanAccountNo ?? "-"}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── EXPORT & SHARING ACTION TOOLBAR ────────────────────────
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurface
                      : AppTheme.charcoalSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorder
                          : AppTheme.cloudWhite),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.share_outlined,
                            size: 16, color: AppTheme.cobalt),
                        const SizedBox(width: 6),
                        Text(
                          l.exportAndShareOptionsTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.charcoal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // 1. Print / Save PDF
                        AppButton(
                          label: l.printSavePdfBtn,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.small,
                          icon: Icons.print,
                          onPressed: () {
                            FinancialExportService.printPaymentRequestPdf(
                                payment: pay);
                          },
                        ),
                        // 2. Export Excel
                        AppButton(
                          label: l.downloadExcelBtn,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.small,
                          icon: Icons.table_chart,
                          onPressed: () async {
                            final scaffold = ScaffoldMessenger.of(context);
                            final path = await FinancialExportService
                                .exportSinglePaymentRequestToExcel(
                              context: context,
                              payment: pay,
                            );
                            if (path != null && mounted) {
                              scaffold.showSnackBar(
                                AppTheme.snackBar(context, l.excelSavedSuccess(path), severity: AppSeverity.success),
                              );
                            }
                          },
                        ),
                        // 3. WhatsApp Sharing
                        AppButton(
                          label: l.whatsappShareBtn,
                          variant: AppButtonVariant.success,
                          size: AppButtonSize.small,
                          icon: Icons.chat,
                          onPressed: () {
                            PaymentWhatsAppShareDialog.show(context,
                                payment: pay);
                          },
                        ),
                        // 4. Email Sharing
                        AppButton(
                          label: l.emailShareBtn,
                          variant: AppButtonVariant.warning,
                          size: AppButtonSize.small,
                          icon: Icons.email_outlined,
                          onPressed: () {
                            PaymentEmailShareDialog.show(context,
                                payment: pay);
                          },
                        ),
                        // 5. Copy Summary
                        AppButton(
                          label: l.copySummaryBtn,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.small,
                          icon: Icons.copy,
                          onPressed: () {
                            final text = FinancialExportService
                                .generatePaymentWhatsAppText(pay);
                            CopyHelper.copy(context, text);
                          },
                        ),
                        // 6. SWIFT Smart Reconcile & Auto Match
                        AppButton(
                          label: l.extractAndMatchSwiftBtn,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.small,
                          icon: Icons.auto_awesome,
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onOpenSwiftReconciliation?.call();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (pay.status == 'Approved') ...[
                const Divider(height: 24),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _swiftController,
                  builder: (context, value, _) {
                    final isEmpty = value.text.trim().isEmpty;
                    return TextField(
                      controller: _swiftController,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.charcoal),
                      decoration: InputDecoration(
                        labelText: l.swiftReferenceInputLabel,
                        errorText: isEmpty ? l.fieldRequired : null,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.tag),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: l.close,
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        if (pay.status == 'Draft' || pay.status == 'Pending Approval') ...[
          AsyncActionButton(
            label: l.approvePaymentAction,
            onAction: () async {
              final nav = Navigator.of(context);
              final scaffold = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(paymentRequestsProvider.notifier)
                    .approvePaymentRequest(pay.paymentId);
                widget.onStatusChanged?.call();
                nav.pop();
              } catch (e) {
                if (mounted) {
                  scaffold.showSnackBar(
                    AppTheme.snackBar(context, ApiError.message(e), severity: AppSeverity.danger),
                  );
                }
              }
            },
          ),
        ],
        if (pay.status == 'Approved') ...[
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _swiftController,
            builder: (context, value, _) {
              final canPay = value.text.trim().isNotEmpty;
              return AsyncActionButton(
                label: l.markAsPaidAction,
                variant: AppButtonVariant.success,
                enabled: canPay,
                onAction: () async {
                  if (!canPay) return;
                  final nav = Navigator.of(context);
                  final scaffold = ScaffoldMessenger.of(context);
                  try {
                    await ref
                        .read(paymentRequestsProvider.notifier)
                        .executePayment(
                          pay.paymentId,
                          swiftRef: _swiftController.text.trim(),
                        );
                    widget.onStatusChanged?.call();
                    nav.pop();
                  } catch (e) {
                    if (mounted) {
                      scaffold.showSnackBar(
                        AppTheme.snackBar(context, ApiError.message(e), severity: AppSeverity.danger),
                      );
                    }
                  }
                },
              );
            },
          ),
        ],
      ],
    ),
    );
  }
}
