import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/comprehensive_dossier_model.dart';
import 'report_card_container.dart';

/// Financial figures, PO totals, and currency breakdown card for Comprehensive Report.
class ReportFinancialCard extends StatelessWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;

  const ReportFinancialCard({
    super.key,
    required this.file,
    this.dossier,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final curr = l.compReportCurrencyUsd;

    final double poFobTotal = dossier?.totalFobFc ??
        (dossier?.purchaseOrders.isNotEmpty == true
            ? (dossier!.purchaseOrders.first['total_amount_fob'] as num?)?.toDouble() ?? 0.0
            : 0.0);
    final String fobCurrency = dossier?.fobCurrency ?? curr;
    final double totalInvoicesValue = file.invoicesData.fold(0.0, (s, i) => s + i.amount);
    final double effectiveBase = poFobTotal > 0 ? poFobTotal : totalInvoicesValue;

    return ReportCardContainer(
      title: l.compReportSecFinancial,
      icon: Icons.account_balance_outlined,
      iconColor: AppTheme.orange,
      child: Column(
        children: [
          if (poFobTotal > 0)
            buildFinancialRow(
              'إجمالي أمر التوريد (PO Total FOB)',
              '${poFobTotal.toStringAsFixed(2)} $fobCurrency',
              const Color(0xFF1E3A8A),
            ),
          buildFinancialRow(
            'إجمالي الفواتير المرفقة (Invoices Total)',
            '${(totalInvoicesValue > 0 ? totalInvoicesValue : poFobTotal).toStringAsFixed(2)} $fobCurrency',
            Colors.teal,
          ),
          buildFinancialRow(
            l.compReportEstimatedCostVal,
            '${file.estimatedCost.toStringAsFixed(2)} $curr',
            AppTheme.cobalt,
          ),
          const Divider(height: 16),
          buildFinancialRow(
            l.compReportEstimatedVariance,
            '${(file.estimatedCost - effectiveBase).toStringAsFixed(2)} $curr',
            file.estimatedCost >= effectiveBase ? AppTheme.emerald : AppTheme.orange,
          ),
        ],
      ),
    );
  }

  static Widget buildFinancialRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
