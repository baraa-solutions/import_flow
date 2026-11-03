import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../models/invoices_aggregation_model.dart';
import '../settlement_ui.dart';

class FinalSettlementInvoicesTable extends StatelessWidget {
  final List<AggregatedInvoiceItemModel> invoices;

  const FinalSettlementInvoicesTable({
    super.key,
    required this.invoices,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (invoices.isEmpty) {
      return SettlementPanel(
        filled: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SettlementStateView.empty(
          message: l10n.settlementClo01NoInvoices,
          icon: Icons.receipt_long_outlined,
        ),
      );
    }

    final egp = l10n.financialSettlementCurrencyEgp;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        border: Border.all(color: SettlementTokens.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(SettlementTokens.tableHeadFill),
            columnSpacing: 16,
            horizontalMargin: 16,
            headingRowHeight: 40,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 64,
            columns: [
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColInvoice)),
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColParty)),
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColCategory)),
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColOriginal), numeric: true),
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColTotal), numeric: true),
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColPaid), numeric: true),
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColRemaining), numeric: true),
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColPayStatus)),
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColSource)),
            ],
            rows: invoices.map((inv) {
              final isPaid = inv.paymentStatus == 'PAID' || inv.remainingAmountEgp == 0;
              final isPartial = inv.paymentStatus == 'PARTIAL';
              final statusColor = isPaid
                  ? AppTheme.emerald
                  : isPartial
                      ? AppTheme.orange
                      : AppTheme.crimson;
              final statusLabel = isPaid
                  ? l10n.settlementClo01PaidFull
                  : isPartial
                      ? l10n.settlementClo01PaidPartial
                      : l10n.settlementClo01Unpaid;

              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LtrText(
                          inv.invoiceNo,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        if (inv.paymentReference != null && inv.paymentReference!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: InkWell(
                              onTap: () => CopyHelper.copy(context, inv.paymentReference!),
                              borderRadius: BorderRadius.circular(4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.tag, size: 11, color: AppTheme.cobalt),
                                  const SizedBox(width: 3),
                                  Text(
                                    inv.paymentReference!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.cobalt,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          inv.partyName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          inv.partyTypeAr,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(inv.categoryAr, style: const TextStyle(fontSize: 11))),
                  DataCell(
                    SettlementMoneyText(
                      inv.currency == 'EGP'
                          ? '${formatSettlementMoney(inv.amountEgp)} $egp'
                          : '${formatSettlementMoney(inv.amountFc)} ${inv.currency}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DataCell(
                    SettlementMoneyText(
                      '${formatSettlementMoney(inv.amountEgp)} $egp',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(
                    SettlementMoneyText(
                      '${formatSettlementMoney(inv.paidAmountEgp)} $egp',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.emerald,
                      ),
                    ),
                  ),
                  DataCell(
                    SettlementMoneyText(
                      '${formatSettlementMoney(inv.remainingAmountEgp)} $egp',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: inv.remainingAmountEgp > 0 ? AppTheme.crimson : AppTheme.textMuted,
                      ),
                    ),
                  ),
                  DataCell(
                    SettlementStatusChip(
                      label: statusLabel,
                      color: statusColor,
                      dense: true,
                    ),
                  ),
                  DataCell(
                    Text(
                      inv.sourceModule,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
