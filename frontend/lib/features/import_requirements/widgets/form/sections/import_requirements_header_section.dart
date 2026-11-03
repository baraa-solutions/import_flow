import 'package:flutter/material.dart';
import '../../../models/import_requirement_model.dart';
import '../../../../import_files/models/import_file_model.dart';
import '../../../../suppliers/models/supplier_model.dart';
import '../../prefill_messages_banner.dart';
import '../import_file_selector_card.dart';
import '../import_requirements_lifecycle_stepper.dart';

class ImportRequirementsHeaderSection extends StatelessWidget {
  final String sailingStatus;
  final String acidNumber;
  final String inspectionStatus;
  final String cooStatus;
  final bool whiteListVerified;
  final List<PrefillMessage> prefillMessages;
  final List<ImportFileModel> importFiles;
  final List<SupplierModel> suppliers;
  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileChanged;
  final TextEditingController acidNumberCtrl;
  final int? selectedSupplierId;
  final ValueChanged<int?> onSupplierChanged;
  final String? selectedConsultationCode;
  final double consultationReadiness;

  const ImportRequirementsHeaderSection({
    super.key,
    required this.sailingStatus,
    required this.acidNumber,
    required this.inspectionStatus,
    required this.cooStatus,
    required this.whiteListVerified,
    required this.prefillMessages,
    required this.importFiles,
    required this.suppliers,
    required this.selectedImportFileId,
    required this.onImportFileChanged,
    required this.acidNumberCtrl,
    required this.selectedSupplierId,
    required this.onSupplierChanged,
    required this.selectedConsultationCode,
    required this.consultationReadiness,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ImportRequirementsLifecycleStepper(
          sailingStatus: sailingStatus,
          acidNumber: acidNumber,
          inspectionStatus: inspectionStatus,
          cooStatus: cooStatus,
          whiteListVerified: whiteListVerified,
        ),
        const SizedBox(height: 12),
        PrefillMessagesBanner(messages: prefillMessages),
        const SizedBox(height: 12),
        ImportFileSelectorCard(
          importFiles: importFiles,
          suppliers: suppliers,
          selectedImportFileId: selectedImportFileId,
          onImportFileChanged: onImportFileChanged,
          acidNumberCtrl: acidNumberCtrl,
          selectedSupplierId: selectedSupplierId,
          onSupplierChanged: onSupplierChanged,
          selectedConsultationCode: selectedConsultationCode,
          consultationReadiness: consultationReadiness,
        ),
      ],
    );
  }
}
