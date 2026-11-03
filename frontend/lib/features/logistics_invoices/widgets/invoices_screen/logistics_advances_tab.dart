import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/logistics_invoices_provider.dart';

class LogisticsAdvancesTab extends ConsumerWidget {
  final bool isDark;
  final VoidCallback onCreateAdvance;

  const LogisticsAdvancesTab({
    super.key,
    required this.isDark,
    required this.onCreateAdvance,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = context.l10n.isArabic;
    final advancesAsync = ref.watch(clearanceAdvancesListProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF161E28) : Colors.white,
          child: Row(
            children: [
              Text(
                isArabic ? 'عهد ودفعات المخلصين الجمركيين' : 'Broker Advance Payments & Custody',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              AppButton(
                label: isArabic ? '+ تسجيل عهدة مخلص' : '+ Record Broker Advance',
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                icon: Icons.add,
                onPressed: onCreateAdvance,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: advancesAsync.when(
            loading: () => const AppLoadingState(),
            error: (err, _) => AppErrorState(
              error: err,
              onRetry: () => ref.invalidate(clearanceAdvancesListProvider),
            ),
            data: (advances) {
              if (advances.isEmpty) {
                return AppEmptyState(
                  icon: Icons.account_balance_wallet,
                  message: isArabic
                      ? 'لا توجد عهد أو دفعات مخلصين مسجلة حتى الآن.'
                      : 'No advance payments recorded yet.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: advances.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final adv = advances[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B232D) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.orange, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${adv.advanceCode} · ${adv.clearancePartnerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                '${isArabic ? "الشحنة" : "Shipment"}: ${adv.shipmentId} · ${isArabic ? "بوليصة" : "B/L"}: ${adv.blNumber ?? "—"} · ${isArabic ? "تاريخ" : "Date"}: ${adv.paymentDate.toIso8601String().split("T").first}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${adv.amountEgp.toStringAsFixed(2)} ${isArabic ? "ج.م" : "EGP"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                              '${isArabic ? "المسوى" : "Settled"}: ${adv.settledAmountEgp.toStringAsFixed(2)} | ${isArabic ? "المتبقي" : "Rem"}: ${adv.remainingAmountEgp.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: adv.remainingAmountEgp > 0 ? AppTheme.orange : AppTheme.emerald,
                              ),
                            ),
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
