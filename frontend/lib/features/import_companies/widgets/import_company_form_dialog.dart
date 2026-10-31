import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/import_company_model.dart';
import '../providers/import_companies_provider.dart';

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
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          AppTheme.snackBar(
            context,
            errorMessage,
            severity: AppSeverity.danger,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEditing = widget.companyToEdit != null;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final companyToEdit = widget.companyToEdit;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: SizedBox(
          width: 580,
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              // Dialog Header Banner
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
                        Icon(isEditing ? Icons.edit : Icons.add_business, color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          isEditing ? l10n.editImporterCompanyTitle : l10n.addImporterCompanyTitle,
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

              // Dialog Form Body
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
                          label: l10n.companyNameLabel,
                          icon: Icons.business,
                          isRequired: true,
                          hint: l10n.companyNameHint,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                            tooltip: l10n.importCompaniesCopyFieldTooltip,
                            onPressed: () => CopyHelper.copy(context, _nameCtrl.text),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _addressCtrl,
                                label: l10n.addressLabel,
                                icon: Icons.location_on,
                                isRequired: true,
                                hint: l10n.addressHint,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, _addressCtrl.text),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _countryCtrl,
                                label: l10n.countryLabel,
                                icon: Icons.flag,
                                isRequired: true,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, _countryCtrl.text),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _impIdCtrl,
                                label: l10n.importerCardIdLabel,
                                icon: Icons.badge,
                                isRequired: true,
                                hint: l10n.importerCardIdHint,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, _impIdCtrl.text),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: AppDatePickerField(
                                label: l10n.importerCardExpiryLabel,
                                value: _impExpiry,
                                allowClear: false,
                                isRequired: true,
                                onChanged: (d) {
                                  if (d != null) setState(() => _impExpiry = d);
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
                                controller: _vatIdCtrl,
                                label: l10n.vatRegIdLabel,
                                icon: Icons.receipt_long,
                                isRequired: true,
                                hint: l10n.vatRegIdHint,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, _vatIdCtrl.text),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: AppDatePickerField(
                                label: l10n.vatRegExpiryLabel,
                                value: _vatExpiry,
                                allowClear: false,
                                isRequired: true,
                                onChanged: (d) {
                                  if (d != null) setState(() => _vatExpiry = d);
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
                                controller: _regNumCtrl,
                                label: l10n.commercialRegNumLabel,
                                icon: Icons.app_registration,
                                isRequired: true,
                                hint: l10n.commercialRegNumHint,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, _regNumCtrl.text),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: AppDatePickerField(
                                label: l10n.commercialRegExpiryLabel,
                                value: _regExpiry,
                                allowClear: false,
                                isRequired: true,
                                onChanged: (d) {
                                  if (d != null) setState(() => _regExpiry = d);
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
                                controller: _phoneCtrl,
                                label: l10n.phoneNumberLabel,
                                icon: Icons.phone,
                                hint: l10n.phoneNumberHint,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, _phoneCtrl.text),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _mobileCtrl,
                                label: l10n.importCompaniesMobileLabel,
                                icon: Icons.smartphone,
                                hint: 'e.g. +20 100 123 4567',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, _mobileCtrl.text),
                                ),
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
                                label: l10n.importCompaniesFaxLabel,
                                icon: Icons.print,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, _faxCtrl.text),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _emailCtrl,
                                label: l10n.importCompaniesPrimaryEmailLabel,
                                icon: Icons.email,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, _emailCtrl.text),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _secondaryEmailCtrl,
                                label: l10n.importCompaniesSecondaryEmailLabel,
                                icon: Icons.mark_email_read_outlined,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, _secondaryEmailCtrl.text),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _websiteCtrl,
                                label: l10n.importCompaniesWebsiteLabel,
                                icon: Icons.language,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, _websiteCtrl.text),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
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
                                  const Icon(Icons.vpn_key_rounded, size: 16, color: AppTheme.cobalt),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.importCompaniesNafezaTokenSection,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              CustomTextField(
                                controller: _nafezaTokenCtrl,
                                label: l10n.importCompaniesNafezaTokenLabel,
                                icon: Icons.lock_outline,
                                obscureText: _obscureToken,
                                hint: (companyToEdit?.hasNafezaToken == true) ? (companyToEdit?.maskedNafezaToken ?? '****') : 'NFZ-TK-xxxxxxxx',
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(_obscureToken ? Icons.visibility_off : Icons.visibility, size: 16, color: Colors.grey),
                                      tooltip: _obscureToken ? l10n.importCompaniesShowTokenTooltip : l10n.importCompaniesHideTokenTooltip,
                                      onPressed: () => setState(() => _obscureToken = !_obscureToken),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                      tooltip: l10n.importCompaniesCopyFieldTooltip,
                                      onPressed: () => CopyHelper.copy(context, _nafezaTokenCtrl.text.isNotEmpty ? _nafezaTokenCtrl.text : (companyToEdit?.maskedNafezaToken ?? '')),
                                    ),
                                  ],
                                ),
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
                                    l10n.importCompaniesCertificatesSection,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.importCompaniesWipoTitle),
                                value: _hasWipo,
                                activeColor: AppTheme.cobalt,
                                onChanged: (val) => setState(() => _hasWipo = val ?? false),
                              ),
                              if (_hasWipo) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: CustomTextField(
                                    controller: _wipoCtrl,
                                    label: l10n.importCompaniesWipoRegLabel,
                                    icon: Icons.numbers,
                                    hint: 'e.g. 1234567',
                                  ),
                                ),
                              ],
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.importCompaniesEuipoTitle),
                                value: _hasEuipo,
                                activeColor: AppTheme.cobalt,
                                onChanged: (val) => setState(() => _hasEuipo = val ?? false),
                              ),
                              if (_hasEuipo) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: CustomTextField(
                                    controller: _euipoCtrl,
                                    label: l10n.importCompaniesEuipoRegLabel,
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
                                    label: isAr ? 'رقم شهادة ISO 9001' : 'ISO 9001 Certificate No.',
                                    icon: Icons.verified_user_outlined,
                                    hint: 'e.g. ISO-9001-2015-XYZ',
                                  ),
                                ),
                              ],
                            ],
                          ),
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
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check, size: 18),
                      label: Text(isEditing ? l10n.updateCompanyBtn : l10n.saveCompanyBtn),
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
