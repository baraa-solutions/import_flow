import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../models/customs_tariff_model.dart';
import '../providers/customs_tariff_provider.dart';
import 'tariff_form/tariff_dialog_mode_selector.dart';
import 'tariff_form/tariff_local_parser.dart';
import 'tariff_form/tariff_manual_form_mode_view.dart';
import 'tariff_form/tariff_smart_text_mode_view.dart';

void showTariffDialog(BuildContext context, WidgetRef ref,
    {CustomsTariffModel? tariff, int initialModeIndex = 0}) {
  final l10n = context.l10n;
  final hsCtrl = TextEditingController(text: tariff?.hsCode ?? '');
  final descCtrl = TextEditingController(text: tariff?.hsDescription ?? '');
  final initialCategory = DomainEnums.initialCode(
    DomainEnumType.customsCategory,
    tariff?.customsCategory,
    tariff?.customsCategory?.trim() ?? '',
  );
  final catCtrl = TextEditingController(text: initialCategory);

  final dutyCtrl = TextEditingController(
      text: tariff?.customsDutyRate.toString() ?? '0.00');
  final vatCtrl =
      TextEditingController(text: tariff?.vatRate.toString() ?? '14.00');
  final schedCtrl = TextEditingController(
      text: tariff?.scheduleTaxRate.toString() ?? '0.00');
  final devCtrl = TextEditingController(
      text: tariff?.developmentFeeRate.toString() ?? '0.00');
  final importFeeCtrl =
      TextEditingController(text: tariff?.importFeeRate.toString() ?? '0.00');

  final authCtrl =
      TextEditingController(text: tariff?.regulatoryAuthority ?? '');
  final priorApprovalCtrl =
      TextEditingController(text: tariff?.priorApprovalNote ?? '');
  final notesCtrl = TextEditingController(text: tariff?.notes ?? '');
  String isoDate(DateTime? d) => d == null ? '' : d.toIso8601String().split('T').first;
  final effectiveFromCtrl = TextEditingController(text: isoDate(tariff?.effectiveFrom ?? DateTime.now()));
  final effectiveToCtrl = TextEditingController(text: isoDate(tariff?.effectiveTo));
  final rawTextCtrl = TextEditingController();

  bool requiresCoo = tariff?.requiresCoo ?? false;
  bool requiresInspection = tariff?.requiresInspection ?? false;
  bool requiresAcid = tariff?.requiresAcid ?? true;

  // Validity window as loaded, so an edit sends only the dates the user actually changed.
  final originalFrom = isoDate(tariff?.effectiveFrom);
  final originalTo = isoDate(tariff?.effectiveTo);
  final rateChangeNotice = ValueNotifier<bool>(false);
  bool effectiveFromDefaultedToToday = false;

  bool rateOrRequirementChanged() {
    final t = tariff;
    if (t == null) return false;
    bool rateDiffers(TextEditingController ctrl, double stored) {
      final value = double.tryParse(ctrl.text.trim());
      return value != null && (value - stored).abs() > 1e-9;
    }

    String text(String? value) => (value ?? '').trim();
    return rateDiffers(dutyCtrl, t.customsDutyRate) ||
        rateDiffers(vatCtrl, t.vatRate) ||
        rateDiffers(schedCtrl, t.scheduleTaxRate) ||
        rateDiffers(devCtrl, t.developmentFeeRate) ||
        rateDiffers(importFeeCtrl, t.importFeeRate) ||
        requiresCoo != t.requiresCoo ||
        requiresInspection != t.requiresInspection ||
        requiresAcid != t.requiresAcid ||
        text(authCtrl.text) != text(t.regulatoryAuthority) ||
        text(priorApprovalCtrl.text) != text(t.priorApprovalNote);
  }

  // A rate change on an in-force version starts a new version: default Effective From to today
  // (and put the original back if the change is undone), and show the hint on the field.
  void syncEffectiveFromWithRateChange() {
    if (tariff == null) return;
    final changed = rateOrRequirementChanged();
    final now = DateTime.now();
    final todayIso = isoDate(now);
    if (shouldDefaultEffectiveFromToToday(
      rateChanged: changed,
      currentFrom: effectiveFromCtrl.text,
      originalFrom: originalFrom,
      today: now,
    )) {
      effectiveFromCtrl.text = todayIso;
      effectiveFromDefaultedToToday = true;
    } else if (!changed && effectiveFromDefaultedToToday && effectiveFromCtrl.text.trim() == todayIso) {
      effectiveFromCtrl.text = originalFrom;
      effectiveFromDefaultedToToday = false;
    }
    rateChangeNotice.value = changed;
  }

  if (tariff != null) {
    for (final ctrl in [dutyCtrl, vatCtrl, schedCtrl, devCtrl, importFeeCtrl, authCtrl, priorApprovalCtrl]) {
      ctrl.addListener(syncEffectiveFromWithRateChange);
    }
  }

  int activeModeIndex = tariff != null ? 1 : initialModeIndex;
  final formKey = GlobalKey<FormState>();
  bool isLoading = false;
  String? parseError;

  Map<String, dynamic>? parsedTariffData;
  List<Map<String, dynamic>> parsedAgreements = [];
  Map<String, dynamic>? parsedComparisonData;

  void doLocalParse(String text, void Function(void Function()) setDialogState) {
    final result = TariffLocalParser.parse(text);
    if (result.error != null) {
      setDialogState(() => parseError = result.error);
      return;
    }

    setDialogState(() {
      parsedTariffData = result.tariffData;
      parsedAgreements = result.agreements;
      parseError = null;

      if (result.tariffData != null) {
        final data = result.tariffData!;
        final hsCodeVal = data['hs_code'] as String;
        final descVal = data['hs_description'] as String;
        final dutyVal = data['customs_duty_rate'] as double;
        final vatVal = data['vat_rate'] as double;
        final schedVal = data['schedule_tax_rate'] as double;
        final devVal = data['development_fee_rate'] as double;
        final impVal = data['import_fee_rate'] as double;
        final authVal = data['regulatory_authority'] as String?;
        final priorNote = data['prior_approval_note'] as String?;

        if (hsCodeVal.isNotEmpty) hsCtrl.text = hsCodeVal;
        if (descVal.isNotEmpty) descCtrl.text = descVal;
        dutyCtrl.text = dutyVal.toStringAsFixed(2);
        vatCtrl.text = vatVal.toStringAsFixed(2);
        schedCtrl.text = schedVal.toStringAsFixed(2);
        devCtrl.text = devVal.toStringAsFixed(2);
        importFeeCtrl.text = impVal.toStringAsFixed(2);
        if (authVal != null) authCtrl.text = authVal;
        if (priorNote != null) priorApprovalCtrl.text = priorNote;
        requiresInspection = data['requires_inspection'] as bool? ?? false;
        requiresCoo = true;
        requiresAcid = true;
      }
    });

    if (text.trim().length > 25) {
      ref.read(customsTariffProvider.notifier).parseSmartNafezaText(text.trim()).then((res) {
        if (res != null && res['comparison'] != null) {
          setDialogState(() {
            parsedComparisonData = res['comparison'];
          });
        }
      }).catchError((_) {});
    }
  }

  bool isDirty() {
    if (rawTextCtrl.text.trim().isNotEmpty) return true;
    if (hsCtrl.text.trim() != (tariff?.hsCode ?? '')) return true;
    if (descCtrl.text.trim() != (tariff?.hsDescription ?? '')) return true;
    if (catCtrl.text.trim() != initialCategory) return true;
    if (notesCtrl.text.trim() != (tariff?.notes ?? '')) return true;
    return false;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => UnsavedChangesGuard(
        isDirty: isDirty(),
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.receipt_long, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tariff == null
                      ? l10n.tariffDialogTitleAdd
                      : l10n.tariffDialogTitleEdit(tariff.hsCode),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          content: SelectionArea(
            child: SizedBox(
              width: 720,
              height: 580,
              child: Column(
                children: [
                  TariffDialogModeSelector(
                    activeModeIndex: activeModeIndex,
                    onModeChanged: (idx) => setDialogState(() => activeModeIndex = idx),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: activeModeIndex == 0
                        ? TariffSmartTextModeView(
                            rawTextCtrl: rawTextCtrl,
                            parsedTariffData: parsedTariffData,
                            parsedAgreements: parsedAgreements,
                            parsedComparisonData: parsedComparisonData,
                            parseError: parseError,
                            onParseRequested: (val) => doLocalParse(val, setDialogState),
                            onSwitchToManual: () => setDialogState(() => activeModeIndex = 1),
                          )
                        : TariffManualFormModeView(
                            formKey: formKey,
                            hsCtrl: hsCtrl,
                            descCtrl: descCtrl,
                            catCtrl: catCtrl,
                            dutyCtrl: dutyCtrl,
                            vatCtrl: vatCtrl,
                            schedCtrl: schedCtrl,
                            devCtrl: devCtrl,
                            importFeeCtrl: importFeeCtrl,
                            authCtrl: authCtrl,
                            priorApprovalCtrl: priorApprovalCtrl,
                            notesCtrl: notesCtrl,
                            effectiveFromCtrl: effectiveFromCtrl,
                            effectiveToCtrl: effectiveToCtrl,
                            rateChangeNotice: rateChangeNotice,
                            isNewTariff: tariff == null,
                            requiresAcid: requiresAcid,
                            requiresCoo: requiresCoo,
                            requiresInspection: requiresInspection,
                            onRequiresAcidChanged: (val) => setDialogState(() {
                              requiresAcid = val;
                              syncEffectiveFromWithRateChange();
                            }),
                            onRequiresCooChanged: (val) => setDialogState(() {
                              requiresCoo = val;
                              syncEffectiveFromWithRateChange();
                            }),
                            onRequiresInspectionChanged: (val) => setDialogState(() {
                              requiresInspection = val;
                              syncEffectiveFromWithRateChange();
                            }),
                            onCategoryChanged: (v) => setDialogState(() => catCtrl.text = v ?? ''),
                          ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => UnsavedChangesGuard.maybePop(ctx, isDirty: isDirty()),
              child: Text(l10n.cancel),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cobalt,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save, color: Colors.white, size: 18),
              label: Text(
                isLoading
                    ? l10n.savingProgress
                    : (activeModeIndex == 0
                        ? l10n.saveAllTariffAndAgreementsBtn
                        : (tariff == null ? l10n.addTariffBtnShort : l10n.saveTariffChangesBtn)),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);

                      String? error;
                      try {
                        if (activeModeIndex == 0) {
                          if (rawTextCtrl.text.trim().isEmpty) {
                            setDialogState(() {
                              isLoading = false;
                              parseError = l10n.pasteTextFirstError;
                            });
                            return;
                          }

                          if (parsedTariffData == null || (parsedTariffData!['hs_code'] as String).isEmpty) {
                            doLocalParse(rawTextCtrl.text, setDialogState);
                          }

                          if (parsedTariffData == null || (parsedTariffData!['hs_code'] as String).isEmpty) {
                            setDialogState(() {
                              isLoading = false;
                              parseError = l10n.cannotExtractHsCodeError;
                            });
                            return;
                          }

                          Map<String, dynamic> finalPayload;
                          try {
                            final backendParsed = await ref
                                .read(customsTariffProvider.notifier)
                                .parseSmartNafezaText(rawTextCtrl.text.trim());
                            if (backendParsed != null && backendParsed['tariff_data'] != null) {
                              finalPayload = {
                                'tariff': backendParsed['tariff_data'],
                                'agreements': backendParsed['agreements'] ?? [],
                              };
                            } else {
                              finalPayload = {
                                'tariff': parsedTariffData,
                                'agreements': parsedAgreements,
                              };
                            }
                          } catch (_) {
                            finalPayload = {
                              'tariff': parsedTariffData,
                              'agreements': parsedAgreements,
                            };
                          }

                          error = await ref
                              .read(customsTariffProvider.notifier)
                              .saveTariffWithAgreements(finalPayload);
                        } else {
                          if (!formKey.currentState!.validate()) {
                            setDialogState(() => isLoading = false);
                            return;
                          }

                          final data = {
                            'hs_code': hsCtrl.text.trim(),
                            'hs_description': descCtrl.text.trim(),
                            'customs_category': catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
                            'customs_duty_rate': double.parse(dutyCtrl.text.trim()),
                            'vat_rate': double.parse(vatCtrl.text.trim()),
                            'schedule_tax_rate': double.parse(schedCtrl.text.trim()),
                            'development_fee_rate': double.parse(devCtrl.text.trim()),
                            'import_fee_rate': double.parse(importFeeCtrl.text.trim()),
                            'requires_coo': requiresCoo,
                            'requires_inspection': requiresInspection,
                            'requires_acid': requiresAcid,
                            'regulatory_authority': authCtrl.text.trim().isEmpty ? null : authCtrl.text.trim(),
                            'prior_approval_note': priorApprovalCtrl.text.trim().isEmpty ? null : priorApprovalCtrl.text.trim(),
                            'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                            ...tariffValidityPayload(
                              from: effectiveFromCtrl.text,
                              to: effectiveToCtrl.text,
                              originalFrom: tariff == null ? null : originalFrom,
                              originalTo: tariff == null ? null : originalTo,
                            ),
                          };

                          if (tariff == null) {
                            error = await ref.read(customsTariffProvider.notifier).createTariff(data);
                          } else {
                            error = await ref.read(customsTariffProvider.notifier).updateTariff(tariff.tariffId, data);
                          }
                        }
                      } catch (e) {
                        error = e.toString();
                      }

                      setDialogState(() => isLoading = false);
                      if (ctx.mounted) {
                        if (error != null) {
                          showDialog(
                            context: context,
                            builder: (errCtx) => AlertDialog(
                              title: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppTheme.crimson),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.saveFailureTitle,
                                    style: const TextStyle(
                                        color: AppTheme.crimson,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                ],
                              ),
                              content: SizedBox(
                                width: 500,
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.saveFailureIntro,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppTheme.charcoal),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.red.shade200),
                                        ),
                                        child: SelectableText(
                                          error ?? 'Error',
                                          style: TextStyle(
                                              fontSize: 12,
                                              height: 1.5,
                                              color: Colors.red.shade900,
                                              fontFamily: 'monospace'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.cobalt),
                                  onPressed: () => Navigator.pop(errCtx),
                                  child: Text(l10n.adjustInputsBtn,
                                      style: const TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            AppTheme.snackBar(
                              context,
                              tariff == null ? l10n.tariffAddedSuccess : l10n.tariffUpdatedSuccess,
                              severity: AppSeverity.success,
                            ),
                          );
                          Navigator.pop(ctx);
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    ),
  ).then((_) {
    hsCtrl.dispose();
    descCtrl.dispose();
    catCtrl.dispose();
    dutyCtrl.dispose();
    vatCtrl.dispose();
    schedCtrl.dispose();
    devCtrl.dispose();
    importFeeCtrl.dispose();
    authCtrl.dispose();
    priorApprovalCtrl.dispose();
    notesCtrl.dispose();
    effectiveFromCtrl.dispose();
    effectiveToCtrl.dispose();
    rawTextCtrl.dispose();
    rateChangeNotice.dispose();
  });
}
