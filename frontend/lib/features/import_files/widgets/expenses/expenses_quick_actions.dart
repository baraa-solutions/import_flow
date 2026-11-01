import 'package:flutter/material.dart';
import '../../../logistics_invoices/widgets/advance_payment_dialog.dart';
import '../../../logistics_invoices/widgets/insurance_policy_dialog.dart';
import '../../../logistics_invoices/widgets/invoice_form_dialog.dart';

class ExpensesQuickActions extends StatelessWidget {
  final int shipmentId;

  const ExpensesQuickActions({
    super.key,
    required this.shipmentId,
  });

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 0,
      ),
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildActionButton(
          context: context,
          label: '+ فاتورة شحن ونولون',
          icon: Icons.directions_boat,
          color: const Color(0xFF0284C7),
          onTap: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => InvoiceFormDialog(
                defaultPartnerType: 'freight',
                initialShipmentId: shipmentId,
                initialBlNumber: null,
              ),
            );
          },
        ),
        _buildActionButton(
          context: context,
          label: '+ فاتورة تخليص جمركي',
          icon: Icons.assignment,
          color: const Color(0xFF059669),
          onTap: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => InvoiceFormDialog(
                defaultPartnerType: 'clearance',
                initialShipmentId: shipmentId,
                initialBlNumber: null,
              ),
            );
          },
        ),
        _buildActionButton(
          context: context,
          label: '+ فاتورة فحص ومعاينة',
          icon: Icons.fact_check,
          color: const Color(0xFFD97706),
          onTap: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => InvoiceFormDialog(
                defaultPartnerType: 'inspection',
                initialShipmentId: shipmentId,
                initialBlNumber: null,
              ),
            );
          },
        ),
        _buildActionButton(
          context: context,
          label: '💼 صرف عهدة مخلص',
          icon: Icons.payment,
          color: const Color(0xFF4F46E5),
          onTap: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AdvancePaymentDialog(
                defaultShipmentId: shipmentId,
                defaultBlNumber: null,
              ),
            );
          },
        ),
        _buildActionButton(
          context: context,
          label: '🛡️ إصدار وثيقة تأمين',
          icon: Icons.security,
          color: const Color(0xFF1E3A8A),
          onTap: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => InsurancePolicyDialog(
                defaultShipmentId: shipmentId,
                defaultBlNumber: null,
              ),
            );
          },
        ),
      ],
    );
  }
}
