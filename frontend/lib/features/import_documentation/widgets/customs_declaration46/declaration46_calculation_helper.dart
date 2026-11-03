import '../form46_variance_bar.dart';
import 'declaration46_form_controllers.dart';

class Form46RevisedEstimate {
  final double cif;
  final double duty;
  final double vat;
  final double other;
  final double total;

  const Form46RevisedEstimate({
    required this.cif,
    required this.duty,
    required this.vat,
    required this.other,
    required this.total,
  });
}

class Declaration46CalculationHelper {
  static Form46RevisedEstimate calculateRevised({
    required double fobForeign,
    required double fxRate,
    required double freight,
    required double insurance,
    required double discharge,
    required double newFees,
    required double dutyRate,
    required double vatRate,
    required double devRate,
    required double serviceRate,
    required double scheduleTaxRate,
    required double importFeeRate,
  }) {
    double rnd(double v) => (v * 100).roundToDouble() / 100;
    final cif = rnd((fobForeign * fxRate) + freight + insurance);
    final duty = rnd(cif * (dutyRate / 100.0));
    final vatBase = cif + duty;
    final vat = rnd(vatBase * (vatRate / 100.0));
    final scheduleTax = rnd(cif * (scheduleTaxRate / 100.0));
    final devFee = rnd(cif * (devRate / 100.0));
    final serviceFee = rnd(cif * (serviceRate / 100.0));
    final importFee = rnd(cif * (importFeeRate / 100.0));
    final other = rnd(scheduleTax + devFee + serviceFee + importFee + discharge + newFees);
    final total = rnd(duty + vat + other);

    return Form46RevisedEstimate(
      cif: cif,
      duty: duty,
      vat: vat,
      other: other,
      total: total,
    );
  }

  static bool isVarianceOver10({
    required double? studyTot,
    required double? revisedTot,
    required double? actualTot,
  }) {
    final bVsA = Form46VarianceResult.compute(studyTot, revisedTot);
    final cVsA = Form46VarianceResult.compute(studyTot, actualTot);
    final cVsB = Form46VarianceResult.compute(revisedTot, actualTot);

    return (bVsA.diffPercentage?.abs() ?? 0) > 10.0 ||
        (cVsA.diffPercentage?.abs() ?? 0) > 10.0 ||
        (cVsB.diffPercentage?.abs() ?? 0) > 10.0;
  }

  static void applyNafezaExtractedData({
    required Map<String, dynamic> ext,
    required Declaration46FormControllers controllers,
  }) {
    if (ext['declaration_no'] != null && ext['declaration_no'].toString().isNotEmpty) {
      controllers.declaration46NoCtrl.text = ext['declaration_no'].toString();
    }
    if (ext['customs_value'] != null) {
      controllers.actualCifCtrl.text = ext['customs_value'].toString();
    }
    if (ext['import_duty'] != null) {
      controllers.actualDutyCtrl.text = ext['import_duty'].toString();
    }
    if (ext['vat_amount'] != null) {
      controllers.actualVatCtrl.text = ext['vat_amount'].toString();
    }
    double other = 0.0;
    if (ext['schedule_tax'] != null) other += (double.tryParse(ext['schedule_tax'].toString()) ?? 0.0);
    if (ext['wht_amount'] != null) other += (double.tryParse(ext['wht_amount'].toString()) ?? 0.0);
    if (ext['lab_service_fees'] != null) other += (double.tryParse(ext['lab_service_fees'].toString()) ?? 0.0);
    if (other > 0) {
      controllers.actualOtherFeesCtrl.text = other.toStringAsFixed(2);
    }
    if (ext['nafeza_claim_number'] != null || ext['claim_number'] != null) {
      controllers.nafezaClaimNoCtrl.text = (ext['nafeza_claim_number'] ?? ext['claim_number']).toString();
    }
    if (ext['claim_date'] != null) {
      controllers.nafezaClaimDateCtrl.text = ext['claim_date'].toString();
    }

    final duty = double.tryParse(controllers.actualDutyCtrl.text) ?? 0.0;
    final vat = double.tryParse(controllers.actualVatCtrl.text) ?? 0.0;
    final otherFees = double.tryParse(controllers.actualOtherFeesCtrl.text) ?? 0.0;
    controllers.actualTotalDutiesCtrl.text = (duty + vat + otherFees).toStringAsFixed(2);
  }
}
