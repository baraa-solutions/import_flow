import '../../../customs_clearance/models/customs_clearance_model.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/customs_declaration_assessment.dart';
import '../form46_variance_bar.dart';

class DeclarationRegistryItem {
  final CustomsClearanceModel record;
  final ImportFileModel? file;
  final CustomsDeclarationAssessment? estimate;

  const DeclarationRegistryItem({
    required this.record,
    required this.file,
    this.estimate,
  });

  String get declarationNo => record.declaration46No ?? '-';
  String get importFileCode => file?.importFileCode ?? (record.importFileId > 0 ? 'IMP-${record.importFileId}' : '-');
  String get primaryNameWithCode => file?.primaryNameWithCode ?? importFileCode;
  String get supplierName => file?.supplierName ?? '-';
  String get declarationDate => record.declaration46Date != null && record.declaration46Date!.length >= 10
      ? record.declaration46Date!.substring(0, 10)
      : '—';
  String get customsOffice => record.customsOfficeName.trim().isNotEmpty ? record.customsOfficeName : '—';
  String get channel => record.channelType;
  String get status => record.status;
  double? get effectiveDutyTotal => record.effectiveDutyTotal;
  double? get estimatedDutyTotal => estimate?.totalDutiesEgp;
  double? get actualDutyTotal => record.actualDutyTotal;
  double? get dutyVarianceAmount => record.dutyVarianceAmount;
  double? get dutyVariancePercentage => record.dutyVariancePercentage;
  String? get dutyVarianceReason => record.dutyVarianceReason;

  Form46VarianceResult get varianceResult {
    if (dutyVariancePercentage != null && dutyVarianceAmount != null) {
      final absPct = dutyVariancePercentage!.abs();
      Form46VarianceSeverity sev;
      if (absPct < 2.0) {
        sev = Form46VarianceSeverity.compliant;
      } else if (absPct <= 10.0) {
        sev = Form46VarianceSeverity.moderate;
      } else {
        sev = Form46VarianceSeverity.high;
      }
      return Form46VarianceResult(
        baseline: estimatedDutyTotal ?? record.estimatedDutyTotal,
        compared: actualDutyTotal ?? record.totalDutyPayable,
        diffAmount: dutyVarianceAmount,
        diffPercentage: dutyVariancePercentage,
        severity: sev,
      );
    }
    final est = estimatedDutyTotal ?? record.estimatedDutyTotal;
    final act = actualDutyTotal ?? record.totalDutyPayable;
    return Form46VarianceResult.compute(est, act);
  }
}
