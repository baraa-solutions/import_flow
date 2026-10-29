import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/change_diff_dialog.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../models/partner_model.dart';
import '../providers/partners_provider.dart';

/// نافذة إضافة أو تعديل بيانات الشريك / مقدم الخدمة
class PartnerRegistrationDialog extends ConsumerStatefulWidget {
  final PartnerModel? partnerToEdit;

  const PartnerRegistrationDialog({
    super.key,
    this.partnerToEdit,
  });

  static Future<void> show(BuildContext context, [PartnerModel? partnerToEdit]) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PartnerRegistrationDialog(partnerToEdit: partnerToEdit),
    );
  }

  @override
  ConsumerState<PartnerRegistrationDialog> createState() => _PartnerRegistrationDialogState();
}

class _PartnerRegistrationDialogState extends ConsumerState<PartnerRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();

  static const List<String> _availableCategories = [
    'Bank',
    'Shipping Line',
    'Customs Broker',
    'Freight Forwarder',
    'Inland Transport',
    'Inspection Agency',
    'Insurance Company',
  ];

  late Set<String> _selectedCategories;
  bool _isSubmitting = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _taxIdCtrl;
  late final TextEditingController _regCtrl;
  late final TextEditingController _licenseCtrl;
  late final TextEditingController _authorizedPortsCtrl;
  late final TextEditingController _transportLicenseCtrl;
  late final TextEditingController _fleetTypesCtrl;
  late final TextEditingController _coverageAreasCtrl;
  late final TextEditingController _insuranceLicenseCtrl;
  late final TextEditingController _insuranceCoverageCtrl;
  late final TextEditingController _scacCtrl;
  late final TextEditingController _defaultFreeDaysCtrl;
  late final TextEditingController _paymentTermsCtrl;
  late final TextEditingController _creditLimitCtrl;
  late final TextEditingController _trackingCtrl;
  late final TextEditingController _fiataCtrl;
  late final TextEditingController _shippingModesCtrl;
  late final TextEditingController _supportedCurrenciesCtrl;
  late final TextEditingController _accreditationCtrl;
  late final TextEditingController _inspectionScopeCtrl;
  late final TextEditingController _swiftCtrl;
  late final TextEditingController _bankCodeCtrl;
  late final TextEditingController _branchCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _faxCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _secondaryEmailCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _countryCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.partnerToEdit;
    _selectedCategories = p != null ? p.categoriesList.toSet() : <String>{};

    _nameCtrl = TextEditingController(text: p?.partnerName ?? '');
    _taxIdCtrl = TextEditingController(text: p?.taxId ?? '');
    _regCtrl = TextEditingController(text: p?.commercialRegister ?? '');
    _licenseCtrl = TextEditingController(text: p?.clearanceLicenseNumber ?? '');
    _authorizedPortsCtrl = TextEditingController(text: p?.authorizedPorts ?? '');
    _transportLicenseCtrl = TextEditingController(text: p?.transportLicenseNumber ?? '');
    _fleetTypesCtrl = TextEditingController(text: p?.fleetTypes ?? '');
    _coverageAreasCtrl = TextEditingController(text: p?.coverageAreas ?? '');
    _insuranceLicenseCtrl = TextEditingController(text: p?.insuranceLicenseNumber ?? '');
    _insuranceCoverageCtrl = TextEditingController(text: p?.insuranceCoverageTypes ?? '');
    _scacCtrl = TextEditingController(text: p?.scacCode ?? '');
    _defaultFreeDaysCtrl = TextEditingController(
      text: p?.defaultFreeDays != null ? p!.defaultFreeDays.toString() : '',
    );
    _paymentTermsCtrl = TextEditingController(text: p?.paymentTerms ?? '');
    _creditLimitCtrl = TextEditingController(
      text: p?.creditLimit != null ? p!.creditLimit.toString() : '',
    );
    _trackingCtrl = TextEditingController(text: p?.trackingUrl ?? '');
    _fiataCtrl = TextEditingController(text: p?.fiataId ?? '');
    _shippingModesCtrl = TextEditingController(text: p?.shippingModes ?? '');
    _supportedCurrenciesCtrl = TextEditingController(text: p?.supportedCurrencies ?? '');
    _accreditationCtrl = TextEditingController(text: p?.inspectionAccreditationNumber ?? '');
    _inspectionScopeCtrl = TextEditingController(text: p?.inspectionScope ?? '');
    _swiftCtrl = TextEditingController(text: p?.swiftCode ?? '');
    _bankCodeCtrl = TextEditingController(text: p?.bankCode ?? '');
    _branchCtrl = TextEditingController(text: p?.branchName ?? '');
    _phoneCtrl = TextEditingController(text: p?.phone ?? '');
    _mobileCtrl = TextEditingController(text: p?.mobile ?? '');
    _faxCtrl = TextEditingController(text: p?.fax ?? '');
    _emailCtrl = TextEditingController(text: p?.email ?? '');
    _secondaryEmailCtrl = TextEditingController(text: p?.secondaryEmail ?? '');
    _websiteCtrl = TextEditingController(text: p?.website ?? '');
    _addressCtrl = TextEditingController(text: p?.address ?? '');
    _countryCtrl = TextEditingController(text: p?.country ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taxIdCtrl.dispose();
    _regCtrl.dispose();
    _licenseCtrl.dispose();
    _authorizedPortsCtrl.dispose();
    _transportLicenseCtrl.dispose();
    _fleetTypesCtrl.dispose();
    _coverageAreasCtrl.dispose();
    _insuranceLicenseCtrl.dispose();
    _insuranceCoverageCtrl.dispose();
    _scacCtrl.dispose();
    _defaultFreeDaysCtrl.dispose();
    _paymentTermsCtrl.dispose();
    _creditLimitCtrl.dispose();
    _trackingCtrl.dispose();
    _fiataCtrl.dispose();
    _shippingModesCtrl.dispose();
    _supportedCurrenciesCtrl.dispose();
    _accreditationCtrl.dispose();
    _inspectionScopeCtrl.dispose();
    _swiftCtrl.dispose();
    _bankCodeCtrl.dispose();
    _branchCtrl.dispose();
    _phoneCtrl.dispose();
    _mobileCtrl.dispose();
    _faxCtrl.dispose();
    _emailCtrl.dispose();
    _secondaryEmailCtrl.dispose();
    _websiteCtrl.dispose();
    _addressCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  String _getCategoryLabel(BuildContext context, String cat) {
    final l10n = context.l10n;
    switch (cat) {
      case 'Bank':
        return l10n.partnerCatBank;
      case 'Shipping Line':
        return l10n.partnerCatShippingLine;
      case 'Customs Broker':
        return l10n.partnerCatCustomsBroker;
      case 'Freight Forwarder':
        return l10n.partnerCatFreightForwarder;
      case 'Inland Transport':
        return l10n.partnerCatInlandTransport;
      case 'Inspection Agency':
        return l10n.partnerCatInspectionAgency;
      case 'Insurance Company':
        return l10n.partnerCatInsuranceCompany;
      default:
        return cat;
    }
  }

  Widget _buildCopySuffix(TextEditingController ctrl) {
    final l10n = context.l10n;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (ctx, val, _) {
        if (val.text.trim().isEmpty) return const SizedBox.shrink();
        return Tooltip(
          message: l10n.partnersCopyFieldTooltip,
          child: InkWell(
            onTap: () => CopyHelper.copy(
              context,
              val.text.trim(),
              customMessage: l10n.copiedToClipboard(val.text.trim()),
            ),
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.copy_rounded, size: 15, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSave() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate() || _selectedCategories.isEmpty) {
      return;
    }

    setState(() => _isSubmitting = true);

    final isBank = _selectedCategories.contains('Bank');
    final isShippingLine = _selectedCategories.contains('Shipping Line');
    final isCustomsBroker = _selectedCategories.contains('Customs Broker');
    final isFreightForwarder = _selectedCategories.contains('Freight Forwarder');
    final isInspectionAgency = _selectedCategories.contains('Inspection Agency');
    final isInlandTransport = _selectedCategories.contains('Inland Transport');
    final isInsuranceCompany = _selectedCategories.contains('Insurance Company');

    final partnerTypeJoined = _selectedCategories.join(', ');
    final partnerToEdit = widget.partnerToEdit;
    final isEditing = partnerToEdit != null;

    final partner = PartnerModel(
      providerId: partnerToEdit?.providerId,
      partnerCode: partnerToEdit?.partnerCode ?? '',
      partnerName: _nameCtrl.text.trim(),
      partnerType: partnerTypeJoined,
      taxId: _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
      commercialRegister: _regCtrl.text.trim().isEmpty ? null : _regCtrl.text.trim(),
      clearanceLicenseNumber: isCustomsBroker ? (_licenseCtrl.text.trim().isEmpty ? null : _licenseCtrl.text.trim()) : null,
      authorizedPorts: isCustomsBroker ? (_authorizedPortsCtrl.text.trim().isEmpty ? null : _authorizedPortsCtrl.text.trim()) : null,
      transportLicenseNumber: isInlandTransport ? (_transportLicenseCtrl.text.trim().isEmpty ? null : _transportLicenseCtrl.text.trim()) : null,
      fleetTypes: isInlandTransport ? (_fleetTypesCtrl.text.trim().isEmpty ? null : _fleetTypesCtrl.text.trim()) : null,
      coverageAreas: isInlandTransport ? (_coverageAreasCtrl.text.trim().isEmpty ? null : _coverageAreasCtrl.text.trim()) : null,
      insuranceLicenseNumber: isInsuranceCompany ? (_insuranceLicenseCtrl.text.trim().isEmpty ? null : _insuranceLicenseCtrl.text.trim()) : null,
      insuranceCoverageTypes: isInsuranceCompany ? (_insuranceCoverageCtrl.text.trim().isEmpty ? null : _insuranceCoverageCtrl.text.trim()) : null,
      scacCode: scacCtrlText(),
      trackingUrl: _trackingCtrl.text.trim().isEmpty ? null : _trackingCtrl.text.trim(),
      defaultFreeDays: (isShippingLine || isFreightForwarder) ? int.tryParse(_defaultFreeDaysCtrl.text.trim()) : null,
      paymentTerms: _paymentTermsCtrl.text.trim().isEmpty ? null : _paymentTermsCtrl.text.trim(),
      creditLimit: double.tryParse(_creditLimitCtrl.text.trim()) ?? (partnerToEdit?.creditLimit ?? 0.0),
      fiataId: isFreightForwarder ? (_fiataCtrl.text.trim().isEmpty ? null : _fiataCtrl.text.trim()) : null,
      shippingModes: isFreightForwarder ? (_shippingModesCtrl.text.trim().isEmpty ? null : _shippingModesCtrl.text.trim()) : null,
      supportedCurrencies: isFreightForwarder ? (_supportedCurrenciesCtrl.text.trim().isEmpty ? null : _supportedCurrenciesCtrl.text.trim()) : null,
      inspectionAccreditationNumber: isInspectionAgency ? (_accreditationCtrl.text.trim().isEmpty ? null : _accreditationCtrl.text.trim()) : null,
      inspectionScope: isInspectionAgency ? (_inspectionScopeCtrl.text.trim().isEmpty ? null : _inspectionScopeCtrl.text.trim()) : null,
      swiftCode: isBank ? (_swiftCtrl.text.trim().isEmpty ? null : _swiftCtrl.text.trim()) : null,
      bankCode: isBank ? (_bankCodeCtrl.text.trim().isEmpty ? null : _bankCodeCtrl.text.trim()) : null,
      branchName: isBank ? (_branchCtrl.text.trim().isEmpty ? null : _branchCtrl.text.trim()) : null,
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      secondaryEmail: _secondaryEmailCtrl.text.trim().isEmpty ? null : _secondaryEmailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim().isEmpty ? null : _mobileCtrl.text.trim(),
      fax: _faxCtrl.text.trim().isEmpty ? null : _faxCtrl.text.trim(),
      website: _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      country: _countryCtrl.text.trim(),
      isActive: partnerToEdit?.isActive ?? true,
    );

    String? errorMessage;
    if (isEditing && partnerToEdit.providerId != null) {
      final List<FieldChangeItem> changes = [];
      if (FieldChangeItem.isDifferent(partnerToEdit.partnerName, partner.partnerName)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffPartnerName, oldValue: partnerToEdit.partnerName, newValue: partner.partnerName));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.partnerType, partner.partnerType)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffPartnerType, oldValue: partnerToEdit.partnerType, newValue: partner.partnerType));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.fiataId, partner.fiataId)) {
        changes.add(FieldChangeItem(fieldName: l10n.fiataLicenseLabel, oldValue: partnerToEdit.fiataId ?? '—', newValue: partner.fiataId ?? '—'));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.shippingModes, partner.shippingModes)) {
        changes.add(FieldChangeItem(fieldName: l10n.shippingModesLabel, oldValue: partnerToEdit.shippingModes ?? '—', newValue: partner.shippingModes ?? '—'));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.supportedCurrencies, partner.supportedCurrencies)) {
        changes.add(FieldChangeItem(fieldName: l10n.supportedCurrenciesLabel, oldValue: partnerToEdit.supportedCurrencies ?? '—', newValue: partner.supportedCurrencies ?? '—'));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.inspectionAccreditationNumber, partner.inspectionAccreditationNumber)) {
        changes.add(FieldChangeItem(fieldName: l10n.inspectionAccreditationNumLabel, oldValue: partnerToEdit.inspectionAccreditationNumber ?? '—', newValue: partner.inspectionAccreditationNumber ?? '—'));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.inspectionScope, partner.inspectionScope)) {
        changes.add(FieldChangeItem(fieldName: l10n.inspectionScopeLabel, oldValue: partnerToEdit.inspectionScope ?? '—', newValue: partner.inspectionScope ?? '—'));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.clearanceLicenseNumber, partner.clearanceLicenseNumber)) {
        changes.add(FieldChangeItem(fieldName: l10n.customsClearanceLicenseNumLabel, oldValue: partnerToEdit.clearanceLicenseNumber ?? '—', newValue: partner.clearanceLicenseNumber ?? '—'));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.authorizedPorts, partner.authorizedPorts)) {
        changes.add(FieldChangeItem(fieldName: l10n.authorizedPortsLabel, oldValue: partnerToEdit.authorizedPorts ?? '—', newValue: partner.authorizedPorts ?? '—'));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.transportLicenseNumber, partner.transportLicenseNumber)) {
        changes.add(FieldChangeItem(fieldName: l10n.transportLicenseNumLabel, oldValue: partnerToEdit.transportLicenseNumber ?? '—', newValue: partner.transportLicenseNumber ?? '—'));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.fleetTypes, partner.fleetTypes)) {
        changes.add(FieldChangeItem(fieldName: l10n.fleetTypesLabel, oldValue: partnerToEdit.fleetTypes ?? '—', newValue: partner.fleetTypes ?? '—'));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.coverageAreas, partner.coverageAreas)) {
        changes.add(FieldChangeItem(fieldName: l10n.coverageAreasLabel, oldValue: partnerToEdit.coverageAreas ?? '—', newValue: partner.coverageAreas ?? '—'));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.insuranceLicenseNumber, partner.insuranceLicenseNumber)) {
        changes.add(FieldChangeItem(fieldName: l10n.insuranceLicenseNumLabel, oldValue: partnerToEdit.insuranceLicenseNumber ?? '—', newValue: partner.insuranceLicenseNumber ?? '—'));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.insuranceCoverageTypes, partner.insuranceCoverageTypes)) {
        changes.add(FieldChangeItem(fieldName: l10n.insuranceCoverageTypesLabel, oldValue: partnerToEdit.insuranceCoverageTypes ?? '—', newValue: partner.insuranceCoverageTypes ?? '—'));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.email, partner.email)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffPartnerEmail, oldValue: partnerToEdit.email, newValue: partner.email));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.phone, partner.phone)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffPartnerPhone, oldValue: partnerToEdit.phone, newValue: partner.phone));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.address, partner.address)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffPartnerAddress, oldValue: partnerToEdit.address, newValue: partner.address));
      }
      if (FieldChangeItem.isDifferent(partnerToEdit.country, partner.country)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffPartnerCountry, oldValue: partnerToEdit.country, newValue: partner.country));
      }

      if (changes.isNotEmpty) {
        final confirmed = await showChangeDiffConfirmationDialog(
          context,
          title: l10n.diffConfirmPartnerTitle,
          itemReference: '${partnerToEdit.partnerCode} (${partnerToEdit.partnerName})',
          changes: changes,
        );
        if (!confirmed) {
          setState(() => _isSubmitting = false);
          return;
        }
      }

      errorMessage = await ref.read(partnersProvider.notifier).updatePartner(partnerToEdit.providerId!, partner);
    } else {
      errorMessage = await ref.read(partnersProvider.notifier).createPartner(partner);
    }

    if (errorMessage == null) {
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            errorMessage,
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

  String? scacCtrlText() => _selectedCategories.contains('Shipping Line')
      ? (_scacCtrl.text.trim().isEmpty ? null : _scacCtrl.text.trim())
      : null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEditing = widget.partnerToEdit != null;
    final isDarkDialog = Theme.of(context).brightness == Brightness.dark;

    final isBank = _selectedCategories.contains('Bank');
    final isShippingLine = _selectedCategories.contains('Shipping Line');
    final isCustomsBroker = _selectedCategories.contains('Customs Broker');
    final isFreightForwarder = _selectedCategories.contains('Freight Forwarder');
    final isInspectionAgency = _selectedCategories.contains('Inspection Agency');
    final isInlandTransport = _selectedCategories.contains('Inland Transport');
    final isInsuranceCompany = _selectedCategories.contains('Insurance Company');

    return Dialog(
      backgroundColor: isDarkDialog ? AppTheme.darkCardBackground : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: SizedBox(
          width: 640,
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              // Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: isDarkDialog ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                  borderRadius: const BorderRadiusDirectional.only(
                    topStart: Radius.circular(16),
                    topEnd: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(isEditing ? Icons.edit : Icons.add_business, color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          isEditing ? l10n.editPartnerDialogTitle : l10n.addPartnerDialogTitle,
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

              // Scrollable Form Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Multi-Select Partner Categories
                        Row(
                          children: [
                            Text(
                              l10n.partnerCategoriesLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isDarkDialog ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableCategories.map((cat) {
                            final isChecked = _selectedCategories.contains(cat);
                            return FilterChip(
                              label: Text(_getCategoryLabel(context, cat)),
                              selected: isChecked,
                              selectedColor: AppTheme.cobalt.withValues(alpha: 0.2),
                              checkmarkColor: AppTheme.cobalt,
                              labelStyle: TextStyle(
                                color: isChecked
                                    ? AppTheme.cobalt
                                    : (isDarkDialog ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (bool selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategories.add(cat);
                                  } else {
                                    if (_selectedCategories.length > 1) {
                                      _selectedCategories.remove(cat);
                                    }
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          controller: _nameCtrl,
                          suffixIcon: _buildCopySuffix(_nameCtrl),
                          label: l10n.partnerNameLabel,
                          icon: Icons.business,
                          isRequired: true,
                          hint: l10n.partnerNameHint,
                        ),
                        const SizedBox(height: 16),

                        // Dynamic Category Fields
                        if (isBank) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🏦 ${l10n.bankingDetailsHeader}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomTextField(
                                        controller: _swiftCtrl,
                                        textDirection: TextDirection.ltr,
                                        suffixIcon: _buildCopySuffix(_swiftCtrl),
                                        label: l10n.bankSwiftCodeLabel,
                                        icon: Icons.code,
                                        isRequired: true,
                                        hint: l10n.bankSwiftCodeHint,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CustomTextField(
                                        controller: _bankCodeCtrl,
                                        suffixIcon: _buildCopySuffix(_bankCodeCtrl),
                                        label: l10n.bankCodeLabel,
                                        icon: Icons.account_balance,
                                        hint: l10n.bankCodeHint,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                CustomTextField(
                                  controller: _branchCtrl,
                                  suffixIcon: _buildCopySuffix(_branchCtrl),
                                  label: l10n.branchNameLabel,
                                  icon: Icons.location_city,
                                  hint: l10n.branchNameHint,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (isShippingLine) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🚢 ${l10n.shippingLineDetailsHeader}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomTextField(
                                        controller: _scacCtrl,
                                        suffixIcon: _buildCopySuffix(_scacCtrl),
                                        label: l10n.scacCarrierCodeLabel,
                                        icon: Icons.code,
                                        isRequired: true,
                                        hint: l10n.scacCarrierCodeHint,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CustomTextField(
                                        controller: _defaultFreeDaysCtrl,
                                        suffixIcon: _buildCopySuffix(_defaultFreeDaysCtrl),
                                        label: l10n.defaultFreeDaysLabel,
                                        icon: Icons.timer_outlined,
                                        isRequired: true,
                                        keyboardType: TextInputType.number,
                                        hint: l10n.defaultFreeDaysHint,
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) return l10n.fieldRequired;
                                          final parsed = int.tryParse(val.trim());
                                          if (parsed == null || parsed < 0) return l10n.defaultFreeDaysHint;
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                CustomTextField(
                                  controller: _trackingCtrl,
                                  suffixIcon: _buildCopySuffix(_trackingCtrl),
                                  label: l10n.trackingWebUrlLabel,
                                  icon: Icons.link,
                                  hint: l10n.trackingWebUrlHint,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (isCustomsBroker) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.orange.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.orange.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🛂 ${l10n.customsBrokerLicenseHeader}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange)),
                                const SizedBox(height: 10),
                                CustomTextField(
                                  controller: _licenseCtrl,
                                  suffixIcon: _buildCopySuffix(_licenseCtrl),
                                  label: l10n.customsClearanceLicenseNumLabel,
                                  icon: Icons.assignment_ind,
                                  isRequired: true,
                                  hint: l10n.customsClearanceLicenseNumHint,
                                ),
                                const SizedBox(height: 10),
                                CustomTextField(
                                  controller: _authorizedPortsCtrl,
                                  suffixIcon: _buildCopySuffix(_authorizedPortsCtrl),
                                  label: l10n.authorizedPortsLabel,
                                  icon: Icons.anchor_outlined,
                                  hint: l10n.authorizedPortsHint,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (isFreightForwarder) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.charcoal.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.charcoal.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '📦 ${l10n.freightForwarderDetailsHeader}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDarkDialog ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomTextField(
                                        controller: _fiataCtrl,
                                        suffixIcon: _buildCopySuffix(_fiataCtrl),
                                        label: l10n.fiataLicenseLabel,
                                        icon: Icons.badge_outlined,
                                        hint: l10n.fiataLicenseHint,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CustomTextField(
                                        controller: _supportedCurrenciesCtrl,
                                        suffixIcon: _buildCopySuffix(_supportedCurrenciesCtrl),
                                        label: l10n.supportedCurrenciesLabel,
                                        icon: Icons.monetization_on_outlined,
                                        hint: l10n.supportedCurrenciesHint,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                CustomTextField(
                                  controller: _shippingModesCtrl,
                                  suffixIcon: _buildCopySuffix(_shippingModesCtrl),
                                  label: l10n.shippingModesLabel,
                                  icon: Icons.alt_route_rounded,
                                  hint: l10n.shippingModesHint,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomTextField(
                                        controller: _defaultFreeDaysCtrl,
                                        suffixIcon: _buildCopySuffix(_defaultFreeDaysCtrl),
                                        label: '${l10n.defaultFreeDaysLabel} (إلزامي)',
                                        icon: Icons.timer_outlined,
                                        isRequired: true,
                                        keyboardType: TextInputType.number,
                                        hint: l10n.defaultFreeDaysHint,
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) return l10n.fieldRequired;
                                          final parsed = int.tryParse(val.trim());
                                          if (parsed == null || parsed < 0) return l10n.defaultFreeDaysHint;
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CustomTextField(
                                        controller: _creditLimitCtrl,
                                        suffixIcon: _buildCopySuffix(_creditLimitCtrl),
                                        label: l10n.creditLimitDetailLabel,
                                        icon: Icons.account_balance_wallet_outlined,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        hint: '0.00',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (isInlandTransport) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🚛 ${l10n.inlandTransportDetailsHeader}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                const SizedBox(height: 10),
                                CustomTextField(
                                  controller: _transportLicenseCtrl,
                                  suffixIcon: _buildCopySuffix(_transportLicenseCtrl),
                                  label: l10n.transportLicenseNumLabel,
                                  icon: Icons.local_shipping_outlined,
                                  isRequired: true,
                                  hint: l10n.transportLicenseNumHint,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomTextField(
                                        controller: _fleetTypesCtrl,
                                        suffixIcon: _buildCopySuffix(_fleetTypesCtrl),
                                        label: l10n.fleetTypesLabel,
                                        icon: Icons.fire_truck_outlined,
                                        hint: l10n.fleetTypesHint,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CustomTextField(
                                        controller: _coverageAreasCtrl,
                                        suffixIcon: _buildCopySuffix(_coverageAreasCtrl),
                                        label: l10n.coverageAreasLabel,
                                        icon: Icons.map_outlined,
                                        hint: l10n.coverageAreasHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (isInspectionAgency) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🔍 ${l10n.inspectionAgencyDetailsHeader}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                                const SizedBox(height: 10),
                                CustomTextField(
                                  controller: _accreditationCtrl,
                                  suffixIcon: _buildCopySuffix(_accreditationCtrl),
                                  label: l10n.inspectionAccreditationNumLabel,
                                  icon: Icons.verified_user_outlined,
                                  isRequired: true,
                                  hint: l10n.inspectionAccreditationNumHint,
                                ),
                                const SizedBox(height: 10),
                                CustomTextField(
                                  controller: _inspectionScopeCtrl,
                                  suffixIcon: _buildCopySuffix(_inspectionScopeCtrl),
                                  label: l10n.inspectionScopeLabel,
                                  icon: Icons.rule_folder_outlined,
                                  hint: l10n.inspectionScopeHint,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (isInsuranceCompany) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🛡️ ${l10n.insuranceDetailsHeader}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                const SizedBox(height: 10),
                                CustomTextField(
                                  controller: _insuranceLicenseCtrl,
                                  suffixIcon: _buildCopySuffix(_insuranceLicenseCtrl),
                                  label: l10n.insuranceLicenseNumLabel,
                                  icon: Icons.verified_user_outlined,
                                  isRequired: true,
                                  hint: l10n.insuranceLicenseNumHint,
                                ),
                                const SizedBox(height: 10),
                                CustomTextField(
                                  controller: _insuranceCoverageCtrl,
                                  suffixIcon: _buildCopySuffix(_insuranceCoverageCtrl),
                                  label: l10n.insuranceCoverageTypesLabel,
                                  icon: Icons.health_and_safety_outlined,
                                  hint: l10n.insuranceCoverageTypesHint,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Registration & Tax Identifiers
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _taxIdCtrl,
                                suffixIcon: _buildCopySuffix(_taxIdCtrl),
                                label: l10n.partnerTaxIdLabel,
                                icon: Icons.receipt_long,
                                hint: l10n.partnerTaxIdHint,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomTextField(
                                controller: _regCtrl,
                                suffixIcon: _buildCopySuffix(_regCtrl),
                                label: l10n.partnerCommercialRegLabel,
                                icon: Icons.description_outlined,
                                hint: l10n.partnerCommercialRegHint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Contact Details
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _emailCtrl,
                                textDirection: TextDirection.ltr,
                                suffixIcon: _buildCopySuffix(_emailCtrl),
                                label: l10n.partnerPrimaryEmailLabel,
                                icon: Icons.email,
                                hint: l10n.partnerPrimaryEmailHint,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomTextField(
                                controller: _secondaryEmailCtrl,
                                textDirection: TextDirection.ltr,
                                suffixIcon: _buildCopySuffix(_secondaryEmailCtrl),
                                label: l10n.partnerSecondaryEmailLabel,
                                icon: Icons.alternate_email,
                                hint: l10n.partnerSecondaryEmailHint,
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
                                textDirection: TextDirection.ltr,
                                suffixIcon: _buildCopySuffix(_phoneCtrl),
                                label: l10n.partnerPhoneLabel,
                                icon: Icons.phone,
                                hint: l10n.partnerPhoneHint,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomTextField(
                                controller: _mobileCtrl,
                                textDirection: TextDirection.ltr,
                                suffixIcon: _buildCopySuffix(_mobileCtrl),
                                label: l10n.partnerMobileLabel,
                                icon: Icons.phone_android,
                                hint: l10n.partnerMobileHint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _faxCtrl,
                                textDirection: TextDirection.ltr,
                                suffixIcon: _buildCopySuffix(_faxCtrl),
                                label: l10n.partnerFaxLabel,
                                icon: Icons.print_outlined,
                                hint: l10n.partnerFaxHint,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomTextField(
                                controller: _websiteCtrl,
                                textDirection: TextDirection.ltr,
                                suffixIcon: _buildCopySuffix(_websiteCtrl),
                                label: l10n.partnerWebsiteUrlLabel,
                                icon: Icons.language,
                                hint: l10n.partnerWebsiteUrlHint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: CustomTextField(
                                controller: _addressCtrl,
                                suffixIcon: _buildCopySuffix(_addressCtrl),
                                label: l10n.partnerAddressLabel,
                                icon: Icons.location_on,
                                hint: l10n.partnerAddressHint,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: CustomTextField(
                                controller: _countryCtrl,
                                suffixIcon: _buildCopySuffix(_countryCtrl),
                                label: l10n.countryLabel,
                                icon: Icons.public,
                                hint: l10n.countryHint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _paymentTermsCtrl,
                                suffixIcon: _buildCopySuffix(_paymentTermsCtrl),
                                label: l10n.paymentTermsDetailLabel,
                                icon: Icons.payment,
                                hint: 'e.g. Net 30',
                              ),
                            ),
                            if (!isFreightForwarder) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: CustomTextField(
                                  controller: _creditLimitCtrl,
                                  suffixIcon: _buildCopySuffix(_creditLimitCtrl),
                                  label: l10n.creditLimitDetailLabel,
                                  icon: Icons.account_balance_wallet_outlined,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  hint: '0.00',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Actions Footer
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkDialog ? AppTheme.darkElevatedSurface : Colors.grey.shade50,
                  borderRadius: const BorderRadiusDirectional.only(
                    bottomStart: Radius.circular(16),
                    bottomEnd: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: l10n.cancelAndCloseBtn,
                      variant: AppButtonVariant.secondary,
                      icon: Icons.close,
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      label: _isSubmitting
                          ? l10n.savingChanges
                          : (isEditing ? l10n.updatePartnerBtn : l10n.savePartnerBtn),
                      variant: AppButtonVariant.primary,
                      icon: Icons.check,
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _handleSave,
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
