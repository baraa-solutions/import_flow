import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../import_files/models/import_file_model.dart';

/// Card containing main shipment identification and parties form fields.
class CargoXEnvelopeIdentityForm extends StatelessWidget {
  final int? selectedImportFileId;
  final List<ImportFileModel> importFiles;
  final ValueChanged<int?> onSelectImportFile;
  final TextEditingController acidNumberCtrl;
  final TextEditingController blNumberCtrl;
  final TextEditingController importerNameCtrl;
  final TextEditingController supplierNameCtrl;
  final TextEditingController supplierCargoXIdCtrl;

  const CargoXEnvelopeIdentityForm({
    super.key,
    required this.selectedImportFileId,
    required this.importFiles,
    required this.onSelectImportFile,
    required this.acidNumberCtrl,
    required this.blNumberCtrl,
    required this.importerNameCtrl,
    required this.supplierNameCtrl,
    required this.supplierCargoXIdCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_outlined, color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 8),
                Text(
                  context.l10n.cargoxSection1ShipmentAcid,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: AppTheme.charcoal,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<int?>(
                    value: selectedImportFileId,
                    labelText: context.l10n.cargoxImportFileField,
                    searchHintText: context.l10n.cargoxSearchFileHint,
                    items: [
                      SearchableDropdownItem<int?>(
                        value: null,
                        label: context.l10n.cargoxUnlinkedOption,
                      ),
                      ...importFiles.map((f) => SearchableDropdownItem<int?>(
                            value: f.importFileId,
                            label: '${f.primaryNameWithCode} — ${f.supplierName} (${f.companyName})',
                          )),
                    ],
                    onChanged: onSelectImportFile,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: acidNumberCtrl,
                    decoration: InputDecoration(
                      labelText: context.l10n.cargoxAcidNumberField,
                      prefixIcon: const Icon(Icons.qr_code_2, size: 18),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return context.l10n.required;
                      final digits = val.replaceAll(RegExp(r'[^0-9]'), '');
                      if (digits.length != 19) return context.l10n.cargoxAcidValidationDigits;
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: blNumberCtrl,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: context.l10n.cargoxBlNumberField,
                      prefixIcon: const Icon(Icons.directions_boat_outlined, size: 18),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: importerNameCtrl,
                    decoration: InputDecoration(
                      labelText: context.l10n.cargoxImporterCompanyField,
                      prefixIcon: const Icon(Icons.business_outlined, size: 18),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? context.l10n.required : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: supplierNameCtrl,
                    decoration: InputDecoration(
                      labelText: context.l10n.cargoxForeignSupplierField,
                      prefixIcon: const Icon(Icons.factory_outlined, size: 18),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? context.l10n.required : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: supplierCargoXIdCtrl,
                    decoration: InputDecoration(
                      labelText: context.l10n.cargoxSupplierCargoxIdField,
                      prefixIcon: const Icon(Icons.fingerprint, size: 18),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? context.l10n.required : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
