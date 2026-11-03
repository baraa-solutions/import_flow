import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/clearance_expense_invoice_model.dart';
import 'clearance_invoice_card.dart';

class ClearanceInvoicesList extends StatelessWidget {
  final List<ClearanceExpenseInvoiceModel> invoices;
  final ValueChanged<ClearanceExpenseInvoiceModel> onDeleteInvoice;

  const ClearanceInvoicesList({
    super.key,
    required this.invoices,
    required this.onDeleteInvoice,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    if (invoices.isEmpty) {
      return Container(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAltOf(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: AppTheme.textMutedOf(context)),
            const SizedBox(height: 12),
            Text(
              l.ccExpEmptyTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              l.ccExpEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: invoices
          .map((inv) => ClearanceInvoiceCard(
                invoice: inv,
                onDelete: onDeleteInvoice,
              ))
          .toList(),
    );
  }
}
