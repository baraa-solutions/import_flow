import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../models/partner_model.dart';
import 'partner_registration/partner_category_specific_fields.dart';
import 'partner_registration/partner_contact_info_fields.dart';
import 'partner_registration/partner_general_info_fields.dart';
import 'partner_registration/partner_registration_form_controllers.dart';
import 'partner_registration/partner_registration_save_handler.dart';

/// نافذة إضافة أو تعديل بيانات الشريك / مقدم الخدمة
class PartnerRegistrationDialog extends ConsumerStatefulWidget {
  final PartnerModel? partnerToEdit;

  const PartnerRegistrationDialog({
    super.key,
    this.partnerToEdit,
  });

  static Future<void> show(BuildContext context,
      [PartnerModel? partnerToEdit]) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) =>
          PartnerRegistrationDialog(partnerToEdit: partnerToEdit),
    );
  }

  @override
  ConsumerState<PartnerRegistrationDialog> createState() =>
      _PartnerRegistrationDialogState();
}

class _PartnerRegistrationDialogState
    extends ConsumerState<PartnerRegistrationDialog> {
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
  late final PartnerRegistrationFormControllers _ctrls;

  @override
  void initState() {
    super.initState();
    final p = widget.partnerToEdit;
    _selectedCategories = p != null ? p.categoriesList.toSet() : <String>{};
    _ctrls = PartnerRegistrationFormControllers(p);
  }

  @override
  void dispose() {
    _ctrls.dispose();
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _selectedCategories.isEmpty) {
      return;
    }

    setState(() => _isSubmitting = true);

    final res = await PartnerRegistrationSaveHandler.save(
      context: context,
      ref: ref,
      partnerToEdit: widget.partnerToEdit,
      selectedCategories: _selectedCategories,
      name: _ctrls.name.text,
      taxId: _ctrls.taxId.text,
      reg: _ctrls.reg.text,
      license: _ctrls.license.text,
      authorizedPorts: _ctrls.authorizedPorts.text,
      transportLicense: _ctrls.transportLicense.text,
      fleetTypes: _ctrls.fleetTypes.text,
      coverageAreas: _ctrls.coverageAreas.text,
      insuranceLicense: _ctrls.insuranceLicense.text,
      insuranceCoverage: _ctrls.insuranceCoverage.text,
      scac: _ctrls.scac.text,
      defaultFreeDays: _ctrls.defaultFreeDays.text,
      paymentTerms: _ctrls.paymentTerms.text,
      creditLimit: _ctrls.creditLimit.text,
      tracking: _ctrls.tracking.text,
      fiata: _ctrls.fiata.text,
      shippingModes: _ctrls.shippingModes.text,
      supportedCurrencies: _ctrls.supportedCurrencies.text,
      accreditation: _ctrls.accreditation.text,
      inspectionScope: _ctrls.inspectionScope.text,
      swift: _ctrls.swift.text,
      bankCode: _ctrls.bankCode.text,
      branch: _ctrls.branch.text,
      phone: _ctrls.phone.text,
      mobile: _ctrls.mobile.text,
      fax: _ctrls.fax.text,
      email: _ctrls.email.text,
      secondaryEmail: _ctrls.secondaryEmail.text,
      website: _ctrls.website.text,
      address: _ctrls.address.text,
      country: _ctrls.country.text,
    );

    if (res == null) {
      if (mounted) {
        Navigator.pop(context);
      }
    } else if (res == 'cancelled') {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    } else {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            res,
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEditing = widget.partnerToEdit != null;
    final isDarkDialog = Theme.of(context).brightness == Brightness.dark;

    final isFreightForwarder = _selectedCategories.contains('Freight Forwarder');

    return Dialog(
      backgroundColor:
          isDarkDialog ? AppTheme.darkCardBackground : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: SizedBox(
          width: 640,
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              // Banner
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: isDarkDialog
                      ? AppTheme.darkElevatedSurface
                      : AppTheme.charcoal,
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
                        Icon(isEditing ? Icons.edit : Icons.add_business,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          isEditing
                              ? l10n.editPartnerDialogTitle
                              : l10n.addPartnerDialogTitle,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
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
                                color: isDarkDialog
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.charcoal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableCategories.map((cat) {
                            final isChecked =
                                _selectedCategories.contains(cat);
                            return FilterChip(
                              label: Text(_getCategoryLabel(context, cat)),
                              selected: isChecked,
                              selectedColor:
                                  AppTheme.cobalt.withValues(alpha: 0.2),
                              checkmarkColor: AppTheme.cobalt,
                              labelStyle: TextStyle(
                                color: isChecked
                                    ? AppTheme.cobalt
                                    : (isDarkDialog
                                        ? AppTheme.darkTextPrimary
                                        : AppTheme.charcoal),
                                fontWeight: isChecked
                                    ? FontWeight.bold
                                    : FontWeight.normal,
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

                        // General info: Name, Tax ID, Reg, Address, Country, Payment Terms
                        PartnerGeneralInfoFields(
                          nameCtrl: _ctrls.name,
                          taxIdCtrl: _ctrls.taxId,
                          regCtrl: _ctrls.reg,
                          addressCtrl: _ctrls.address,
                          countryCtrl: _ctrls.country,
                          paymentTermsCtrl: _ctrls.paymentTerms,
                          creditLimitCtrl: _ctrls.creditLimit,
                          isFreightForwarder: isFreightForwarder,
                        ),
                        const SizedBox(height: 16),

                        // Contact info: Email, Secondary Email, Phone, Mobile, Fax, Website
                        PartnerContactInfoFields(
                          emailCtrl: _ctrls.email,
                          secondaryEmailCtrl: _ctrls.secondaryEmail,
                          phoneCtrl: _ctrls.phone,
                          mobileCtrl: _ctrls.mobile,
                          faxCtrl: _ctrls.fax,
                          websiteCtrl: _ctrls.website,
                        ),
                        const SizedBox(height: 16),

                        // Dynamic Category Fields
                        PartnerCategorySpecificFields(
                          isDarkDialog: isDarkDialog,
                          isBank: _selectedCategories.contains('Bank'),
                          isShippingLine:
                              _selectedCategories.contains('Shipping Line'),
                          isCustomsBroker:
                              _selectedCategories.contains('Customs Broker'),
                          isFreightForwarder: isFreightForwarder,
                          isInlandTransport:
                              _selectedCategories.contains('Inland Transport'),
                          isInspectionAgency:
                              _selectedCategories.contains('Inspection Agency'),
                          isInsuranceCompany:
                              _selectedCategories.contains('Insurance Company'),
                          swiftCtrl: _ctrls.swift,
                          bankCodeCtrl: _ctrls.bankCode,
                          branchCtrl: _ctrls.branch,
                          scacCtrl: _ctrls.scac,
                          defaultFreeDaysCtrl: _ctrls.defaultFreeDays,
                          trackingCtrl: _ctrls.tracking,
                          licenseCtrl: _ctrls.license,
                          authorizedPortsCtrl: _ctrls.authorizedPorts,
                          fiataCtrl: _ctrls.fiata,
                          supportedCurrenciesCtrl: _ctrls.supportedCurrencies,
                          shippingModesCtrl: _ctrls.shippingModes,
                          creditLimitCtrl: _ctrls.creditLimit,
                          transportLicenseCtrl: _ctrls.transportLicense,
                          fleetTypesCtrl: _ctrls.fleetTypes,
                          coverageAreasCtrl: _ctrls.coverageAreas,
                          accreditationCtrl: _ctrls.accreditation,
                          inspectionScopeCtrl: _ctrls.inspectionScope,
                          insuranceLicenseCtrl: _ctrls.insuranceLicense,
                          insuranceCoverageCtrl: _ctrls.insuranceCoverage,
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
                  color: isDarkDialog
                      ? AppTheme.darkElevatedSurface
                      : Colors.grey.shade50,
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
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      label: _isSubmitting
                          ? l10n.savingChanges
                          : (isEditing
                              ? l10n.updatePartnerBtn
                              : l10n.savePartnerBtn),
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
