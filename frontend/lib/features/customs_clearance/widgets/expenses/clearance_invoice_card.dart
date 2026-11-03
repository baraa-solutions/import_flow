import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../models/clearance_expense_invoice_model.dart';
import '../customs_ui.dart';

class ClearanceInvoiceCard extends StatelessWidget {
  final ClearanceExpenseInvoiceModel invoice;
  final ValueChanged<ClearanceExpenseInvoiceModel> onDelete;

  const ClearanceInvoiceCard({
    super.key,
    required this.invoice,
    required this.onDelete,
  });

  Color _getCategoryColor(String category) {
    switch (DomainEnums.legacyToCode(DomainEnumType.clearanceExpenseCategory, category)) {
      case 'BROKER_FEES':
        return AppTheme.cobalt;
      case 'PORT_DUES_WHARFAGE':
        return AppTheme.orange;
      case 'STEVEDORING_HANDLING':
        return AppTheme.wcagCobalt;
      case 'LABORATORY_TESTING':
        return AppTheme.emerald;
      case 'STORAGE_DEMURRAGE':
        return AppTheme.crimson;
    }
    return AppTheme.charcoal;
  }

  Widget _buildCardInfo(BuildContext context, IconData icon, String label, String value, {bool ltr = false}) {
    const valueStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textMutedOf(context)),
        const SizedBox(width: 4),
        Text('$label: ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
        Flexible(
          child: ltr
              ? LtrText(value, style: valueStyle, overflow: TextOverflow.ellipsis)
              : Text(value, style: valueStyle, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final catColor = _getCategoryColor(invoice.expenseCategory);
    final cur = l.ccCurrencyShort;

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 12),
      padding: const EdgeInsetsDirectional.all(14),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: catColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DomainEnums.label(l, DomainEnumType.clearanceExpenseCategory, invoice.expenseCategory),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: catColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  l.ccExpInvoiceNo(invoice.invoiceNumber),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              LtrText(
                '(${invoice.invoiceCode})',
                style: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context)),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CcMoneyText(
                    invoice.netPayableEgp,
                    currency: cur,
                    fontSize: 15,
                    color: AppTheme.successForeground,
                  ),
                  if (invoice.vatIncluded || invoice.whtDeducted)
                    LtrText(
                      l.ccExpBreakdown(
                        CcFormat.money(invoice.amountEgp),
                        CcFormat.money(invoice.vatAmount),
                        CcFormat.money(invoice.whtAmount),
                      ),
                      style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondaryOf(context)),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              IconButton(
                key: Key('deleteInvoiceBtn_${invoice.invoiceId}'),
                icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 20),
                tooltip: l.ccExpDeleteTooltip,
                onPressed: () => onDelete(invoice),
              ),
            ],
          ),
          Divider(height: 18, color: AppTheme.borderOf(context)),
          Wrap(
            spacing: 24,
            runSpacing: 6,
            children: [
              _buildCardInfo(context, Icons.business, l.ccExpInfoProvider, invoice.providerName),
              _buildCardInfo(context, Icons.calendar_today, l.ccExpInfoDate, invoice.invoiceDate, ltr: true),
              _buildCardInfo(
                context,
                Icons.pie_chart,
                l.ccExpInfoAllocation,
                invoice.allocationRule == 'Equal' ? l.ccExpAllocEqualShort : invoice.allocationRule,
              ),
              if (invoice.notes != null && invoice.notes!.isNotEmpty)
                _buildCardInfo(context, Icons.notes, l.ccExpInfoNotes, invoice.notes!),
            ],
          ),
        ],
      ),
    );
  }
}
