import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/logistics_invoices_provider.dart';

class InvoicesScreenHeader extends ConsumerWidget {
  final String? initialBlNumber;

  const InvoicesScreenHeader({
    super.key,
    this.initialBlNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = context.l10n.isArabic;
    final selectedShipment = ref.watch(selectedShipmentFilterProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.charcoal,
        border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: AppTheme.cobalt, size: 24),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? 'مركز فواتير ومدفوعات الخدمات اللوجستية' : 'Logistics Service Invoices & Payments Hub',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                isArabic
                    ? 'نولون الشحن · التخليص الجمركي · الفحص والمعاينة · التأمين البحري · أسعار الصرف'
                    : 'Freight · Customs Broker · Inspection Agency · Marine Insurance · CBE Rates',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          if (selectedShipment != null) ...[
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cobalt),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_alt, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${isArabic ? "الشحنة: IMP-" : "Shipment: IMP-"}$selectedShipment${initialBlNumber != null && initialBlNumber!.isNotEmpty ? " | B/L: $initialBlNumber" : ""}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      ref.read(selectedShipmentFilterProvider.notifier).state = null;
                    },
                    child: const Icon(Icons.close, color: Colors.white70, size: 14),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            tooltip: isArabic ? 'تحديث البيانات' : 'Live Refresh',
            onPressed: () {
              ref.invalidate(logisticsInvoicesListProvider);
              ref.invalidate(paymentVouchersListProvider);
              ref.invalidate(clearanceAdvancesListProvider);
              ref.invalidate(insurancePoliciesListProvider);
            },
          ),
          const SizedBox(width: 8),
          const BackToDashboardButton(),
        ],
      ),
    );
  }
}
