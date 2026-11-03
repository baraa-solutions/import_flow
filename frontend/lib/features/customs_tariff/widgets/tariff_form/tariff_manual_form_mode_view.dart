import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';

class TariffManualFormModeView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController hsCtrl;
  final TextEditingController descCtrl;
  final TextEditingController catCtrl;
  final TextEditingController dutyCtrl;
  final TextEditingController vatCtrl;
  final TextEditingController schedCtrl;
  final TextEditingController devCtrl;
  final TextEditingController importFeeCtrl;
  final TextEditingController authCtrl;
  final TextEditingController priorApprovalCtrl;
  final TextEditingController notesCtrl;
  final bool isNewTariff;
  final bool requiresAcid;
  final bool requiresCoo;
  final bool requiresInspection;
  final ValueChanged<bool> onRequiresAcidChanged;
  final ValueChanged<bool> onRequiresCooChanged;
  final ValueChanged<bool> onRequiresInspectionChanged;
  final ValueChanged<String?> onCategoryChanged;

  const TariffManualFormModeView({
    super.key,
    required this.formKey,
    required this.hsCtrl,
    required this.descCtrl,
    required this.catCtrl,
    required this.dutyCtrl,
    required this.vatCtrl,
    required this.schedCtrl,
    required this.devCtrl,
    required this.importFeeCtrl,
    required this.authCtrl,
    required this.priorApprovalCtrl,
    required this.notesCtrl,
    required this.isNewTariff,
    required this.requiresAcid,
    required this.requiresCoo,
    required this.requiresInspection,
    required this.onRequiresAcidChanged,
    required this.onRequiresCooChanged,
    required this.onRequiresInspectionChanged,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: hsCtrl,
                    textDirection: TextDirection.ltr,
                    enabled: isNewTariff,
                    decoration: InputDecoration(
                      labelText: l10n.hsCodeLabelReq,
                      hintText: l10n.hsCodeHint,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: l10n.copyTooltip,
                        onPressed: () => CopyHelper.copy(context, hsCtrl.text),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? l10n.hsCodeRequiredError : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SearchableDropdownField<String>(
                    value: catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
                    labelText: l10n.customsCategoryLabel,
                    hintText: l10n.customsCategoryHint,
                    items: [
                      for (final code in DomainEnums.codesOf(DomainEnumType.customsCategory))
                        SearchableDropdownItem<String>(
                          value: code,
                          label: DomainEnums.label(l10n, DomainEnumType.customsCategory, code),
                        ),
                      if (catCtrl.text.trim().isNotEmpty &&
                          !DomainEnums.isCode(DomainEnumType.customsCategory, catCtrl.text.trim()))
                        SearchableDropdownItem<String>(
                          value: catCtrl.text.trim(),
                          label: catCtrl.text.trim(),
                        ),
                    ],
                    onChanged: onCategoryChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descCtrl,
              decoration: InputDecoration(
                labelText: l10n.hsDescriptionLabelReq,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: l10n.copyTooltip,
                  onPressed: () => CopyHelper.copy(context, descCtrl.text),
                ),
              ),
              maxLines: 2,
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.hsDescriptionRequiredError : null,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.taxRatesBreakdownSection,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: dutyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.dutyRateInputLabel,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: l10n.copyTooltip,
                        onPressed: () => CopyHelper.copy(context, dutyCtrl.text),
                      ),
                    ),
                    validator: (v) => (v == null || double.tryParse(v) == null) ? l10n.invalidNumberError : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: vatCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.vatRateInputLabel,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: l10n.copyTooltip,
                        onPressed: () => CopyHelper.copy(context, vatCtrl.text),
                      ),
                    ),
                    validator: (v) => (v == null || double.tryParse(v) == null) ? l10n.invalidNumberError : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: schedCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.scheduleTaxInputLabel,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: l10n.copyTooltip,
                        onPressed: () => CopyHelper.copy(context, schedCtrl.text),
                      ),
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
                    controller: devCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.devFeeInputLabel,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: l10n.copyTooltip,
                        onPressed: () => CopyHelper.copy(context, devCtrl.text),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: importFeeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.importFeeInputLabel,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: l10n.copyTooltip,
                        onPressed: () => CopyHelper.copy(context, importFeeCtrl.text),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.docsAndClearanceSection,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal),
              ),
            ),
            Row(
              children: [
                Checkbox(
                  value: requiresAcid,
                  activeColor: AppTheme.cobalt,
                  onChanged: (val) => onRequiresAcidChanged(val ?? true),
                ),
                Text(l10n.requiresAcidCheckbox, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                Checkbox(
                  value: requiresCoo,
                  activeColor: AppTheme.cobalt,
                  onChanged: (val) => onRequiresCooChanged(val ?? false),
                ),
                Text(l10n.requiresCooCheckbox, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                Checkbox(
                  value: requiresInspection,
                  activeColor: AppTheme.cobalt,
                  onChanged: (val) => onRequiresInspectionChanged(val ?? false),
                ),
                Text(l10n.requiresInspectionCheckbox, style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: authCtrl,
              decoration: InputDecoration(
                labelText: l10n.govAuthorityLabel,
                hintText: l10n.govAuthorityHint,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: l10n.copyTooltip,
                  onPressed: () => CopyHelper.copy(context, authCtrl.text),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: priorApprovalCtrl,
              decoration: InputDecoration(
                labelText: l10n.priorApprovalsLabel,
                hintText: l10n.priorApprovalsHint,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: l10n.copyTooltip,
                  onPressed: () => CopyHelper.copy(context, priorApprovalCtrl.text),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: notesCtrl,
              decoration: InputDecoration(
                labelText: l10n.tariffNotesLabel,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: l10n.copyTooltip,
                  onPressed: () => CopyHelper.copy(context, notesCtrl.text),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
