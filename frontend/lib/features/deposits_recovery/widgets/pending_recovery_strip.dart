import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/metric_card.dart';
import '../deposits_recovery_provider.dart';

class PendingRecoveryStrip extends ConsumerWidget {
  const PendingRecoveryStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(depositRecoveryMetricsProvider);
    final m = metricsAsync.value ?? DepositRecoveryMetricsModel.empty;

    final metrics = [
      MetricCardData(
        title: 'إجمالي قيود التأمينات',
        value: '${m.totalDepositsCount}',
        icon: Icons.account_balance_wallet_rounded,
        color: AppTheme.cobalt,
      ),
      MetricCardData(
        title: 'مبالغ قيد الاسترداد والمطالبة',
        value: '${m.pendingRecoveryAmountEgp.toStringAsFixed(0)} ج.م',
        icon: Icons.hourglass_top_rounded,
        color: AppTheme.orange,
      ),
      MetricCardData(
        title: 'إجمالي المبالغ المستردة',
        value: '${m.recoveredAmountEgp.toStringAsFixed(0)} ج.م',
        icon: Icons.check_circle_outline_rounded,
        color: AppTheme.emerald,
      ),
      MetricCardData(
        title: 'استقطاعات غسيل وأضرار الحاويات',
        value: '${m.totalDeductionsEgp.toStringAsFixed(0)} ج.م',
        icon: Icons.cleaning_services_rounded,
        color: AppTheme.crimson,
      ),
      MetricCardData(
        title: 'خطابات الضمان البنكية السارية',
        value: '${m.activeBankLgCount}',
        icon: Icons.security_rounded,
        color: AppTheme.charcoal,
      ),
    ];

    return SelectionArea(
      child: MetricCardStrip(metrics: metrics),
    );
  }
}
