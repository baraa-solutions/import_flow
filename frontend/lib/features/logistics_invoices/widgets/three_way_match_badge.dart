import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/logistics_invoice_models.dart';
import '../providers/logistics_invoices_provider.dart';

class ThreeWayMatchBadge extends ConsumerWidget {
  final int invoiceId;

  const ThreeWayMatchBadge({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(threeWayMatchProvider(invoiceId));

    return matchAsync.when(
      loading: () => const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5)),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final isMatched = data.isFullyMatched;
        return InkWell(
          onTap: () => _showDetailsDialog(context, data),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isMatched ? AppTheme.emerald.withValues(alpha: 0.12) : AppTheme.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isMatched ? AppTheme.emerald : AppTheme.orange, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isMatched ? Icons.verified : Icons.warning_amber_rounded,
                  size: 13,
                  color: isMatched ? AppTheme.emerald : AppTheme.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  isMatched ? '3-Way Match Verified' : 'Variance: ${data.totalVarianceEgp.toStringAsFixed(0)} EGP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isMatched ? AppTheme.emerald : AppTheme.orange,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDetailsDialog(BuildContext context, ThreeWayMatchModel data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              data.isFullyMatched ? Icons.verified : Icons.warning_amber_rounded,
              color: data.isFullyMatched ? AppTheme.emerald : AppTheme.orange,
            ),
            const SizedBox(width: 8),
            const Text('3-Way Match Verification Details', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statItem('Quotation Quoted', '${data.totalQuotedEgp.toStringAsFixed(2)} EGP'),
                  _statItem('Actual Invoiced', '${data.totalInvoicedEgp.toStringAsFixed(2)} EGP'),
                  _statItem(
                    'Net Variance',
                    '${data.totalVarianceEgp.toStringAsFixed(2)} EGP',
                    color: data.totalVarianceEgp > 0 ? AppTheme.crimson : AppTheme.emerald,
                  ),
                ],
              ),
              const Divider(height: 24),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('Line-by-Line Breakdown:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: data.items.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: item.isMatched ? Colors.grey.withValues(alpha: 0.05) : AppTheme.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: item.isMatched ? Colors.grey.withValues(alpha: 0.2) : AppTheme.orange.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.isMatched ? Icons.check_circle_outline : Icons.error_outline,
                              size: 16,
                              color: item.isMatched ? AppTheme.emerald : AppTheme.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(item.itemDescription, style: const TextStyle(fontSize: 12)),
                            ),
                            Text(
                              'Invoiced: ${item.invoicedAmountEgp.toStringAsFixed(0)} | Quoted: ${item.quotedAmountEgp.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color ?? Colors.black87),
        ),
      ],
    );
  }
}
