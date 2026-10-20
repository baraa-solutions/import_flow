import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../models/customs_tariff_model.dart';
import '../providers/customs_tariff_provider.dart';

  void showVerifyTariffDialog(
      BuildContext context, WidgetRef ref, CustomsTariffModel tariff) {
    final l10n = context.l10n;
    final formKey = GlobalKey<FormState>();
    final verifiedByController =
        TextEditingController(text: tariff.verifiedBy ?? 'System Admin');
    final sourceUrlController = TextEditingController(
        text: tariff.sourceUrl ??
            'https://www.nafeza.gov.eg/ar/tarrif?code=${tariff.hsCode}');
    final priorApprovalNoteController =
        TextEditingController(text: tariff.priorApprovalNote ?? '');
    final dutyRateController =
        TextEditingController(text: tariff.customsDutyRate.toString());
    final vatRateController =
        TextEditingController(text: tariff.vatRate.toString());
    final scheduleTaxRateController =
        TextEditingController(text: tariff.scheduleTaxRate.toString());

    String confidence = tariff.confidence ?? 'verified_manual';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.verified, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.verifyTariffDialogTitle(tariff.hsCode),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SelectionArea(
            child: SingleChildScrollView(
              child: SizedBox(
                width: 550,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.verificationProtocolHeader,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.charcoal),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.verificationProtocolText,
                              style:
                                  const TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: verifiedByController,
                        decoration: InputDecoration(
                          labelText: l10n.verifiedByAuditorLabel,
                          prefixIcon: const Icon(Icons.person_outline),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: l10n.copyTooltip,
                            onPressed: () => CopyHelper.copy(context, verifiedByController.text),
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? l10n.auditorNameRequired
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: sourceUrlController,
                        decoration: InputDecoration(
                          labelText: l10n.sourceUrlLabel,
                          prefixIcon: const Icon(Icons.link),
                          hintText:
                              'https://www.nafeza.gov.eg/ar/tarrif?code=...',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: l10n.copyTooltip,
                            onPressed: () => CopyHelper.copy(context, sourceUrlController.text),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SearchableDropdownField<String>(
                        value: confidence,
                        labelText: l10n.confidenceLevelLabel,
                        searchHintText: l10n.searchHint,
                        items: [
                          SearchableDropdownItem(
                              value: 'verified_manual',
                              label: l10n.confidenceManualAudit),
                          SearchableDropdownItem(
                              value: 'verified_official_gazette',
                              label: l10n.confidenceOfficialGazette),
                          SearchableDropdownItem(
                              value: 'draft', label: l10n.confidenceDraft),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => confidence = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priorApprovalNoteController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: l10n.priorApprovalSpecialConditionsLabel,
                          prefixIcon: const Icon(Icons.notes),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: l10n.copyTooltip,
                            onPressed: () => CopyHelper.copy(context, priorApprovalNoteController.text),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(l10n.taxRatesVerificationHeader,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: dutyRateController,
                              keyboardType: TextInputType.number,
                              decoration:
                                  InputDecoration(
                                labelText: l10n.dutyRateLabel,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  tooltip: l10n.copyTooltip,
                                  onPressed: () => CopyHelper.copy(context, dutyRateController.text),
                                ),
                              ),
                              validator: (val) =>
                                  val == null || double.tryParse(val) == null
                                      ? l10n.invalidNumberError
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: vatRateController,
                              keyboardType: TextInputType.number,
                              decoration:
                                  InputDecoration(
                                labelText: l10n.vatRateLabel,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  tooltip: l10n.copyTooltip,
                                  onPressed: () => CopyHelper.copy(context, vatRateController.text),
                                ),
                              ),
                              validator: (val) =>
                                  val == null || double.tryParse(val) == null
                                      ? l10n.invalidNumberError
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: scheduleTaxRateController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.scheduleTaxRateLabel,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  tooltip: l10n.copyTooltip,
                                  onPressed: () => CopyHelper.copy(context, scheduleTaxRateController.text),
                                ),
                              ),
                              validator: (val) =>
                                  val == null || double.tryParse(val) == null
                                      ? l10n.invalidNumberError
                                      : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 18),
              label: Text(l10n.confirmVerificationBtn),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => isLoading = true);

                      final error = await ref
                          .read(customsTariffProvider.notifier)
                          .verifyTariff(
                        tariff.hsCode,
                        {
                          'verified_by': verifiedByController.text.trim(),
                          'source_url': sourceUrlController.text.trim(),
                          'confidence': confidence,
                          'prior_approval_note':
                              priorApprovalNoteController.text.trim().isEmpty
                                  ? null
                                  : priorApprovalNoteController.text.trim(),
                          'customs_duty_rate':
                              double.parse(dutyRateController.text),
                          'vat_rate': double.parse(vatRateController.text),
                          'schedule_tax_rate':
                              double.parse(scheduleTaxRateController.text),
                        },
                      );

                      setState(() => isLoading = false);
                      if (context.mounted) {
                        if (error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(l10n.verificationFailedSnack(error)),
                                backgroundColor: AppTheme.crimson),
                          );
                        } else {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  l10n.tariffVerifiedSuccess(tariff.hsCode)),
                              backgroundColor: AppTheme.emerald,
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
