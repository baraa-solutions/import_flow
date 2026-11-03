import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/broker_custody_model.dart';

class SettlementVarianceFooterBar extends StatelessWidget {
  final CustomsSettlementVarianceModel? reconciliation;

  const SettlementVarianceFooterBar({super.key, required this.reconciliation});

  @override
  Widget build(BuildContext context) {
    if (reconciliation == null) {
      return const SizedBox.shrink();
    }

    final rec = reconciliation!;
    final isRefund = rec.varianceAmount > 0;
    final isReimbursement = rec.varianceAmount < 0;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined, color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 8),
              const Text(
                'المطابقة والتسوية المالية الختامية للعهدة',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isRefund
                      ? Colors.blue.shade50
                      : (isReimbursement ? Colors.amber.shade50 : Colors.green.shade50),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isRefund
                        ? Colors.blue.shade300
                        : (isReimbursement ? Colors.amber.shade300 : Colors.green.shade300),
                  ),
                ),
                child: Text(
                  isRefund
                      ? 'فائض مسترد للشركة: ${rec.varianceAmount.toStringAsFixed(2)} ج.م'
                      : (isReimbursement
                          ? 'عجز مستحق للمخلص: ${(rec.varianceAmount.abs()).toStringAsFixed(2)} ج.م'
                          : 'تسوية ومطابقة تامة'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isRefund
                        ? Colors.blue.shade900
                        : (isReimbursement ? Colors.amber.shade900 : Colors.green.shade900),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'مبلغ العهدة المصروفة',
                  '${rec.advanceAmount.toStringAsFixed(2)} ج.م',
                  Colors.grey.shade800,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'إجمالي الإيصالات والفواتير',
                  '${rec.totalReceiptsAmount.toStringAsFixed(2)} ج.م',
                  Colors.grey.shade800,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'إجمالي الخصم من المنبع 1%',
                  '${rec.totalTaxWithheld.toStringAsFixed(2)} ج.م',
                  AppTheme.crimson,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'صافي المبلغ المسدد فعلياً',
                  '${rec.totalNetSettled.toStringAsFixed(2)} ج.م',
                  AppTheme.cobalt,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
