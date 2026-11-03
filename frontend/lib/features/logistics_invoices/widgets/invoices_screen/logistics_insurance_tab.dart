import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/logistics_invoices_provider.dart';

class LogisticsInsuranceTab extends ConsumerWidget {
  final bool isDark;
  final VoidCallback onIssuePolicy;

  const LogisticsInsuranceTab({
    super.key,
    required this.isDark,
    required this.onIssuePolicy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = context.l10n.isArabic;
    final policiesAsync = ref.watch(insurancePoliciesListProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF161E28) : Colors.white,
          child: Row(
            children: [
              Text(
                isArabic ? 'بوالص التأمين البحري على الشحنات' : 'Marine Insurance Policies',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              AppButton(
                label: isArabic ? '+ إصدار وثيقة تأمين' : '+ Issue Marine Policy',
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                icon: Icons.add,
                onPressed: onIssuePolicy,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: policiesAsync.when(
            loading: () => const AppLoadingState(),
            error: (err, _) => AppErrorState(
              error: err,
              onRetry: () => ref.invalidate(insurancePoliciesListProvider),
            ),
            data: (policies) {
              if (policies.isEmpty) {
                return AppEmptyState(
                  icon: Icons.shield,
                  message: isArabic
                      ? 'لا توجد بوالص تأمين بحري مسجلة حتى الآن.'
                      : 'No marine insurance policies issued yet.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: policies.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final pol = policies[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B232D) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.purple, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${pol.policyCode} — #${pol.policyNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                '${pol.insuranceCompanyName} · Clause: ${pol.coverageType.toUpperCase()}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              Text(
                                'Insured Value (CIF+10%): ${pol.insuredValueFx.toStringAsFixed(2)} ${pol.insuredValueCurrency}',
                                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${pol.netPremiumEgp.toStringAsFixed(2)} EGP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                              pol.invoiceGenerated ? (isArabic ? 'تم إصدار الفاتورة ✅' : 'Invoice Generated ✅') : (isArabic ? 'بانتظار الفاتورة' : 'Invoice Pending'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: pol.invoiceGenerated ? AppTheme.emerald : AppTheme.orange,
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
