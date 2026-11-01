import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../models/container_deposit_model.dart';

class DepositLedgerHeader extends StatelessWidget {
  final ContainerDepositOverviewModel? overview;
  final VoidCallback onNewDeposit;
  final VoidCallback onClose;

  const DepositLedgerHeader({
    super.key,
    required this.overview,
    required this.onNewDeposit,
    required this.onClose,
  });

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: AppTheme.charcoal,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: AppTheme.emerald, size: 26),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سجل تأمين الحاويات وإيصالات الاسترجاع (Container Deposit & EIR Ledger)',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'إدارة تأمينات الخطوط الملاحية، تتبع إيصالات الـ EIR، وحصر التأمينات المتأخرة عن مهلة الـ 30 يوماً',
                      style: TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              AppButton(
                label: 'تسجيل تأمين حاوية',
                icon: Icons.add_card_rounded,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: onNewDeposit,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: onClose,
              ),
            ],
          ),
        ),

        // Metrics Bar
        if (overview != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey.shade100,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMetricChip('إجمالي التأمينات المسجلة', '${overview!.totalActiveDeposits}', Colors.blueGrey),
                  const SizedBox(width: 8),
                  _buildMetricChip('إجمالي المدفوع للخطوط', '${overview!.totalDepositAmountEgp.toStringAsFixed(0)} ج.م', AppTheme.cobalt),
                  const SizedBox(width: 8),
                  _buildMetricChip('قيد الإرجاع الفارغ 🟡', '${overview!.pendingReturnCount}', AppTheme.orange),
                  const SizedBox(width: 8),
                  _buildMetricChip('تم تقديم الـ EIR 🔵', '${overview!.claimSubmittedCount}', Colors.blue.shade700),
                  const SizedBox(width: 8),
                  _buildMetricChip('متأخرة عن 30 يوم 🔴', '${overview!.overdue30DaysCount}', AppTheme.crimson),
                  const SizedBox(width: 8),
                  _buildMetricChip('مستردة بالكامل 🟢', '${overview!.refundedFullCount}', AppTheme.emerald),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
