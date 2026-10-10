import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import 'copyable_data_helper.dart';
import 'searchable_dropdown_field.dart';
import 'extraction_progress_dialog.dart';

enum EntityTarget {
  supplier,
  company,
  customsBroker,
  shippingLine,
  freightForwarder,
  inlandTransport,
  inspectionAgency,
  insuranceCompany,
  bank,
  partner,
}

class UniversalEntityExtractorDialog extends ConsumerStatefulWidget {
  final EntityTarget initialTarget;
  final bool lockTarget;
  final VoidCallback? onSaved;

  const UniversalEntityExtractorDialog({
    super.key,
    this.initialTarget = EntityTarget.supplier,
    this.lockTarget = false,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    EntityTarget initialTarget = EntityTarget.supplier,
    bool lockTarget = false,
    VoidCallback? onSaved,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UniversalEntityExtractorDialog(
        initialTarget: initialTarget,
        lockTarget: lockTarget,
        onSaved: onSaved,
      ),
    );
  }

  static Future<void> showSupplierExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.supplier, lockTarget: true, onSaved: onSaved);
  }

  static Future<void> showImporterExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.company, lockTarget: true, onSaved: onSaved);
  }

  static Future<void> showCustomsBrokerExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.customsBroker, lockTarget: true, onSaved: onSaved);
  }

  static Future<void> showShippingLineExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.shippingLine, lockTarget: true, onSaved: onSaved);
  }

  static Future<void> showFreightForwarderExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.freightForwarder, lockTarget: true, onSaved: onSaved);
  }

  static Future<void> showInlandTransportExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.inlandTransport, lockTarget: true, onSaved: onSaved);
  }

  static Future<void> showInspectionAgencyExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.inspectionAgency, lockTarget: true, onSaved: onSaved);
  }

  static Future<void> showInsuranceCompanyExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.insuranceCompany, lockTarget: true, onSaved: onSaved);
  }

  static Future<void> showBankExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.bank, lockTarget: true, onSaved: onSaved);
  }

  @override
  ConsumerState<UniversalEntityExtractorDialog> createState() => _UniversalEntityExtractorDialogState();
}

class _UniversalEntityExtractorDialogState extends ConsumerState<UniversalEntityExtractorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late EntityTarget _selectedTarget;
  int _inputModeTab = 0;
  bool _isExtracting = false;
  bool _isSaving = false;

  final TextEditingController _rawTextCtrl = TextEditingController();
  final TextEditingController _companyNameCtrl = TextEditingController();
  final TextEditingController _arabicNameCtrl = TextEditingController();
  final TextEditingController _contactPersonCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _secondaryEmailCtrl = TextEditingController();
  final TextEditingController _websiteCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _countryCtrl = TextEditingController();
  final TextEditingController _countryCodeCtrl = TextEditingController();

  final TextEditingController _cargoxIdCtrl = TextEditingController();
  final TextEditingController _foreignTaxIdCtrl = TextEditingController();
  final TextEditingController _brandsCtrl = TextEditingController();
  final TextEditingController _faxCtrl = TextEditingController();
  final TextEditingController _bankNameCtrl = TextEditingController();
  final TextEditingController _accountNumberCtrl = TextEditingController();
  final TextEditingController _ibanCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  String _supplierType = 'Manufacturer';
  String _supplierRegType = 'Factory Registration';
  bool _hasIso = false;
  bool _registeredDecree43 = false;
  bool _whiteListRegistered = false;

  final TextEditingController _taxIdCtrl = TextEditingController();
  final TextEditingController _commercialRegisterCtrl = TextEditingController();
  final TextEditingController _importerCardCtrl = TextEditingController();
  final TextEditingController _nafezaTokenCtrl = TextEditingController();
  bool _showNafezaToken = false;
  DateTime _importerIdExpiry = DateTime.now().add(const Duration(days: 365));
  DateTime _vatIdExpiry = DateTime.now().add(const Duration(days: 365 * 3));
  DateTime _registrationExpiry = DateTime.now().add(const Duration(days: 365 * 2));

  final TextEditingController _brokerLicenseCtrl = TextEditingController();
  final TextEditingController _portsCtrl = TextEditingController();
  final TextEditingController _scacCodeCtrl = TextEditingController();
  final TextEditingController _trackingUrlCtrl = TextEditingController();
  final TextEditingController _servicesScopeCtrl = TextEditingController();
  final TextEditingController _fleetTypesCtrl = TextEditingController();
  final TextEditingController _inspectionScopeCtrl = TextEditingController();
  final TextEditingController _policyTermsCtrl = TextEditingController();

  final TextEditingController _swiftCodeCtrl = TextEditingController();
  final TextEditingController _branchNameCtrl = TextEditingController();
  final TextEditingController _bankAccountCtrl = TextEditingController();

  // Trademark & Quality Certificates
  bool _hasWipo = false;
  final TextEditingController _wipoNumberCtrl = TextEditingController();
  bool _hasEuipo = false;
  final TextEditingController _euipoNumberCtrl = TextEditingController();
  bool _hasGlobalBrand = false;
  final TextEditingController _globalBrandNumberCtrl = TextEditingController();
  bool _hasIso9001 = false;
  final TextEditingController _iso9001NumberCtrl = TextEditingController();

  // Freight Forwarder Financial & Credit Conditions
  final TextEditingController _defaultFreeDaysCtrl = TextEditingController();
  final TextEditingController _paymentTermsCtrl = TextEditingController();
  final TextEditingController _creditLimitCtrl = TextEditingController();

  double _confidenceScore = 0.0;
  String? _selectedFileName;

  final List<Map<String, String>> _countryList = [
    {'name': 'China (CN)', 'code': 'CN'},
    {'name': 'Egypt (EG)', 'code': 'EG'},
    {'name': 'United States (US)', 'code': 'US'},
    {'name': 'Germany (DE)', 'code': 'DE'},
    {'name': 'Italy (IT)', 'code': 'IT'},
    {'name': 'Turkey (TR)', 'code': 'TR'},
    {'name': 'United Arab Emirates (AE)', 'code': 'AE'},
    {'name': 'Saudi Arabia (SA)', 'code': 'SA'},
    {'name': 'India (IN)', 'code': 'IN'},
    {'name': 'United Kingdom (GB)', 'code': 'GB'},
    {'name': 'Spain (ES)', 'code': 'ES'},
    {'name': 'France (FR)', 'code': 'FR'},
    {'name': 'Japan (JP)', 'code': 'JP'},
    {'name': 'South Korea (KR)', 'code': 'KR'},
    {'name': 'Russia (RU)', 'code': 'RU'},
    {'name': 'Brazil (BR)', 'code': 'BR'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedTarget = widget.initialTarget;
    _setupInitialDefaults();
  }

  void _setupInitialDefaults() {
    // Keep controllers empty for clean state
  }

  @override
  void dispose() {
    _rawTextCtrl.dispose();
    _companyNameCtrl.dispose();
    _arabicNameCtrl.dispose();
    _contactPersonCtrl.dispose();
    _phoneCtrl.dispose();
    _mobileCtrl.dispose();
    _faxCtrl.dispose();
    _emailCtrl.dispose();
    _secondaryEmailCtrl.dispose();
    _websiteCtrl.dispose();
    _addressCtrl.dispose();
    _countryCtrl.dispose();
    _countryCodeCtrl.dispose();
    _cargoxIdCtrl.dispose();
    _foreignTaxIdCtrl.dispose();
    _brandsCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ibanCtrl.dispose();
    _notesCtrl.dispose();
    _taxIdCtrl.dispose();
    _commercialRegisterCtrl.dispose();
    _importerCardCtrl.dispose();
    _nafezaTokenCtrl.dispose();
    _brokerLicenseCtrl.dispose();
    _portsCtrl.dispose();
    _scacCodeCtrl.dispose();
    _trackingUrlCtrl.dispose();
    _servicesScopeCtrl.dispose();
    _fleetTypesCtrl.dispose();
    _inspectionScopeCtrl.dispose();
    _policyTermsCtrl.dispose();
    _swiftCodeCtrl.dispose();
    _branchNameCtrl.dispose();
    _bankAccountCtrl.dispose();
    _wipoNumberCtrl.dispose();
    _euipoNumberCtrl.dispose();
    _globalBrandNumberCtrl.dispose();
    _iso9001NumberCtrl.dispose();
    _defaultFreeDaysCtrl.dispose();
    _paymentTermsCtrl.dispose();
    _creditLimitCtrl.dispose();
    super.dispose();
  }

  String _targetName(BuildContext context, EntityTarget t) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    switch (t) {
      case EntityTarget.supplier:
        return isArabic ? 'المورد الأجنبي' : 'Foreign Supplier';
      case EntityTarget.company:
        return isArabic ? 'الشركة المستوردة' : 'Importing Company';
      case EntityTarget.customsBroker:
        return isArabic ? 'المخلص الجمركي' : 'Customs Broker';
      case EntityTarget.shippingLine:
        return isArabic ? 'الخط الملاحي' : 'Shipping Line';
      case EntityTarget.freightForwarder:
        return isArabic ? 'شركة الشحن الدولي' : 'Freight Forwarder';
      case EntityTarget.inlandTransport:
        return isArabic ? 'الناقل البري' : 'Inland Transport';
      case EntityTarget.inspectionAgency:
        return isArabic ? 'جهة الفحص والمعاينة' : 'Inspection Agency';
      case EntityTarget.insuranceCompany:
        return isArabic ? 'شركة التأمين' : 'Insurance Company';
      case EntityTarget.bank:
        return isArabic ? 'البنك المصرفي' : 'Authorized Bank';
      case EntityTarget.partner:
        return isArabic ? 'الشريك اللوجستي' : 'Logistics Partner';
    }
  }

  String _getModuleForTarget(EntityTarget t) {
    switch (t) {
      case EntityTarget.supplier:
        return 'supplier-entity';
      case EntityTarget.company:
        return 'import-company-entity';
      case EntityTarget.customsBroker:
        return 'customs-broker-entity';
      case EntityTarget.shippingLine:
        return 'shipping-line-entity';
      case EntityTarget.freightForwarder:
        return 'freight-forwarder-entity';
      case EntityTarget.inlandTransport:
        return 'inland-transport-entity';
      case EntityTarget.inspectionAgency:
        return 'inspection-agency-entity';
      case EntityTarget.insuranceCompany:
        return 'insurance-company-entity';
      case EntityTarget.bank:
        return 'bank-entity';
      case EntityTarget.partner:
        return 'partner-entity';
    }
  }

  Future<void> _extractFromRawText() async {
    final text = _rawTextCtrl.text.trim();
    if (text.isEmpty) return;

    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final progressCtrl = ExtractionProgressController();
    progressCtrl.update(
      percent: 0.15,
      status: isArabic ? 'جاري فحص النص وتحليل الحقول التخصصية...' : 'Analyzing text and extracting specialized fields...',
      stepLabel: isArabic ? 'المرحلة 1 من 4: تحليل النص' : 'Step 1 of 4: Text Analysis',
      currentStep: 1,
    );

    setState(() => _isExtracting = true);

    if (mounted) {
      ExtractionProgressDialog.show(
        context: context,
        title: isArabic
            ? 'جاري استخراج بيانات ${_targetName(context, _selectedTarget)}'
            : 'Extracting ${_targetName(context, _selectedTarget)} Profile',
        fileName: isArabic ? 'النص المنسوخ (${text.length} حرف)' : 'Pasted Text (${text.length} characters)',
        controller: progressCtrl,
      );
    }

    try {
      final dio = ref.read(uploadDioProvider);
      final formData = FormData.fromMap({'raw_text': text});
      final moduleName = _getModuleForTarget(_selectedTarget);
      final resp = await dio.post(
        '${ApiConstants.baseUrl}/smart-upload/parse-text/$moduleName',
        data: formData,
      );

      progressCtrl.complete();
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (resp.statusCode == 200 && resp.data != null) {
        final extracted = resp.data['extracted_fields'] as Map<String, dynamic>? ?? {};
        final score = (resp.data['confidence_score'] as num?)?.toDouble() ?? 0.85;
        _populateFields(extracted, score);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        final isArabic = Directionality.of(context) == TextDirection.rtl;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'خطأ في استخراج البيانات: $e' : 'Extraction Error: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _pickAndExtractFile() async {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'bmp', 'tiff', 'xlsx', 'xls', 'docx', 'doc', 'txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      setState(() => _selectedFileName = file.name);

      final progressCtrl = ExtractionProgressController();
      progressCtrl.update(
        percent: 0.2,
        status: isArabic ? 'جاري قراءة الملف ومعالجة المستند...' : 'Reading file and processing document...',
        stepLabel: isArabic ? 'المرحلة 1 من 4: قراءة المستند' : 'Step 1 of 4: Document Reading',
        currentStep: 1,
      );

      if (mounted) {
        ExtractionProgressDialog.show(
          context: context,
          title: isArabic
              ? 'جاري استخراج بيانات ${_targetName(context, _selectedTarget)}'
              : 'Extracting ${_targetName(context, _selectedTarget)} Profile',
          fileName: file.name,
          controller: progressCtrl,
        );
      }

      setState(() => _isExtracting = true);

      final dio = ref.read(uploadDioProvider);
      final moduleName = _getModuleForTarget(_selectedTarget);
      FormData formData;

      if (file.bytes != null) {
        formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
        });
      } else if (file.path != null) {
        formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path!, filename: file.name),
        });
      } else {
        throw Exception('Unable to read file content');
      }

      final resp = await dio.post(
        '${ApiConstants.baseUrl}/smart-upload/upload/$moduleName',
        data: formData,
      );

      progressCtrl.complete();
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (resp.statusCode == 200 && resp.data != null) {
        final extracted = resp.data['extracted_fields'] as Map<String, dynamic>? ?? {};
        final score = (resp.data['confidence_score'] as num?)?.toDouble() ?? 0.90;
        _populateFields(extracted, score);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'خطأ في معالجة واستخراج الملف: $e' : 'File Processing Error: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  DateTime? _tryParseDate(dynamic val) {
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

  void _populateFields(Map<String, dynamic> ext, double score) {
    setState(() {
      _confidenceScore = score;

      if (ext['company_name'] != null && ext['company_name'].toString().isNotEmpty) {
        _companyNameCtrl.text = ext['company_name'].toString();
      } else if (ext['name_en'] != null && ext['name_en'].toString().isNotEmpty) {
        _companyNameCtrl.text = ext['name_en'].toString();
      } else if (ext['partner_name'] != null && ext['partner_name'].toString().isNotEmpty) {
        _companyNameCtrl.text = ext['partner_name'].toString();
      }

      if (ext['arabic_name'] != null && ext['arabic_name'].toString().isNotEmpty) {
        _arabicNameCtrl.text = ext['arabic_name'].toString();
      } else if (ext['name_ar'] != null && ext['name_ar'].toString().isNotEmpty) {
        _arabicNameCtrl.text = ext['name_ar'].toString();
      }

      if (ext['contact_person'] != null) {
        _contactPersonCtrl.text = ext['contact_person'].toString();
      } else if (ext['manager'] != null) {
        _contactPersonCtrl.text = ext['manager'].toString();
      } else if (ext['legal_representative'] != null) {
        _contactPersonCtrl.text = ext['legal_representative'].toString();
      }
      if (ext['phone'] != null) {
        _phoneCtrl.text = ext['phone'].toString();
      } else if (ext['phone_number'] != null) {
        _phoneCtrl.text = ext['phone_number'].toString();
      }
      if (ext['mobile'] != null) {
        _mobileCtrl.text = ext['mobile'].toString();
      } else if (ext['mobile_number'] != null) {
        _mobileCtrl.text = ext['mobile_number'].toString();
      }
      if (ext['fax'] != null) {
        _faxCtrl.text = ext['fax'].toString();
      } else if (ext['fax_number'] != null) {
        _faxCtrl.text = ext['fax_number'].toString();
      }
      if (ext['email'] != null) _emailCtrl.text = ext['email'].toString();
      if (ext['secondary_email'] != null) _secondaryEmailCtrl.text = ext['secondary_email'].toString();
      if (ext['website'] != null) _websiteCtrl.text = ext['website'].toString();
      if (ext['address'] != null) _addressCtrl.text = ext['address'].toString();

      if (ext['country'] != null && ext['country'].toString().isNotEmpty) {
        final c = ext['country'].toString();
        _countryCtrl.text = c;
        final match = _countryList.firstWhere(
          (item) => item['name']!.toLowerCase().contains(c.toLowerCase()) || item['code']!.toLowerCase() == c.toLowerCase(),
          orElse: () => {'name': c, 'code': 'CN'},
        );
        _countryCodeCtrl.text = match['code']!;
      } else if (ext['country_code'] != null && ext['country_code'].toString().isNotEmpty) {
        final code = ext['country_code'].toString().toUpperCase();
        final match = _countryList.firstWhere(
          (item) => item['code']!.toUpperCase() == code,
          orElse: () => {'name': code, 'code': code},
        );
        _countryCtrl.text = match['name']!;
        _countryCodeCtrl.text = match['code']!;
      }

      if (ext['cargox_id'] != null) {
        _cargoxIdCtrl.text = ext['cargox_id'].toString();
      } else if (ext['cargox_platform_id'] != null) {
        _cargoxIdCtrl.text = ext['cargox_platform_id'].toString();
      }
      if (ext['foreign_exporter_id'] != null) {
        _foreignTaxIdCtrl.text = ext['foreign_exporter_id'].toString();
      } else if (ext['foreign_tax_id'] != null) {
        _foreignTaxIdCtrl.text = ext['foreign_tax_id'].toString();
      } else if (ext['vat_tax_id'] != null) {
        _foreignTaxIdCtrl.text = ext['vat_tax_id'].toString();
      }
      if (ext['brands'] != null) _brandsCtrl.text = ext['brands'].toString();
      if (ext['supplier_type'] != null && ext['supplier_type'].toString().isNotEmpty) {
        _supplierType = ext['supplier_type'].toString();
      }
      if (ext['registration_type'] != null && ext['registration_type'].toString().isNotEmpty) {
        _supplierRegType = ext['registration_type'].toString();
      } else if (ext['supplier_registration_type'] != null && ext['supplier_registration_type'].toString().isNotEmpty) {
        _supplierRegType = ext['supplier_registration_type'].toString();
      }

      if (ext['vat_id'] != null) {
        _taxIdCtrl.text = ext['vat_id'].toString();
      } else if (ext['tax_id'] != null) {
        _taxIdCtrl.text = ext['tax_id'].toString();
      } else if (ext['vat_tax_id'] != null) {
        _taxIdCtrl.text = ext['vat_tax_id'].toString();
      }
      if (ext['registration_number'] != null) {
        _commercialRegisterCtrl.text = ext['registration_number'].toString();
      } else if (ext['commercial_register'] != null) {
        _commercialRegisterCtrl.text = ext['commercial_register'].toString();
      }
      if (ext['importer_id'] != null) {
        _importerCardCtrl.text = ext['importer_id'].toString();
      } else if (ext['importer_card_number'] != null) {
        _importerCardCtrl.text = ext['importer_card_number'].toString();
      }
      if (ext['nafeza_token_id'] != null) {
        _nafezaTokenCtrl.text = ext['nafeza_token_id'].toString();
      } else if (ext['nafeza_token'] != null) {
        _nafezaTokenCtrl.text = ext['nafeza_token'].toString();
      }

      if (ext['importer_id_expiry'] != null) {
        final d = _tryParseDate(ext['importer_id_expiry']);
        if (d != null) _importerIdExpiry = d;
      }
      if (ext['vat_id_expiry'] != null) {
        final d = _tryParseDate(ext['vat_id_expiry']);
        if (d != null) _vatIdExpiry = d;
      }
      if (ext['registration_expiry'] != null) {
        final d = _tryParseDate(ext['registration_expiry']);
        if (d != null) _registrationExpiry = d;
      }

      if (ext['clearance_license_number'] != null) {
        _brokerLicenseCtrl.text = ext['clearance_license_number'].toString();
      } else if (ext['license_number'] != null) {
        _brokerLicenseCtrl.text = ext['license_number'].toString();
      } else if (ext['transport_license_number'] != null) {
        _brokerLicenseCtrl.text = ext['transport_license_number'].toString();
      } else if (ext['inspection_accreditation_number'] != null) {
        _brokerLicenseCtrl.text = ext['inspection_accreditation_number'].toString();
      } else if (ext['insurance_license_number'] != null) {
        _brokerLicenseCtrl.text = ext['insurance_license_number'].toString();
      } else if (ext['fiata_id'] != null) {
        _brokerLicenseCtrl.text = ext['fiata_id'].toString();
      }

      if (ext['ports'] != null) {
        _portsCtrl.text = ext['ports'].toString();
      } else if (ext['authorized_ports'] != null) {
        _portsCtrl.text = ext['authorized_ports'].toString();
      }
      if (ext['scac_code'] != null) _scacCodeCtrl.text = ext['scac_code'].toString();
      if (ext['tracking_url'] != null) _trackingUrlCtrl.text = ext['tracking_url'].toString();
      if (ext['services_scope'] != null) {
        _servicesScopeCtrl.text = ext['services_scope'].toString();
      } else if (ext['shipping_modes'] != null) {
        _servicesScopeCtrl.text = ext['shipping_modes'].toString();
      }
      if (ext['fleet_types'] != null) _fleetTypesCtrl.text = ext['fleet_types'].toString();
      if (ext['inspection_scope'] != null) _inspectionScopeCtrl.text = ext['inspection_scope'].toString();
      if (ext['policy_terms'] != null) {
        _policyTermsCtrl.text = ext['policy_terms'].toString();
      } else if (ext['insurance_terms'] != null) {
        _policyTermsCtrl.text = ext['insurance_terms'].toString();
      } else if (ext['insurance_coverage_types'] != null) {
        _policyTermsCtrl.text = ext['insurance_coverage_types'].toString();
      }

      if (ext['swift_code'] != null) _swiftCodeCtrl.text = ext['swift_code'].toString();
      if (ext['bank_name'] != null) _bankNameCtrl.text = ext['bank_name'].toString();
      if (ext['branch_name'] != null) _branchNameCtrl.text = ext['branch_name'].toString();
      if (ext['bank_account'] != null) {
        _bankAccountCtrl.text = ext['bank_account'].toString();
        _accountNumberCtrl.text = ext['bank_account'].toString();
      } else if (ext['account_number'] != null) {
        _bankAccountCtrl.text = ext['account_number'].toString();
        _accountNumberCtrl.text = ext['account_number'].toString();
      }
      if (ext['iban'] != null) _ibanCtrl.text = ext['iban'].toString();
      if (ext['notes'] != null) _notesCtrl.text = ext['notes'].toString();
      if (ext['has_iso'] != null) _hasIso = ext['has_iso'] == true || ext['has_iso'] == 'true';
      if (ext['registered_decree_43'] != null) _registeredDecree43 = ext['registered_decree_43'] == true || ext['registered_decree_43'] == 'true';
      if (ext['white_list_registered'] != null) _whiteListRegistered = ext['white_list_registered'] == true || ext['white_list_registered'] == 'true';

      // Trademark & Quality Certificates
      if (ext['has_wipo'] != null) _hasWipo = ext['has_wipo'] == true || ext['has_wipo'] == 'true';
      if (ext['wipo_number'] != null) _wipoNumberCtrl.text = ext['wipo_number'].toString();
      if (ext['has_euipo'] != null) _hasEuipo = ext['has_euipo'] == true || ext['has_euipo'] == 'true';
      if (ext['euipo_number'] != null) _euipoNumberCtrl.text = ext['euipo_number'].toString();
      if (ext['has_global_brand'] != null) _hasGlobalBrand = ext['has_global_brand'] == true || ext['has_global_brand'] == 'true';
      if (ext['global_brand_number'] != null) _globalBrandNumberCtrl.text = ext['global_brand_number'].toString();
      if (ext['has_iso_9001'] != null) _hasIso9001 = ext['has_iso_9001'] == true || ext['has_iso_9001'] == 'true';
      if (ext['iso_9001_number'] != null) _iso9001NumberCtrl.text = ext['iso_9001_number'].toString();

      // Freight Forwarder Financial & Credit
      if (ext['default_free_days'] != null) _defaultFreeDaysCtrl.text = ext['default_free_days'].toString();
      if (ext['payment_terms'] != null) _paymentTermsCtrl.text = ext['payment_terms'].toString();
      if (ext['credit_limit'] != null) _creditLimitCtrl.text = ext['credit_limit'].toString();
    });
  }

  Future<void> _saveEntityToDatabase() async {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final name = _companyNameCtrl.text.trim();
    final arabicName = _arabicNameCtrl.text.trim();
    final effectiveName = name.isNotEmpty ? name : arabicName;

    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    if (effectiveName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'اسم الكيان أو الشركة مطلوب لإتمام الحفظ والتسجيل' : 'Entity / Company name is required.'),
          backgroundColor: AppTheme.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final dio = ref.read(dioProvider);
      String endpoint = '${ApiConstants.baseUrl}/suppliers';
      Map<String, dynamic> payload = {};

      switch (_selectedTarget) {
        case EntityTarget.supplier:
          endpoint = '${ApiConstants.baseUrl}/suppliers';
          payload = {
            'company_name': effectiveName,
            'supplier_type': _supplierType,
            'registration_type': _supplierRegType,
            'foreign_exporter_id': _foreignTaxIdCtrl.text.trim().isNotEmpty ? _foreignTaxIdCtrl.text.trim() : 'EXP-${DateTime.now().millisecondsSinceEpoch}',
            'cargox_platform_id': _cargoxIdCtrl.text.trim().isNotEmpty ? _cargoxIdCtrl.text.trim() : null,
            'foreign_exporter_country': _countryCtrl.text.trim(),
            'foreign_exporter_country_code': _countryCodeCtrl.text.trim(),
            'address': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : 'Foreign Address',
            'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            'mobile': _mobileCtrl.text.trim().isNotEmpty ? _mobileCtrl.text.trim() : null,
            'fax': _faxCtrl.text.trim().isNotEmpty ? _faxCtrl.text.trim() : null,
            'email': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
            'secondary_email': _secondaryEmailCtrl.text.trim().isNotEmpty ? _secondaryEmailCtrl.text.trim() : null,
            'website': _websiteCtrl.text.trim().isNotEmpty ? _websiteCtrl.text.trim() : null,
            'bank_name': _bankNameCtrl.text.trim().isNotEmpty ? _bankNameCtrl.text.trim() : null,
            'swift_code': _swiftCodeCtrl.text.trim().isNotEmpty ? _swiftCodeCtrl.text.trim() : null,
            'account_number': (_accountNumberCtrl.text.trim().isNotEmpty ? _accountNumberCtrl.text.trim() : (_bankAccountCtrl.text.trim().isNotEmpty ? _bankAccountCtrl.text.trim() : null)),
            'iban': _ibanCtrl.text.trim().isNotEmpty ? _ibanCtrl.text.trim() : null,
            'has_iso': _hasIso,
            'registered_decree_43': _registeredDecree43,
            'white_list_registered': _whiteListRegistered,
            'brands': _brandsCtrl.text.trim().isNotEmpty ? _brandsCtrl.text.trim() : null,
            'has_wipo': _hasWipo,
            'wipo_number': _hasWipo && _wipoNumberCtrl.text.trim().isNotEmpty ? _wipoNumberCtrl.text.trim() : null,
            'has_euipo': _hasEuipo,
            'euipo_number': _hasEuipo && _euipoNumberCtrl.text.trim().isNotEmpty ? _euipoNumberCtrl.text.trim() : null,
            'has_global_brand': _hasGlobalBrand,
            'global_brand_number': _hasGlobalBrand && _globalBrandNumberCtrl.text.trim().isNotEmpty ? _globalBrandNumberCtrl.text.trim() : null,
            'has_iso_9001': _hasIso9001,
            'iso_9001_number': _hasIso9001 && _iso9001NumberCtrl.text.trim().isNotEmpty ? _iso9001NumberCtrl.text.trim() : null,
            'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          };
          break;

        case EntityTarget.company:
          endpoint = '${ApiConstants.baseUrl}/import-companies';
          final notesParts = <String>[];
          if (_contactPersonCtrl.text.trim().isNotEmpty) notesParts.add('Manager: ${_contactPersonCtrl.text.trim()}');
          if (_bankNameCtrl.text.trim().isNotEmpty) notesParts.add('Bank: ${_bankNameCtrl.text.trim()}');
          if (_swiftCodeCtrl.text.trim().isNotEmpty) notesParts.add('SWIFT: ${_swiftCodeCtrl.text.trim()}');
          if (_accountNumberCtrl.text.trim().isNotEmpty) notesParts.add('Account: ${_accountNumberCtrl.text.trim()}');
          if (_ibanCtrl.text.trim().isNotEmpty) notesParts.add('IBAN: ${_ibanCtrl.text.trim()}');
          if (_notesCtrl.text.trim().isNotEmpty) notesParts.add(_notesCtrl.text.trim());

          payload = {
            'importer_name': effectiveName,
            'address': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : 'Cairo, Egypt',
            'country': _countryCtrl.text.trim().isNotEmpty ? _countryCtrl.text.trim() : 'Egypt',
            'importer_id': _importerCardCtrl.text.trim().isNotEmpty ? _importerCardCtrl.text.trim() : 'IMP-${DateTime.now().millisecondsSinceEpoch}',
            'importer_id_expiry': '${_importerIdExpiry.year}-${_importerIdExpiry.month.toString().padLeft(2, '0')}-${_importerIdExpiry.day.toString().padLeft(2, '0')}',
            'vat_id': _taxIdCtrl.text.trim().isNotEmpty ? _taxIdCtrl.text.trim() : '000000000',
            'vat_id_expiry': '${_vatIdExpiry.year}-${_vatIdExpiry.month.toString().padLeft(2, '0')}-${_vatIdExpiry.day.toString().padLeft(2, '0')}',
            'registration_number': _commercialRegisterCtrl.text.trim().isNotEmpty ? _commercialRegisterCtrl.text.trim() : '000000',
            'registration_expiry': '${_registrationExpiry.year}-${_registrationExpiry.month.toString().padLeft(2, '0')}-${_registrationExpiry.day.toString().padLeft(2, '0')}',
            'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            'mobile': _mobileCtrl.text.trim().isNotEmpty ? _mobileCtrl.text.trim() : null,
            'fax': _faxCtrl.text.trim().isNotEmpty ? _faxCtrl.text.trim() : null,
            'email': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
            'secondary_email': _secondaryEmailCtrl.text.trim().isNotEmpty ? _secondaryEmailCtrl.text.trim() : null,
            'website': _websiteCtrl.text.trim().isNotEmpty ? _websiteCtrl.text.trim() : null,
            'nafeza_token': _nafezaTokenCtrl.text.trim().isNotEmpty ? _nafezaTokenCtrl.text.trim() : null,
            'has_wipo': _hasWipo,
            'wipo_number': _hasWipo && _wipoNumberCtrl.text.trim().isNotEmpty ? _wipoNumberCtrl.text.trim() : null,
            'has_euipo': _hasEuipo,
            'euipo_number': _hasEuipo && _euipoNumberCtrl.text.trim().isNotEmpty ? _euipoNumberCtrl.text.trim() : null,
            'has_global_brand': _hasGlobalBrand,
            'global_brand_number': _hasGlobalBrand && _globalBrandNumberCtrl.text.trim().isNotEmpty ? _globalBrandNumberCtrl.text.trim() : null,
            'has_iso_9001': _hasIso9001,
            'iso_9001_number': _hasIso9001 && _iso9001NumberCtrl.text.trim().isNotEmpty ? _iso9001NumberCtrl.text.trim() : null,
            'notes': notesParts.isNotEmpty ? notesParts.join(' | ') : null,
          };
          break;

        case EntityTarget.customsBroker:
          endpoint = '${ApiConstants.baseUrl}/external-service-providers';
          payload = {
            'partner_name': effectiveName,
            'partner_type': 'Customs Broker',
            'clearance_license_number': _brokerLicenseCtrl.text.trim().isNotEmpty ? _brokerLicenseCtrl.text.trim() : null,
            'authorized_ports': _portsCtrl.text.trim().isNotEmpty ? _portsCtrl.text.trim() : null,
            'tax_id': _taxIdCtrl.text.trim().isNotEmpty ? _taxIdCtrl.text.trim() : null,
            'commercial_register': _commercialRegisterCtrl.text.trim().isNotEmpty ? _commercialRegisterCtrl.text.trim() : null,
            'contact_person': _contactPersonCtrl.text.trim().isNotEmpty ? _contactPersonCtrl.text.trim() : null,
            'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            'mobile': _mobileCtrl.text.trim().isNotEmpty ? _mobileCtrl.text.trim() : null,
            'email': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
            'website': _websiteCtrl.text.trim().isNotEmpty ? _websiteCtrl.text.trim() : null,
            'address': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : 'Egypt',
            'country': 'Egypt',
            'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          };
          break;

        case EntityTarget.shippingLine:
          endpoint = '${ApiConstants.baseUrl}/external-service-providers';
          final scac = _scacCodeCtrl.text.trim().toUpperCase();
          payload = {
            'partner_name': effectiveName,
            'partner_type': 'Shipping Line',
            'scac_code': scac.isNotEmpty ? scac : 'LINE',
            'tracking_url': _trackingUrlCtrl.text.trim().isNotEmpty ? _trackingUrlCtrl.text.trim() : null,
            'website': _websiteCtrl.text.trim().isNotEmpty ? _websiteCtrl.text.trim() : null,
            'email': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
            'secondary_email': _secondaryEmailCtrl.text.trim().isNotEmpty ? _secondaryEmailCtrl.text.trim() : null,
            'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            'address': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : 'Egypt',
            'country': _countryCtrl.text.trim().isNotEmpty ? _countryCtrl.text.trim() : 'Egypt',
            'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          };
          break;

        case EntityTarget.freightForwarder:
          endpoint = '${ApiConstants.baseUrl}/external-service-providers';
          payload = {
            'partner_name': effectiveName,
            'partner_type': 'Freight Forwarder',
            'commercial_register': _commercialRegisterCtrl.text.trim().isNotEmpty ? _commercialRegisterCtrl.text.trim() : null,
            'fiata_id': _brokerLicenseCtrl.text.trim().isNotEmpty ? _brokerLicenseCtrl.text.trim() : null,
            'shipping_modes': _servicesScopeCtrl.text.trim().isNotEmpty ? _servicesScopeCtrl.text.trim() : null,
            'contact_person': _contactPersonCtrl.text.trim().isNotEmpty ? _contactPersonCtrl.text.trim() : null,
            'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            'email': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
            'secondary_email': _secondaryEmailCtrl.text.trim().isNotEmpty ? _secondaryEmailCtrl.text.trim() : null,
            'website': _websiteCtrl.text.trim().isNotEmpty ? _websiteCtrl.text.trim() : null,
            'address': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : 'Egypt',
            'country': 'Egypt',
            'default_free_days': int.tryParse(_defaultFreeDaysCtrl.text.trim()),
            'payment_terms': _paymentTermsCtrl.text.trim().isNotEmpty ? _paymentTermsCtrl.text.trim() : null,
            'credit_limit': double.tryParse(_creditLimitCtrl.text.trim()) ?? 0.0,
            'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          };
          break;

        case EntityTarget.inlandTransport:
          endpoint = '${ApiConstants.baseUrl}/external-service-providers';
          payload = {
            'partner_name': effectiveName,
            'partner_type': 'Inland Transport',
            'transport_license_number': _brokerLicenseCtrl.text.trim().isNotEmpty ? _brokerLicenseCtrl.text.trim() : null,
            'fleet_types': _fleetTypesCtrl.text.trim().isNotEmpty ? _fleetTypesCtrl.text.trim() : null,
            'coverage_areas': _portsCtrl.text.trim().isNotEmpty ? _portsCtrl.text.trim() : null,
            'contact_person': _contactPersonCtrl.text.trim().isNotEmpty ? _contactPersonCtrl.text.trim() : null,
            'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            'mobile': _mobileCtrl.text.trim().isNotEmpty ? _mobileCtrl.text.trim() : null,
            'email': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
            'address': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : 'Egypt Hub',
            'country': 'Egypt',
            'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          };
          break;

        case EntityTarget.inspectionAgency:
          endpoint = '${ApiConstants.baseUrl}/external-service-providers';
          payload = {
            'partner_name': effectiveName,
            'partner_type': 'Inspection Agency',
            'inspection_accreditation_number': _brokerLicenseCtrl.text.trim().isNotEmpty ? _brokerLicenseCtrl.text.trim() : null,
            'inspection_scope': _inspectionScopeCtrl.text.trim().isNotEmpty ? _inspectionScopeCtrl.text.trim() : null,
            'contact_person': _contactPersonCtrl.text.trim().isNotEmpty ? _contactPersonCtrl.text.trim() : null,
            'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            'email': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
            'website': _websiteCtrl.text.trim().isNotEmpty ? _websiteCtrl.text.trim() : null,
            'address': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : 'Egypt Hub',
            'country': 'Egypt',
            'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          };
          break;

        case EntityTarget.insuranceCompany:
          endpoint = '${ApiConstants.baseUrl}/external-service-providers';
          payload = {
            'partner_name': effectiveName,
            'partner_type': 'Insurance Company',
            'insurance_license_number': _brokerLicenseCtrl.text.trim().isNotEmpty ? _brokerLicenseCtrl.text.trim() : null,
            'insurance_coverage_types': _policyTermsCtrl.text.trim().isNotEmpty ? _policyTermsCtrl.text.trim() : null,
            'contact_person': _contactPersonCtrl.text.trim().isNotEmpty ? _contactPersonCtrl.text.trim() : null,
            'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            'email': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
            'website': _websiteCtrl.text.trim().isNotEmpty ? _websiteCtrl.text.trim() : null,
            'address': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : 'Egypt HQ',
            'country': 'Egypt',
            'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          };
          break;

        case EntityTarget.bank:
          endpoint = '${ApiConstants.baseUrl}/external-service-providers';
          final swift = _swiftCodeCtrl.text.trim();
          payload = {
            'partner_name': effectiveName,
            'partner_type': 'Bank',
            'swift_code': swift.isNotEmpty ? swift : 'BANK-EG-SWIFT',
            'bank_code': swift.length >= 4 ? swift.substring(0, 4) : 'BNK-001',
            'branch_name': _branchNameCtrl.text.trim().isNotEmpty ? _branchNameCtrl.text.trim() : 'Main Branch',
            'contact_person': _contactPersonCtrl.text.trim().isNotEmpty ? _contactPersonCtrl.text.trim() : null,
            'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            'email': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
            'address': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
            'country': 'Egypt',
            'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          };
          break;

        case EntityTarget.partner:
          endpoint = '${ApiConstants.baseUrl}/external-service-providers';
          payload = {
            'partner_name': effectiveName,
            'partner_type': 'Freight Forwarder',
            'contact_person': _contactPersonCtrl.text.trim().isNotEmpty ? _contactPersonCtrl.text.trim() : null,
            'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            'email': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
            'address': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
            'country': 'Egypt',
            'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          };
          break;
      }

      await dio.post(endpoint, data: payload);

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'تم تكويد وحفظ ${_targetName(context, _selectedTarget)} "$effectiveName" بنجاح'
                  : 'Successfully registered ${_targetName(context, _selectedTarget)} "$effectiveName"',
            ),
            backgroundColor: AppTheme.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        String msg = e.toString();
        if (e is DioException && e.response?.data != null) {
          msg = e.response?.data['detail']?.toString() ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'خطأ أثناء الحفظ: $msg' : 'Error saving record: $msg'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SelectionArea(
        child: Container(
          width: 1080,
          height: 720,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildDialogHeader(isArabic),
              if (!widget.lockTarget) _buildTargetSelectorBar(isArabic),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Side: Input (Raw Text or File Upload)
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: isArabic
                              ? BorderDirectional(start: BorderSide(color: Colors.grey.shade200))
                              : BorderDirectional(end: BorderSide(color: Colors.grey.shade200)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputModeSwitcher(isArabic),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _inputModeTab == 0 ? _buildRawTextInputArea(isArabic) : _buildFileUploadArea(isArabic),
                            ),
                            const SizedBox(height: 12),
                            _buildExtractActionButton(isArabic),
                          ],
                        ),
                      ),
                    ),

                    // Right Side: Extracted Structured Form
                    Expanded(
                      flex: 6,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(_getTargetIcon(_selectedTarget), color: AppTheme.cobalt, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isArabic
                                                ? 'بيانات تكويد ${_targetName(context, _selectedTarget)}'
                                                : '${_targetName(context, _selectedTarget)} Registration Profile',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.charcoal),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (_confidenceScore > 0) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _confidenceScore >= 0.8 ? AppTheme.emerald.withOpacity(0.15) : AppTheme.orange.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            isArabic
                                                ? 'دقة التحليل: ${(_confidenceScore * 100).toStringAsFixed(0)}%'
                                                : 'Extraction Accuracy: ${(_confidenceScore * 100).toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _confidenceScore >= 0.8 ? AppTheme.emerald : AppTheme.orange,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      IconButton(
                                        icon: const Icon(Icons.copy_all_rounded, size: 18, color: AppTheme.cobalt),
                                        tooltip: isArabic ? 'نسخ البيانات المستخرجة' : 'Copy Extracted Profile',
                                        onPressed: () => _copyExtractedDataSummary(context),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: _buildTargetSpecificFields(isArabic),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildSaveActionButton(isArabic),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader(bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppTheme.orange, size: 22),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic
                        ? 'أداة التكويد والاستخراج الذكي: ${_targetName(context, _selectedTarget)}'
                        : 'AI Entity Extractor & Registration: ${_targetName(context, _selectedTarget)}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic
                        ? 'محرك التحليل الذكي للوثائق والتكويد الفوري لقواعد البيانات'
                        : 'Intelligent Document Parsing & Master Data Onboarding Engine',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSelectorBar(bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              isArabic ? 'توجيه التكويد المباشر إلى:' : 'Direct Entity Target:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
            ),
            const SizedBox(width: 12),
            _targetChip(EntityTarget.supplier, isArabic ? 'مورد أجنبي' : 'Foreign Supplier', Icons.public),
            _targetChip(EntityTarget.company, isArabic ? 'شركة مستوردة' : 'Importing Company', Icons.business_rounded),
            _targetChip(EntityTarget.customsBroker, isArabic ? 'مخلص جمركي' : 'Customs Broker', Icons.badge_rounded),
            _targetChip(EntityTarget.shippingLine, isArabic ? 'خط ملاحي' : 'Shipping Line', Icons.directions_boat_rounded),
            _targetChip(EntityTarget.freightForwarder, isArabic ? 'شحن دولي' : 'Freight Forwarder', Icons.local_shipping_rounded),
            _targetChip(EntityTarget.inlandTransport, isArabic ? 'ناقل بري' : 'Inland Transport', Icons.fire_truck_rounded),
            _targetChip(EntityTarget.inspectionAgency, isArabic ? 'فحص ومعاينة' : 'Inspection Agency', Icons.fact_check_rounded),
            _targetChip(EntityTarget.insuranceCompany, isArabic ? 'شركة تأمين' : 'Insurance Company', Icons.security_rounded),
            _targetChip(EntityTarget.bank, isArabic ? 'بنك معتمد' : 'Authorized Bank', Icons.account_balance),
          ],
        ),
      ),
    );
  }

  Widget _targetChip(EntityTarget target, String label, IconData icon) {
    final isSelected = _selectedTarget == target;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: ChoiceChip(
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.cobalt),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.charcoal,
          ),
        ),
        selected: isSelected,
        selectedColor: AppTheme.cobalt,
        backgroundColor: Colors.white,
        onSelected: (val) {
          if (val) {
            setState(() {
              _selectedTarget = target;
              _setupInitialDefaults();
            });
          }
        },
      ),
    );
  }

  Widget _buildInputModeSwitcher(bool isArabic) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _inputModeTab = 0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _inputModeTab == 0 ? AppTheme.emerald : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _inputModeTab == 0 ? AppTheme.emerald : Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.content_paste_rounded, size: 16, color: _inputModeTab == 0 ? Colors.white : AppTheme.charcoal),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isArabic ? 'لصق نص حر' : 'Paste Free Text',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _inputModeTab == 0 ? Colors.white : AppTheme.charcoal),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _inputModeTab = 1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _inputModeTab == 1 ? AppTheme.emerald : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _inputModeTab == 1 ? AppTheme.emerald : Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.attach_file_rounded, size: 16, color: _inputModeTab == 1 ? Colors.white : AppTheme.charcoal),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isArabic ? 'مستند أو صورة أو ملف' : 'Document or Image File',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _inputModeTab == 1 ? Colors.white : AppTheme.charcoal),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRawTextInputArea(bool isArabic) {
    return Column(
      children: [
        Expanded(
          child: TextField(
            controller: _rawTextCtrl,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: _getPlaceholderForTarget(_selectedTarget, isArabic),
              hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileUploadArea(bool isArabic) {
    return InkWell(
      onTap: _isExtracting ? null : _pickAndExtractFile,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.cobalt.withOpacity(0.4), style: BorderStyle.solid),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_upload_outlined, size: 48, color: AppTheme.cobalt),
            const SizedBox(height: 12),
            Text(
              _selectedFileName ?? (isArabic ? 'اضغط لاختيار ملف أو سحب مستند الفاتورة أو الكارت' : 'Click to select file or drag document / business card'),
              style: TextStyle(fontWeight: FontWeight.bold, color: _selectedFileName != null ? AppTheme.charcoal : Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isArabic ? 'يدعم ملفات: المستندات والصور والجداول الإلكترونية' : 'Supported formats: PDF, Images (PNG/JPG), Excel, Word',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtractActionButton(bool isArabic) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton.icon(
        icon: _isExtracting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.auto_awesome, size: 18),
        label: Text(
          _isExtracting
              ? (isArabic ? 'جاري التحليل والاستخراج...' : 'Analyzing & Extracting Data...')
              : (isArabic ? 'استخراج وتحليل البيانات تلقائياً ✨' : 'Smart Extract & Auto-Analyze ✨'),
        ),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, foregroundColor: Colors.white),
        onPressed: _isExtracting
            ? null
            : () {
                if (_inputModeTab == 0) {
                  _extractFromRawText();
                } else {
                  _pickAndExtractFile();
                }
              },
      ),
    );
  }

  Widget _buildSaveActionButton(bool isArabic) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        icon: _isSaving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.check_circle_rounded, size: 20),
        label: Text(
          isArabic
              ? 'حفظ وتكويد ${_targetName(context, _selectedTarget)} في قاعدة البيانات 💾'
              : 'Save & Register ${_targetName(context, _selectedTarget)} in Database 💾',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
        onPressed: (_isSaving || _isExtracting) ? null : _saveEntityToDatabase,
      ),
    );
  }

  Widget _buildTargetSpecificFields(bool isArabic) {
    switch (_selectedTarget) {
      case EntityTarget.supplier:
        return _buildSupplierFields(isArabic);
      case EntityTarget.company:
        return _buildImporterFields(isArabic);
      case EntityTarget.customsBroker:
        return _buildCustomsBrokerFields(isArabic);
      case EntityTarget.shippingLine:
        return _buildShippingLineFields(isArabic);
      case EntityTarget.freightForwarder:
        return _buildFreightForwarderFields(isArabic);
      case EntityTarget.inlandTransport:
        return _buildInlandTransportFields(isArabic);
      case EntityTarget.inspectionAgency:
        return _buildInspectionAgencyFields(isArabic);
      case EntityTarget.insuranceCompany:
        return _buildInsuranceCompanyFields(isArabic);
      case EntityTarget.bank:
        return _buildBankFields(isArabic);
      case EntityTarget.partner:
        return _buildFreightForwarderFields(isArabic);
    }
  }

  Widget _buildTrademarkSection(bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, size: 16, color: AppTheme.cobalt),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isArabic ? 'شهادات العلامة التجارية والجودة (Trademark Certificates)' : 'Trademark & Quality Certificates',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 1. WIPO Madrid Monitor
          Row(
            children: [
              SizedBox(
                width: 170,
                child: Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('WIPO Madrid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    value: _hasWipo,
                    activeColor: AppTheme.cobalt,
                    onChanged: (val) => setState(() => _hasWipo = val ?? false),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _wipoNumberCtrl,
                  enabled: _hasWipo,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'رقم تسجيل WIPO Madrid Monitor' : 'WIPO Registration Number',
                    isDense: true,
                    prefixIcon: const Icon(Icons.tag, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 2. EUIPO
          Row(
            children: [
              SizedBox(
                width: 170,
                child: Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('EUIPO (أوروبا)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    value: _hasEuipo,
                    activeColor: AppTheme.cobalt,
                    onChanged: (val) => setState(() => _hasEuipo = val ?? false),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _euipoNumberCtrl,
                  enabled: _hasEuipo,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'رقم تسجيل EUIPO' : 'EUIPO Registration Number',
                    isDense: true,
                    prefixIcon: const Icon(Icons.tag, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 3. Global Brand Database
          Row(
            children: [
              SizedBox(
                width: 170,
                child: Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Global Brand', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    value: _hasGlobalBrand,
                    activeColor: AppTheme.cobalt,
                    onChanged: (val) => setState(() => _hasGlobalBrand = val ?? false),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _globalBrandNumberCtrl,
                  enabled: _hasGlobalBrand,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'رقم تسجيل Global Brand Database' : 'Global Brand Registration Number',
                    isDense: true,
                    prefixIcon: const Icon(Icons.public, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 4. ISO 9001 Certificate
          Row(
            children: [
              SizedBox(
                width: 170,
                child: Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('ISO 9001 Cert', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    value: _hasIso9001,
                    activeColor: AppTheme.emerald,
                    onChanged: (val) => setState(() => _hasIso9001 = val ?? false),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _iso9001NumberCtrl,
                  enabled: _hasIso9001,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'رقم وتفاصيل شهادة ISO 9001' : 'ISO 9001 Certificate Number',
                    isDense: true,
                    prefixIcon: const Icon(Icons.workspace_premium_outlined, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierFields(bool isArabic) {
    const supplierTypeOptions = [
      'Manufacturer',
      'Foreign Supplier / Trader',
      'Authorized Agent / Distributor',
      'Exporter',
    ];

    const regTypeOptions = [
      'Factory Registration',
      'Foreign Exporter Number (Nafeza)',
      'Company Registration Number',
      'VAT Number',
      'Tax Number',
      'Commercial Register',
    ];

    String getSupplierTypeLabel(String val) {
      if (!isArabic) return val;
      switch (val) {
        case 'Manufacturer':
          return 'مصنع';
        case 'Foreign Supplier / Trader':
          return 'مورد أجنبي أو تاجر';
        case 'Authorized Agent / Distributor':
          return 'وكيل معتمد أو موزع';
        case 'Exporter':
          return 'مصدر';
        default:
          return val;
      }
    }

    String getRegTypeLabel(String val) {
      if (!isArabic) return val;
      switch (val) {
        case 'Factory Registration':
          return 'سجل مصنع';
        case 'Foreign Exporter Number (Nafeza)':
          return 'رقم المصدر الأجنبي بمنظومة نافذة';
        case 'Company Registration Number':
          return 'رقم تسجيل الشركة';
        case 'VAT Number':
          return 'رقم ضريبة القيمة المضافة';
        case 'Tax Number':
          return 'الرقم الضريبي';
        case 'Commercial Register':
          return 'السجل التجاري';
        default:
          return val;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Company Name
        TextFormField(
          controller: _companyNameCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'اسم المورد الأجنبي بالإنجليزية *' : 'Foreign Supplier Name *',
            prefixIcon: const Icon(Icons.business_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'اسم المورد مطلوب' : 'Supplier name is required') : null,
        ),
        const SizedBox(height: 10),
        // Supplier Type & Registration Type
        Row(
          children: [
            Expanded(
              child: SearchableDropdownField<String>(
                value: supplierTypeOptions.contains(_supplierType) ? _supplierType : supplierTypeOptions.first,
                labelText: isArabic ? 'نوع المورد *' : 'Supplier Type *',
                items: supplierTypeOptions
                    .map((type) => SearchableDropdownItem<String>(value: type, label: getSupplierTypeLabel(type)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _supplierType = v);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SearchableDropdownField<String>(
                value: regTypeOptions.contains(_supplierRegType) ? _supplierRegType : regTypeOptions.first,
                labelText: isArabic ? 'نوع السجل الأجنبي *' : 'Registration Type *',
                items: regTypeOptions
                    .map((type) => SearchableDropdownItem<String>(value: type, label: getRegTypeLabel(type)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _supplierRegType = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Foreign Exporter ID & CargoX ID
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _foreignTaxIdCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم السجل ومعرف المصدر الأجنبي بمنظومة نافذة *' : 'Foreign Exporter ID (Nafeza) *',
                  prefixIcon: const Icon(Icons.badge_rounded, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'رقم السجل مطلوب' : 'Foreign Exporter ID is required') : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _cargoxIdCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'معرف منصة كارجو إكس المعتمد' : 'CargoX Platform Registered ID',
                  prefixIcon: const Icon(Icons.hub_rounded, size: 18, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Country & Country Code
        Row(
          children: [
            Expanded(
              flex: 3,
              child: SearchableDropdownField<String>(
                value: _countryCtrl.text.isNotEmpty ? _countryCtrl.text : 'China (CN)',
                labelText: isArabic ? 'الدولة والمنشأ *' : 'Country *',
                items: _countryList.map((c) => SearchableDropdownItem(value: c['name']!, label: c['name']!)).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _countryCtrl.text = v;
                      final match = _countryList.firstWhere((c) => c['name'] == v, orElse: () => {});
                      if (match.isNotEmpty) _countryCodeCtrl.text = match['code']!;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _countryCodeCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'كود الدولة المكون من حرفين *' : 'Country Code (ISO 2-letter) *',
                  prefixIcon: const Icon(Icons.code, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'كود الدولة مطلوب' : 'Country code is required') : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Full Address
        TextFormField(
          controller: _addressCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'العنوان الكامل للمصنع والمقر *' : 'Full Address *',
            prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'العنوان مطلوب' : 'Address is required') : null,
        ),
        const SizedBox(height: 10),
        // Primary & Secondary Email
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _emailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'البريد الإلكتروني الرئيسي' : 'Primary Email',
                  prefixIcon: const Icon(Icons.email_outlined, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _secondaryEmailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'البريد الإلكتروني الثانوي' : 'Secondary / Additional Email',
                  prefixIcon: const Icon(Icons.mark_email_read_outlined, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Phone, Mobile, Fax
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم الهاتف' : 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _mobileCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'المحمول ورقم التواصل' : 'Mobile Number',
                  prefixIcon: const Icon(Icons.smartphone_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _faxCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الفاكس' : 'Fax',
                  prefixIcon: const Icon(Icons.print_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Contact Person & Website
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _contactPersonCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'مسؤول التواصل والمبيعات' : 'Contact Person & Sales',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _websiteCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الموقع الإلكتروني' : 'Website URL',
                  prefixIcon: const Icon(Icons.language_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Beneficiary Bank Details
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueGrey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance, size: 16, color: AppTheme.charcoal),
                  const SizedBox(width: 6),
                  Text(
                    isArabic ? 'بيانات البنك المستفيد والحساب المصرفي' : 'Beneficiary Bank Details',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bankNameCtrl,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'اسم البنك المستفيد' : 'Beneficiary Bank Name',
                        prefixIcon: const Icon(Icons.account_balance_outlined, size: 16),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _swiftCodeCtrl,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'كود السويفت البنكي الدولي' : 'Bank SWIFT Code',
                        prefixIcon: const Icon(Icons.code, size: 16),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _accountNumberCtrl,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'رقم الحساب المصرفي' : 'Account Number',
                        prefixIcon: const Icon(Icons.numbers, size: 16),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _ibanCtrl,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'رقم الآيبان الدولي' : 'IBAN',
                        prefixIcon: const Icon(Icons.credit_card, size: 16),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Compliance Section
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: Material(type: MaterialType.transparency, child: CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(isArabic ? 'شهادة آيزو العالمية' : 'ISO Certified', style: const TextStyle(fontSize: 11)),
                  value: _hasIso,
                  activeColor: AppTheme.cobalt,
                  onChanged: (val) => setState(() => _hasIso = val ?? false),
                )),
              ),
              Expanded(
                child: Material(type: MaterialType.transparency, child: CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(isArabic ? 'قرار 43' : 'Decree 43', style: const TextStyle(fontSize: 11)),
                  value: _registeredDecree43,
                  activeColor: AppTheme.cobalt,
                  onChanged: (val) => setState(() => _registeredDecree43 = val ?? false),
                )),
              ),
              Expanded(
                child: Material(type: MaterialType.transparency, child: CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(isArabic ? 'القائمة البيضاء' : 'White List', style: const TextStyle(fontSize: 11)),
                  value: _whiteListRegistered,
                  activeColor: AppTheme.emerald,
                  onChanged: (val) => setState(() => _whiteListRegistered = val ?? false),
                )),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Trademark Certificates & ISO 9001
        _buildTrademarkSection(isArabic),
        const SizedBox(height: 10),
        // Brands & Notes
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _brandsCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'العلامات التجارية والمنتجات' : 'Brands & Products',
                  prefixIcon: const Icon(Icons.category_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _notesCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'ملاحظات إضافية' : 'Additional Notes',
                  prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImporterFields(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Company Name
        TextFormField(
          controller: _companyNameCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'اسم الشركة المستوردة *' : 'Company Name *',
            prefixIcon: const Icon(Icons.business_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'اسم الشركة مطلوب' : 'Company name is required') : null,
        ),
        const SizedBox(height: 10),
        // Address & Country
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _addressCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'العنوان المسجل للشركة *' : 'Registered Address *',
                  prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'العنوان مطلوب' : 'Address is required') : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _countryCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الدولة *' : 'Country *',
                  prefixIcon: const Icon(Icons.flag_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Importer Card ID & Importer Card Expiry Date
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _importerCardCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم البطاقة الاستيرادية المكون من 9 أرقام *' : 'Importer Card ID (9 digits) *',
                  prefixIcon: const Icon(Icons.credit_card_rounded, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'البطاقة الاستيرادية مطلوبة' : 'Importer card is required') : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _importerIdExpiry,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040),
                  );
                  if (picked != null) setState(() => _importerIdExpiry = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: isArabic ? 'تاريخ انتهاء البطاقة الاستيرادية *' : 'Importer Card Expiry Date *',
                    prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.cobalt),
                  ),
                  child: Text('${_importerIdExpiry.year}-${_importerIdExpiry.month.toString().padLeft(2, '0')}-${_importerIdExpiry.day.toString().padLeft(2, '0')}'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // VAT Registration ID & VAT Registration Expiry Date
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _taxIdCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم التسجيل الضريبي والقيمة المضافة المكون من 9 أرقام *' : 'VAT Registration ID (9 digits) *',
                  prefixIcon: const Icon(Icons.pin_rounded, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'الرقم الضريبي مطلوب' : 'Tax ID is required') : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _vatIdExpiry,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040),
                  );
                  if (picked != null) setState(() => _vatIdExpiry = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: isArabic ? 'تاريخ انتهاء التسجيل الضريبي *' : 'VAT Registration Expiry Date *',
                    prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.cobalt),
                  ),
                  child: Text('${_vatIdExpiry.year}-${_vatIdExpiry.month.toString().padLeft(2, '0')}-${_vatIdExpiry.day.toString().padLeft(2, '0')}'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Commercial Reg # & Commercial Reg Expiry Date
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _commercialRegisterCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم السجل التجاري المكون من 15 رقماً *' : 'Commercial Reg # (15 digits) *',
                  prefixIcon: const Icon(Icons.badge_rounded, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'السجل التجاري مطلوب' : 'Commercial register is required') : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _registrationExpiry,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040),
                  );
                  if (picked != null) setState(() => _registrationExpiry = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: isArabic ? 'تاريخ انتهاء السجل التجاري *' : 'Commercial Reg Expiry Date *',
                    prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.cobalt),
                  ),
                  child: Text('${_registrationExpiry.year}-${_registrationExpiry.month.toString().padLeft(2, '0')}-${_registrationExpiry.day.toString().padLeft(2, '0')}'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Phone, Mobile, Fax
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم الهاتف' : 'Primary Phone',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _mobileCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم المحمول' : 'Mobile Number',
                  prefixIcon: const Icon(Icons.smartphone_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _faxCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الفاكس' : 'Fax',
                  prefixIcon: const Icon(Icons.print_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Primary Email, Secondary Email, Website
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _emailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'البريد الإلكتروني الرسمي' : 'Official Email Address',
                  prefixIcon: const Icon(Icons.email_outlined, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _secondaryEmailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'البريد الإلكتروني الثانوي' : 'Secondary Email',
                  prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _websiteCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الموقع الإلكتروني' : 'Website URL',
                  prefixIcon: const Icon(Icons.language_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Legal Representative / Manager & Nafeza Token
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _contactPersonCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الممثل القانوني / مدير الاستيراد' : 'Legal Representative / Manager',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatefulBuilder(
                builder: (context, setFieldState) => TextFormField(
                  controller: _nafezaTokenCtrl,
                  obscureText: !_showNafezaToken,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'معرف توكن نافذة المعتمد' : 'Nafeza E-Token ID',
                    prefixIcon: const Icon(Icons.vpn_key_rounded, size: 18, color: Colors.blue),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showNafezaToken ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                      ),
                      tooltip: isArabic ? (_showNafezaToken ? 'إخفاء' : 'إظهار') : (_showNafezaToken ? 'Hide' : 'Show'),
                      onPressed: () {
                        setState(() => _showNafezaToken = !_showNafezaToken);
                        setFieldState(() {});
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Beneficiary Bank Details
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueGrey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance, size: 16, color: AppTheme.charcoal),
                  const SizedBox(width: 6),
                  Text(
                    isArabic ? 'بيانات البنك المعتمد للتعاملات الجمركية' : 'Bank & Customs Account Details',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bankNameCtrl,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'اسم البنك المصرفي' : 'Bank Name',
                        prefixIcon: const Icon(Icons.account_balance_outlined, size: 16),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _swiftCodeCtrl,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'كود السويفت' : 'SWIFT Code',
                        prefixIcon: const Icon(Icons.code, size: 16),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _accountNumberCtrl,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'رقم الحساب المصرفي' : 'Account Number',
                        prefixIcon: const Icon(Icons.numbers, size: 16),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _ibanCtrl,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'رقم الآيبان الدولي' : 'IBAN',
                        prefixIcon: const Icon(Icons.credit_card, size: 16),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Trademark Certificates & ISO 9001
        _buildTrademarkSection(isArabic),
        const SizedBox(height: 10),
        TextFormField(
          controller: _notesCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'ملاحظات إضافية' : 'Additional Notes',
            prefixIcon: const Icon(Icons.notes_rounded, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomsBrokerFields(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _companyNameCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'اسم مكتب أو شركة التخليص الجمركي *' : 'Customs Brokerage Firm Name *',
            prefixIcon: const Icon(Icons.badge_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'اسم المستخلص مطلوب' : 'Broker name is required') : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _brokerLicenseCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم رخصة التخليص الجمركي *' : 'Customs Broker License Number *',
                  prefixIcon: const Icon(Icons.assignment_ind_rounded, size: 18, color: Colors.blue),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'رقم الرخصة مطلوب' : 'License number is required') : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _portsCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'موانئ ومواقع العمل الجمركي *' : 'Operating Ports & Customs Zones *',
                  prefixIcon: const Icon(Icons.anchor_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _taxIdCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الرقم الضريبي' : 'Tax ID',
                  prefixIcon: const Icon(Icons.pin_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _commercialRegisterCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'السجل التجاري' : 'Commercial Register',
                  prefixIcon: const Icon(Icons.receipt_long_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _addressCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'عنوان المكتب والمقر الرئيسي' : 'Office Address & Headquarters',
            prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _contactPersonCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'المخلص الجمركي المعتمد والمسؤول' : 'Certified Customs Specialist',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم الهاتف والمحمول' : 'Phone & Mobile Number',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _emailCtrl,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: isArabic ? 'البريد الإلكتروني للعمليات' : 'Operations Email Address',
            prefixIcon: const Icon(Icons.email_outlined, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildShippingLineFields(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _companyNameCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'اسم الخط الملاحي بالإنجليزية *' : 'Shipping Line Carrier Name *',
            prefixIcon: const Icon(Icons.directions_boat_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'اسم الخط الملاحي مطلوب' : 'Shipping line name is required') : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _scacCodeCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'كود الناقل الملاحي المعتمد *' : 'SCAC Carrier Code *',
                  prefixIcon: const Icon(Icons.qr_code_rounded, size: 18, color: Colors.blue),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'كود الناقل الملاحي مطلوب' : 'SCAC code is required') : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: TextFormField(
                controller: _trackingUrlCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رابط التتبع الحي للشحنات *' : 'Cargo Tracking Website URL *',
                  prefixIcon: const Icon(Icons.travel_explore_rounded, size: 18, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _websiteCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الموقع الإلكتروني الرسمي' : 'Official Website URL',
                  prefixIcon: const Icon(Icons.language_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _emailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'بريد العمليات وخدمة العملاء *' : 'Operations & Customer Service Email *',
                  prefixIcon: const Icon(Icons.email_outlined, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _secondaryEmailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'بريد الحجوزات الثانوي' : 'Secondary / Booking Email',
                  prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'أرقام هواتف وخدمة عملاء الوكيل' : 'Agency Customer Service & Phone',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _addressCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'عناوين مقرات الوكيل الملاحي في مصر' : 'Agency & Office Addresses',
            prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildFreightForwarderFields(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _companyNameCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'اسم شركة الشحن الدولي بالإنجليزية *' : 'Freight Forwarding Company Name *',
            prefixIcon: const Icon(Icons.local_shipping_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'اسم شركة الشحن مطلوب' : 'Forwarder name is required') : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _commercialRegisterCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رخصة الفياتا والسجل التجاري' : 'FIATA License & Commercial Register',
                  prefixIcon: const Icon(Icons.badge_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _servicesScopeCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'مجالات وخطوط الشحن المغطاة' : 'Covered Freight Modes & Trade Lanes',
                  prefixIcon: const Icon(Icons.alt_route_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _addressCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'عنوان المكتب والمقر الرئيسي' : 'Office Address & Headquarters',
            prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _contactPersonCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'مسؤول التسعير والعمليات' : 'Pricing & Operations Lead',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم الهاتف والمحمول' : 'Phone & Mobile Number',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _emailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'بريد عروض الأسعار والعمليات *' : 'Pricing & Operations Email *',
                  prefixIcon: const Icon(Icons.email_outlined, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _websiteCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الموقع الإلكتروني' : 'Website URL',
                  prefixIcon: const Icon(Icons.language_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Financial & Credit Conditions
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueGrey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppTheme.charcoal),
                  const SizedBox(width: 6),
                  Text(
                    isArabic ? 'شروط الائتمان والعمليات المالية' : 'Credit Terms & Financial Conditions',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _defaultFreeDaysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'أيام السماح الافتراضية (Default Free Days) *' : 'Default Free Days *',
                        prefixIcon: const Icon(Icons.timer_outlined, size: 16),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'حقل إلزامي لحساب تاريخ الاستحقاق' : 'Required') : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _paymentTermsCtrl,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'شروط الدفع (Payment Terms)' : 'Payment Terms',
                        prefixIcon: const Icon(Icons.credit_card_outlined, size: 16),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _creditLimitCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: isArabic ? 'الحد الائتماني (Credit Limit)' : 'Credit Limit',
                        prefixIcon: const Icon(Icons.monetization_on_outlined, size: 16),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInlandTransportFields(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _companyNameCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'اسم شركة النقل البري بالإنجليزية *' : 'Inland Transport Company Name *',
            prefixIcon: const Icon(Icons.fire_truck_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'اسم شركة النقل مطلوب' : 'Transport company name is required') : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _brokerLicenseCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم ترخيص النقل البري والسجل' : 'Transport License & Reg Number',
                  prefixIcon: const Icon(Icons.badge_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _fleetTypesCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'أنواع وتجهيزات أسطول الشاحنات *' : 'Fleet Types & Truck Equipment *',
                  prefixIcon: const Icon(Icons.view_carousel_rounded, size: 18, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _addressCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'عنوان الجراج والمستودع الرئيسي ومناطق التغطية' : 'Central Garage & Depot Location',
            prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _contactPersonCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'مسؤول الحركة والتشغيل' : 'Fleet & Dispatch Coordinator',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'هاتف الطوارئ والتتبع على مدار الساعة *' : '24/7 Emergency & Tracking Phone *',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _emailCtrl,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: isArabic ? 'البريد الإلكتروني للتشغيل' : 'Operations Email Address',
            prefixIcon: const Icon(Icons.email_outlined, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildInspectionAgencyFields(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _companyNameCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'اسم شركة الفحص والمعاينة بالإنجليزية *' : 'Inspection & Testing Agency Name *',
            prefixIcon: const Icon(Icons.fact_check_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'اسم جهة الفحص مطلوب' : 'Inspection agency name is required') : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _brokerLicenseCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم الاعتماد والتسجيل بالرقابة على الصادرات' : 'GOIEC Accreditation & ISO Number',
                  prefixIcon: const Icon(Icons.verified_user_rounded, size: 18, color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _inspectionScopeCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'نطاق الفحص والاختبارات المعتمدة *' : 'Accredited Inspection Scope & Tests *',
                  prefixIcon: const Icon(Icons.biotech_rounded, size: 18, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _addressCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'عنوان المعامل والمقر الإقليمي' : 'Laboratories & Regional Address',
            prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _contactPersonCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'مسؤول المعاينة والمدير الفني' : 'Technical Director & Lead Inspector',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم الهاتف' : 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _emailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'البريد الإلكتروني للشهادات والتقارير *' : 'Certificates & Reports Email *',
                  prefixIcon: const Icon(Icons.email_outlined, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _websiteCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الموقع الإلكتروني' : 'Website URL',
                  prefixIcon: const Icon(Icons.language_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsuranceCompanyFields(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _companyNameCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'اسم شركة التأمين بالإنجليزية *' : 'Marine Insurance Company Name *',
            prefixIcon: const Icon(Icons.security_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'اسم شركة التأمين مطلوب' : 'Insurance company name is required') : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _brokerLicenseCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم ترخيص هيئة الرقابة المالية' : 'FRA Insurance License Number',
                  prefixIcon: const Icon(Icons.verified_rounded, size: 18, color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _policyTermsCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'شروط ووثائق التأمين البحري المغطاة *' : 'Marine Cargo Coverage & Policy Terms *',
                  prefixIcon: const Icon(Icons.shield_outlined, size: 18, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _addressCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'عنوان المقر الرئيسي وفروع التأمين البحري' : 'Headquarters & Marine Branches Address',
            prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _contactPersonCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'مسؤول الاكتتاب البحري والتعويضات' : 'Marine Underwriter & Claims Officer',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الخط الساخن ورقم الهاتف' : 'Hotline & Phone Number',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _emailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'البريد الإلكتروني للوثائق والمطالبات *' : 'Policies & Claims Email *',
                  prefixIcon: const Icon(Icons.email_outlined, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _websiteCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الموقع الإلكتروني' : 'Website URL',
                  prefixIcon: const Icon(Icons.language_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBankFields(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _companyNameCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'اسم البنك المصرفي بالإنجليزية *' : 'Bank Name *',
            prefixIcon: const Icon(Icons.account_balance_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'اسم البنك مطلوب' : 'Bank name is required') : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _swiftCodeCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'كود السويفت الدولي *' : 'International SWIFT / BIC Code *',
                  prefixIcon: const Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.blue),
                  hintText: 'e.g. CIBEGGCAXXX',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'كود السويفت مطلوب' : 'SWIFT code is required') : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _branchNameCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'اسم الفرع المعتمد *' : 'Authorized Branch Name *',
                  prefixIcon: const Icon(Icons.store_rounded, size: 18),
                  hintText: isArabic ? 'الفرع الرئيسي للشركات' : 'Main Corporate Branch',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _addressCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'عنوان المقر والفرع' : 'Branch & Headquarters Address',
            prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'هاتف الاعتمادات المستندية' : 'Trade Finance & LC Phone',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _emailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'البريد الإلكتروني للفرع' : 'Branch Operations Email',
                  prefixIcon: const Icon(Icons.email_outlined, size: 18),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getTargetIcon(EntityTarget target) {
    switch (target) {
      case EntityTarget.supplier:
        return Icons.public;
      case EntityTarget.company:
        return Icons.domain_rounded;
      case EntityTarget.customsBroker:
        return Icons.badge_rounded;
      case EntityTarget.shippingLine:
        return Icons.directions_boat_rounded;
      case EntityTarget.freightForwarder:
        return Icons.local_shipping_rounded;
      case EntityTarget.inlandTransport:
        return Icons.fire_truck_rounded;
      case EntityTarget.inspectionAgency:
        return Icons.fact_check_rounded;
      case EntityTarget.insuranceCompany:
        return Icons.security_rounded;
      case EntityTarget.bank:
        return Icons.account_balance;
      case EntityTarget.partner:
        return Icons.handshake;
    }
  }

  String _getPlaceholderForTarget(EntityTarget target, bool isArabic) {
    if (isArabic) {
      switch (target) {
        case EntityTarget.supplier:
          return 'الصق هنا ترويسة الفاتورة المبدئية أو كارت المورد الأجنبي:\n\nمثال:\nشركة شينخوا العالمية للنسيج المحدودة\nعنوان المصنع: طريق كانغ شينغ، تشانغشو، الصين\nالرقم الضريبي: 91320581MA1X7... كود كارجو إكس: 0x71C8a9...\nالهاتف: +86-512-52889988\nالبريد الإلكتروني: export@yuheng.com\nكود السويفت: BKCHCNBJ920';
        case EntityTarget.company:
          return 'الصق هنا بيانات الشركة المستوردة أو السجل التجاري والبطاقة الضريبية:\n\nمثال:\nشركة النيل للاستيراد والتصدير ش.م.م\nالعنوان: 15 شارع مصدق، الدقي، الجيزة، مصر\nالسجل التجاري: 184520 | البطاقة الاستيرادية: 489201\nالرقم الضريبي: 200-183-044\nالهاتف: +20 2 3762 1000 | البريد: info@nile-import.com\nتوكن نافذة: NFT-88921-EG';
        case EntityTarget.customsBroker:
          return 'الصق هنا كارت أو بيانات مكتب التخليص الجمركي:\n\nمثال:\nمكتب الأهرام للتخليص الجمركي والخدمات اللوجستية\nالعنوان: 14 شارع السلطان حسين، الإسكندرية، مصر\nرقم رخصة التخليص: 14820-2021 | الرقم الضريبي: 312-884-912\nموانئ العمل: ميناء الإسكندرية، الدخيلة، السخنة، دمياط\nمسؤول التخليص: طارق محمود (01001234567)\nالبريد: clearance@ahram-customs.com | الهاتف: 034876000';
        case EntityTarget.shippingLine:
          return 'الصق هنا بيانات الخط الملاحي والناقل البحري:\n\nمثال:\nشركة هاباج لويد للملاحة البحرية\nكود سكاك: HLCU\nالبريد الإلكتروني: egypt@hlag.com | الهاتف: +20 2 2696 4500\nالعنوان: مجمع سيتي ستارز، مبنى 3، مصر الجديدة، القاهرة';
        case EntityTarget.freightForwarder:
          return 'الصق هنا بيانات شركة الشحن الدولي:\n\nمثال:\nشركة أبيكس العالمية للشحن والتفريغ المحدودة\nالسجل التجاري: 294810 | رخصة فياتا: EG-7721\nخدمات الشحن: شحن بحري كلي وجزئي، شحن جوي، نقل متعدد الوسائط\nمسؤول التسعير: كريم نبيل (01223456789)\nالبريد: pricing@apex-freight.com | الهاتف: 0222998877\nالعنوان: 22 شارع حسن علام، مصر الجديدة، القاهرة';
        case EntityTarget.inlandTransport:
          return 'الصق هنا بيانات شركة النقل البري والأسطول:\n\nمثال:\nشركة الرواد للنقل الثقيل وخدمات الأسطول\nترخيص النقل: TR-88412 | الرقم الضريبي: 412-990-123\nأنواع الأسطول: تريلات حاويات، سطحات 40 قدم، لوابد، مبردات\nمسؤول الحركة: مصطفى جمال (01118889999 - على مدار الساعة)\nالبريد: dispatch@rowad-transport.com\nالجراج: قطعة 4، المنطقة الصناعية، العاشر من رمضان';
        case EntityTarget.inspectionAgency:
          return 'الصق هنا بيانات شركة الفحص والمعاينة:\n\nمثال:\nالشركة الدولية للفحص والمعاينة وإصدار الشهادات\nرقم الاعتماد: GOIEC-REG-4412 أو أيزو 17020\nنطاق الفحص: فحص ما قبل الشحن، شهادات المطابقة، تحاليل كيميائية\nمسؤول المعاينة: م. حسام فاروق (01025554433)\nالبريد: egypt.industrial@sgs.com | الهاتف: 034887766\nالعنوان: المنطقة الحرة، ميناء الإسكندرية';
        case EntityTarget.insuranceCompany:
          return 'الصق هنا بيانات شركة التأمين البحري:\n\nمثال:\nشركة مصر للتأمين - قطاع التأمين البحري وجسم السفن\nترخيص الرقابة المالية: INS-001 | الرقم الضريبي: 100-200-300\nمسؤول الاكتتاب: أيمن حلمي (01007776655)\nالخط الساخن: 19990 | البريد: marine.cargo@misr-ins.com.eg\nالتغطية: شروط مجمع مكتتبي التأمين في لندن (أ) - كافة الأخطار والحروب والإضرابات\nالعنوان: 7 شارع طلعت حرب، وسط البلد، القاهرة';
        case EntityTarget.bank:
          return 'الصق هنا بيانات البنك المصرفي والسويفت كود:\n\nمثال:\nالبنك الأهلي المصري\nكود السويفت: NBEGEGCX001\nكود البنك: NBE-001 | الفرع: فرع الشركات الرئيسي\nمسؤول العمليات: أحمد سالم\nالهاتف: +20 2 2594 5000 | البريد: corporate@nbe.com.eg\nالعنوان: 1187 كورنيش النيل، القاهرة، مصر';
        case EntityTarget.partner:
          return 'الصق هنا بيانات الشريك اللوجستي...';
      }
    } else {
      switch (target) {
        case EntityTarget.supplier:
          return 'Paste proforma invoice header or supplier business card text here:\n\nExample:\nSuzhou Yuheng Textile Co., Ltd\nFactory Address: No.16, Kangsheng Road, Changshu, Jiangsu, China\nVAT Number: 91320581MA1X7... CargoX ID: 0x71C8a9...\nTel: +86-512-52889988\nEmail: export@yuheng.com\nSWIFT: BKCHCNBJ920';
        case EntityTarget.company:
          return 'Paste importing company registration or tax card text here:\n\nExample:\nNile Import & Export SAE\nAddress: 15 Mossadak St., Dokki, Giza, Egypt\nCommercial Reg: 184520 | Importer Card: 489201\nTax ID: 200-183-044\nPhone: +20 2 3762 1000 | Email: info@nile-import.com\nNafeza Token: NFT-88921-EG';
        case EntityTarget.customsBroker:
          return 'Paste customs broker card or agency details here:\n\nExample:\nAl-Ahram Customs Clearance & Logistics Office\nAddress: 14 El-Sultan Hussein St., Alexandria, Egypt\nCustoms License No: 14820/2021 | Tax ID: 312-884-912\nOperating Ports: Alexandria Port, Dekheila, Sokhna, Damietta\nContact: Customs Specialist Tarek Mahmoud (+20 100 123 4567)\nEmail: clearance@ahram-customs.com | Tel: +20 3 487 6000';
        case EntityTarget.shippingLine:
          return 'Paste shipping line or carrier details here:\n\nExample:\nHapag-Lloyd AG\nSCAC Code: HLCU\nTracking URL: https://www.hapag-lloyd.com/en/online-business/track/track-by-booking-solution.html\nWebsite: https://www.hapag-lloyd.com\nEmail: egypt@hlag.com | Tel: +20 2 2696 4500\nAddress: Citystars Complex, Building 3, Heliopolis, Cairo, Egypt';
        case EntityTarget.freightForwarder:
          return 'Paste freight forwarder company details here:\n\nExample:\nApex Global Freight Forwarding Ltd\nCommercial Register: 294810 | FIATA ID: EG-7721\nServices: Ocean FCL/LCL, Air Cargo, Multimodal Transport\nContact: Pricing Manager Karim Nabil (+20 122 345 6789)\nEmail: pricing@apex-freight.com | Web: https://www.apex-freight.com\nAddress: 22 Hassan Allam St., Heliopolis, Cairo, Egypt';
        case EntityTarget.inlandTransport:
          return 'Paste inland transport & fleet company details here:\n\nExample:\nAl-Rowad Heavy Inland Transport & Fleet Services\nTransport License: TR-88412 | Tax ID: 412-990-123\nFleet Types: Container Chassis, 40ft Flatbed, Lowbed, Refrigerated\nOperations Dispatcher: Mostafa Gamal (+20 111 888 9999 - 24/7)\nEmail: dispatch@rowad-transport.com\nGarage & Hub: Plot 4, 10th of Ramadan Industrial Zone, Egypt';
        case EntityTarget.inspectionAgency:
          return 'Paste inspection & testing agency details here:\n\nExample:\nSGS Egypt International Inspection & Testing\nAccreditation No: GOIEC-REG-4412 / ISO 17020\nScope: Pre-Shipment Inspection (PSI), Verification of Conformity (VOC), Chemical Testing\nContact: Eng. Hossam Farouk (+20 102 555 4433)\nEmail: egypt.industrial@sgs.com | Web: https://www.sgs.com\nAddress: Alexandria Port Free Zone / Cairo Industrial Hub';
        case EntityTarget.insuranceCompany:
          return 'Paste marine cargo insurance company details here:\n\nExample:\nMisr Insurance Company - Marine Hull & Cargo Department\nFRA Authority License: INS-001 | Tax ID: 100-200-300\nMarine Underwriting Specialist: Ayman Helmy (+20 100 777 6655)\nHotline: 19990 | Marine Email: marine.cargo@misr-ins.com.eg\nWeb: https://www.misr-ins.com.eg\nCoverage: Institute Cargo Clauses (A) - All Risks, War & Strikes\nAddress: 7 Talaat Harb St., Downtown, Cairo, Egypt';
        case EntityTarget.bank:
          return 'Paste bank & SWIFT code details here:\n\nExample:\nNational Bank of Egypt (NBE)\nSWIFT / BIC Code: NBEGEGCX001\nBank Code: NBE-001 | Branch: Corporate Main Branch\nContact: Trade Finance Officer Ahmed Salem\nPhone: +20 2 2594 5000 | Email: corporate@nbe.com.eg\nAddress: 1187 Corniche El-Nil, Cairo, Egypt';
        case EntityTarget.partner:
          return 'Paste partner data here...';
      }
    }
  }

  void _copyExtractedDataSummary(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final buffer = StringBuffer();
    buffer.writeln(isArabic
        ? '--- بيانات ${_targetName(context, _selectedTarget)} المستخرجة ---'
        : '--- Extracted ${_targetName(context, _selectedTarget)} Profile ---');

    void addField(String labelAr, String labelEn, String val) {
      if (val.trim().isNotEmpty) {
        buffer.writeln('${isArabic ? labelAr : labelEn}: ${val.trim()}');
      }
    }

    addField('اسم الكيان', 'Entity Name', _companyNameCtrl.text);
    addField('الاسم بالعربية', 'Arabic Name', _arabicNameCtrl.text);
    addField('رقم السجل والتعريف الضريبي', 'Tax / Reg ID', _taxIdCtrl.text.isNotEmpty ? _taxIdCtrl.text : _foreignTaxIdCtrl.text);
    addField('معرف كارجو إكس', 'CargoX Platform ID', _cargoxIdCtrl.text);
    addField('رقم السجل التجاري', 'Commercial Register', _commercialRegisterCtrl.text);
    addField('البطاقة الاستيرادية', 'Importer Card', _importerCardCtrl.text);
    addField('الدولة', 'Country', _countryCtrl.text);
    addField('العنوان', 'Address', _addressCtrl.text);
    addField('المسؤول', 'Contact Person', _contactPersonCtrl.text);
    addField('الهاتف', 'Phone', _phoneCtrl.text);
    addField('المحمول', 'Mobile', _mobileCtrl.text);
    addField('الفاكس', 'Fax', _faxCtrl.text);
    addField('البريد الإلكتروني', 'Email', _emailCtrl.text);
    addField('البريد الثانوي', 'Secondary Email', _secondaryEmailCtrl.text);
    addField('الموقع الإلكتروني', 'Website', _websiteCtrl.text);
    final nafezaRaw = _nafezaTokenCtrl.text.trim();
    if (nafezaRaw.isNotEmpty) {
      final masked = nafezaRaw.length > 4 ? '****${nafezaRaw.substring(nafezaRaw.length - 4)}' : '****';
      addField('توكن نافذة', 'Nafeza Token', masked);
    }
    if (_hasWipo) addField('WIPO Madrid', 'WIPO Madrid', _wipoNumberCtrl.text.isNotEmpty ? _wipoNumberCtrl.text : 'Yes');
    if (_hasEuipo) addField('EUIPO', 'EUIPO', _euipoNumberCtrl.text.isNotEmpty ? _euipoNumberCtrl.text : 'Yes');
    if (_hasGlobalBrand) addField('Global Brand', 'Global Brand', _globalBrandNumberCtrl.text.isNotEmpty ? _globalBrandNumberCtrl.text : 'Yes');
    if (_hasIso9001) addField('ISO 9001', 'ISO 9001', _iso9001NumberCtrl.text.isNotEmpty ? _iso9001NumberCtrl.text : 'Yes');
    addField('أيام السماح الافتراضية', 'Default Free Days', _defaultFreeDaysCtrl.text);
    addField('شروط الدفع', 'Payment Terms', _paymentTermsCtrl.text);
    addField('الحد الائتماني', 'Credit Limit', _creditLimitCtrl.text);
    addField('البنك', 'Bank Name', _bankNameCtrl.text);
    addField('سويفت', 'SWIFT Code', _swiftCodeCtrl.text);
    addField('الحساب المصرفي', 'Bank Account', _accountNumberCtrl.text);
    addField('الآيبان', 'IBAN', _ibanCtrl.text);
    addField('كود الناقل', 'SCAC Code', _scacCodeCtrl.text);
    addField('رخصة التخليص', 'Broker License', _brokerLicenseCtrl.text);
    addField('نطاق العمل', 'Services Scope', _servicesScopeCtrl.text);
    addField('ملاحظات', 'Notes', _notesCtrl.text);

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: isArabic ? 'تم نسخ البيانات المستخرجة بنجاح' : 'Extracted data copied successfully',
    );
  }
}
