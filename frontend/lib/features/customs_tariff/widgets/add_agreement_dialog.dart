import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../providers/customs_tariff_provider.dart';

  void showAddAgreementDialog(
      BuildContext context, WidgetRef ref, String hsCode) {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController();
    final countriesCtrl = TextEditingController();
    final pctCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.addAgreementDialogTitle(hsCode)),
          content: SelectionArea(
            child: Form(
              key: formKey,
              child: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.agreementNameLabel,
                        hintText: l10n.agreementNameHint,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: l10n.copyTooltip,
                          onPressed: () => CopyHelper.copy(context, nameCtrl.text),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l10n.agreementNameRequired
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: countriesCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.agreementCountriesLabel,
                        hintText: l10n.agreementCountriesHint,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: l10n.copyTooltip,
                          onPressed: () => CopyHelper.copy(context, countriesCtrl.text),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l10n.agreementCountriesRequired
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: pctCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.dutyReductionPctLabel,
                        hintText: l10n.dutyReductionPctHint,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: l10n.copyTooltip,
                          onPressed: () => CopyHelper.copy(context, pctCtrl.text),
                        ),
                      ),
                      validator: (v) => (v == null || double.tryParse(v) == null)
                          ? l10n.invalidNumberError
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.agreementConditionsLabel,
                        hintText: l10n.agreementConditionsHint,
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
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);

                      final pctVal = double.parse(pctCtrl.text.trim()) / 100.0;
                      final data = {
                        'hs_code': hsCode,
                        'agreement_name': nameCtrl.text.trim(),
                        'reduction_type': pctVal >= 1.0
                            ? 'full_duty_exemption'
                            : 'percentage_of_duty',
                        'reduction_percentage': pctVal,
                        'origin_countries': countriesCtrl.text.trim(),
                        'conditions_note': notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      };

                      final error = await ref
                          .read(customsTariffProvider.notifier)
                          .createPreferentialAgreement(data);

                      setDialogState(() => isLoading = false);
                      if (ctx.mounted) {
                        if (error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(l10n.agreementAddFailed(error)),
                                backgroundColor: AppTheme.crimson),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.agreementAddedSuccess),
                              backgroundColor: AppTheme.emerald,
                            ),
                          );
                          Navigator.pop(ctx);
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.saveAgreementBtn),
            ),
          ],
        ),
      ),
    );
  }
