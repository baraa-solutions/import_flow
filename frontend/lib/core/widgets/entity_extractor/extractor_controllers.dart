import 'package:flutter/material.dart';
import '../../constants/api_constants.dart';
import 'extractor_types.dart';

class ExtractorControllers {
  final TextEditingController rawTextCtrl = TextEditingController();
  final TextEditingController companyNameCtrl = TextEditingController();
  final TextEditingController arabicNameCtrl = TextEditingController();
  final TextEditingController contactPersonCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController mobileCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController secondaryEmailCtrl = TextEditingController();
  final TextEditingController websiteCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController countryCtrl = TextEditingController();
  final TextEditingController countryCodeCtrl = TextEditingController();

  final TextEditingController cargoxIdCtrl = TextEditingController();
  final TextEditingController foreignTaxIdCtrl = TextEditingController();
  final TextEditingController brandsCtrl = TextEditingController();
  final TextEditingController faxCtrl = TextEditingController();
  final TextEditingController bankNameCtrl = TextEditingController();
  final TextEditingController accountNumberCtrl = TextEditingController();
  final TextEditingController ibanCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();
  String supplierType = 'Manufacturer';
  String supplierRegType = 'Factory Registration';
  bool hasIso = false;
  bool registeredDecree43 = false;
  bool whiteListRegistered = false;

  final TextEditingController taxIdCtrl = TextEditingController();
  final TextEditingController commercialRegisterCtrl = TextEditingController();
  final TextEditingController importerCardCtrl = TextEditingController();
  final TextEditingController nafezaTokenCtrl = TextEditingController();
  bool showNafezaToken = false;
  DateTime importerIdExpiry = DateTime.now().add(const Duration(days: 365));
  DateTime vatIdExpiry = DateTime.now().add(const Duration(days: 365 * 3));
  DateTime registrationExpiry = DateTime.now().add(const Duration(days: 365 * 2));

  final TextEditingController brokerLicenseCtrl = TextEditingController();
  final TextEditingController portsCtrl = TextEditingController();
  final TextEditingController scacCodeCtrl = TextEditingController();
  final TextEditingController trackingUrlCtrl = TextEditingController();
  final TextEditingController servicesScopeCtrl = TextEditingController();
  final TextEditingController fleetTypesCtrl = TextEditingController();
  final TextEditingController inspectionScopeCtrl = TextEditingController();
  final TextEditingController policyTermsCtrl = TextEditingController();

  final TextEditingController swiftCodeCtrl = TextEditingController();
  final TextEditingController branchNameCtrl = TextEditingController();
  final TextEditingController bankAccountCtrl = TextEditingController();

  bool hasWipo = false;
  final TextEditingController wipoNumberCtrl = TextEditingController();
  bool hasEuipo = false;
  final TextEditingController euipoNumberCtrl = TextEditingController();
  bool hasGlobalBrand = false;
  final TextEditingController globalBrandNumberCtrl = TextEditingController();
  bool hasIso9001 = false;
  final TextEditingController iso9001NumberCtrl = TextEditingController();

  final TextEditingController defaultFreeDaysCtrl = TextEditingController();
  final TextEditingController paymentTermsCtrl = TextEditingController();
  final TextEditingController creditLimitCtrl = TextEditingController();

  double confidenceScore = 0.0;
  String? selectedFileName;

  void dispose() {
    rawTextCtrl.dispose();
    companyNameCtrl.dispose();
    arabicNameCtrl.dispose();
    contactPersonCtrl.dispose();
    phoneCtrl.dispose();
    mobileCtrl.dispose();
    faxCtrl.dispose();
    emailCtrl.dispose();
    secondaryEmailCtrl.dispose();
    websiteCtrl.dispose();
    addressCtrl.dispose();
    countryCtrl.dispose();
    countryCodeCtrl.dispose();
    cargoxIdCtrl.dispose();
    foreignTaxIdCtrl.dispose();
    brandsCtrl.dispose();
    bankNameCtrl.dispose();
    accountNumberCtrl.dispose();
    ibanCtrl.dispose();
    notesCtrl.dispose();
    taxIdCtrl.dispose();
    commercialRegisterCtrl.dispose();
    importerCardCtrl.dispose();
    nafezaTokenCtrl.dispose();
    brokerLicenseCtrl.dispose();
    portsCtrl.dispose();
    scacCodeCtrl.dispose();
    trackingUrlCtrl.dispose();
    servicesScopeCtrl.dispose();
    fleetTypesCtrl.dispose();
    inspectionScopeCtrl.dispose();
    policyTermsCtrl.dispose();
    swiftCodeCtrl.dispose();
    branchNameCtrl.dispose();
    bankAccountCtrl.dispose();
    wipoNumberCtrl.dispose();
    euipoNumberCtrl.dispose();
    globalBrandNumberCtrl.dispose();
    iso9001NumberCtrl.dispose();
    defaultFreeDaysCtrl.dispose();
    paymentTermsCtrl.dispose();
    creditLimitCtrl.dispose();
  }

  static DateTime? tryParseDate(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim();
    if (str.isEmpty) return null;
    final d = DateTime.tryParse(str);
    if (d != null) return d;
    final parts = str.split(RegExp(r'[-/]'));
    if (parts.length == 3) {
      if (parts[0].length == 4) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (y != null && m != null && day != null) return DateTime(y, m, day);
      } else if (parts[2].length == 4) {
        final day = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (y != null && m != null && day != null) return DateTime(y, m, day);
      }
    }
    return null;
  }

  void populateFields(Map<String, dynamic> ext, double score) {
    confidenceScore = score;

    if (ext['company_name'] != null && ext['company_name'].toString().isNotEmpty) {
      companyNameCtrl.text = ext['company_name'].toString();
    } else if (ext['name_en'] != null && ext['name_en'].toString().isNotEmpty) {
      companyNameCtrl.text = ext['name_en'].toString();
    } else if (ext['partner_name'] != null && ext['partner_name'].toString().isNotEmpty) {
      companyNameCtrl.text = ext['partner_name'].toString();
    }

    if (ext['arabic_name'] != null && ext['arabic_name'].toString().isNotEmpty) {
      arabicNameCtrl.text = ext['arabic_name'].toString();
    } else if (ext['name_ar'] != null && ext['name_ar'].toString().isNotEmpty) {
      arabicNameCtrl.text = ext['name_ar'].toString();
    }

    if (ext['contact_person'] != null) {
      contactPersonCtrl.text = ext['contact_person'].toString();
    } else if (ext['manager'] != null) {
      contactPersonCtrl.text = ext['manager'].toString();
    } else if (ext['legal_representative'] != null) {
      contactPersonCtrl.text = ext['legal_representative'].toString();
    }
    if (ext['phone'] != null) {
      phoneCtrl.text = ext['phone'].toString();
    } else if (ext['phone_number'] != null) {
      phoneCtrl.text = ext['phone_number'].toString();
    }
    if (ext['mobile'] != null) {
      mobileCtrl.text = ext['mobile'].toString();
    } else if (ext['mobile_number'] != null) {
      mobileCtrl.text = ext['mobile_number'].toString();
    }
    if (ext['fax'] != null) {
      faxCtrl.text = ext['fax'].toString();
    } else if (ext['fax_number'] != null) {
      faxCtrl.text = ext['fax_number'].toString();
    }
    if (ext['email'] != null) emailCtrl.text = ext['email'].toString();
    if (ext['secondary_email'] != null) secondaryEmailCtrl.text = ext['secondary_email'].toString();
    if (ext['website'] != null) websiteCtrl.text = ext['website'].toString();
    if (ext['address'] != null) addressCtrl.text = ext['address'].toString();

    if (ext['country'] != null && ext['country'].toString().isNotEmpty) {
      final c = ext['country'].toString();
      countryCtrl.text = c;
      final match = kExtractorCountryList.firstWhere(
        (item) => item['name']!.toLowerCase().contains(c.toLowerCase()) || item['code']!.toLowerCase() == c.toLowerCase(),
        orElse: () => {'name': c, 'code': 'CN'},
      );
      countryCodeCtrl.text = match['code']!;
    } else if (ext['country_code'] != null && ext['country_code'].toString().isNotEmpty) {
      final code = ext['country_code'].toString().toUpperCase();
      final match = kExtractorCountryList.firstWhere(
        (item) => item['code']!.toUpperCase() == code,
        orElse: () => {'name': code, 'code': code},
      );
      countryCtrl.text = match['name']!;
      countryCodeCtrl.text = match['code']!;
    }

    if (ext['cargox_id'] != null) {
      cargoxIdCtrl.text = ext['cargox_id'].toString();
    } else if (ext['cargox_platform_id'] != null) {
      cargoxIdCtrl.text = ext['cargox_platform_id'].toString();
    }
    if (ext['foreign_exporter_id'] != null) {
      foreignTaxIdCtrl.text = ext['foreign_exporter_id'].toString();
    } else if (ext['foreign_tax_id'] != null) {
      foreignTaxIdCtrl.text = ext['foreign_tax_id'].toString();
    } else if (ext['vat_tax_id'] != null) {
      foreignTaxIdCtrl.text = ext['vat_tax_id'].toString();
    }
    if (ext['brands'] != null) brandsCtrl.text = ext['brands'].toString();
    if (ext['supplier_type'] != null && ext['supplier_type'].toString().isNotEmpty) {
      supplierType = ext['supplier_type'].toString();
    }
    if (ext['registration_type'] != null && ext['registration_type'].toString().isNotEmpty) {
      supplierRegType = ext['registration_type'].toString();
    } else if (ext['supplier_registration_type'] != null && ext['supplier_registration_type'].toString().isNotEmpty) {
      supplierRegType = ext['supplier_registration_type'].toString();
    }

    if (ext['vat_id'] != null) {
      taxIdCtrl.text = ext['vat_id'].toString();
    } else if (ext['tax_id'] != null) {
      taxIdCtrl.text = ext['tax_id'].toString();
    } else if (ext['vat_tax_id'] != null) {
      taxIdCtrl.text = ext['vat_tax_id'].toString();
    }
    if (ext['registration_number'] != null) {
      commercialRegisterCtrl.text = ext['registration_number'].toString();
    } else if (ext['commercial_register'] != null) {
      commercialRegisterCtrl.text = ext['commercial_register'].toString();
    }
    if (ext['importer_id'] != null) {
      importerCardCtrl.text = ext['importer_id'].toString();
    } else if (ext['importer_card_number'] != null) {
      importerCardCtrl.text = ext['importer_card_number'].toString();
    }
    if (ext['nafeza_token_id'] != null) {
      nafezaTokenCtrl.text = ext['nafeza_token_id'].toString();
    } else if (ext['nafeza_token'] != null) {
      nafezaTokenCtrl.text = ext['nafeza_token'].toString();
    }

    if (ext['importer_id_expiry'] != null) {
      final d = tryParseDate(ext['importer_id_expiry']);
      if (d != null) importerIdExpiry = d;
    }
    if (ext['vat_id_expiry'] != null) {
      final d = tryParseDate(ext['vat_id_expiry']);
      if (d != null) vatIdExpiry = d;
    }
    if (ext['registration_expiry'] != null) {
      final d = tryParseDate(ext['registration_expiry']);
      if (d != null) registrationExpiry = d;
    }

    if (ext['clearance_license_number'] != null) {
      brokerLicenseCtrl.text = ext['clearance_license_number'].toString();
    } else if (ext['license_number'] != null) {
      brokerLicenseCtrl.text = ext['license_number'].toString();
    } else if (ext['transport_license_number'] != null) {
      brokerLicenseCtrl.text = ext['transport_license_number'].toString();
    } else if (ext['inspection_accreditation_number'] != null) {
      brokerLicenseCtrl.text = ext['inspection_accreditation_number'].toString();
    } else if (ext['insurance_license_number'] != null) {
      brokerLicenseCtrl.text = ext['insurance_license_number'].toString();
    } else if (ext['fiata_id'] != null) {
      brokerLicenseCtrl.text = ext['fiata_id'].toString();
    }

    if (ext['ports'] != null) {
      portsCtrl.text = ext['ports'].toString();
    } else if (ext['authorized_ports'] != null) {
      portsCtrl.text = ext['authorized_ports'].toString();
    }
    if (ext['scac_code'] != null) scacCodeCtrl.text = ext['scac_code'].toString();
    if (ext['tracking_url'] != null) trackingUrlCtrl.text = ext['tracking_url'].toString();
    if (ext['services_scope'] != null) {
      servicesScopeCtrl.text = ext['services_scope'].toString();
    } else if (ext['shipping_modes'] != null) {
      servicesScopeCtrl.text = ext['shipping_modes'].toString();
    }
    if (ext['fleet_types'] != null) fleetTypesCtrl.text = ext['fleet_types'].toString();
    if (ext['inspection_scope'] != null) inspectionScopeCtrl.text = ext['inspection_scope'].toString();
    if (ext['policy_terms'] != null) {
      policyTermsCtrl.text = ext['policy_terms'].toString();
    } else if (ext['insurance_terms'] != null) {
      policyTermsCtrl.text = ext['insurance_terms'].toString();
    } else if (ext['insurance_coverage_types'] != null) {
      policyTermsCtrl.text = ext['insurance_coverage_types'].toString();
    }

    if (ext['swift_code'] != null) swiftCodeCtrl.text = ext['swift_code'].toString();
    if (ext['bank_name'] != null) bankNameCtrl.text = ext['bank_name'].toString();
    if (ext['branch_name'] != null) branchNameCtrl.text = ext['branch_name'].toString();
    // Account number and IBAN stay in their own fields: an IBAN is never copied into the account number.
    final ibanValue = ext['iban']?.toString();
    final accountValue = ext['account_number'] ?? ext['bank_account'];
    if (accountValue != null && accountValue.toString().isNotEmpty && accountValue.toString() != ibanValue) {
      bankAccountCtrl.text = accountValue.toString();
      accountNumberCtrl.text = accountValue.toString();
    }
    if (ibanValue != null && ibanValue.isNotEmpty) ibanCtrl.text = ibanValue;
    if (ext['notes'] != null) notesCtrl.text = ext['notes'].toString();
    if (ext['has_iso'] != null) hasIso = ext['has_iso'] == true || ext['has_iso'] == 'true';
    if (ext['registered_decree_43'] != null) registeredDecree43 = ext['registered_decree_43'] == true || ext['registered_decree_43'] == 'true';
    if (ext['white_list_registered'] != null) whiteListRegistered = ext['white_list_registered'] == true || ext['white_list_registered'] == 'true';

    // Trademark & Quality Certificates
    if (ext['has_wipo'] != null) hasWipo = ext['has_wipo'] == true || ext['has_wipo'] == 'true';
    if (ext['wipo_number'] != null) wipoNumberCtrl.text = ext['wipo_number'].toString();
    if (ext['has_euipo'] != null) hasEuipo = ext['has_euipo'] == true || ext['has_euipo'] == 'true';
    if (ext['euipo_number'] != null) euipoNumberCtrl.text = ext['euipo_number'].toString();
    if (ext['has_global_brand'] != null) hasGlobalBrand = ext['has_global_brand'] == true || ext['has_global_brand'] == 'true';
    if (ext['global_brand_number'] != null) globalBrandNumberCtrl.text = ext['global_brand_number'].toString();
    if (ext['has_iso_9001'] != null) hasIso9001 = ext['has_iso_9001'] == true || ext['has_iso_9001'] == 'true';
    if (ext['iso_9001_number'] != null) iso9001NumberCtrl.text = ext['iso_9001_number'].toString();

    // Freight Forwarder Financial & Credit
    if (ext['default_free_days'] != null) defaultFreeDaysCtrl.text = ext['default_free_days'].toString();
    if (ext['payment_terms'] != null) paymentTermsCtrl.text = ext['payment_terms'].toString();
    if (ext['credit_limit'] != null) creditLimitCtrl.text = ext['credit_limit'].toString();
  }

  ({String endpoint, Map<String, dynamic> payload}) buildSavePayload(EntityTarget target, String effectiveName) {
    switch (target) {
      case EntityTarget.supplier:
        return (
          endpoint: '${ApiConstants.baseUrl}/suppliers',
          payload: {
            'company_name': effectiveName,
            'supplier_type': supplierType,
            'registration_type': supplierRegType,
            'foreign_exporter_id': foreignTaxIdCtrl.text.trim().isNotEmpty ? foreignTaxIdCtrl.text.trim() : 'EXP-${DateTime.now().millisecondsSinceEpoch}',
            'cargox_platform_id': cargoxIdCtrl.text.trim().isNotEmpty ? cargoxIdCtrl.text.trim() : null,
            'foreign_exporter_country': countryCtrl.text.trim(),
            'foreign_exporter_country_code': countryCodeCtrl.text.trim(),
            'address': addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : 'Foreign Address',
            'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
            'mobile': mobileCtrl.text.trim().isNotEmpty ? mobileCtrl.text.trim() : null,
            'fax': faxCtrl.text.trim().isNotEmpty ? faxCtrl.text.trim() : null,
            'email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
            'secondary_email': secondaryEmailCtrl.text.trim().isNotEmpty ? secondaryEmailCtrl.text.trim() : null,
            'website': websiteCtrl.text.trim().isNotEmpty ? websiteCtrl.text.trim() : null,
            'bank_name': bankNameCtrl.text.trim().isNotEmpty ? bankNameCtrl.text.trim() : null,
            'swift_code': swiftCodeCtrl.text.trim().isNotEmpty ? swiftCodeCtrl.text.trim() : null,
            'account_number': (accountNumberCtrl.text.trim().isNotEmpty ? accountNumberCtrl.text.trim() : (bankAccountCtrl.text.trim().isNotEmpty ? bankAccountCtrl.text.trim() : null)),
            'iban': ibanCtrl.text.trim().isNotEmpty ? ibanCtrl.text.trim() : null,
            'has_iso': hasIso,
            'registered_decree_43': registeredDecree43,
            'white_list_registered': whiteListRegistered,
            'brands': brandsCtrl.text.trim().isNotEmpty ? brandsCtrl.text.trim() : null,
            'has_wipo': hasWipo,
            'wipo_number': hasWipo && wipoNumberCtrl.text.trim().isNotEmpty ? wipoNumberCtrl.text.trim() : null,
            'has_euipo': hasEuipo,
            'euipo_number': hasEuipo && euipoNumberCtrl.text.trim().isNotEmpty ? euipoNumberCtrl.text.trim() : null,
            'has_global_brand': hasGlobalBrand,
            'global_brand_number': hasGlobalBrand && globalBrandNumberCtrl.text.trim().isNotEmpty ? globalBrandNumberCtrl.text.trim() : null,
            'has_iso_9001': hasIso9001,
            'iso_9001_number': hasIso9001 && iso9001NumberCtrl.text.trim().isNotEmpty ? iso9001NumberCtrl.text.trim() : null,
            'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
          },
        );

      case EntityTarget.company:
        final notesParts = <String>[];
        if (contactPersonCtrl.text.trim().isNotEmpty) notesParts.add('Manager: ${contactPersonCtrl.text.trim()}');
        if (bankNameCtrl.text.trim().isNotEmpty) notesParts.add('Bank: ${bankNameCtrl.text.trim()}');
        if (swiftCodeCtrl.text.trim().isNotEmpty) notesParts.add('SWIFT: ${swiftCodeCtrl.text.trim()}');
        if (accountNumberCtrl.text.trim().isNotEmpty) notesParts.add('Account: ${accountNumberCtrl.text.trim()}');
        if (ibanCtrl.text.trim().isNotEmpty) notesParts.add('IBAN: ${ibanCtrl.text.trim()}');
        if (notesCtrl.text.trim().isNotEmpty) notesParts.add(notesCtrl.text.trim());

        return (
          endpoint: '${ApiConstants.baseUrl}/import-companies',
          payload: {
            'importer_name': effectiveName,
            'address': addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : 'Cairo, Egypt',
            'country': countryCtrl.text.trim().isNotEmpty ? countryCtrl.text.trim() : 'Egypt',
            'importer_id': importerCardCtrl.text.trim().isNotEmpty ? importerCardCtrl.text.trim() : 'IMP-${DateTime.now().millisecondsSinceEpoch}',
            'importer_id_expiry': '${importerIdExpiry.year}-${importerIdExpiry.month.toString().padLeft(2, '0')}-${importerIdExpiry.day.toString().padLeft(2, '0')}',
            'vat_id': taxIdCtrl.text.trim().isNotEmpty ? taxIdCtrl.text.trim() : '000000000',
            'vat_id_expiry': '${vatIdExpiry.year}-${vatIdExpiry.month.toString().padLeft(2, '0')}-${vatIdExpiry.day.toString().padLeft(2, '0')}',
            'registration_number': commercialRegisterCtrl.text.trim().isNotEmpty ? commercialRegisterCtrl.text.trim() : '000000',
            'registration_expiry': '${registrationExpiry.year}-${registrationExpiry.month.toString().padLeft(2, '0')}-${registrationExpiry.day.toString().padLeft(2, '0')}',
            'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
            'mobile': mobileCtrl.text.trim().isNotEmpty ? mobileCtrl.text.trim() : null,
            'fax': faxCtrl.text.trim().isNotEmpty ? faxCtrl.text.trim() : null,
            'email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
            'secondary_email': secondaryEmailCtrl.text.trim().isNotEmpty ? secondaryEmailCtrl.text.trim() : null,
            'website': websiteCtrl.text.trim().isNotEmpty ? websiteCtrl.text.trim() : null,
            'nafeza_token': nafezaTokenCtrl.text.trim().isNotEmpty ? nafezaTokenCtrl.text.trim() : null,
            'has_wipo': hasWipo,
            'wipo_number': hasWipo && wipoNumberCtrl.text.trim().isNotEmpty ? wipoNumberCtrl.text.trim() : null,
            'has_euipo': hasEuipo,
            'euipo_number': hasEuipo && euipoNumberCtrl.text.trim().isNotEmpty ? euipoNumberCtrl.text.trim() : null,
            'has_global_brand': hasGlobalBrand,
            'global_brand_number': hasGlobalBrand && globalBrandNumberCtrl.text.trim().isNotEmpty ? globalBrandNumberCtrl.text.trim() : null,
            'has_iso_9001': hasIso9001,
            'iso_9001_number': hasIso9001 && iso9001NumberCtrl.text.trim().isNotEmpty ? iso9001NumberCtrl.text.trim() : null,
            'notes': notesParts.isNotEmpty ? notesParts.join(' | ') : null,
          },
        );

      case EntityTarget.customsBroker:
        return (
          endpoint: '${ApiConstants.baseUrl}/external-service-providers',
          payload: {
            'partner_name': effectiveName,
            'partner_type': 'Customs Broker',
            'clearance_license_number': brokerLicenseCtrl.text.trim().isNotEmpty ? brokerLicenseCtrl.text.trim() : null,
            'authorized_ports': portsCtrl.text.trim().isNotEmpty ? portsCtrl.text.trim() : null,
            'tax_id': taxIdCtrl.text.trim().isNotEmpty ? taxIdCtrl.text.trim() : null,
            'commercial_register': commercialRegisterCtrl.text.trim().isNotEmpty ? commercialRegisterCtrl.text.trim() : null,
            'contact_person': contactPersonCtrl.text.trim().isNotEmpty ? contactPersonCtrl.text.trim() : null,
            'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
            'mobile': mobileCtrl.text.trim().isNotEmpty ? mobileCtrl.text.trim() : null,
            'email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
            'website': websiteCtrl.text.trim().isNotEmpty ? websiteCtrl.text.trim() : null,
            'address': addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : 'Egypt',
            'country': 'Egypt',
            'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
          },
        );

      case EntityTarget.shippingLine:
        final scac = scacCodeCtrl.text.trim().toUpperCase();
        return (
          endpoint: '${ApiConstants.baseUrl}/external-service-providers',
          payload: {
            'partner_name': effectiveName,
            'partner_type': 'Shipping Line',
            'scac_code': scac.isNotEmpty ? scac : 'LINE',
            'tracking_url': trackingUrlCtrl.text.trim().isNotEmpty ? trackingUrlCtrl.text.trim() : null,
            'website': websiteCtrl.text.trim().isNotEmpty ? websiteCtrl.text.trim() : null,
            'email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
            'secondary_email': secondaryEmailCtrl.text.trim().isNotEmpty ? secondaryEmailCtrl.text.trim() : null,
            'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
            'address': addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : 'Egypt',
            'country': countryCtrl.text.trim().isNotEmpty ? countryCtrl.text.trim() : 'Egypt',
            'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
          },
        );

      case EntityTarget.freightForwarder:
        return (
          endpoint: '${ApiConstants.baseUrl}/external-service-providers',
          payload: {
            'partner_name': effectiveName,
            'partner_type': 'Freight Forwarder',
            'commercial_register': commercialRegisterCtrl.text.trim().isNotEmpty ? commercialRegisterCtrl.text.trim() : null,
            'fiata_id': brokerLicenseCtrl.text.trim().isNotEmpty ? brokerLicenseCtrl.text.trim() : null,
            'shipping_modes': servicesScopeCtrl.text.trim().isNotEmpty ? servicesScopeCtrl.text.trim() : null,
            'contact_person': contactPersonCtrl.text.trim().isNotEmpty ? contactPersonCtrl.text.trim() : null,
            'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
            'email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
            'secondary_email': secondaryEmailCtrl.text.trim().isNotEmpty ? secondaryEmailCtrl.text.trim() : null,
            'website': websiteCtrl.text.trim().isNotEmpty ? websiteCtrl.text.trim() : null,
            'address': addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : 'Egypt',
            'country': 'Egypt',
            'default_free_days': int.tryParse(defaultFreeDaysCtrl.text.trim()),
            'payment_terms': paymentTermsCtrl.text.trim().isNotEmpty ? paymentTermsCtrl.text.trim() : null,
            'credit_limit': double.tryParse(creditLimitCtrl.text.trim()) ?? 0.0,
            'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
          },
        );

      case EntityTarget.inlandTransport:
        return (
          endpoint: '${ApiConstants.baseUrl}/external-service-providers',
          payload: {
            'partner_name': effectiveName,
            'partner_type': 'Inland Transport',
            'transport_license_number': brokerLicenseCtrl.text.trim().isNotEmpty ? brokerLicenseCtrl.text.trim() : null,
            'fleet_types': fleetTypesCtrl.text.trim().isNotEmpty ? fleetTypesCtrl.text.trim() : null,
            'coverage_areas': portsCtrl.text.trim().isNotEmpty ? portsCtrl.text.trim() : null,
            'contact_person': contactPersonCtrl.text.trim().isNotEmpty ? contactPersonCtrl.text.trim() : null,
            'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
            'mobile': mobileCtrl.text.trim().isNotEmpty ? mobileCtrl.text.trim() : null,
            'email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
            'address': addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : 'Egypt Hub',
            'country': 'Egypt',
            'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
          },
        );

      case EntityTarget.inspectionAgency:
        return (
          endpoint: '${ApiConstants.baseUrl}/external-service-providers',
          payload: {
            'partner_name': effectiveName,
            'partner_type': 'Inspection Agency',
            'inspection_accreditation_number': brokerLicenseCtrl.text.trim().isNotEmpty ? brokerLicenseCtrl.text.trim() : null,
            'inspection_scope': inspectionScopeCtrl.text.trim().isNotEmpty ? inspectionScopeCtrl.text.trim() : null,
            'contact_person': contactPersonCtrl.text.trim().isNotEmpty ? contactPersonCtrl.text.trim() : null,
            'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
            'email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
            'website': websiteCtrl.text.trim().isNotEmpty ? websiteCtrl.text.trim() : null,
            'address': addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : 'Egypt Hub',
            'country': 'Egypt',
            'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
          },
        );

      case EntityTarget.insuranceCompany:
        return (
          endpoint: '${ApiConstants.baseUrl}/external-service-providers',
          payload: {
            'partner_name': effectiveName,
            'partner_type': 'Insurance Company',
            'insurance_license_number': brokerLicenseCtrl.text.trim().isNotEmpty ? brokerLicenseCtrl.text.trim() : null,
            'insurance_coverage_types': policyTermsCtrl.text.trim().isNotEmpty ? policyTermsCtrl.text.trim() : null,
            'contact_person': contactPersonCtrl.text.trim().isNotEmpty ? contactPersonCtrl.text.trim() : null,
            'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
            'email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
            'website': websiteCtrl.text.trim().isNotEmpty ? websiteCtrl.text.trim() : null,
            'address': addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : 'Egypt HQ',
            'country': 'Egypt',
            'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
          },
        );

      case EntityTarget.bank:
        final swift = swiftCodeCtrl.text.trim();
        return (
          endpoint: '${ApiConstants.baseUrl}/external-service-providers',
          payload: {
            'partner_name': effectiveName,
            'partner_type': 'Bank',
            'swift_code': swift.isNotEmpty ? swift : 'BANK-EG-SWIFT',
            'bank_code': swift.length >= 4 ? swift.substring(0, 4) : 'BNK-001',
            'branch_name': branchNameCtrl.text.trim().isNotEmpty ? branchNameCtrl.text.trim() : 'Main Branch',
            'contact_person': contactPersonCtrl.text.trim().isNotEmpty ? contactPersonCtrl.text.trim() : null,
            'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
            'email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
            'address': addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : null,
            'country': 'Egypt',
            'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
          },
        );

      case EntityTarget.partner:
        return (
          endpoint: '${ApiConstants.baseUrl}/external-service-providers',
          payload: {
            'partner_name': effectiveName,
            'partner_type': 'Freight Forwarder',
            'contact_person': contactPersonCtrl.text.trim().isNotEmpty ? contactPersonCtrl.text.trim() : null,
            'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
            'email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
            'address': addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : null,
            'country': 'Egypt',
            'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
          },
        );
    }
  }

  String buildExtractedSummary(BuildContext context, EntityTarget target) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final buffer = StringBuffer();
    buffer.writeln(isArabic
        ? '--- بيانات ${getTargetName(context, target)} المستخرجة ---'
        : '--- Extracted ${getTargetName(context, target)} Profile ---');

    void addField(String labelAr, String labelEn, String val) {
      if (val.trim().isNotEmpty) {
        buffer.writeln('${isArabic ? labelAr : labelEn}: ${val.trim()}');
      }
    }

    addField('اسم الكيان', 'Entity Name', companyNameCtrl.text);
    addField('الاسم بالعربية', 'Arabic Name', arabicNameCtrl.text);
    addField('رقم السجل والتعريف الضريبي', 'Tax / Reg ID', taxIdCtrl.text.isNotEmpty ? taxIdCtrl.text : foreignTaxIdCtrl.text);
    addField('معرف كارجو إكس', 'CargoX Platform ID', cargoxIdCtrl.text);
    addField('رقم السجل التجاري', 'Commercial Register', commercialRegisterCtrl.text);
    addField('البطاقة الاستيرادية', 'Importer Card', importerCardCtrl.text);
    addField('الدولة', 'Country', countryCtrl.text);
    addField('العنوان', 'Address', addressCtrl.text);
    addField('المسؤول', 'Contact Person', contactPersonCtrl.text);
    addField('الهاتف', 'Phone', phoneCtrl.text);
    addField('المحمول', 'Mobile', mobileCtrl.text);
    addField('الفاكس', 'Fax', faxCtrl.text);
    addField('البريد الإلكتروني', 'Email', emailCtrl.text);
    addField('البريد الثانوي', 'Secondary Email', secondaryEmailCtrl.text);
    addField('الموقع الإلكتروني', 'Website', websiteCtrl.text);
    final nafezaRaw = nafezaTokenCtrl.text.trim();
    if (nafezaRaw.isNotEmpty) {
      final masked = nafezaRaw.length > 4 ? '****${nafezaRaw.substring(nafezaRaw.length - 4)}' : '****';
      addField('توكن نافذة', 'Nafeza Token', masked);
    }
    if (hasWipo) addField('WIPO Madrid', 'WIPO Madrid', wipoNumberCtrl.text.isNotEmpty ? wipoNumberCtrl.text : 'Yes');
    if (hasEuipo) addField('EUIPO', 'EUIPO', euipoNumberCtrl.text.isNotEmpty ? euipoNumberCtrl.text : 'Yes');
    if (hasGlobalBrand) addField('Global Brand', 'Global Brand', globalBrandNumberCtrl.text.isNotEmpty ? globalBrandNumberCtrl.text : 'Yes');
    if (hasIso9001) addField('ISO 9001', 'ISO 9001', iso9001NumberCtrl.text.isNotEmpty ? iso9001NumberCtrl.text : 'Yes');
    addField('أيام السماح الافتراضية', 'Default Free Days', defaultFreeDaysCtrl.text);
    addField('شروط الدفع', 'Payment Terms', paymentTermsCtrl.text);
    addField('الحد الائتماني', 'Credit Limit', creditLimitCtrl.text);
    addField('البنك', 'Bank Name', bankNameCtrl.text);
    addField('سويفت', 'SWIFT Code', swiftCodeCtrl.text);
    addField('الحساب المصرفي', 'Bank Account', accountNumberCtrl.text);
    addField('الآيبان', 'IBAN', ibanCtrl.text);
    addField('كود الناقل', 'SCAC Code', scacCodeCtrl.text);
    addField('رخصة التخليص', 'Broker License', brokerLicenseCtrl.text);
    addField('نطاق العمل', 'Services Scope', servicesScopeCtrl.text);
    addField('ملاحظات', 'Notes', notesCtrl.text);

    return buffer.toString();
  }
}
