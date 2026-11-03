import 'package:flutter/material.dart';

import 'partner_bank_inspection_insurance_fields.dart';
import 'partner_transport_customs_fields.dart';

class PartnerCategorySpecificFields extends StatelessWidget {
  final bool isDarkDialog;
  final bool isBank;
  final bool isShippingLine;
  final bool isCustomsBroker;
  final bool isFreightForwarder;
  final bool isInlandTransport;
  final bool isInspectionAgency;
  final bool isInsuranceCompany;

  final TextEditingController swiftCtrl;
  final TextEditingController bankCodeCtrl;
  final TextEditingController branchCtrl;
  final TextEditingController scacCtrl;
  final TextEditingController defaultFreeDaysCtrl;
  final TextEditingController trackingCtrl;
  final TextEditingController licenseCtrl;
  final TextEditingController authorizedPortsCtrl;
  final TextEditingController fiataCtrl;
  final TextEditingController supportedCurrenciesCtrl;
  final TextEditingController shippingModesCtrl;
  final TextEditingController creditLimitCtrl;
  final TextEditingController transportLicenseCtrl;
  final TextEditingController fleetTypesCtrl;
  final TextEditingController coverageAreasCtrl;
  final TextEditingController accreditationCtrl;
  final TextEditingController inspectionScopeCtrl;
  final TextEditingController insuranceLicenseCtrl;
  final TextEditingController insuranceCoverageCtrl;

  const PartnerCategorySpecificFields({
    super.key,
    required this.isDarkDialog,
    required this.isBank,
    required this.isShippingLine,
    required this.isCustomsBroker,
    required this.isFreightForwarder,
    required this.isInlandTransport,
    required this.isInspectionAgency,
    required this.isInsuranceCompany,
    required this.swiftCtrl,
    required this.bankCodeCtrl,
    required this.branchCtrl,
    required this.scacCtrl,
    required this.defaultFreeDaysCtrl,
    required this.trackingCtrl,
    required this.licenseCtrl,
    required this.authorizedPortsCtrl,
    required this.fiataCtrl,
    required this.supportedCurrenciesCtrl,
    required this.shippingModesCtrl,
    required this.creditLimitCtrl,
    required this.transportLicenseCtrl,
    required this.fleetTypesCtrl,
    required this.coverageAreasCtrl,
    required this.accreditationCtrl,
    required this.inspectionScopeCtrl,
    required this.insuranceLicenseCtrl,
    required this.insuranceCoverageCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PartnerBankInspectionInsuranceFields(
          isBank: isBank,
          isInspectionAgency: isInspectionAgency,
          isInsuranceCompany: isInsuranceCompany,
          swiftCtrl: swiftCtrl,
          bankCodeCtrl: bankCodeCtrl,
          branchCtrl: branchCtrl,
          accreditationCtrl: accreditationCtrl,
          inspectionScopeCtrl: inspectionScopeCtrl,
          insuranceLicenseCtrl: insuranceLicenseCtrl,
          insuranceCoverageCtrl: insuranceCoverageCtrl,
        ),
        PartnerTransportCustomsFields(
          isDarkDialog: isDarkDialog,
          isShippingLine: isShippingLine,
          isCustomsBroker: isCustomsBroker,
          isFreightForwarder: isFreightForwarder,
          isInlandTransport: isInlandTransport,
          scacCtrl: scacCtrl,
          defaultFreeDaysCtrl: defaultFreeDaysCtrl,
          trackingCtrl: trackingCtrl,
          licenseCtrl: licenseCtrl,
          authorizedPortsCtrl: authorizedPortsCtrl,
          fiataCtrl: fiataCtrl,
          supportedCurrenciesCtrl: supportedCurrenciesCtrl,
          shippingModesCtrl: shippingModesCtrl,
          creditLimitCtrl: creditLimitCtrl,
          transportLicenseCtrl: transportLicenseCtrl,
          fleetTypesCtrl: fleetTypesCtrl,
          coverageAreasCtrl: coverageAreasCtrl,
        ),
      ],
    );
  }
}
