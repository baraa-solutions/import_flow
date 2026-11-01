import '../../../models/import_requirement_model.dart';
import '../../../../../core/localization/domain_enum_labels.dart';

class ImportRequirementsPillarsState {
  // 5 Pillars
  bool decree43Applicable = false;
  bool whiteListRequired = false;
  bool whiteListVerified = false;
  String? decree43Action;
  String? decree43Justification;

  bool cooRequired = false;
  String? cooType;
  String cooStatus = 'Not Required';

  bool inspectionRequired = false;
  String? inspectionBody;
  String inspectionStatus = 'Not Required';

  bool importPermitRequired = false;
  String? permitIssuingAuthority;
  String permitStatus = 'Not Required';

  bool msdsRequired = false;
  String msdsStatus = 'Not Required';
  bool halalCertRequired = false;
  String halalCertStatus = 'Not Required';
  bool coaRequired = false;
  String coaStatus = 'Not Required';

  String confirmationStatus = 'Pending Confirmation';
  bool isPostAcidConfirmed = false;
  String sailingStatus = 'Pre-Sailing';
  String overallStatus = 'Draft';
  String riskLevel = 'Low';

  // Advanced Pillars
  bool cargoxVerified = false;
  String cargoxStatus = 'PENDING';
  String? cargoxId;
  bool isShelflifeApplicable = false;
  String? eosSpecNumber;
  bool samplingRequired = false;
  String? labType;
  bool isHazmat = false;
  String? imoClass;

  void reset() {
    decree43Applicable = false;
    whiteListRequired = false;
    whiteListVerified = false;
    decree43Action = null;
    decree43Justification = null;
    cooRequired = false;
    cooType = null;
    cooStatus = 'Not Required';
    inspectionRequired = false;
    inspectionBody = null;
    inspectionStatus = 'Not Required';
    importPermitRequired = false;
    permitIssuingAuthority = null;
    permitStatus = 'Not Required';
    msdsRequired = false;
    msdsStatus = 'Not Required';
    halalCertRequired = false;
    halalCertStatus = 'Not Required';
    coaRequired = false;
    coaStatus = 'Not Required';
    confirmationStatus = 'Pending Confirmation';
    isPostAcidConfirmed = false;
    sailingStatus = 'Pre-Sailing';
    overallStatus = 'Draft';
    riskLevel = 'Low';

    cargoxVerified = false;
    cargoxStatus = 'PENDING';
    cargoxId = null;
    isShelflifeApplicable = false;
    eosSpecNumber = null;
    samplingRequired = false;
    labType = null;
    isHazmat = false;
    imoClass = null;
  }

  void loadFromAssessment(ImportRequirementModel item) {
    confirmationStatus = item.confirmationStatus;
    isPostAcidConfirmed = item.isPostAcidConfirmed;
    sailingStatus = item.sailingStatus;
    overallStatus = item.overallStatus;
    riskLevel = item.riskLevel;

    cargoxVerified = item.cargoxVerified;
    cargoxStatus = item.cargoxStatus;
    isShelflifeApplicable = item.isShelflifeApplicable;
    samplingRequired = item.samplingRequired;
    labType = item.labType;
    isHazmat = item.isHazmat;
    imoClass = item.imoClass;

    if (item.hsCodeItems.isEmpty) {
      decree43Applicable = item.decree43Applicable;
      whiteListRequired = item.whiteListRequired;
      whiteListVerified = item.whiteListVerified;
      decree43Action = item.decree43Action;
      decree43Justification = item.decree43Justification;
      cooRequired = item.cooRequired;
      cooType = item.cooType;
      cooStatus = item.cooStatus;
      inspectionRequired = item.inspectionRequired;
      inspectionBody = item.inspectionBody;
      inspectionStatus = item.inspectionStatus;
      importPermitRequired = item.importPermitRequired;
      permitIssuingAuthority = item.permitIssuingAuthority;
      permitStatus = item.permitStatus;
      msdsRequired = item.msdsRequired;
      msdsStatus = item.msdsStatus;
      halalCertRequired = item.halalCertRequired;
      halalCertStatus = item.halalCertStatus;
      coaRequired = item.coaRequired;
      coaStatus = item.coaStatus;
    }
  }

  void loadFromPrefill(ImportRequirementPrefillModel prefill) {
    cargoxVerified = prefill.cargoxVerified;
    cargoxStatus = prefill.cargoxStatus;
    isShelflifeApplicable = prefill.isShelflifeApplicable;
    samplingRequired = prefill.samplingRequired;
    labType = prefill.labType;
    isHazmat = prefill.isHazmat;
    imoClass = prefill.imoClass;

    if (prefill.hsCodeItems.isEmpty) {
      decree43Applicable = prefill.decree43Applicable;
      whiteListRequired = prefill.whiteListRequired;
      whiteListVerified = prefill.whiteListVerified;
      cooRequired = prefill.cooRequired;
      cooType = prefill.cooType;
      cooStatus = prefill.cooStatus;
      inspectionRequired = prefill.inspectionRequired;
      inspectionBody = prefill.inspectionBody;
      inspectionStatus = prefill.inspectionStatus;
      importPermitRequired = prefill.importPermitRequired;
      permitIssuingAuthority = DomainEnums.legacyToCode(
        DomainEnumType.regulatoryBody,
        prefill.permitIssuingAuthority,
      );
      permitStatus = prefill.permitStatus;
      msdsRequired = prefill.msdsRequired;
      msdsStatus = prefill.msdsStatus;
      halalCertRequired = prefill.halalCertRequired;
      halalCertStatus = prefill.halalCertStatus;
      coaRequired = prefill.coaRequired;
      coaStatus = prefill.coaStatus;
    }
  }

  void loadFromHsItem(ImportRequirementHSCodeItemModel itm) {
    decree43Applicable = itm.decree43Applicable;
    whiteListRequired = itm.whiteListRequired;
    whiteListVerified = itm.whiteListVerified;
    decree43Action = itm.decree43Action;
    decree43Justification = itm.decree43Justification;
    cooRequired = itm.cooRequired;
    cooType = itm.cooType;
    cooStatus = itm.cooStatus;
    inspectionRequired = itm.inspectionRequired;
    inspectionBody = itm.inspectionBody;
    inspectionStatus = itm.inspectionStatus;
    importPermitRequired = itm.permitRequired;
    permitIssuingAuthority = itm.regulatoryAuthority;
    permitStatus = itm.permitStatus;
    msdsRequired = itm.msdsRequired;
    msdsStatus = itm.msdsStatus;
    halalCertRequired = itm.halalCertRequired;
    halalCertStatus = itm.halalCertStatus;
    coaRequired = itm.coaRequired;
    coaStatus = itm.coaStatus;
  }

  void autoCompleteAll() {
    whiteListVerified = true;
    cooStatus = 'Obtained';
    inspectionStatus = 'Completed';
    permitStatus = 'Approved';
    msdsStatus = 'Obtained';
    halalCertStatus = 'Obtained';
    coaStatus = 'Obtained';
    isPostAcidConfirmed = true;
    confirmationStatus = 'Confirmed';
    sailingStatus = 'Cleared for Sailing';
    overallStatus = 'Complete';
    riskLevel = 'Low';
  }
}
