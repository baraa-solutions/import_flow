import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/logistics_invoice_models.dart';
import '../../providers/logistics_invoices_provider.dart';
import '../../repositories/logistics_invoices_repository.dart';
import '../three_way_match_badge.dart';

class InvoiceListCard extends ConsumerWidget {
  final LogisticsInvoiceModel inv;
  final bool isDark;
  final VoidCallback onEdit;
  final void Function(int partnerId, String partnerName) onPay;

  const InvoiceListCard({
    super.key,
    required this.inv,
    required this.isDark,
    required this.onEdit,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    Color partnerColor;
    IconData partnerIcon;

    switch (inv.partnerType) {
      case 'freight':
        partnerColor = AppTheme.cobalt;
        partnerIcon = Icons.directions_boat;
        break;
      case 'clearance':
        partnerColor = AppTheme.orange;
        partnerIcon = Icons.assignment;
        break;
      case 'insurance':
        partnerColor = Colors.purple;
        partnerIcon = Icons.shield;
        break;
      default:
        partnerColor = AppTheme.emerald;
        partnerIcon = Icons.verified;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B232D) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: partnerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(partnerIcon, color: partnerColor, size: 22),
          ),
          const SizedBox(width: 12),

          // Code and Partner Info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      inv.invoiceCode,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: partnerColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        inv.partnerType.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: partnerColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${inv.partnerName} · Inv #${inv.invoiceNumber}',
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
                Text(
                  'B/L: ${inv.blNumber ?? "N/A"} · Containers: ${inv.containers.length} · Shipment ID: ${inv.shipmentId}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),

          // 3-Way Match Badge
          ThreeWayMatchBadge(invoiceId: inv.invoiceId),
          const SizedBox(width: 16),

          // Financial Amounts
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${inv.netPayableEgp.toStringAsFixed(2)} EGP',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '${inv.totalAmountFx.toStringAsFixed(2)} ${inv.currency} @ ${inv.exchangeRate.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  'Remaining: ${inv.remainingAmountEgp.toStringAsFixed(2)} EGP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: inv.remainingAmountEgp > 0 ? AppTheme.crimson : AppTheme.emerald,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Status Badges & Quick Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildStatusPill(inv.status),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (inv.status == 'draft') ...[
                    Tooltip(
                      message: isArabic ? 'ترحيل الفاتورة للمراجعة' : 'Submit Invoice',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        onTap: () async {
                          final repo = ref.read(logisticsInvoicesRepositoryProvider);
                          await repo.submitInvoice(inv.invoiceId);
                          ref.invalidate(logisticsInvoicesListProvider);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: AppTheme.cobaltLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.send_rounded, size: 13, color: AppTheme.cobalt),
                              const SizedBox(width: 4),
                              Text(
                                isArabic ? 'ترحيل' : 'Submit',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (inv.status == 'submitted') ...[
                    Tooltip(
                      message: isArabic ? 'اعتماد الفاتورة' : 'Approve Invoice',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        onTap: () async {
                          final repo = ref.read(logisticsInvoicesRepositoryProvider);
                          await repo.approveInvoice(inv.invoiceId);
                          ref.invalidate(logisticsInvoicesListProvider);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 13, color: AppTheme.emerald),
                              const SizedBox(width: 4),
                              Text(
                                isArabic ? 'اعتماد' : 'Approve',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (inv.remainingAmountEgp > 0 && inv.status == 'approved') ...[
                    Tooltip(
                      message: isArabic ? 'سداد / إقفال الفاتورة' : 'Pay / Knock-off',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        onTap: () => onPay(inv.partnerId, inv.partnerName),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: AppTheme.orangeLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.payments_outlined, size: 13, color: AppTheme.orange),
                              const SizedBox(width: 4),
                              Text(
                                isArabic ? 'سداد' : 'Pay',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orange),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  RowActionsPill(
                    viewTooltip: isArabic ? 'عرض الفاتورة' : 'View Invoice',
                    onView: onEdit,
                    editTooltip: inv.status == 'draft' ? (isArabic ? 'تعديل الفاتورة' : 'Edit Invoice') : null,
                    onEdit: inv.status == 'draft' ? onEdit : null,
                    cloneTooltip: isArabic ? 'نسخ بيانات الفاتورة' : 'Copy Invoice Details',
                    onClone: () {
                      final summary = '${inv.invoiceCode} · ${inv.partnerName} · ${inv.netPayableEgp.toStringAsFixed(2)} EGP · ${inv.status.toUpperCase()}';
                      CopyHelper.copy(context, summary);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg;
    Color fg;

    switch (status) {
      case 'draft':
        bg = AppTheme.charcoal.withValues(alpha: 0.1);
        fg = AppTheme.charcoal;
        break;
      case 'submitted':
        bg = AppTheme.cobaltLight;
        fg = AppTheme.cobalt;
        break;
      case 'approved':
        bg = AppTheme.emeraldLight;
        fg = AppTheme.emerald;
        break;
      case 'partially_paid':
        bg = AppTheme.orangeLight;
        fg = AppTheme.orange;
        break;
      case 'fully_paid':
        bg = AppTheme.emeraldLight;
        fg = AppTheme.emerald;
        break;
      default:
        bg = AppTheme.crimsonLight;
        fg = AppTheme.crimson;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
