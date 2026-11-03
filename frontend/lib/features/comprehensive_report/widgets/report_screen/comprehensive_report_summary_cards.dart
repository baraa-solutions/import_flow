import 'package:flutter/material.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../purchase_orders/models/purchase_order_model.dart' hide PackingListItemModel;
import '../../models/comprehensive_dossier_model.dart';
import '../report_basic_info_card.dart';
import '../report_cargo_stacking_section.dart';
import '../report_containers_card.dart';
import '../report_documents_card.dart';
import '../report_executive_metric_tiles.dart';
import '../report_header_banner_card.dart';
import '../report_institutional_knowledge_card.dart';
import '../report_notes_card.dart';
import '../report_smart_reference_card.dart';
import '../report_status_card.dart';

/// Shipment Executive Summary & Detail Overview Cards for Comprehensive Report.
class ComprehensiveReportSummaryCards extends StatelessWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;
  final List<PurchaseOrderModel> allPOs;
  final bool isLoading;
  final Set<int> acknowledgedAlerts;
  final VoidCallback onOpenOperationalDetails;

  const ComprehensiveReportSummaryCards({
    super.key,
    required this.file,
    required this.dossier,
    this.allPOs = const [],
    this.isLoading = false,
    required this.acknowledgedAlerts,
    required this.onOpenOperationalDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1: Header Banner with Quick Operational Navigation
        ReportHeaderBanner(
          file: file,
          dossier: dossier,
          onOpenOperationalDetails: onOpenOperationalDetails,
        ),
        const SizedBox(height: 14),

        // Section 2: Executive KPI Physical & Financial Metric Tiles
        ReportExecutiveMetricTiles(
          file: file,
          dossier: dossier,
          allPOs: allPOs,
          isLoading: isLoading,
        ),
        const SizedBox(height: 16),

        // Section 3: Smart Shipment Reference Card (KB-GUIDE-012 Part 2)
        ReportSmartShipmentReferenceCard(
          file: file,
          dossier: dossier,
          allPOs: allPOs,
        ),
        const SizedBox(height: 16),

        // Section 4: Institutional Knowledge & Pattern Engine
        ReportInstitutionalKnowledgeCard(
          file: file,
          dossier: dossier,
          initialAcknowledgedAlerts: acknowledgedAlerts,
        ),
        const SizedBox(height: 16),

        // Section 5: Two-Column Summary & Specification Cards
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Basic Information, Containers, Documents & Cargo Stacking
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  ReportBasicInfoCard(file: file, dossier: dossier),
                  const SizedBox(height: 14),
                  ReportContainersCard(file: file, dossier: dossier),
                  const SizedBox(height: 14),
                  ReportDocumentsCard(file: file),
                  const SizedBox(height: 14),
                  ReportCargoStackingSection(file: file, allPOs: allPOs, dossier: dossier),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Right Column: Status & Notes
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  ReportStatusCard(file: file),
                  const SizedBox(height: 14),
                  ReportNotesCard(file: file),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
