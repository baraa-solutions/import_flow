import 'package:flutter/material.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../purchase_orders/models/purchase_order_model.dart' hide PackingListItemModel;
import '../../models/comprehensive_dossier_model.dart';
import '../report_financial_card.dart';
import '../report_fx_reconciliation_card.dart';
import '../report_invoices_card.dart';
import '../report_packing_list_card.dart';
import '../report_trade_agreements_section.dart';

/// Commercial Invoicing, Financial Summary, Trade Agreements & FX View.
class ComprehensiveReportFinancialsView extends StatelessWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;
  final List<PurchaseOrderModel> allPOs;

  const ComprehensiveReportFinancialsView({
    super.key,
    required this.file,
    required this.dossier,
    this.allPOs = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Commercial Invoices, Packing Lists & Trade Agreements
        Expanded(
          flex: 3,
          child: Column(
            children: [
              ReportInvoicesCard(file: file, dossier: dossier),
              const SizedBox(height: 14),
              ReportPackingListCard(file: file, dossier: dossier),
              const SizedBox(height: 14),
              ReportTradeAgreementsSection(file: file, allPOs: allPOs),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Right Column: Financial Overview & FX Settlement Reconciliation
        Expanded(
          flex: 2,
          child: Column(
            children: [
              ReportFinancialCard(file: file, dossier: dossier),
              const SizedBox(height: 14),
              ReportFxReconciliationCard(file: file, dossier: dossier),
            ],
          ),
        ),
      ],
    );
  }
}
