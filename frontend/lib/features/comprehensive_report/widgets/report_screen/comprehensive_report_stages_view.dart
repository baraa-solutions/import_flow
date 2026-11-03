import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../customs_clearance/models/customs_clearance_model.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../shipment_updates/providers/shipment_updates_provider.dart';
import '../../../smart_checklists/providers/smart_checklists_provider.dart';
import '../../../warehouse_receiving/models/warehouse_receiving_model.dart';
import '../../models/comprehensive_dossier_model.dart';
import '../report_clearance_section.dart';
import '../report_command_footer.dart';
import '../report_interactive_timeline_card.dart';
import '../report_phase_pipeline_card.dart';
import '../report_simulation_shortcuts_strip.dart';
import '../report_updates_timeline_card.dart';
import '../report_warehouse_section.dart';

/// Operational Stages, Simulation Strip, Pipeline, Customs, Warehouse & Audit Timeline View.
class ComprehensiveReportStagesView extends StatelessWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;
  final ShipmentUpdatesState updatesState;
  final SmartChecklistState checklistState;
  final AsyncValue<List<CustomsClearanceModel>> clearanceState;
  final AsyncValue<List<WarehouseReceivingModel>> warehouseState;
  final ValueChanged<int> onNavigate;
  final ValueChanged<String> onNavigateToStage;

  const ComprehensiveReportStagesView({
    super.key,
    required this.file,
    required this.dossier,
    required this.updatesState,
    required this.checklistState,
    required this.clearanceState,
    required this.warehouseState,
    required this.onNavigate,
    required this.onNavigateToStage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1: Top Stage Simulation & Shortcuts Strip
        ReportSimulationShortcutsStrip(
          file: file,
          onNavigate: onNavigate,
        ),
        const SizedBox(height: 14),

        // Section 2: 10-Phase Progress Pipeline
        ReportPhasePipeline(
          file: file,
          updatesState: updatesState,
          checklistState: checklistState,
        ),
        const SizedBox(height: 16),

        // Section 3: Interactive Operational Timeline & SLA Radar
        ReportInteractiveTimelineCard(
          file: file,
          dossier: dossier,
          updatesState: updatesState,
          onNavigateToStage: onNavigateToStage,
        ),
        const SizedBox(height: 16),

        // Section 4: Live Operational Updates Timeline
        ReportUpdatesTimelineCard(
          file: file,
          updatesState: updatesState,
        ),
        const SizedBox(height: 16),

        // Section 5: Customs Clearance Real-Time Data (Declaration 46)
        ReportClearanceSection(state: clearanceState),
        const SizedBox(height: 16),

        // Section 6: Warehouse Receiving & GRN Real-Time Data
        ReportWarehouseSection(state: warehouseState),
        const SizedBox(height: 20),

        // Section 7: Operational Command Footer
        ReportOperationalCommandFooter(
          file: file,
          dossier: dossier,
        ),
      ],
    );
  }
}
