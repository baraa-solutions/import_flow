import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/logistics_invoices_provider.dart';

class LogisticsPaymentsTab extends ConsumerWidget {
  final bool isDark;
  final VoidCallback onCreatePayment;

  const LogisticsPaymentsTab({
    super.key,
    required this.isDark,
    required this.onCreatePayment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = context.l10n.isArabic;
    final vouchersAsync = ref.watch(paymentVouchersListProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF161E28) : Colors.white,
          child: Row(
            children: [
              Text(
                isArabic ? 'سندات صرف وإقفال فواتير الخدمات اللوجستية' : 'Logistics Payment Vouchers & Invoice Knock-offs',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              AppButton(
                label: isArabic ? '+ إنشاء سند صرف' : '+ Create Payment Voucher',
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                icon: Icons.add,
                onPressed: onCreatePayment,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: vouchersAsync.when(
            loading: () => const AppLoadingState(),
            error: (err, _) => AppErrorState(
              error: err,
              onRetry: () => ref.invalidate(paymentVouchersListProvider),
            ),
            data: (vouchers) {
              if (vouchers.isEmpty) {
                return AppEmptyState(
                  icon: Icons.payment,
                  message: isArabic
                      ? 'لا توجد سندات صرف مسجلة حتى الآن.'
                      : 'No payment vouchers recorded yet.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: vouchers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final v = vouchers[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B232D) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_outlined, color: AppTheme.emerald, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${v.voucherCode} · ${v.partnerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                '${isArabic ? "الطريقة" : "Method"}: ${v.paymentMethod} · ${isArabic ? "المرجع" : "Ref"}: ${v.bankReference ?? "—"} · ${isArabic ? "التاريخ" : "Date"}: ${v.paymentDate.toIso8601String().split("T").first}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${v.amountEgp.toStringAsFixed(2)} ${isArabic ? "ج.م" : "EGP"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('${isArabic ? "المقفل" : "Knocked Off"}: ${v.knockoffs.length} ${isArabic ? "فواتير" : "Invoices"}', style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
