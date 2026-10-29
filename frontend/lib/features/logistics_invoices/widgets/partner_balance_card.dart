import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../models/logistics_invoice_models.dart';
import '../providers/logistics_invoices_provider.dart';

class PartnerBalanceCard extends ConsumerWidget {
  final int partnerId;

  const PartnerBalanceCard({super.key, required this.partnerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(partnerBalanceCardProvider(partnerId));

    return balanceAsync.when(
      loading: () => Container(
        height: 80,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.isDark(context) ? const Color(0xFF1E2630) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: const Center(child: AppLoadingState.inline()),
      ),
      error: (err, _) => const SizedBox.shrink(),
      data: (data) => _buildCard(context, data),
    );
  }

  Widget _buildCard(BuildContext context, PartnerBalanceCardModel data) {
    final isDark = AppTheme.isDark(context);
    final bg = isDark ? const Color(0xFF1A222D) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF2C3E50) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${data.partnerName} (${data.partnerType.toUpperCase()}) — Partner Balance Card',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : AppTheme.charcoal,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${data.openInvoicesCount} Open Invoices',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _metricItem(context, 'Total Invoiced', '${data.totalInvoicedEgp.toStringAsFixed(2)} EGP', Colors.blueGrey),
              _divider(),
              _metricItem(context, 'Total Paid', '${data.totalPaidEgp.toStringAsFixed(2)} EGP', AppTheme.emerald),
              _divider(),
              _metricItem(context, 'Current Balance Due', '${data.balanceDueEgp.toStringAsFixed(2)} EGP', AppTheme.crimson, isBold: true),
            ],
          ),
          const SizedBox(height: 10),
          // Aging Buckets Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131A22) : const Color(0xFFEDF2F7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: _agingItem('≤ 30 Days', data.aging.current30Days, AppTheme.emerald)),
                Flexible(child: _agingItem('31 - 60 Days', data.aging.days31To60, Colors.amber.shade700)),
                Flexible(child: _agingItem('61 - 90 Days', data.aging.days61To90, AppTheme.orange)),
                Flexible(child: _agingItem('> 90 Days', data.aging.days90Plus, AppTheme.crimson)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricItem(BuildContext context, String title, String value, Color color, {bool isBold = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.grey.withValues(alpha: 0.3),
    );
  }

  Widget _agingItem(String label, double amount, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$label: ${amount.toStringAsFixed(2)} EGP',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
