import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/import_company_model.dart';
import '../providers/import_companies_provider.dart';
import 'form/company_certificates_fields.dart';
import 'form/company_contact_fields.dart';
import 'form/company_form_header.dart';
import 'form/company_registration_fields.dart';

/// نافذة إضافة أو تعديل بيانات الشركة المستوردة
class ImportCompanyFormDialog extends ConsumerStatefulWidget {
  final ImportCompanyModel? companyToEdit;

  const ImportCompanyFormDialog({
    super.key,
    this.companyToEdit,
  });

  static Future<void> show(BuildContext context, [ImportCompanyModel? companyToEdit]) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => ImportCompanyFormDialog(companyToEdit: companyToEdit),
    );
  }

  @override
  ConsumerState<ImportCompanyFormDialog> createState() => _ImportCompanyFormDialogState();
}

class _ImportCompanyFormDialogState extends ConsumerState<ImportCompanyFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _impIdCtrl;
  late final TextEditingController _vatIdCtrl;
  late final TextEditingController _regNumCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _faxCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _secondaryEmailCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _nafezaTokenCtrl;

  bool _obscureToken = true;
  bool _isSubmitting = false;

  late bool _hasWipo;
  late final TextEditingController _wipoCtrl;
  late bool _hasEuipo;
  late final TextEditingController _euipoCtrl;
  late bool _hasGlobalBrand;
  late final TextEditingController _globalBrandCtrl;
  late bool _hasIso9001;
  late final Map<String, DateTime?> _expiries;
  late final TextEditingController _iso9001Ctrl;

  late DateTime _impExpiry;
  late DateTime _vatExpiry;
  late DateTime _regExpiry;

  @override
  void initState() {
    super.initState();
    final c = widget.companyToEdit;
    _nameCtrl = TextEditingController(text: c?.importerName ?? '');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _countryCtrl = TextEditingController(text: c?.country ?? '');
    _impIdCtrl = TextEditingController(text: c?.importerId ?? '');
    _vatIdCtrl = TextEditingController(text: c?.vatId ?? '');
    _regNumCtrl = TextEditingController(text: c?.registrationNumber ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _mobileCtrl = TextEditingController(text: c?.mobileNumber ?? '');
    _faxCtrl = TextEditingController(text: c?.faxNumber ?? '');
    _emailCtrl = TextEditingController(text: c?.primaryEmail ?? '');
    _secondaryEmailCtrl = TextEditingController(text: c?.secondaryEmail ?? '');
    _websiteCtrl = TextEditingController(text: c?.website ?? '');
    _nafezaTokenCtrl = TextEditingController();

    _hasWipo = c?.hasWipo ?? false;
    _wipoCtrl = TextEditingController(text: c?.wipoNumber ?? '');
    _hasEuipo = c?.hasEuipo ?? false;
    _euipoCtrl = TextEditingController(text: c?.euipoNumber ?? '');
    _hasGlobalBrand = c?.hasGlobalBrand ?? false;
    _globalBrandCtrl = TextEditingController(text: c?.globalBrandNumber ?? '');
    _hasIso9001 = c?.hasIso9001 ?? false;
    _expiries = {
      'nafeza_token': c?.nafezaTokenExpiry,
      'wipo': c?.wipoExpiry,
      'euipo': c?.euipoExpiry,
      'global_brand': c?.globalBrandExpiry,
      'iso_9001': c?.iso9001Expiry,
    };
    _iso9001Ctrl = TextEditingController(text: c?.iso9001Number ?? '');

    _impExpiry = c?.importerIdExpiry ?? DateTime.now().add(const Duration(days: 365));
    _vatExpiry = c?.vatIdExpiry ?? DateTime.now().add(const Duration(days: 365));
    _regExpiry = c?.registrationExpiry ?? DateTime.now().add(const Duration(days: 365));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _countryCtrl.dispose();
    _impIdCtrl.dispose();
    _vatIdCtrl.dispose();
    _regNumCtrl.dispose();
    _phoneCtrl.dispose();
    _mobileCtrl.dispose();
    _faxCtrl.dispose();
    _emailCtrl.dispose();
    _secondaryEmailCtrl.dispose();
    _websiteCtrl.dispose();
    _nafezaTokenCtrl.dispose();
    _wipoCtrl.dispose();
    _euipoCtrl.dispose();
    _globalBrandCtrl.dispose();
    _iso9001Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final companyToEdit = widget.companyToEdit;
      final isEditing = companyToEdit != null;

      final company = ImportCompanyModel(
        companyId: companyToEdit?.companyId,
        importerName: _nameCtrl.text.trim(),
        importerId: _impIdCtrl.text.trim(),
        importerIdExpiry: _impExpiry,
        vatId: _vatIdCtrl.text.trim(),
        vatIdExpiry: _vatExpiry,
        registrationNumber: _regNumCtrl.text.trim(),
        registrationExpiry: _regExpiry,
        country: _countryCtrl.text.trim().isEmpty ? l10n.egyptCountryFallback : _countryCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        mobileNumber: _mobileCtrl.text.trim().isEmpty ? null : _mobileCtrl.text.trim(),
        faxNumber: _faxCtrl.text.trim().isEmpty ? null : _faxCtrl.text.trim(),
        primaryEmail: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        secondaryEmail: _secondaryEmailCtrl.text.trim().isEmpty ? null : _secondaryEmailCtrl.text.trim(),
        website: _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        nafezaToken: _nafezaTokenCtrl.text.trim().isEmpty ? null : _nafezaTokenCtrl.text.trim(),
        hasWipo: _hasWipo,
        wipoNumber: _hasWipo && _wipoCtrl.text.trim().isNotEmpty ? _wipoCtrl.text.trim() : null,
        hasEuipo: _hasEuipo,
        euipoNumber: _hasEuipo && _euipoCtrl.text.trim().isNotEmpty ? _euipoCtrl.text.trim() : null,
        hasGlobalBrand: _hasGlobalBrand,
        globalBrandNumber: _hasGlobalBrand && _globalBrandCtrl.text.trim().isNotEmpty ? _globalBrandCtrl.text.trim() : null,
        hasIso9001: _hasIso9001,
        iso9001Number: _hasIso9001 && _iso9001Ctrl.text.trim().isNotEmpty ? _iso9001Ctrl.text.trim() : null,
        nafezaTokenExpiry: _expiries['nafeza_token'],
        wipoExpiry: _hasWipo ? _expiries['wipo'] : null,
        euipoExpiry: _hasEuipo ? _expiries['euipo'] : null,
        globalBrandExpiry: _hasGlobalBrand ? _expiries['global_brand'] : null,
        iso9001Expiry: _hasIso9001 ? _expiries['iso_9001'] : null,
        isActive: companyToEdit?.isActive ?? true,
      );

      String? errorMessage;
      if (isEditing && companyToEdit.companyId != null) {
        final List<FieldChangeItem> changes = [];
        if (FieldChangeItem.isDifferent(companyToEdit.importerName, company.importerName)) {
          changes.add(FieldChangeItem(fieldName: l10n.diffCompanyName, oldValue: companyToEdit.importerName, newValue: company.importerName));
        }
        if (FieldChangeItem.isDifferent(companyToEdit.importerId, company.importerId)) {
          changes.add(FieldChangeItem(fieldName: l10n.diffImporterCardId, oldValue: companyToEdit.importerId, newValue: company.importerId));
        }
        if (FieldChangeItem.isDifferent(companyToEdit.importerIdExpiry.toString().substring(0, 10), company.importerIdExpiry.toString().substring(0, 10))) {
          changes.add(FieldChangeItem(fieldName: l10n.diffImporterCardExpiry, oldValue: companyToEdit.importerIdExpiry.toString().substring(0, 10), newValue: company.importerIdExpiry.toString().substring(0, 10)));
        }
        if (FieldChangeItem.isDifferent(companyToEdit.vatId, company.vatId)) {
          changes.add(FieldChangeItem(fieldName: l10n.diffVatId, oldValue: companyToEdit.vatId, newValue: company.vatId));
        }
        if (FieldChangeItem.isDifferent(companyToEdit.registrationNumber, company.registrationNumber)) {
          changes.add(FieldChangeItem(fieldName: l10n.diffCommercialReg, oldValue: companyToEdit.registrationNumber, newValue: company.registrationNumber));
        }
        if (FieldChangeItem.isDifferent(companyToEdit.address, company.address)) {
          changes.add(FieldChangeItem(fieldName: l10n.diffAddress, oldValue: companyToEdit.address, newValue: company.address));
        }
        if (FieldChangeItem.isDifferent(companyToEdit.phone, company.phone)) {
          changes.add(FieldChangeItem(fieldName: l10n.diffPhone, oldValue: companyToEdit.phone, newValue: company.phone));
        }
        if (FieldChangeItem.isDifferent(companyToEdit.primaryEmail, company.primaryEmail)) {
          changes.add(FieldChangeItem(fieldName: 'البريد الإلكتروني الأساسي', oldValue: companyToEdit.primaryEmail ?? '—', newValue: company.primaryEmail ?? '—'));
        }
        if (FieldChangeItem.isDifferent(companyToEdit.website, company.website)) {
          changes.add(FieldChangeItem(fieldName: 'الموقع الإلكتروني', oldValue: companyToEdit.website ?? '—', newValue: company.website ?? '—'));
        }
        if (FieldChangeItem.isDifferent(companyToEdit.hasWipo, company.hasWipo)) {
          changes.add(FieldChangeItem(fieldName: 'WIPO Madrid', oldValue: companyToEdit.hasWipo ? 'نعم' : 'لا', newValue: company.hasWipo ? 'نعم' : 'لا'));
        }
        if (FieldChangeItem.isDifferent(companyToEdit.hasIso9001, company.hasIso9001)) {
          changes.add(FieldChangeItem(fieldName: 'ISO 9001', oldValue: companyToEdit.hasIso9001 ? 'نعم' : 'لا', newValue: company.hasIso9001 ? 'نعم' : 'لا'));
        }

        if (changes.isNotEmpty) {
          final confirmed = await showChangeDiffConfirmationDialog(
            context,
            title: l10n.diffConfirmCompanyTitle,
            itemReference: companyToEdit.importerName,
            changes: changes,
          );
          if (!confirmed) return;
        }

        errorMessage = await ref.read(importCompaniesProvider.notifier).updateCompany(companyToEdit.companyId!, company);
      } else {
        errorMessage = await ref.read(importCompaniesProvider.notifier).createCompany(company);
      }

      if (errorMessage == null) {
        if (mounted) Navigator.pop(context);
      } else {
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
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEditing = widget.companyToEdit != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: SizedBox(
          width: 580,
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              CompanyFormHeader(
                isEditing: isEditing,
                onClose: () => Navigator.pop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CompanyRegistrationFields(
                          nameCtrl: _nameCtrl,
                          addressCtrl: _addressCtrl,
                          countryCtrl: _countryCtrl,
                          impIdCtrl: _impIdCtrl,
                          vatIdCtrl: _vatIdCtrl,
                          regNumCtrl: _regNumCtrl,
                          impExpiry: _impExpiry,
                          vatExpiry: _vatExpiry,
                          regExpiry: _regExpiry,
                          onImpExpiryChanged: (d) => setState(() => _impExpiry = d),
                          onVatExpiryChanged: (d) => setState(() => _vatExpiry = d),
                          onRegExpiryChanged: (d) => setState(() => _regExpiry = d),
                        ),
                        const SizedBox(height: 16),
                        CompanyContactFields(
                          phoneCtrl: _phoneCtrl,
                          mobileCtrl: _mobileCtrl,
                          faxCtrl: _faxCtrl,
                          emailCtrl: _emailCtrl,
                          secondaryEmailCtrl: _secondaryEmailCtrl,
                          websiteCtrl: _websiteCtrl,
                        ),
                        const SizedBox(height: 16),
                        CompanyCertificatesFields(
                          companyToEdit: widget.companyToEdit,
                          nafezaTokenCtrl: _nafezaTokenCtrl,
                          obscureToken: _obscureToken,
                          onToggleObscure: () => setState(() => _obscureToken = !_obscureToken),
                          hasWipo: _hasWipo,
                          wipoCtrl: _wipoCtrl,
                          onWipoChanged: (v) => setState(() => _hasWipo = v ?? false),
                          hasEuipo: _hasEuipo,
                          euipoCtrl: _euipoCtrl,
                          onEuipoChanged: (v) => setState(() => _hasEuipo = v ?? false),
                          hasGlobalBrand: _hasGlobalBrand,
                          globalBrandCtrl: _globalBrandCtrl,
                          onGlobalBrandChanged: (v) => setState(() => _hasGlobalBrand = v ?? false),
                          hasIso9001: _hasIso9001,
                          iso9001Ctrl: _iso9001Ctrl,
                          onIso9001Changed: (v) => setState(() => _hasIso9001 = v ?? false),
                          expiries: _expiries,
                          onExpiryChanged: (key, value) => setState(() => _expiries[key] = value),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(top: BorderSide(color: AppTheme.borderOf(context))),
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
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      label: isEditing ? l10n.updateCompanyBtn : l10n.saveCompanyBtn,
                      icon: Icons.check,
                      variant: AppButtonVariant.primary,
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _submit,
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
