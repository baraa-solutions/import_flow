import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/supplier_model.dart';
import 'form/supplier_bank_compliance_section.dart';
import 'form/supplier_form_controllers.dart';
import 'form/supplier_form_submit_helper.dart';
import 'form/supplier_trademark_section.dart';

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
  late final SupplierFormControllers _controllers;

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
    _controllers = SupplierFormControllers.fromSupplier(widget.supplierToEdit);
  }

  @override
  void dispose() {
    _controllers.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final supplier = _controllers.buildSupplierModel(widget.supplierToEdit);
    await SupplierFormSubmitHelper.submit(
      context: context,
      ref: ref,
      supplierToEdit: widget.supplierToEdit,
      supplier: supplier,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEditing = widget.supplierToEdit != null;

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
                  borderRadius: BorderRadiusDirectional.only(
                    topStart: Radius.circular(16),
                    topEnd: Radius.circular(16),
                  ),
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
                          controller: _controllers.nameCtrl,
                          suffixIcon: _controllers.buildCopySuffix(context, _controllers.nameCtrl),
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
                                value: _supplierTypeOptions.contains(_controllers.selectedSupplierType)
                                    ? _controllers.selectedSupplierType
                                    : _supplierTypeOptions.first,
                                labelText: l10n.supplierTypeLabel,
                                items: _supplierTypeOptions
                                    .map((type) => SearchableDropdownItem<String>(
                                          value: type,
                                          label: _getSupplierTypeLabel(context, type),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _controllers.selectedSupplierType = val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Registration Type Dropdown
                            Expanded(
                              child: SearchableDropdownField<String>(
                                value: _regTypeOptions.contains(_controllers.selectedRegType)
                                    ? _controllers.selectedRegType
                                    : _regTypeOptions.first,
                                labelText: l10n.supplierRegTypeLabel,
                                items: _regTypeOptions
                                    .map((type) => SearchableDropdownItem<String>(
                                          value: type,
                                          label: _getRegTypeLabel(context, type),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _controllers.selectedRegType = val);
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
                                controller: _controllers.expIdCtrl,
                                suffixIcon: _controllers.buildCopySuffix(context, _controllers.expIdCtrl),
                                label: l10n.supplierForeignExporterIdLabel,
                                icon: Icons.badge,
                                isRequired: true,
                                hint: l10n.foreignExporterIdHint,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _controllers.cargoxPlatformIdCtrl,
                                suffixIcon: _controllers.buildCopySuffix(context, _controllers.cargoxPlatformIdCtrl),
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
                                controller: _controllers.countryCtrl,
                                suffixIcon: _controllers.buildCopySuffix(context, _controllers.countryCtrl),
                                label: l10n.supplierCountryLabel,
                                icon: Icons.flag,
                                isRequired: true,
                                hint: l10n.supplierCountryHint,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _controllers.countryCodeCtrl,
                                suffixIcon: _controllers.buildCopySuffix(context, _controllers.countryCodeCtrl),
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
                          controller: _controllers.addressCtrl,
                          suffixIcon: _controllers.buildCopySuffix(context, _controllers.addressCtrl),
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
                                controller: _controllers.emailCtrl,
                                suffixIcon: _controllers.buildCopySuffix(context, _controllers.emailCtrl),
                                label: l10n.supplierEmailLabel,
                                icon: Icons.email,
                                hint: l10n.supplierEmailHint,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _controllers.secondaryEmailCtrl,
                                suffixIcon: _controllers.buildCopySuffix(context, _controllers.secondaryEmailCtrl),
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
                                controller: _controllers.phoneCtrl,
                                suffixIcon: _controllers.buildCopySuffix(context, _controllers.phoneCtrl),
                                label: l10n.supplierPhoneLabel,
                                icon: Icons.phone,
                                hint: l10n.supplierPhoneHint,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _controllers.mobileCtrl,
                                suffixIcon: _controllers.buildCopySuffix(context, _controllers.mobileCtrl),
                                label: l10n.supplierMobileLabel,
                                icon: Icons.smartphone,
                                hint: l10n.supplierMobileHint,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _controllers.faxCtrl,
                                suffixIcon: _controllers.buildCopySuffix(context, _controllers.faxCtrl),
                                label: l10n.supplierFaxLabel,
                                icon: Icons.print,
                                hint: l10n.supplierFaxHint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _controllers.websiteCtrl,
                          suffixIcon: _controllers.buildCopySuffix(context, _controllers.websiteCtrl),
                          label: l10n.supplierWebsiteLabel,
                          icon: Icons.language,
                          hint: l10n.supplierWebsiteHint,
                        ),
                        const SizedBox(height: 16),
                        SupplierBankComplianceSection(
                          controllers: _controllers,
                          onStateChanged: (fn) => setState(fn),
                        ),
                        const SizedBox(height: 16),
                        SupplierTrademarkSection(
                          controllers: _controllers,
                          onStateChanged: (fn) => setState(fn),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _controllers.brandsCtrl,
                          suffixIcon: _controllers.buildCopySuffix(context, _controllers.brandsCtrl),
                          label: l10n.brandsProductLinesLabel,
                          icon: Icons.branding_watermark,
                          hint: l10n.brandsProductLinesHint,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _controllers.notesCtrl,
                          suffixIcon: _controllers.buildCopySuffix(context, _controllers.notesCtrl),
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
                  borderRadius: const BorderRadiusDirectional.only(
                    bottomStart: Radius.circular(16),
                    bottomEnd: Radius.circular(16),
                  ),
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
