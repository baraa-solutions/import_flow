import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../customs_tariff/models/customs_tariff_model.dart';
import '../../services/customs_declaration46_calculator.dart';
import '../form46_variance_bar.dart';
import 'declaration46_calculation_helper.dart';
import 'declaration46_form_controllers.dart';
import 'declaration46_form_service.dart';

class Declaration46SaveDelegate {
  static Future<void> selectSubmissionDate({
    required BuildContext context,
    required DateTime currentDate,
    required ValueChanged<DateTime> onDatePicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) {
      onDatePicked(picked);
    }
  }

  static Future<bool> saveDeclaration46({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations l,
    required GlobalKey<FormState> formKey,
    required Declaration46FormControllers controllers,
    required int? selectedImportFileId,
    required String? selectedOffice,
    required String? selectedChannel,
    required DateTime declarationDate,
    required List<CustomsTariffModel> matchedTariffs,
    required Form46Figures? studyFigures,
  }) async {
    if (!formKey.currentState!.validate()) return false;
    if (selectedOffice == null || selectedChannel == null) return false;
    if (selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.customsDeclSelectFileWarning, severity: AppSeverity.danger),
      );
      return false;
    }

    final over10 = Declaration46CalculationHelper.isVarianceOver10(
      studyTot: double.tryParse(controllers.totalDutyAndTaxesCtrl.text),
      revisedTot: double.tryParse(controllers.revisedTotalDutiesCtrl.text),
      actualTot: double.tryParse(controllers.actualTotalDutiesCtrl.text),
    );
    if (over10 && controllers.dutyVarianceReasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.form46VarianceReasonRequired, severity: AppSeverity.danger),
      );
      return false;
    }

    final studyTot = double.tryParse(controllers.totalDutyAndTaxesCtrl.text);
    final actualTot = double.tryParse(controllers.actualTotalDutiesCtrl.text);
    final revisedTot = double.tryParse(controllers.revisedTotalDutiesCtrl.text);
    final effectiveActual = actualTot != null && actualTot > 0 ? actualTot : revisedTot;
    final varResult = Form46VarianceResult.compute(studyTot, effectiveActual);

    return CustomsDeclaration46FormService.saveDeclaration46(
      context: context,
      ref: ref,
      l: l,
      importFileId: selectedImportFileId,
      declaration46No: controllers.declaration46NoCtrl.text,
      declarationDate: declarationDate,
      customsOffice: selectedOffice,
      channelType: selectedChannel,
      tariffItemsCount: matchedTariffs.length,
      notes: controllers.notesCtrl.text,
      customsExchangeRate: double.tryParse(controllers.revisedFxRateCtrl.text) ?? studyFigures?.exchangeRate,
      importDutyAmount: double.tryParse(controllers.actualDutyCtrl.text) ?? double.tryParse(controllers.importDutyEgpCtrl.text),
      vatAmount: double.tryParse(controllers.actualVatCtrl.text) ?? double.tryParse(controllers.vatEgpCtrl.text),
      totalDutyPayable: effectiveActual ?? studyTot,
      estimatedDutyTotal: studyTot,
      actualDutyTotal: effectiveActual,
      dutyVarianceAmount: varResult.diffAmount,
      dutyVariancePercentage: varResult.diffPercentage,
      dutyVarianceReason: controllers.dutyVarianceReasonCtrl.text.trim().isNotEmpty ? controllers.dutyVarianceReasonCtrl.text.trim() : null,
      nafezaClaimNumber: controllers.nafezaClaimNoCtrl.text.trim().isNotEmpty ? controllers.nafezaClaimNoCtrl.text.trim() : null,
      nafezaClaimDate: DateTime.tryParse(controllers.nafezaClaimDateCtrl.text.trim()),
    );
  }
}
