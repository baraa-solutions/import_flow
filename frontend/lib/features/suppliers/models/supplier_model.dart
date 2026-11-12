import '../../../core/utils/certificate_expiry.dart';
class SupplierModel {
  final int? supplierId;
  final String supplierCode;
  final String companyName;
  final String supplierType;
  final String registrationType;
  final String foreignExporterId;
  final String? cargoxPlatformId;
  final String? taxId;
  final String currency;
  final String foreignExporterCountry;
  final String foreignExporterCountryCode;
  final String? city;
  final String? postalCode;
  final String address;
  final String? contactPerson;
  final String? phone;
  final String? mobile;
  final String? fax;
  final String? email;
  final String? secondaryEmail;
  final String? website;
  final String? bankName;
  final String? swiftCode;
  final String? accountNumber;
  final String? iban;
  final bool hasIso;
  final bool registeredDecree43;
  final bool whiteListRegistered;
  final String? brands;
  final String? paymentTerms;
  final double creditLimit;
  final double rating;
  final String? notes;
  final bool isActive;
  final bool hasWipo;
  final String? wipoNumber;
  final bool hasEuipo;
  final String? euipoNumber;
  final bool hasGlobalBrand;
  final String? globalBrandNumber;
  final bool hasIso9001;
  final String? iso9001Number;
  final DateTime? wipoExpiry;
  final DateTime? euipoExpiry;
  final DateTime? globalBrandExpiry;
  final DateTime? iso9001Expiry;

  String get country => foreignExporterCountry;

  SupplierModel({
    this.supplierId,
    required this.supplierCode,
    required this.companyName,
    required this.supplierType,
    required this.registrationType,
    required this.foreignExporterId,
    this.cargoxPlatformId,
    this.taxId,
    this.currency = 'USD',
    required this.foreignExporterCountry,
    required this.foreignExporterCountryCode,
    this.city,
    this.postalCode,
    required this.address,
    this.contactPerson,
    this.phone,
    this.mobile,
    this.fax,
    this.email,
    this.secondaryEmail,
    this.website,
    this.bankName,
    this.swiftCode,
    this.accountNumber,
    this.iban,
    this.hasIso = false,
    this.registeredDecree43 = false,
    this.whiteListRegistered = false,
    this.brands,
    this.paymentTerms,
    this.creditLimit = 0.0,
    this.rating = 5.0,
    this.notes,
    this.isActive = true,
    this.hasWipo = false,
    this.wipoNumber,
    this.hasEuipo = false,
    this.euipoNumber,
    this.hasGlobalBrand = false,
    this.globalBrandNumber,
    this.hasIso9001 = false,
    this.iso9001Number,
    this.wipoExpiry,
    this.euipoExpiry,
    this.globalBrandExpiry,
    this.iso9001Expiry,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic val, {bool defaultValue = false}) {
      if (val == null) return defaultValue;
      if (val is bool) return val;
      if (val is num) return val != 0;
      if (val is String) {
        final s = val.toLowerCase().trim();
        return s == 'true' || s == '1' || s == 'yes' || s == 't';
      }
      return defaultValue;
    }

    return SupplierModel(
      supplierId: json['supplier_id'],
      supplierCode: json['supplier_code']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? '',
      supplierType: json['supplier_type']?.toString() ?? 'Manufacturer',
      registrationType: json['registration_type']?.toString() ?? 'Factory Registration',
      foreignExporterId: json['foreign_exporter_id']?.toString() ?? '',
      cargoxPlatformId: json['cargox_platform_id']?.toString(),
      taxId: json['tax_id']?.toString(),
      currency: json['currency']?.toString() ?? 'USD',
      foreignExporterCountry: json['foreign_exporter_country']?.toString() ?? '',
      foreignExporterCountryCode: json['foreign_exporter_country_code']?.toString() ?? '',
      city: json['city']?.toString(),
      postalCode: json['postal_code']?.toString(),
      address: json['address']?.toString() ?? '',
      contactPerson: json['contact_person']?.toString(),
      phone: json['phone']?.toString(),
      mobile: json['mobile']?.toString(),
      fax: json['fax']?.toString(),
      email: json['email']?.toString(),
      secondaryEmail: json['secondary_email']?.toString(),
      website: json['website']?.toString(),
      bankName: json['bank_name']?.toString(),
      swiftCode: json['swift_code']?.toString(),
      accountNumber: json['account_number']?.toString(),
      iban: json['iban']?.toString(),
      hasIso: parseBool(json['has_iso']),
      registeredDecree43: parseBool(json['registered_decree_43']),
      whiteListRegistered: parseBool(json['white_list_registered']),
      brands: json['brands']?.toString(),
      paymentTerms: json['payment_terms']?.toString(),
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      notes: json['notes']?.toString(),
      isActive: parseBool(json['is_active'], defaultValue: true),
      hasWipo: parseBool(json['has_wipo']),
      wipoNumber: json['wipo_number']?.toString(),
      hasEuipo: parseBool(json['has_euipo']),
      euipoNumber: json['euipo_number']?.toString(),
      hasGlobalBrand: parseBool(json['has_global_brand']),
      globalBrandNumber: json['global_brand_number']?.toString(),
      hasIso9001: parseBool(json['has_iso_9001']),
      iso9001Number: json['iso_9001_number']?.toString(),
      wipoExpiry: CertificateExpiry.parse(json['wipo_expiry']),
      euipoExpiry: CertificateExpiry.parse(json['euipo_expiry']),
      globalBrandExpiry: CertificateExpiry.parse(json['global_brand_expiry']),
      iso9001Expiry: CertificateExpiry.parse(json['iso_9001_expiry']),
    );
  }

  /// Soonest expiry among the certificates that are enabled (and the Nafeza token), for one table badge.
  DateTime? get soonestCertificateExpiry => CertificateExpiry.soonest([
        if (hasWipo) wipoExpiry,
        if (hasEuipo) euipoExpiry,
        if (hasGlobalBrand) globalBrandExpiry,
        if (hasIso9001) iso9001Expiry,
      ]);

  Map<String, dynamic> toJson() {
    return {
      if (supplierId != null) 'supplier_id': supplierId,
      'supplier_code': supplierCode,
      'company_name': companyName,
      'supplier_type': supplierType,
      'registration_type': registrationType,
      'foreign_exporter_id': foreignExporterId,
      if (cargoxPlatformId != null) 'cargox_platform_id': cargoxPlatformId,
      if (taxId != null) 'tax_id': taxId,
      'currency': currency,
      'foreign_exporter_country': foreignExporterCountry,
      'foreign_exporter_country_code': foreignExporterCountryCode,
      if (city != null) 'city': city,
      if (postalCode != null) 'postal_code': postalCode,
      'address': address,
      if (contactPerson != null) 'contact_person': contactPerson,
      'phone': phone,
      'mobile': mobile,
      'fax': fax,
      'email': email,
      'secondary_email': secondaryEmail,
      'website': website,
      'bank_name': bankName,
      'swift_code': swiftCode,
      'account_number': accountNumber,
      'iban': iban,
      'has_iso': hasIso,
      'registered_decree_43': registeredDecree43,
      'white_list_registered': whiteListRegistered,
      'brands': brands,
      if (paymentTerms != null) 'payment_terms': paymentTerms,
      'credit_limit': creditLimit,
      'rating': rating,
      'notes': notes,
      'is_active': isActive,
      'has_wipo': hasWipo,
      'wipo_number': wipoNumber,
      'has_euipo': hasEuipo,
      'euipo_number': euipoNumber,
      'has_global_brand': hasGlobalBrand,
      'global_brand_number': globalBrandNumber,
      'has_iso_9001': hasIso9001,
      'iso_9001_number': iso9001Number,
      'wipo_expiry': CertificateExpiry.toJsonDate(wipoExpiry),
      'euipo_expiry': CertificateExpiry.toJsonDate(euipoExpiry),
      'global_brand_expiry': CertificateExpiry.toJsonDate(globalBrandExpiry),
      'iso_9001_expiry': CertificateExpiry.toJsonDate(iso9001Expiry),
    };
  }
}
