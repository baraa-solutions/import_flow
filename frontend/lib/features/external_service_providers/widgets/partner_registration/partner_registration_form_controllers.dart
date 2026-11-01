import 'package:flutter/material.dart';
import '../../models/partner_model.dart';

class PartnerRegistrationFormControllers {
  final TextEditingController name;
  final TextEditingController taxId;
  final TextEditingController reg;
  final TextEditingController license;
  final TextEditingController authorizedPorts;
  final TextEditingController transportLicense;
  final TextEditingController fleetTypes;
  final TextEditingController coverageAreas;
  final TextEditingController insuranceLicense;
  final TextEditingController insuranceCoverage;
  final TextEditingController scac;
  final TextEditingController defaultFreeDays;
  final TextEditingController paymentTerms;
  final TextEditingController creditLimit;
  final TextEditingController tracking;
  final TextEditingController fiata;
  final TextEditingController shippingModes;
  final TextEditingController supportedCurrencies;
  final TextEditingController accreditation;
  final TextEditingController inspectionScope;
  final TextEditingController swift;
  final TextEditingController bankCode;
  final TextEditingController branch;
  final TextEditingController phone;
  final TextEditingController mobile;
  final TextEditingController fax;
  final TextEditingController email;
  final TextEditingController secondaryEmail;
  final TextEditingController website;
  final TextEditingController address;
  final TextEditingController country;

  PartnerRegistrationFormControllers(PartnerModel? p)
      : name = TextEditingController(text: p?.partnerName ?? ''),
        taxId = TextEditingController(text: p?.taxId ?? ''),
        reg = TextEditingController(text: p?.commercialRegister ?? ''),
        license =
            TextEditingController(text: p?.clearanceLicenseNumber ?? ''),
        authorizedPorts =
            TextEditingController(text: p?.authorizedPorts ?? ''),
        transportLicense =
            TextEditingController(text: p?.transportLicenseNumber ?? ''),
        fleetTypes = TextEditingController(text: p?.fleetTypes ?? ''),
        coverageAreas = TextEditingController(text: p?.coverageAreas ?? ''),
        insuranceLicense =
            TextEditingController(text: p?.insuranceLicenseNumber ?? ''),
        insuranceCoverage =
            TextEditingController(text: p?.insuranceCoverageTypes ?? ''),
        scac = TextEditingController(text: p?.scacCode ?? ''),
        defaultFreeDays = TextEditingController(
          text: p?.defaultFreeDays != null ? p!.defaultFreeDays.toString() : '',
        ),
        paymentTerms = TextEditingController(text: p?.paymentTerms ?? ''),
        creditLimit = TextEditingController(
          text: p?.creditLimit != null ? p!.creditLimit.toString() : '',
        ),
        tracking = TextEditingController(text: p?.trackingUrl ?? ''),
        fiata = TextEditingController(text: p?.fiataId ?? ''),
        shippingModes =
            TextEditingController(text: p?.shippingModes ?? ''),
        supportedCurrencies =
            TextEditingController(text: p?.supportedCurrencies ?? ''),
        accreditation =
            TextEditingController(text: p?.inspectionAccreditationNumber ?? ''),
        inspectionScope =
            TextEditingController(text: p?.inspectionScope ?? ''),
        swift = TextEditingController(text: p?.swiftCode ?? ''),
        bankCode = TextEditingController(text: p?.bankCode ?? ''),
        branch = TextEditingController(text: p?.branchName ?? ''),
        phone = TextEditingController(text: p?.phone ?? ''),
        mobile = TextEditingController(text: p?.mobile ?? ''),
        fax = TextEditingController(text: p?.fax ?? ''),
        email = TextEditingController(text: p?.email ?? ''),
        secondaryEmail =
            TextEditingController(text: p?.secondaryEmail ?? ''),
        website = TextEditingController(text: p?.website ?? ''),
        address = TextEditingController(text: p?.address ?? ''),
        country = TextEditingController(text: p?.country ?? '');

  void dispose() {
    name.dispose();
    taxId.dispose();
    reg.dispose();
    license.dispose();
    authorizedPorts.dispose();
    transportLicense.dispose();
    fleetTypes.dispose();
    coverageAreas.dispose();
    insuranceLicense.dispose();
    insuranceCoverage.dispose();
    scac.dispose();
    defaultFreeDays.dispose();
    paymentTerms.dispose();
    creditLimit.dispose();
    tracking.dispose();
    fiata.dispose();
    shippingModes.dispose();
    supportedCurrencies.dispose();
    accreditation.dispose();
    inspectionScope.dispose();
    swift.dispose();
    bankCode.dispose();
    branch.dispose();
    phone.dispose();
    mobile.dispose();
    fax.dispose();
    email.dispose();
    secondaryEmail.dispose();
    website.dispose();
    address.dispose();
    country.dispose();
  }
}
