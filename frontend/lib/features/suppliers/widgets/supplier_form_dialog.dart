import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/supplier_model.dart';
import '../providers/suppliers_provider.dart';

/// نافذة إضافة أو تعديل بيانات المورد الأجنبي
class SupplierFormDialog extends ConsumerStatefulWidget {
  final SupplierModel? supplierToEdit;

  const SupplierFormDialog({
    super.key,
    this.supplierToEdit,
  });

  static Future<void> show(BuildContext context, {SupplierModel? supplierToEdit}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => SupplierFormDialog(supplierToEdit: supplierToEdit),
    );
  }

  @override
  ConsumerState<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late String _selectedSupplierType;
  late String _selectedRegType;
  late final TextEditingController _expIdCtrl;
  late final TextEditingController _cargoxPlatformIdCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _countryCodeCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _secondaryEmailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _faxCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _swiftCodeCtrl;
  late final TextEditingController _accountNumberCtrl;
  late final TextEditingController _ibanCtrl;
  late final TextEditingController _brandsCtrl;
  late final TextEditingController _notesCtrl;

  late bool _hasIso;
  late bool _registeredDecree43;
  late bool _whiteListRegistered;

  late bool _hasWipo;
  late final TextEditingController _wipoCtrl;
  late bool _hasEuipo;
  late final TextEditingController _euipoCtrl;
  late bool _hasGlobalBrand;
  late final TextEditingController _globalBrandCtrl;
  late bool _hasIso9001;
  late final TextEditingController _iso9001Ctrl;

  static const List<String> _supplierTypeOptions = [
    'Manufacturer',
    'Foreign Supplier / Trader',
    'Authorized Agent / Distributor',
    'Exporter',
  ];

  static const List<String> _regTypeOptions = [
    'Factory Registration',
    'Foreign Exporter Number (Nafeza)',
    'Company Registration Number',
    'VAT Number',
    'Tax Number',
    'Commercial Register',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.supplierToEdit;
    _nameCtrl = TextEditingController(text: s?.companyName ?? '');
    _selectedSupplierType = s?.supplierType ?? 'Manufacturer';
    _selectedRegType = s?.registrationType ?? 'Factory Registration';
    _expIdCtrl = TextEditingController(text: s?.foreignExporterId ?? '');
    _cargoxPlatformIdCtrl = TextEditingController(text: s?.cargoxPlatformId ?? '');
    _countryCtrl = TextEditingController(text: s?.foreignExporterCountry ?? '');
    _countryCodeCtrl = TextEditingController(text: s?.foreignExporterCountryCode ?? '');
    _addressCtrl = TextEditingController(text: s?.address ?? '');
    _emailCtrl = TextEditingController(text: s?.email ?? '');
    _secondaryEmailCtrl = TextEditingController(text: s?.secondaryEmail ?? '');
    _phoneCtrl = TextEditingController(text: s?.phone ?? '');
    _mobileCtrl = TextEditingController(text: s?.mobile ?? '');
    _faxCtrl = TextEditingController(text: s?.fax ?? '');
    _websiteCtrl = TextEditingController(text: s?.website ?? '');
    _bankNameCtrl = TextEditingController(text: s?.bankName ?? '');
    _swiftCodeCtrl = TextEditingController(text: s?.swiftCode ?? '');
    _accountNumberCtrl = TextEditingController(text: s?.accountNumber ?? '');
    _ibanCtrl = TextEditingController(text: s?.iban ?? '');
    _brandsCtrl = TextEditingController(text: s?.brands ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');

    _hasIso = s?.hasIso ?? false;
    _registeredDecree43 = s?.registeredDecree43 ?? false;
    _whiteListRegistered = s?.whiteListRegistered ?? false;

    _hasWipo = s?.hasWipo ?? false;
    _wipoCtrl = TextEditingController(text: s?.wipoNumber ?? '');
    _hasEuipo = s?.hasEuipo ?? false;
    _euipoCtrl = TextEditingController(text: s?.euipoNumber ?? '');
    _hasGlobalBrand = s?.hasGlobalBrand ?? false;
    _globalBrandCtrl = TextEditingController(text: s?.globalBrandNumber ?? '');
    _hasIso9001 = s?.hasIso9001 ?? false;
    _iso9001Ctrl = TextEditingController(text: s?.iso9001Number ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _expIdCtrl.dispose();
    _cargoxPlatformIdCtrl.dispose();
    _countryCtrl.dispose();
    _countryCodeCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _secondaryEmailCtrl.dispose();
    _phoneCtrl.dispose();
    _mobileCtrl.dispose();
    _faxCtrl.dispose();
    _websiteCtrl.dispose();
    _bankNameCtrl.dispose();
    _swiftCodeCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ibanCtrl.dispose();
    _brandsCtrl.dispose();
    _notesCtrl.dispose();
    _wipoCtrl.dispose();
    _euipoCtrl.dispose();
    _globalBrandCtrl.dispose();
    _iso9001Ctrl.dispose();
    super.dispose();
  }

  String _getSupplierTypeLabel(BuildContext context, String type) {
    final l10n = context.l10n;
    switch (type) {
      case 'Manufacturer':
        return l10n.supplierTypeManufacturer;
      case 'Foreign Supplier / Trader':
        return l10n.supplierTypeTrader;
      case 'Authorized Agent / Distributor':
        return l10n.supplierTypeAgent;
      case 'Exporter':
        return l10n.supplierTypeExporter;
      default:
        return type;
    }
  }

  String _getRegTypeLabel(BuildContext context, String type) {
    final l10n = context.l10n;
    switch (type) {
      case 'Factory Registration':
        return l10n.regTypeFactory;
      case 'Foreign Exporter Number (Nafeza)':
        return l10n.regTypeNafezaExporter;
      case 'Company Registration Number':
        return l10n.regTypeCompanyReg;
      case 'VAT Number':
        return l10n.regTypeVat;
      case 'Tax Number':
        return l10n.regTypeTax;
      case 'Commercial Register':
        return l10n.regTypeCommercial;
      default:
        return type;
    }
  }

  Widget _buildCopySuffix(BuildContext context, TextEditingController ctrl) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (_, val, __) {
        if (val.text.trim().isEmpty) return const SizedBox.shrink();
        return IconButton(
          icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
          tooltip: context.l10n.suppliersCopyFieldTooltip,
          splashRadius: 16,
          onPressed: () => CopyHelper.copy(context, val.text),
        );
      },
    );
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final supplierToEdit = widget.supplierToEdit;
    final isEditing = supplierToEdit != null;

    final supplier = SupplierModel(
      supplierId: supplierToEdit?.supplierId,
      supplierCode: supplierToEdit?.supplierCode ?? '',
      companyName: _nameCtrl.text.trim(),
      supplierType: _selectedSupplierType,
      registrationType: _selectedRegType,
      foreignExporterId: _expIdCtrl.text.trim(),
      cargoxPlatformId: _cargoxPlatformIdCtrl.text.trim().isEmpty ? null : _cargoxPlatformIdCtrl.text.trim(),
      foreignExporterCountry: _countryCtrl.text.trim(),
      foreignExporterCountryCode: _countryCodeCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim().isEmpty ? null : _mobileCtrl.text.trim(),
      fax: _faxCtrl.text.trim().isEmpty ? null : _faxCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      secondaryEmail: _secondaryEmailCtrl.text.trim().isEmpty ? null : _secondaryEmailCtrl.text.trim(),
      website: _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
      bankName: _bankNameCtrl.text.trim().isEmpty ? null : _bankNameCtrl.text.trim(),
      swiftCode: _swiftCodeCtrl.text.trim().isEmpty ? null : _swiftCodeCtrl.text.trim(),
      accountNumber: _accountNumberCtrl.text.trim().isEmpty ? null : _accountNumberCtrl.text.trim(),
      iban: _ibanCtrl.text.trim().isEmpty ? null : _ibanCtrl.text.trim(),
      hasIso: _hasIso,
      registeredDecree43: _registeredDecree43,
      whiteListRegistered: _whiteListRegistered,
      hasWipo: _hasWipo,
      wipoNumber: _hasWipo && _wipoCtrl.text.trim().isNotEmpty ? _wipoCtrl.text.trim() : null,
      hasEuipo: _hasEuipo,
      euipoNumber: _hasEuipo && _euipoCtrl.text.trim().isNotEmpty ? _euipoCtrl.text.trim() : null,
      hasGlobalBrand: _hasGlobalBrand,
      globalBrandNumber: _hasGlobalBrand && _globalBrandCtrl.text.trim().isNotEmpty ? _globalBrandCtrl.text.trim() : null,
      hasIso9001: _hasIso9001,
      iso9001Number: _hasIso9001 && _iso9001Ctrl.text.trim().isNotEmpty ? _iso9001Ctrl.text.trim() : null,
      brands: _brandsCtrl.text.trim().isEmpty ? null : _brandsCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      isActive: supplierToEdit?.isActive ?? true,
    );

    String? errorMessage;
    if (isEditing && supplierToEdit.supplierId != null) {
      final List<FieldChangeItem> changes = [];
      if (FieldChangeItem.isDifferent(supplierToEdit.companyName, supplier.companyName)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffSupplierCompanyName, oldValue: supplierToEdit.companyName, newValue: supplier.companyName));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.supplierType, supplier.supplierType)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffSupplierType, oldValue: supplierToEdit.supplierType, newValue: supplier.supplierType));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.registrationType, supplier.registrationType)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffSupplierRegType, oldValue: supplierToEdit.registrationType, newValue: supplier.registrationType));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.hasWipo, supplier.hasWipo)) {
        changes.add(FieldChangeItem(fieldName: 'WIPO Madrid', oldValue: supplierToEdit.hasWipo ? 'نعم' : 'لا', newValue: supplier.hasWipo ? 'نعم' : 'لا'));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.hasIso9001, supplier.hasIso9001)) {
        changes.add(FieldChangeItem(fieldName: 'ISO 9001', oldValue: supplierToEdit.hasIso9001 ? 'نعم' : 'لا', newValue: supplier.hasIso9001 ? 'نعم' : 'لا'));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.foreignExporterId, supplier.foreignExporterId)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffForeignExporterId, oldValue: supplierToEdit.foreignExporterId, newValue: supplier.foreignExporterId));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.cargoxPlatformId, supplier.cargoxPlatformId)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffCargoXId, oldValue: supplierToEdit.cargoxPlatformId ?? '', newValue: supplier.cargoxPlatformId ?? ''));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.foreignExporterCountry, supplier.foreignExporterCountry)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffSupplierCountry, oldValue: supplierToEdit.foreignExporterCountry, newValue: supplier.foreignExporterCountry));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.email, supplier.email)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffSupplierEmail, oldValue: supplierToEdit.email, newValue: supplier.email));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.phone, supplier.phone)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffSupplierPhone, oldValue: supplierToEdit.phone, newValue: supplier.phone));
      }

      if (changes.isNotEmpty) {
        final confirmed = await showChangeDiffConfirmationDialog(
          context,
          title: l10n.diffConfirmSupplierTitle,
          itemReference: '${supplierToEdit.supplierCode} (${supplierToEdit.companyName})',
          changes: changes,
        );
        if (!confirmed) return;
      }

      errorMessage = await ref.read(suppliersProvider.notifier).updateSupplier(supplierToEdit.supplierId!, supplier);
    } else {
      errorMessage = await ref.read(suppliersProvider.notifier).createSupplier(supplier);
    }

    if (errorMessage == null) {
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: AppTheme.crimson,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEditing = widget.supplierToEdit != null;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: SizedBox(
          width: 650,
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: const BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadiusDirectional.only(topStart: Radius.circular(16), topEnd: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(isEditing ? Icons.edit : Icons.public, color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          isEditing ? l10n.editSupplierDialogTitle : l10n.addSupplierDialogTitle,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      tooltip: l10n.closeDialogTooltip,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Form Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextField(
                          controller: _nameCtrl,
                          suffixIcon: _buildCopySuffix(context, _nameCtrl),
                          label: l10n.supplierCompanyNameLabel,
                          icon: Icons.business,
                          isRequired: true,
                          hint: l10n.supplierCompanyNameHint,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            // Supplier Type Dropdown
                            Expanded(
                              child: SearchableDropdownField<String>(
                                value: _supplierTypeOptions.contains(_selectedSupplierType) ? _selectedSupplierType : _supplierTypeOptions.first,
                                labelText: l10n.supplierTypeLabel,
                                items: _supplierTypeOptions
                                    .map((type) => SearchableDropdownItem<String>(
                                          value: type,
                                          label: _getSupplierTypeLabel(context, type),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedSupplierType = val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Registration Type Dropdown
                            Expanded(
                              child: SearchableDropdownField<String>(
                                value: _regTypeOptions.contains(_selectedRegType) ? _selectedRegType : _regTypeOptions.first,
                                labelText: l10n.supplierRegTypeLabel,
                                items: _regTypeOptions
                                    .map((type) => SearchableDropdownItem<String>(
                                          value: type,
                                          label: _getRegTypeLabel(context, type),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedRegType = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _expIdCtrl,
                                suffixIcon: _buildCopySuffix(context, _expIdCtrl),
                                label: l10n.supplierForeignExporterIdLabel,
                                icon: Icons.badge,
                                isRequired: true,
                                hint: l10n.foreignExporterIdHint,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _cargoxPlatformIdCtrl,
                                suffixIcon: _buildCopySuffix(context, _cargoxPlatformIdCtrl),
                                label: l10n.cargoxIdLabel,
                                icon: Icons.verified_user_outlined,
                                hint: l10n.cargoxIdHint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _countryCtrl,
                                suffixIcon: _buildCopySuffix(context, _countryCtrl),
                                label: l10n.supplierCountryLabel,
                                icon: Icons.flag,
                                isRequired: true,
                                hint: l10n.supplierCountryHint,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _countryCodeCtrl,
                                suffixIcon: _buildCopySuffix(context, _countryCodeCtrl),
                                label: l10n.supplierCountryCodeLabel,
                                icon: Icons.code,
                                isRequired: true,
                                hint: l10n.supplierCountryCodeHint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _addressCtrl,
                          suffixIcon: _buildCopySuffix(context, _addressCtrl),
                          label: l10n.supplierAddressLabel,
                          icon: Icons.location_on,
                          isRequired: true,
                          hint: l10n.supplierAddressHint,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _emailCtrl,
                                suffixIcon: _buildCopySuffix(context, _emailCtrl),
                                label: l10n.supplierEmailLabel,
                                icon: Icons.email,
                                hint: l10n.supplierEmailHint,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _secondaryEmailCtrl,
                                suffixIcon: _buildCopySuffix(context, _secondaryEmailCtrl),
                                label: l10n.supplierSecondaryEmailLabel,
                                icon: Icons.mark_email_read_outlined,
                                hint: l10n.supplierSecondaryEmailHint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _phoneCtrl,
                                suffixIcon: _buildCopySuffix(context, _phoneCtrl),
                                label: l10n.supplierPhoneLabel,
                                icon: Icons.phone,
                                hint: l10n.supplierPhoneHint,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _mobileCtrl,
                                suffixIcon: _buildCopySuffix(context, _mobileCtrl),
                                label: l10n.supplierMobileLabel,
                                icon: Icons.smartphone,
                                hint: l10n.supplierMobileHint,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _faxCtrl,
                                suffixIcon: _buildCopySuffix(context, _faxCtrl),
                                label: l10n.supplierFaxLabel,
                                icon: Icons.print,
                                hint: l10n.supplierFaxHint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _websiteCtrl,
                          suffixIcon: _buildCopySuffix(context, _websiteCtrl),
                          label: l10n.supplierWebsiteLabel,
                          icon: Icons.language,
                          hint: l10n.supplierWebsiteHint,
                        ),
                        const SizedBox(height: 16),
                        // Beneficiary Bank & SWIFT Information
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50.withValues(alpha: 0.5),
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
                                  Text(l10n.beneficiaryBankDetailsHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              CustomTextField(
                                controller: _bankNameCtrl,
                                suffixIcon: _buildCopySuffix(context, _bankNameCtrl),
                                label: l10n.beneficiaryBankNameLabel,
                                icon: Icons.business,
                                hint: l10n.beneficiaryBankNameHint,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      controller: _swiftCodeCtrl,
                                      textDirection: TextDirection.ltr,
                                      suffixIcon: _buildCopySuffix(context, _swiftCodeCtrl),
                                      label: l10n.beneficiarySwiftCodeLabel,
                                      icon: Icons.code,
                                      hint: l10n.beneficiarySwiftCodeHint,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: CustomTextField(
                                      controller: _accountNumberCtrl,
                                      suffixIcon: _buildCopySuffix(context, _accountNumberCtrl),
                                      label: l10n.beneficiaryAccountNumberLabel,
                                      icon: Icons.numbers,
                                      hint: l10n.beneficiaryAccountNumberHint,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              CustomTextField(
                                controller: _ibanCtrl,
                                textDirection: TextDirection.ltr,
                                suffixIcon: _buildCopySuffix(context, _ibanCtrl),
                                label: l10n.beneficiaryIbanLabel,
                                icon: Icons.credit_card,
                                hint: l10n.beneficiaryIbanHint,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Compliance Flags Section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.complianceAndCertsHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 8),
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.isoCertifiedCheck),
                                value: _hasIso,
                                activeColor: AppTheme.cobalt,
                                onChanged: (val) => setState(() => _hasIso = val ?? false),
                              ),
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.decree43Check),
                                value: _registeredDecree43,
                                activeColor: AppTheme.cobalt,
                                onChanged: (val) => setState(() => _registeredDecree43 = val ?? false),
                              ),
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.whiteListCheck),
                                value: _whiteListRegistered,
                                activeColor: AppTheme.emerald,
                                onChanged: (val) => setState(() => _whiteListRegistered = val ?? false),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.verified_rounded, size: 18, color: Colors.amber.shade900),
                                  const SizedBox(width: 8),
                                  Text(
                                    isAr ? 'شهادات العلامة التجارية والجودة' : 'Trademark Certificates & ISO',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(isAr ? 'شهادة وايپو مدريد (WIPO)' : 'WIPO Madrid Monitor Certificate'),
                                value: _hasWipo,
                                activeColor: AppTheme.cobalt,
                                onChanged: (val) => setState(() => _hasWipo = val ?? false),
                              ),
                              if (_hasWipo) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: CustomTextField(
                                    controller: _wipoCtrl,
                                    suffixIcon: _buildCopySuffix(context, _wipoCtrl),
                                    label: isAr ? 'رقم تسجيل WIPO Madrid' : 'WIPO Madrid Registration No.',
                                    icon: Icons.numbers,
                                    hint: 'e.g. 1234567',
                                  ),
                                ),
                              ],
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(isAr ? 'شهادة العلامة الأوروبية (EUIPO)' : 'EUIPO Certificate'),
                                value: _hasEuipo,
                                activeColor: AppTheme.cobalt,
                                onChanged: (val) => setState(() => _hasEuipo = val ?? false),
                              ),
                              if (_hasEuipo) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: CustomTextField(
                                    controller: _euipoCtrl,
                                    suffixIcon: _buildCopySuffix(context, _euipoCtrl),
                                    label: isAr ? 'رقم تسجيل EUIPO' : 'EUIPO Registration No.',
                                    icon: Icons.numbers,
                                    hint: 'e.g. 018345678',
                                  ),
                                ),
                              ],
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(isAr ? 'قاعدة بيانات العلامات العالمية' : 'Global Brand Database'),
                                value: _hasGlobalBrand,
                                activeColor: AppTheme.cobalt,
                                onChanged: (val) => setState(() => _hasGlobalBrand = val ?? false),
                              ),
                              if (_hasGlobalBrand) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: CustomTextField(
                                    controller: _globalBrandCtrl,
                                    suffixIcon: _buildCopySuffix(context, _globalBrandCtrl),
                                    label: isAr ? 'معرف العلامة في قاعدة بيانات العلامات العالمية' : 'Global Brand DB Identifier',
                                    icon: Icons.numbers,
                                    hint: 'e.g. GBD-987654',
                                  ),
                                ),
                              ],
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(isAr ? 'شهادة نظام إدارة الجودة (ISO 9001)' : 'ISO 9001 Certificate'),
                                value: _hasIso9001,
                                activeColor: AppTheme.cobalt,
                                onChanged: (val) => setState(() => _hasIso9001 = val ?? false),
                              ),
                              if (_hasIso9001) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: CustomTextField(
                                    controller: _iso9001Ctrl,
                                    suffixIcon: _buildCopySuffix(context, _iso9001Ctrl),
                                    label: isAr ? 'رقم شهادة ISO 9001' : 'ISO 9001 Certificate No.',
                                    icon: Icons.verified_user_outlined,
                                    hint: 'e.g. ISO-9001-2015-XYZ',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _brandsCtrl,
                          suffixIcon: _buildCopySuffix(context, _brandsCtrl),
                          label: l10n.brandsProductLinesLabel,
                          icon: Icons.branding_watermark,
                          hint: l10n.brandsProductLinesHint,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _notesCtrl,
                          suffixIcon: _buildCopySuffix(context, _notesCtrl),
                          label: l10n.supplierNotesLabel,
                          icon: Icons.notes,
                          hint: l10n.supplierNotesHint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Dialog Action Buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadiusDirectional.only(bottomStart: Radius.circular(16), bottomEnd: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.crimson,
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 16, color: AppTheme.crimson),
                      label: Text(l10n.cancelAndCloseBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(isEditing ? l10n.updateSupplierBtn : l10n.saveSupplierBtn),
                      onPressed: _submit,
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
}
