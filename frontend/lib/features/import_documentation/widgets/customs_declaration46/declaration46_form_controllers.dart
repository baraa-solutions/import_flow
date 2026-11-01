import 'package:flutter/material.dart';
import 'declaration46_form_service.dart';

class Declaration46FormControllers {
  final TextEditingController declaration46NoCtrl = TextEditingController();
  final TextEditingController acidNumberCtrl = TextEditingController();
  final TextEditingController form4NumberCtrl = TextEditingController();
  final TextEditingController blNumberCtrl = TextEditingController();
  final TextEditingController customsValueEgpCtrl = TextEditingController();
  final TextEditingController importDutyEgpCtrl = TextEditingController();
  final TextEditingController vatEgpCtrl = TextEditingController();
  final TextEditingController otherFeesEgpCtrl = TextEditingController();
  final TextEditingController totalDutyAndTaxesCtrl = TextEditingController();
  final TextEditingController submissionDateCtrl = TextEditingController(
    text: DateTime.now().toString().substring(0, 10),
  );
  final TextEditingController notesCtrl = TextEditingController();

  // Column B controllers (Revised Estimate)
  final TextEditingController revisedFxRateCtrl = TextEditingController();
  final TextEditingController approvedFreightCtrl = TextEditingController(text: '0.00');
  final TextEditingController actualInsuranceCtrl = TextEditingController(text: '0.00');
  final TextEditingController dischargeExpensesCtrl = TextEditingController(text: '0.00');
  final TextEditingController newCustomsFeesCtrl = TextEditingController(text: '0.00');
  final TextEditingController revisedCifCtrl = TextEditingController();
  final TextEditingController revisedDutyCtrl = TextEditingController();
  final TextEditingController revisedVatCtrl = TextEditingController();
  final TextEditingController revisedOtherFeesCtrl = TextEditingController();
  final TextEditingController revisedTotalDutiesCtrl = TextEditingController();

  // Column C controllers (Nafeza Actual)
  final TextEditingController actualCifCtrl = TextEditingController();
  final TextEditingController actualDutyCtrl = TextEditingController();
  final TextEditingController actualVatCtrl = TextEditingController();
  final TextEditingController actualOtherFeesCtrl = TextEditingController();
  final TextEditingController actualTotalDutiesCtrl = TextEditingController();
  final TextEditingController nafezaClaimNoCtrl = TextEditingController();
  final TextEditingController nafezaClaimDateCtrl = TextEditingController();

  // Duty Variance Reason controller
  final TextEditingController dutyVarianceReasonCtrl = TextEditingController();

  void attachListeners(VoidCallback onDirty) {
    declaration46NoCtrl.addListener(onDirty);
    acidNumberCtrl.addListener(onDirty);
    form4NumberCtrl.addListener(onDirty);
    blNumberCtrl.addListener(onDirty);
    customsValueEgpCtrl.addListener(onDirty);
    notesCtrl.addListener(onDirty);
    dutyVarianceReasonCtrl.addListener(onDirty);
  }

  void applyFormData(Form46LoadedData data) {
    acidNumberCtrl.text = data.acidNumber;
    form4NumberCtrl.text = data.form4Number;
    blNumberCtrl.text = data.blNumber;
    declaration46NoCtrl.text = data.form46No;
    submissionDateCtrl.text = data.declarationDate.toIso8601String().substring(0, 10);
    customsValueEgpCtrl.text = data.cifEgp;
    importDutyEgpCtrl.text = data.importDutyEgp;
    vatEgpCtrl.text = data.vatEgp;
    otherFeesEgpCtrl.text = data.otherFeesEgp;
    totalDutyAndTaxesCtrl.text = data.totalDutiesEgp;

    // Initialize Column B
    revisedFxRateCtrl.text = data.figures?.exchangeRate?.toStringAsFixed(4) ?? '';
    approvedFreightCtrl.text = '0.00';
    actualInsuranceCtrl.text = '0.00';
    dischargeExpensesCtrl.text = '0.00';
    newCustomsFeesCtrl.text = '0.00';
    revisedCifCtrl.text = data.cifEgp;
    revisedDutyCtrl.text = data.importDutyEgp;
    revisedVatCtrl.text = data.vatEgp;
    revisedOtherFeesCtrl.text = data.otherFeesEgp;
    revisedTotalDutiesCtrl.text = data.totalDutiesEgp;

    // Initialize Column C defaults if blank
    if (actualCifCtrl.text.isEmpty) actualCifCtrl.text = data.cifEgp;
    if (actualDutyCtrl.text.isEmpty) actualDutyCtrl.text = data.importDutyEgp;
    if (actualVatCtrl.text.isEmpty) actualVatCtrl.text = data.vatEgp;
    if (actualOtherFeesCtrl.text.isEmpty) actualOtherFeesCtrl.text = data.otherFeesEgp;
    if (actualTotalDutiesCtrl.text.isEmpty) actualTotalDutiesCtrl.text = data.totalDutiesEgp;
  }

  void clearForEmptyFile(DateTime defaultDate) {
    declaration46NoCtrl.clear();
    acidNumberCtrl.clear();
    form4NumberCtrl.clear();
    blNumberCtrl.clear();
    customsValueEgpCtrl.text = '0.00';
    importDutyEgpCtrl.text = '0.00';
    vatEgpCtrl.text = '0.00';
    otherFeesEgpCtrl.text = '0.00';
    totalDutyAndTaxesCtrl.text = '0.00';
    submissionDateCtrl.text = defaultDate.toIso8601String().substring(0, 10);

    revisedFxRateCtrl.clear();
    approvedFreightCtrl.text = '0.00';
    actualInsuranceCtrl.text = '0.00';
    dischargeExpensesCtrl.text = '0.00';
    newCustomsFeesCtrl.text = '0.00';
    revisedCifCtrl.clear();
    revisedDutyCtrl.clear();
    revisedVatCtrl.clear();
    revisedOtherFeesCtrl.clear();
    revisedTotalDutiesCtrl.clear();

    actualCifCtrl.clear();
    actualDutyCtrl.clear();
    actualVatCtrl.clear();
    actualOtherFeesCtrl.clear();
    actualTotalDutiesCtrl.clear();
    nafezaClaimNoCtrl.clear();
    nafezaClaimDateCtrl.clear();
    dutyVarianceReasonCtrl.clear();
  }

  void dispose() {
    declaration46NoCtrl.dispose();
    acidNumberCtrl.dispose();
    form4NumberCtrl.dispose();
    blNumberCtrl.dispose();
    customsValueEgpCtrl.dispose();
    importDutyEgpCtrl.dispose();
    vatEgpCtrl.dispose();
    otherFeesEgpCtrl.dispose();
    totalDutyAndTaxesCtrl.dispose();
    submissionDateCtrl.dispose();
    notesCtrl.dispose();

    revisedFxRateCtrl.dispose();
    approvedFreightCtrl.dispose();
    actualInsuranceCtrl.dispose();
    dischargeExpensesCtrl.dispose();
    newCustomsFeesCtrl.dispose();
    revisedCifCtrl.dispose();
    revisedDutyCtrl.dispose();
    revisedVatCtrl.dispose();
    revisedOtherFeesCtrl.dispose();
    revisedTotalDutiesCtrl.dispose();

    actualCifCtrl.dispose();
    actualDutyCtrl.dispose();
    actualVatCtrl.dispose();
    actualOtherFeesCtrl.dispose();
    actualTotalDutiesCtrl.dispose();
    nafezaClaimNoCtrl.dispose();
    nafezaClaimDateCtrl.dispose();

    dutyVarianceReasonCtrl.dispose();
  }
}
