import '../../../core/utils/certificate_expiry.dart';
class ImportCompanyModel {
  final int? companyId;
  final String importerName;
  final String address;
  final String country;
  final String importerId;
  final DateTime importerIdExpiry;
  final String vatId;
  final DateTime vatIdExpiry;
  final String registrationNumber;
  final DateTime registrationExpiry;
  final String? phone;
  final String? mobile;
  final String? fax;
  final String? email;
  final String? secondaryEmail;
  final String? website;
  final String? nafezaToken;
  final bool hasNafezaToken;
  final String? maskedNafezaToken;
  final bool hasWipo;
  final String? wipoNumber;
  final bool hasEuipo;
  final String? euipoNumber;
  final bool hasGlobalBrand;
  final String? globalBrandNumber;
  final bool hasIso9001;
  final String? iso9001Number;
  final DateTime? nafezaTokenExpiry;
  final DateTime? wipoExpiry;
  final DateTime? euipoExpiry;
  final DateTime? globalBrandExpiry;
  final DateTime? iso9001Expiry;
  final bool isActive;
  final String? notes;

  int get daysUntilImporterIdExpiry => importerIdExpiry.difference(DateTime.now()).inDays;
  int get daysUntilVatExpiry => vatIdExpiry.difference(DateTime.now()).inDays;
  int get daysUntilRegExpiry => registrationExpiry.difference(DateTime.now()).inDays;

  String? get primaryEmail => email;
  String? get mobileNumber => mobile;
  String? get faxNumber => fax;

  ImportCompanyModel({
    this.companyId,
    required this.importerName,
    required this.address,
    required this.country,
    required this.importerId,
    required this.importerIdExpiry,
    required this.vatId,
    required this.vatIdExpiry,
    required this.registrationNumber,
    required this.registrationExpiry,
    this.phone,
    String? mobile,
    String? mobileNumber,
    String? fax,
    String? faxNumber,
    String? email,
    String? primaryEmail,
    this.secondaryEmail,
    this.website,
    this.nafezaToken,
    this.hasNafezaToken = false,
    this.maskedNafezaToken,
    this.hasWipo = false,
    this.wipoNumber,
    this.hasEuipo = false,
    this.euipoNumber,
    this.hasGlobalBrand = false,
    this.globalBrandNumber,
    this.hasIso9001 = false,
    this.iso9001Number,
    this.nafezaTokenExpiry,
    this.wipoExpiry,
    this.euipoExpiry,
    this.globalBrandExpiry,
    this.iso9001Expiry,
    this.isActive = true,
    this.notes,
  }) : mobile = mobile ?? mobileNumber,
       fax = fax ?? faxNumber,
       email = email ?? primaryEmail;

  factory ImportCompanyModel.fromJson(Map<String, dynamic> json) {
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

    final maskedToken = json['masked_nafeza_token']?.toString();
    final hasToken = parseBool(json['has_nafeza_token']) || (maskedToken != null && maskedToken.isNotEmpty);

    return ImportCompanyModel(
      companyId: json['company_id'] as int?,
      importerName: json['importer_name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      importerId: json['importer_id']?.toString() ?? '',
      importerIdExpiry: json['importer_id_expiry'] != null
          ? DateTime.tryParse(json['importer_id_expiry'].toString()) ?? DateTime.now()
          : DateTime.now(),
      vatId: json['vat_id']?.toString() ?? '',
      vatIdExpiry: json['vat_id_expiry'] != null
          ? DateTime.tryParse(json['vat_id_expiry'].toString()) ?? DateTime.now()
          : DateTime.now(),
      registrationNumber: json['registration_number']?.toString() ?? '',
      registrationExpiry: json['registration_expiry'] != null
          ? DateTime.tryParse(json['registration_expiry'].toString()) ?? DateTime.now()
          : DateTime.now(),
      phone: json['phone']?.toString(),
      mobile: json['mobile']?.toString(),
      fax: json['fax']?.toString(),
      email: json['email']?.toString(),
      secondaryEmail: json['secondary_email']?.toString(),
      website: json['website']?.toString(),
      hasNafezaToken: hasToken,
      maskedNafezaToken: maskedToken,
      nafezaToken: maskedToken ?? json['nafeza_token']?.toString(),
      hasWipo: parseBool(json['has_wipo']),
      wipoNumber: json['wipo_number']?.toString(),
      hasEuipo: parseBool(json['has_euipo']),
      euipoNumber: json['euipo_number']?.toString(),
      hasGlobalBrand: parseBool(json['has_global_brand']),
      globalBrandNumber: json['global_brand_number']?.toString(),
      hasIso9001: parseBool(json['has_iso_9001']),
      iso9001Number: json['iso_9001_number']?.toString(),
      nafezaTokenExpiry: CertificateExpiry.parse(json['nafeza_token_expiry']),
      wipoExpiry: CertificateExpiry.parse(json['wipo_expiry']),
      euipoExpiry: CertificateExpiry.parse(json['euipo_expiry']),
      globalBrandExpiry: CertificateExpiry.parse(json['global_brand_expiry']),
      iso9001Expiry: CertificateExpiry.parse(json['iso_9001_expiry']),
      isActive: parseBool(json['is_active'], defaultValue: true),
      notes: json['notes']?.toString(),
    );
  }

  /// Soonest expiry among the certificates that are enabled (and the Nafeza token), for one table badge.
  DateTime? get soonestCertificateExpiry => CertificateExpiry.soonest([
        nafezaTokenExpiry, if (hasWipo) wipoExpiry,
        if (hasEuipo) euipoExpiry,
        if (hasGlobalBrand) globalBrandExpiry,
        if (hasIso9001) iso9001Expiry,
      ]);

  Map<String, dynamic> toJson() {
    return {
      if (companyId != null) 'company_id': companyId,
      'importer_name': importerName,
      'address': address,
      'country': country,
      'importer_id': importerId,
      'importer_id_expiry': importerIdExpiry.toIso8601String().split('T')[0],
      'vat_id': vatId,
      'vat_id_expiry': vatIdExpiry.toIso8601String().split('T')[0],
      'registration_number': registrationNumber,
      'registration_expiry': registrationExpiry.toIso8601String().split('T')[0],
      'phone': phone,
      'mobile': mobile,
      'fax': fax,
      'email': email,
      'secondary_email': secondaryEmail,
      'website': website,
      if (nafezaToken != null && nafezaToken!.trim().isNotEmpty && !nafezaToken!.trim().startsWith('****'))
        'nafeza_token': nafezaToken!.trim(),
      'has_wipo': hasWipo,
      'wipo_number': wipoNumber,
      'has_euipo': hasEuipo,
      'euipo_number': euipoNumber,
      'has_global_brand': hasGlobalBrand,
      'global_brand_number': globalBrandNumber,
      'has_iso_9001': hasIso9001,
      'iso_9001_number': iso9001Number,
      'nafeza_token_expiry': CertificateExpiry.toJsonDate(nafezaTokenExpiry),
      'wipo_expiry': CertificateExpiry.toJsonDate(wipoExpiry),
      'euipo_expiry': CertificateExpiry.toJsonDate(euipoExpiry),
      'global_brand_expiry': CertificateExpiry.toJsonDate(globalBrandExpiry),
      'iso_9001_expiry': CertificateExpiry.toJsonDate(iso9001Expiry),
      'is_active': isActive,
      'notes': notes,
    };
  }
}
