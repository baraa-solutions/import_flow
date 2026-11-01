import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/logistics_invoice_models.dart';

class InvoiceFormHeader extends StatelessWidget {
  final LogisticsInvoiceModel? initialInvoice;
  final String partnerType;
  final bool isDark;
  final bool isArabic;
  final VoidCallback onClose;

  const InvoiceFormHeader({
    super.key,
    required this.initialInvoice,
    required this.partnerType,
    required this.isDark,
    required this.isArabic,
    required this.onClose,
  });

  String _partnerTypeLabel(bool isArabic) {
    switch (partnerType) {
      case 'clearance':
        return isArabic ? 'تخليص جمركي' : 'Customs Clearance';
      case 'transport':
        return isArabic ? 'نقل داخلي' : 'Inland Transport';
      case 'inspection':
        return isArabic ? 'فحص ومعاينة' : 'Inspection';
      case 'insurance':
        return isArabic ? 'تأمين بحري' : 'Marine Insurance';
      case 'freight':
      default:
        return isArabic ? 'شحن ونولون' : 'Freight';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              partnerType == 'freight'
                  ? Icons.directions_boat_outlined
                  : partnerType == 'clearance'
                      ? Icons.assignment_outlined
                      : partnerType == 'transport'
                          ? Icons.local_shipping_outlined
                          : partnerType == 'insurance'
                              ? Icons.shield_outlined
                              : Icons.verified_outlined,
              color: AppTheme.cobalt,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              initialInvoice == null
                  ? (isArabic
                      ? 'تسجيل فاتورة جديدة (${_partnerTypeLabel(isArabic)})'
                      : 'New ${_partnerTypeLabel(isArabic)} Service Invoice')
                  : (isArabic
                      ? 'تعديل فاتورة: ${initialInvoice!.invoiceCode}'
                      : 'Edit Invoice: ${initialInvoice!.invoiceCode}'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.charcoal,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ],
        ),
        const Divider(height: 20),
      ],
    );
  }
}
