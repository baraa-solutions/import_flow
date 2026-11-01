import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/localization/api_error_text.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../currencies/models/currency_model.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/shipping_scenario_model.dart';
import '../../providers/shipping_scenarios_provider.dart';
import '../../utils/shipping_scenario_calculator.dart';
import '../shipping_scenarios_dialogs.dart';

/// Modal dialogs, validations, diff reviews, and save orchestration for the Shipping Scenario Evaluator.
class ScenarioEvaluatorDialogs {
  ScenarioEvaluatorDialogs._();

  /// Confirms resetting the evaluator form for a new study.
  static Future<bool> confirmResetStudy(BuildContext context) async {
    final l = context.l10n;
    return await AppConfirmDialog.show(
      context,
      title: l.clearAndStartNew,
      message: l.confirmActionTitle,
      confirmLabel: l.confirm,
      cancelLabel: l.cancel,
      confirmVariant: AppButtonVariant.warning,
      icon: Icons.refresh_rounded,
    );
  }

  /// Confirms deleting a carrier option from the active study.
  static Future<bool> confirmDeleteOption(BuildContext context, String providerName) async {
    final l = context.l10n;
    return await AppConfirmDialog.showDelete(
      context,
      entityName: providerName,
      title: l.confirmDelete,
      message: '${l.confirmDelete} ($providerName)؟',
    );
  }

  /// Client-side validation of shipping scenarios items before saving.
  static bool validateScenarioItems({
    required BuildContext context,
    required List<ShippingScenarioItemModel> items,
    required DateTime cargoReadyDate,
    required List<CurrencyModel> currencies,
  }) {
    final isArabic = (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';
    final l = context.l10n;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          isArabic
              ? 'يرجى إضافة خيار شحن واحد على الأقل لحفظ دراسة السيناريوهات'
              : 'Please add at least one shipping carrier option to save the study',
          severity: AppSeverity.danger,
        ),
      );
      return false;
    }

    final seen = <String>{};
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.providerName.isEmpty || item.providerName == 'Select Line') {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l.shippingLineRequiredMsg(i + 1),
            severity: AppSeverity.danger,
          ),
        );
        return false;
      }

      final sDate = DateTime.tryParse(item.sailingDate);
      final etaDate = DateTime.tryParse(item.estimatedArrivalDate);

      if (sDate == null || etaDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l.datesRequiredMsg(i + 1, item.providerName),
            severity: AppSeverity.danger,
          ),
        );
        return false;
      }

      final crdDateOnly = DateTime(cargoReadyDate.year, cargoReadyDate.month, cargoReadyDate.day);
      final sailingDateOnly = DateTime(sDate.year, sDate.month, sDate.day);
      if (sailingDateOnly.isBefore(crdDateOnly)) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l.sailingBeforeCrdError(i + 1, item.providerName, item.sailingDate, crdDateOnly.toString().substring(0, 10)),
            severity: AppSeverity.danger,
          ),
        );
        return false;
      }

      if (!etaDate.isAfter(sDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l.etaAfterSailingError(i + 1, item.providerName, item.estimatedArrivalDate, item.sailingDate),
            severity: AppSeverity.danger,
          ),
        );
        return false;
      }

      if (item.expectedLineDelayDays < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l.negativeDaysError(i + 1, item.providerName),
            severity: AppSeverity.danger,
          ),
        );
        return false;
      }

      final key = '${item.providerId}_${item.providerName.trim().toLowerCase()}_${item.vesselName.trim().toLowerCase()}_${item.sailingDate}';
      if (seen.contains(key)) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l.duplicateQuoteError(i + 1, item.providerName),
            severity: AppSeverity.danger,
          ),
        );
        return false;
      }

      if (item.totalQuotationAmount == null) {
        final missing = ShippingScenarioCalculator.calculateTotalQuoteValue(item: item, currencies: currencies).missingCurrencies;
        final missingStr = missing.isNotEmpty ? missing.join(', ') : (item.quotationCurrency ?? '—');
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l.scenarioSaveRateMissingError(i + 1, item.providerName, missingStr),
            severity: AppSeverity.danger,
          ),
        );
        return false;
      }

      seen.add(key);
    }
    return true;
  }

  /// Builds a list of FieldChangeItem comparing an existing study session with new edits.
  static List<FieldChangeItem> buildSessionDiffChanges({
    required BuildContext context,
    required ShippingEvaluationModel oldSession,
    required String newTitle,
    required DateTime newCargoReadyDate,
    required String newPickUpAddress,
    required int newAvgForm4Days,
    required int newAvgClearanceDays,
    required int? newSelectedImportFileId,
    required int? newSelectedPoId,
    required List<ShippingScenarioItemModel> newItems,
  }) {
    final isArabic = (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';
    final l = context.l10n;
    final List<FieldChangeItem> changes = [];

    final secGeneral = isArabic ? 'البيانات العامة للدراسة' : 'General Study Info';
    final secOps = isArabic ? 'الربط التشغيلي' : 'Operational Linkage';
    final secQuotes = isArabic ? 'عروض أسعار الشحن المقارنة' : 'Comparative Shipping Quotes';
    final daysUnit = isArabic ? 'يوم' : 'days';
    final quotesUnit = isArabic ? 'عرض' : 'quotes';
    final excludedLabel = isArabic ? 'مستبعد' : 'Excluded';
    final includedLabel = isArabic ? 'محتسب' : 'Included';

    if (FieldChangeItem.isDifferent(oldSession.title, newTitle)) {
      changes.add(FieldChangeItem(
        section: secGeneral,
        fieldName: isArabic ? 'عنوان دراسة الشحن' : 'Shipping Study Title',
        oldValue: oldSession.title,
        newValue: newTitle,
      ));
    }

    final newCrd = newCargoReadyDate.toString().substring(0, 10);
    if (FieldChangeItem.isDifferent(oldSession.cargoReadyDate, newCrd)) {
      changes.add(FieldChangeItem(
        section: secGeneral,
        fieldName: isArabic ? 'تاريخ جاهزية البضاعة' : 'Cargo Ready Date',
        oldValue: oldSession.cargoReadyDate,
        newValue: newCrd,
      ));
    }

    final newPickup = newPickUpAddress.trim().isNotEmpty ? newPickUpAddress.trim() : null;
    if (FieldChangeItem.isDifferent(oldSession.pickUpAddress, newPickup)) {
      changes.add(FieldChangeItem(
        section: secGeneral,
        fieldName: isArabic ? 'موقع وعنوان الاستلام' : 'Pick-up Location',
        oldValue: oldSession.pickUpAddress,
        newValue: newPickup,
      ));
    }

    if (FieldChangeItem.isDifferent(oldSession.avgForm4Days, newAvgForm4Days)) {
      changes.add(FieldChangeItem(
        section: secGeneral,
        fieldName: isArabic ? 'أيام إصدار نموذج 4 المتوقعة' : 'Expected Form 4 Days',
        oldValue: '${oldSession.avgForm4Days} $daysUnit',
        newValue: '$newAvgForm4Days $daysUnit',
      ));
    }

    if (FieldChangeItem.isDifferent(oldSession.avgClearanceDays, newAvgClearanceDays)) {
      changes.add(FieldChangeItem(
        section: secGeneral,
        fieldName: isArabic ? 'أيام التخليص الجمركي المتوقعة' : 'Expected Clearance Days',
        oldValue: '${oldSession.avgClearanceDays} $daysUnit',
        newValue: '$newAvgClearanceDays $daysUnit',
      ));
    }

    if (FieldChangeItem.isDifferent(oldSession.importFileId, newSelectedImportFileId)) {
      changes.add(FieldChangeItem(
        section: secOps,
        fieldName: isArabic ? 'ملف الاستيراد المرتبط' : 'Linked Import File',
        oldValue: oldSession.importFileCode ?? (oldSession.importFileId != null ? 'ID: ${oldSession.importFileId}' : null),
        newValue: newSelectedImportFileId != null ? 'ID: $newSelectedImportFileId' : null,
      ));
    }

    if (FieldChangeItem.isDifferent(oldSession.poId, newSelectedPoId)) {
      changes.add(FieldChangeItem(
        section: secOps,
        fieldName: isArabic ? 'أمر الشراء المرتبط' : 'Linked Purchase Order',
        oldValue: oldSession.poNumber ?? (oldSession.poId != null ? 'ID: ${oldSession.poId}' : null),
        newValue: newSelectedPoId != null ? 'ID: $newSelectedPoId' : null,
      ));
    }

    if (oldSession.items.length != newItems.length) {
      changes.add(FieldChangeItem(
        section: secQuotes,
        fieldName: isArabic ? 'عدد عروض الشحن المدرجة' : 'Shipping Quotes Count',
        oldValue: '${oldSession.items.length} $quotesUnit',
        newValue: '${newItems.length} $quotesUnit',
      ));
    } else {
      for (int i = 0; i < newItems.length; i++) {
        final o = oldSession.items[i];
        final n = newItems[i];
        final defaultCarrier = l.ssCarrier;
        final quotePrefix = l.ssQuote;
        final quoteTitle = '$quotePrefix #${i + 1} (${n.providerName.isNotEmpty ? n.providerName : defaultCarrier})';

        if (FieldChangeItem.isDifferent(o.providerName, n.providerName)) {
          changes.add(FieldChangeItem(
            section: secQuotes,
            fieldName: '$quoteTitle - ${isArabic ? "وكيل الشحن" : "Carrier"}',
            oldValue: o.providerName,
            newValue: n.providerName,
          ));
        }
        if (FieldChangeItem.isDifferent(o.vesselName, n.vesselName)) {
          changes.add(FieldChangeItem(
            section: secQuotes,
            fieldName: '$quoteTitle - ${isArabic ? "الخط الملاحي / الباخرة" : "Vessel"}',
            oldValue: o.vesselName,
            newValue: n.vesselName,
          ));
        }
        if (FieldChangeItem.isDifferent(o.sailingDate, n.sailingDate)) {
          changes.add(FieldChangeItem(
            section: secQuotes,
            fieldName: '$quoteTitle - ${isArabic ? "تاريخ الإبحار" : "Sailing Date"}',
            oldValue: o.sailingDate,
            newValue: n.sailingDate,
          ));
        }
        if (FieldChangeItem.isDifferent(o.estimatedArrivalDate, n.estimatedArrivalDate)) {
          changes.add(FieldChangeItem(
            section: secQuotes,
            fieldName: '$quoteTitle - ${isArabic ? "تاريخ الوصول المتوقع" : "Arrival Date"}',
            oldValue: o.estimatedArrivalDate,
            newValue: n.estimatedArrivalDate,
          ));
        }
        if (FieldChangeItem.isDifferent(o.freeTimeDays, n.freeTimeDays)) {
          changes.add(FieldChangeItem(
            section: secQuotes,
            fieldName: '$quoteTitle - ${isArabic ? "أيام السماح" : "Free Time Days"}',
            oldValue: '${o.freeTimeDays} $daysUnit',
            newValue: '${n.freeTimeDays} $daysUnit',
          ));
        }
        if (FieldChangeItem.isDifferent(o.totalQuotationAmount, n.totalQuotationAmount)) {
          final cur = n.quotationCurrency ?? "";
          changes.add(FieldChangeItem(
            section: secQuotes,
            fieldName: '$quoteTitle - ${isArabic ? "إجمالي قيمة العرض" : "Total Quote"} ($cur)',
            oldValue: o.totalQuotationAmount != null ? '${o.totalQuotationAmount!.toStringAsFixed(2)} $cur' : '—',
            newValue: n.totalQuotationAmount != null ? '${n.totalQuotationAmount!.toStringAsFixed(2)} $cur' : '—',
          ));
        }
        if (FieldChangeItem.isDifferent(o.isExcludedFromAverage, n.isExcludedFromAverage)) {
          changes.add(FieldChangeItem(
            section: secQuotes,
            fieldName: '$quoteTitle - ${isArabic ? "استبعاد من المتوسط الحسابي" : "Exclude from Average"}',
            oldValue: o.isExcludedFromAverage ? excludedLabel : includedLabel,
            newValue: n.isExcludedFromAverage ? excludedLabel : includedLabel,
          ));
        }
      }
    }

    return changes;
  }

  /// Prompts confirmation dialog if any changes were detected between saved and edited study.
  static Future<bool> confirmSessionEdits(
    BuildContext context, {
    required List<FieldChangeItem> changes,
    required String itemReference,
  }) async {
    final isArabic = (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';
    return await showChangeDiffConfirmationDialog(
      context,
      title: isArabic ? 'مراجعة وتأكيد تعديلات دراسة وعروض الشحن' : 'Review and Confirm Shipping Study Edits',
      itemReference: itemReference,
      changes: changes,
    );
  }

  /// Handles save errors gracefully with existing record detection or error dialog.
  static Future<void> handleSaveError({
    required BuildContext context,
    required WidgetRef ref,
    required VoidCallback onRetry,
    required void Function(ShippingEvaluationModel existing) onOpenExisting,
  }) async {
    final failure = ref.read(shippingScenariosProvider).error;
    if (ApiErrorText.code(failure) == ApiErrorCode.scenarioSessionExists) {
      final l = context.l10n;
      final existingId = ApiErrorText.detail(failure)?['session_id'];
      final existingCode = ApiErrorText.detail(failure)?['session_code'];
      showExistingRecordSnack(
        context,
        message: ApiErrorText.of(l, failure),
        actionLabel: l.openExistingRecord,
        onOpen: () {
          final match = ref.read(shippingScenariosProvider).sessions.where(
                (s) => s.sessionId == existingId || (existingCode != null && s.sessionCode == existingCode),
              );
          if (match.isNotEmpty) onOpenExisting(match.first);
        },
      );
      return;
    }
    final err = ApiErrorText.of(context.l10n, failure, fallback: context.l10n.saveFailed);
    await showErrorDetailsDialog(
      context,
      title: context.l10n.saveFailedTitle,
      error: err,
      onRetry: () async => onRetry(),
    );
  }

  /// Full orchestration to validate, diff-confirm, save/update, and display report dialog.
  static Future<bool> saveEvaluationSession({
    required BuildContext context,
    required WidgetRef ref,
    required GlobalKey<FormState> formKey,
    required List<CurrencyModel> currenciesList,
    required int? editingSessionId,
    required String? editingSessionCode,
    required String title,
    required DateTime cargoReadyDate,
    required String pickUpAddress,
    required int avgForm4Days,
    required int avgClearanceDays,
    required int? selectedImportFileId,
    required int? selectedPoId,
    required int? selectedProjectId,
    required String sessionNotes,
    required List<ShippingScenarioItemModel> items,
    required VoidCallback onResetForm,
    required VoidCallback? onSwitchToRegistry,
    required void Function(ShippingEvaluationModel match) onOpenExisting,
  }) async {
    final l = context.l10n;
    if (!formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.completeRequiredDataMsg,
          severity: AppSeverity.danger,
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }

    if (!validateScenarioItems(
      context: context,
      items: items,
      cargoReadyDate: cargoReadyDate,
      currencies: currenciesList,
    )) {
      return false;
    }

    formKey.currentState!.save();

    String titleToSave = title.trim();
    if (selectedImportFileId != null) {
      final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
      final f = importFiles.where((file) => file.importFileId == selectedImportFileId).firstOrNull;
      if (f != null) {
        final fCode = f.displayName;
        if (!titleToSave.startsWith('[$fCode]')) {
          titleToSave = '[$fCode] ${f.companyName}';
        }
      }
    }
    if (titleToSave.isEmpty) {
      titleToSave = l.defaultStudyTitle(DateTime.now().toString().substring(0, 10));
    }

    bool ok = false;
    if (editingSessionId != null) {
      final oldSession = ref.read(shippingScenariosProvider).sessions.where((s) => s.sessionId == editingSessionId).firstOrNull;
      if (oldSession != null) {
        final changes = buildSessionDiffChanges(
          context: context,
          oldSession: oldSession,
          newTitle: titleToSave,
          newCargoReadyDate: cargoReadyDate,
          newPickUpAddress: pickUpAddress,
          newAvgForm4Days: avgForm4Days,
          newAvgClearanceDays: avgClearanceDays,
          newSelectedImportFileId: selectedImportFileId,
          newSelectedPoId: selectedPoId,
          newItems: items,
        );

        if (changes.isNotEmpty) {
          if (!context.mounted) return false;
          final confirmed = await confirmSessionEdits(
            context,
            changes: changes,
            itemReference: oldSession.sessionCode.isNotEmpty ? oldSession.sessionCode : titleToSave,
          );
          if (!confirmed) return false;
        }
      }

      final data = {
        'title': titleToSave,
        'cargo_ready_date': cargoReadyDate.toString().substring(0, 10),
        if (pickUpAddress.trim().isNotEmpty) 'pick_up_address': pickUpAddress.trim(),
        'avg_form4_days': avgForm4Days,
        'avg_clearance_days': avgClearanceDays,
        if (selectedImportFileId != null) 'import_file_id': selectedImportFileId,
        if (selectedPoId != null) 'po_id': selectedPoId,
        if (selectedProjectId != null) 'project_id': selectedProjectId,
        'is_active': true,
        'items': items.map((i) => i.toCreateJson()).toList(),
      };
      ok = await ref.read(shippingScenariosProvider.notifier).updateSession(editingSessionId, data);
    } else {
      final session = ShippingEvaluationModel(
        sessionCode: '',
        title: titleToSave,
        cargoReadyDate: cargoReadyDate.toString().substring(0, 10),
        pickUpAddress: pickUpAddress.trim().isNotEmpty ? pickUpAddress.trim() : null,
        avgForm4Days: avgForm4Days,
        avgClearanceDays: avgClearanceDays,
        importFileId: selectedImportFileId,
        poId: selectedPoId,
        projectId: selectedProjectId,
        notes: sessionNotes,
        items: items,
      );
      ok = await ref.read(shippingScenariosProvider.notifier).createSession(session);
    }

    if (ok && context.mounted) {
      final freshState = ref.read(shippingScenariosProvider);
      final savedSess = freshState.sessions.firstWhere(
        (s) => s.title == titleToSave || s.sessionCode == editingSessionCode,
        orElse: () => ShippingEvaluationModel(
          sessionCode: editingSessionCode ?? 'NEW',
          title: titleToSave,
          cargoReadyDate: cargoReadyDate.toString().substring(0, 10),
          items: items,
          recommendedScenarioProvider: items.isNotEmpty
              ? items.firstWhere((i) => i.isRecommended, orElse: () => items.first).providerName
              : null,
        ),
      );

      onResetForm();
      onSwitchToRegistry?.call();
      ShippingScenariosDialogs.showSaveSuccessReportDialog(context, savedSess);
      return true;
    } else if (!ok && context.mounted) {
      await handleSaveError(
        context: context,
        ref: ref,
        onRetry: () async {
          await saveEvaluationSession(
            context: context,
            ref: ref,
            formKey: formKey,
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editingSessionCode: editingSessionCode,
            title: title,
            cargoReadyDate: cargoReadyDate,
            pickUpAddress: pickUpAddress,
            avgForm4Days: avgForm4Days,
            avgClearanceDays: avgClearanceDays,
            selectedImportFileId: selectedImportFileId,
            selectedPoId: selectedPoId,
            selectedProjectId: selectedProjectId,
            sessionNotes: sessionNotes,
            items: items,
            onResetForm: onResetForm,
            onSwitchToRegistry: onSwitchToRegistry,
            onOpenExisting: onOpenExisting,
          );
        },
        onOpenExisting: onOpenExisting,
      );
      return false;
    }
    return false;
  }
}
