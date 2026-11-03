import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// 📂 Import File & Supplier Selector Card — ImportFlow ERP
///
/// Handles linking to active Import Files, extracting Nafeza ACID numbers,
/// foreign suppliers, and linking to technical customs consultations.
class ImportFileSelectorCard extends StatelessWidget {
  final List<dynamic> importFiles;
  final List<dynamic> suppliers;
  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileChanged;
  final TextEditingController acidNumberCtrl;
  final int? selectedSupplierId;
  final ValueChanged<int?> onSupplierChanged;
  final String? selectedConsultationCode;
  final double consultationReadiness;

  const ImportFileSelectorCard({
    super.key,
    required this.importFiles,
    required this.suppliers,
    required this.selectedImportFileId,
    required this.onImportFileChanged,
    required this.acidNumberCtrl,
    required this.selectedSupplierId,
    required this.onSupplierChanged,
    this.selectedConsultationCode,
    this.consultationReadiness = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cloudWhite),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.linkImportFileAndConsultationHeader,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
              ),
              const Spacer(),
              if (selectedConsultationCode != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.cobalt),
                  ),
                  child: Text(
                    l10n.consultationStudyBadge(selectedConsultationCode, consultationReadiness.toInt()),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SearchableDropdownField<int?>(
                  labelText: l10n.linkedImportFileFieldLabel,
                  hintText: l10n.selectImportFileHint,
                  value: selectedImportFileId,
                  items: [
                    SearchableDropdownItem<int?>(value: null, label: l10n.selectImportFileOption),
                    ...importFiles.map((f) => SearchableDropdownItem<int?>(
                          value: f.importFileId,
                          label: '${f.primaryNameWithCode} - ${f.companyName} | ACID: ${f.acidNumber ?? l10n.acidNotIssued}',
                        )),
                  ],
                  onChanged: onImportFileChanged,
                  validator: (v) => v == null ? l10n.pleaseSelectImportFileError : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: acidNumberCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.acidNumberFieldLabel,
                    hintText: l10n.acidNumberOptionalHint,
                    helperText: l10n.acidNumberOptionalHint,
                    helperStyle: const TextStyle(fontSize: 10, color: AppTheme.charcoal),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.numbers, color: AppTheme.cobalt, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(
                        context,
                        acidNumberCtrl.text,
                        customMessage: l10n.requirementCopySummarySuccess,
                      ),
                    ),
                  ),
                  validator: null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SearchableDropdownField<int?>(
                  labelText: l10n.foreignSupplierFieldLabel,
                  hintText: l10n.foreignSupplierHint,
                  value: selectedSupplierId,
                  items: [
                    SearchableDropdownItem<int?>(value: null, label: l10n.notSpecifiedOption),
                    ...suppliers.map((s) => SearchableDropdownItem<int?>(
                          value: s.supplierId,
                          label: '${s.companyName} (${s.foreignExporterCountry ?? "N/A"})',
                        )),
                  ],
                  onChanged: onSupplierChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
