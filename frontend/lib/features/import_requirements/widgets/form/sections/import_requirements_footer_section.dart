import 'package:flutter/material.dart';
import '../advanced_operational_pillars_accordion.dart';
import '../import_requirements_bottom_bar.dart';
import '../../advanced/advanced_pillars.dart';

class ImportRequirementsFooterSection extends StatelessWidget {
  final String? supplierName;
  final String supplierCountry;
  final String? cargoxId;
  final String cargoxStatus;
  final ValueChanged<CargoXPreAcidData> onCargoXChanged;
  final bool isShelflifeApplicable;
  final String? eosSpecNumber;
  final ValueChanged<ShelfLifeEosData> onShelfLifeChanged;
  final bool samplingRequired;
  final String? labType;
  final ValueChanged<TestingLabTrackData> onTestingLabChanged;
  final bool isHazmat;
  final String? imoClass;
  final ValueChanged<HazardousMaterialsData> onHazmatChanged;
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onAutoComplete;
  final VoidCallback onRefresh;
  final VoidCallback onReset;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;

  const ImportRequirementsFooterSection({
    super.key,
    required this.supplierName,
    required this.supplierCountry,
    required this.cargoxId,
    required this.cargoxStatus,
    required this.onCargoXChanged,
    required this.isShelflifeApplicable,
    required this.eosSpecNumber,
    required this.onShelfLifeChanged,
    required this.samplingRequired,
    required this.labType,
    required this.onTestingLabChanged,
    required this.isHazmat,
    required this.imoClass,
    required this.onHazmatChanged,
    required this.isEditing,
    required this.isSaving,
    required this.onAutoComplete,
    required this.onRefresh,
    required this.onReset,
    required this.onSaveDraft,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdvancedOperationalPillarsAccordion(
          supplierName: supplierName,
          supplierCountry: supplierCountry,
          cargoxId: cargoxId,
          cargoxStatus: cargoxStatus,
          onCargoXChanged: onCargoXChanged,
          isShelflifeApplicable: isShelflifeApplicable,
          eosSpecNumber: eosSpecNumber,
          onShelfLifeChanged: onShelfLifeChanged,
          samplingRequired: samplingRequired,
          labType: labType,
          onTestingLabChanged: onTestingLabChanged,
          isHazmat: isHazmat,
          imoClass: imoClass,
          onHazmatChanged: onHazmatChanged,
        ),
        const SizedBox(height: 16),
        ImportRequirementsBottomBar(
          isEditing: isEditing,
          isSaving: isSaving,
          onAutoComplete: onAutoComplete,
          onRefresh: onRefresh,
          onReset: onReset,
          onSaveDraft: onSaveDraft,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}
