import 'package:flutter/material.dart';

import '../../pillars/pillars.dart';
import 'import_requirements_controllers.dart';
import 'import_requirements_pillars_state.dart';

class PillarsWorkspaceSection extends StatelessWidget {
  final int activePillarIndex;
  final ValueChanged<int> onPillarTabSelected;
  final ImportRequirementsPillarsState state;
  final ImportRequirementsControllers controllers;
  final VoidCallback onStateUpdated;
  final VoidCallback onRequestJustification;
  final VoidCallback onCreateDashboardTask;

  const PillarsWorkspaceSection({
    super.key,
    required this.activePillarIndex,
    required this.onPillarTabSelected,
    required this.state,
    required this.controllers,
    required this.onStateUpdated,
    required this.onRequestJustification,
    required this.onCreateDashboardTask,
  });

  @override
  Widget build(BuildContext context) {
    return PillarsWorkspaceCard(
      activePillarIndex: activePillarIndex,
      onPillarTabSelected: onPillarTabSelected,
      whiteListVerified: state.whiteListVerified,
      cooFulfilled: state.cooStatus == 'Obtained',
      inspectionFulfilled: state.inspectionStatus == 'Completed',
      permitFulfilled: state.permitStatus == 'Approved',
      techCertsFulfilled: state.isPostAcidConfirmed,
      hsCode: controllers.hsCodeCtrl.text,
      commodityDescription: controllers.descCtrl.text,
      pillar1Child: Pillar1Decree43Widget(
        decree43Applicable: state.decree43Applicable,
        whiteListVerified: state.whiteListVerified,
        factoryRegCtrl: controllers.factoryRegCtrl,
        decree43Action: state.decree43Action,
        decree43Justification: state.decree43Justification,
        onDecree43ApplicableChanged: (v) {
          state.decree43Applicable = v;
          onStateUpdated();
        },
        onWhiteListVerifiedChanged: (v) {
          state.whiteListVerified = v;
          onStateUpdated();
        },
        onRequestJustification: onRequestJustification,
        onCreateDashboardTask: onCreateDashboardTask,
      ),
      pillar2Child: Pillar2CooWidget(
        cooRequired: state.cooRequired,
        cooType: state.cooType,
        cooStatus: state.cooStatus,
        cooNotesCtrl: controllers.cooNotesCtrl,
        onCooRequiredChanged: (v) {
          state.cooRequired = v;
          onStateUpdated();
        },
        onCooTypeChanged: (v) {
          state.cooType = v;
          onStateUpdated();
        },
        onCooStatusChanged: (v) {
          state.cooStatus = v;
          onStateUpdated();
        },
      ),
      pillar3Child: Pillar3InspectionWidget(
        inspectionRequired: state.inspectionRequired,
        inspectionBody: state.inspectionBody,
        inspectionStatus: state.inspectionStatus,
        inspReportNoCtrl: controllers.inspReportNoCtrl,
        inspNotesCtrl: controllers.inspNotesCtrl,
        onInspectionRequiredChanged: (v) {
          state.inspectionRequired = v;
          onStateUpdated();
        },
        onInspectionBodyChanged: (v) {
          state.inspectionBody = v;
          onStateUpdated();
        },
        onInspectionStatusChanged: (v) {
          state.inspectionStatus = v;
          onStateUpdated();
        },
      ),
      pillar4Child: Pillar4PermitsWidget(
        importPermitRequired: state.importPermitRequired,
        permitIssuingAuthority: state.permitIssuingAuthority,
        permitStatus: state.permitStatus,
        permitNumberCtrl: controllers.permitNumberCtrl,
        permitNotesCtrl: controllers.permitNotesCtrl,
        onImportPermitRequiredChanged: (v) {
          state.importPermitRequired = v;
          onStateUpdated();
        },
        onPermitIssuingAuthorityChanged: (v) {
          state.permitIssuingAuthority = v;
          onStateUpdated();
        },
        onPermitStatusChanged: (v) {
          state.permitStatus = v;
          onStateUpdated();
        },
      ),
      pillar5Child: Pillar5TechCertsWidget(
        msdsRequired: state.msdsRequired,
        halalCertRequired: state.halalCertRequired,
        coaRequired: state.coaRequired,
        sailingStatus: state.sailingStatus,
        riskLevel: state.riskLevel,
        overallStatus: state.overallStatus,
        sailingDateCtrl: controllers.sailingDateCtrl,
        specialNotesCtrl: controllers.specialNotesCtrl,
        onMsdsRequiredChanged: (v) {
          state.msdsRequired = v;
          onStateUpdated();
        },
        onHalalCertRequiredChanged: (v) {
          state.halalCertRequired = v;
          onStateUpdated();
        },
        onCoaRequiredChanged: (v) {
          state.coaRequired = v;
          onStateUpdated();
        },
        onSailingStatusChanged: (v) {
          state.sailingStatus = v;
          onStateUpdated();
        },
        onRiskLevelChanged: (v) {
          state.riskLevel = v;
          onStateUpdated();
        },
        onOverallStatusChanged: (v) {
          state.overallStatus = v;
          onStateUpdated();
        },
      ),
    );
  }
}
