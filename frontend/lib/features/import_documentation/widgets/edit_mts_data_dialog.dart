import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/localization/app_localizations.dart';
import 'idoc_ui_b.dart';

/// Lazy Modal dialog for editing extracted MTS / Nafeza parsed data.
/// Encapsulates 14 text editing controllers with strict lifecycle disposal
/// to prevent memory leaks in the ACID operations screen.
class EditMtsDataDialog extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final ValueChanged<Map<String, dynamic>> onSaved;

  const EditMtsDataDialog({
    super.key,
    required this.initialData,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> initialData,
    required ValueChanged<Map<String, dynamic>> onSaved,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => EditMtsDataDialog(
        initialData: initialData,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<EditMtsDataDialog> createState() => _EditMtsDataDialogState();
}

class _EditMtsDataDialogState extends State<EditMtsDataDialog> {
  late final TextEditingController _acidCtrl;
  late final TextEditingController _genDateCtrl;
  late final TextEditingController _expDateCtrl;
  late final TextEditingController _reqDateCtrl;
  late final TextEditingController _impNameCtrl;
  late final TextEditingController _impTaxCtrl;
  late final TextEditingController _impAddrCtrl;
  late final TextEditingController _expNameCtrl;
  late final TextEditingController _expRegIdCtrl;
  late final TextEditingController _expCountryCtrl;
  late final TextEditingController _cargoxCtrl;
  late final TextEditingController _piCtrl;
  late final TextEditingController _polCtrl;
  late final TextEditingController _podCtrl;
  late String _regType;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _acidCtrl = TextEditingController(text: d['acid_number']?.toString() ?? '');
    _genDateCtrl = TextEditingController(text: d['generated_date']?.toString() ?? '');
    _expDateCtrl = TextEditingController(text: d['expiry_date']?.toString() ?? '');
    _reqDateCtrl = TextEditingController(text: d['requested_date']?.toString() ?? '');
    _impNameCtrl = TextEditingController(text: d['importer_name']?.toString() ?? '');
    _impTaxCtrl = TextEditingController(text: d['importer_tax_id']?.toString() ?? '');
    _impAddrCtrl = TextEditingController(text: d['importer_address']?.toString() ?? '');
    _expNameCtrl = TextEditingController(text: d['exporter_name']?.toString() ?? '');
    _expRegIdCtrl = TextEditingController(text: d['exporter_reg_id']?.toString() ?? '');
    _expCountryCtrl = TextEditingController(text: d['exporter_country']?.toString() ?? '');
    _cargoxCtrl = TextEditingController(text: d['cargox_id']?.toString() ?? '');
    _piCtrl = TextEditingController(text: d['proforma_invoice_no']?.toString() ?? '');
    _polCtrl = TextEditingController(text: d['pol_name']?.toString() ?? '');
    _podCtrl = TextEditingController(text: d['pod_name']?.toString() ?? '');
    _regType = d['exporter_reg_type']?.toString() ?? 'Company Registration Number';
  }

  @override
  void dispose() {
    _acidCtrl.dispose();
    _genDateCtrl.dispose();
    _expDateCtrl.dispose();
    _reqDateCtrl.dispose();
    _impNameCtrl.dispose();
    _impTaxCtrl.dispose();
    _impAddrCtrl.dispose();
    _expNameCtrl.dispose();
    _expRegIdCtrl.dispose();
    _expCountryCtrl.dispose();
    _cargoxCtrl.dispose();
    _piCtrl.dispose();
    _polCtrl.dispose();
    _podCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final updated = Map<String, dynamic>.from(widget.initialData);
    updated['acid_number'] = _acidCtrl.text.trim();
    updated['requested_date'] = _reqDateCtrl.text.trim();
    updated['generated_date'] = _genDateCtrl.text.trim();
    updated['expiry_date'] = _expDateCtrl.text.trim();
    updated['importer_name'] = _impNameCtrl.text.trim();
    updated['importer_tax_id'] = _impTaxCtrl.text.trim();
    updated['importer_address'] = _impAddrCtrl.text.trim();
    updated['exporter_name'] = _expNameCtrl.text.trim();
    updated['exporter_reg_id'] = _expRegIdCtrl.text.trim();
    updated['exporter_country'] = _expCountryCtrl.text.trim();
    updated['exporter_reg_type'] = _regType;
    updated['cargox_id'] = _cargoxCtrl.text.trim();
    updated['proforma_invoice_no'] = _piCtrl.text.trim();
    updated['pol_name'] = _polCtrl.text.trim();
    updated['pod_name'] = _podCtrl.text.trim();

    widget.onSaved(updated);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.mtsExtractedDataUpdated, severity: AppSeverity.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 700,
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadiusDirectional.only(
                    topStart: Radius.circular(16),
                    topEnd: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note, color: AppTheme.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      l.editExtractedDataButton,
                      style: const TextStyle(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _acidCtrl,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: '${l.acidNumberCol} *',
                                prefixIcon: const Icon(Icons.qr_code),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _reqDateCtrl,
                              decoration: InputDecoration(
                                labelText: l.acidRequestDateLabel,
                                prefixIcon: const Icon(Icons.event_available),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _genDateCtrl,
                              decoration: InputDecoration(
                                labelText: l.issueDateCol,
                                prefixIcon: const Icon(Icons.calendar_today),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _expDateCtrl,
                              decoration: InputDecoration(
                                labelText: l.expiryDateCol,
                                prefixIcon: const Icon(Icons.event_busy),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _impNameCtrl,
                              decoration: InputDecoration(
                                labelText: l.importerCompanyCol,
                                prefixIcon: const Icon(Icons.business),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _impTaxCtrl,
                              decoration: InputDecoration(
                                labelText: l.importerTaxIdLabel,
                                prefixIcon: const Icon(Icons.badge),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _expNameCtrl,
                              decoration: InputDecoration(
                                labelText: l.foreignExporterCol,
                                prefixIcon: const Icon(Icons.public),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _expRegIdCtrl,
                              decoration: InputDecoration(
                                labelText: l.foreignExporterIdLabel,
                                prefixIcon: const Icon(Icons.confirmation_number),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: SearchableDropdownField<String>(
                              labelText: l.regTypeLabel,
                              value: _regType,
                              items: [
                                SearchableDropdownItem(
                                  value: 'Company Registration Number',
                                  label: l.companyRegNumberType,
                                ),
                                SearchableDropdownItem(
                                  value: 'Foreign Exporter Number (Nafeza)',
                                  label: l.foreignExporterNafezaType,
                                ),
                                SearchableDropdownItem(
                                  value: 'Factory Registration',
                                  label: l.factoryRegType,
                                ),
                                SearchableDropdownItem(
                                  value: 'VAT Number',
                                  label: l.vatRegType,
                                ),
                                SearchableDropdownItem(
                                  value: 'Tax Number',
                                  label: l.taxIdRegType,
                                ),
                                SearchableDropdownItem(
                                  value: 'Commercial Register',
                                  label: l.crRegType,
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _regType = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _expCountryCtrl,
                              decoration: InputDecoration(
                                labelText: l.countryOfOriginExportLabel,
                                prefixIcon: const Icon(Icons.flag),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _cargoxCtrl,
                              decoration: InputDecoration(
                                labelText: l.cargoxPlatformIdLabel,
                                prefixIcon: const Icon(Icons.token),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _piCtrl,
                              decoration: InputDecoration(
                                labelText: l.proformaInvoiceNoLabel,
                                prefixIcon: const Icon(Icons.receipt),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _polCtrl,
                              decoration: InputDecoration(
                                labelText: l.portOfLoadingLabel,
                                prefixIcon: const Icon(Icons.sailing),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _podCtrl,
                              decoration: InputDecoration(
                                labelText: l.portOfDischargeLabel,
                                prefixIcon: const Icon(Icons.anchor),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  border: Border(top: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IdocBUi.fit(AppButton(
                      label: l.cancel,
                      onPressed: () => Navigator.pop(context),
                      variant: AppButtonVariant.secondary,
                    )),
                    const SizedBox(width: 12),
                    IdocBUi.fit(AppButton(
                      label: l.save,
                      onPressed: _save,
                      variant: AppButtonVariant.success,
                      icon: Icons.check,
                    )),
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
