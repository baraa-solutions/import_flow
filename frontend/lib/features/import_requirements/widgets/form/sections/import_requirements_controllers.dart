import 'package:flutter/material.dart';
import '../../../models/import_requirement_model.dart';

class ImportRequirementsControllers {
  final hsCodeCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final originCtrl = TextEditingController();
  final currencyCtrl = TextEditingController(text: 'USD');
  final valueCtrl = TextEditingController();
  final acidNumberCtrl = TextEditingController();
  final factoryRegCtrl = TextEditingController();
  final cooNotesCtrl = TextEditingController();
  final inspReportNoCtrl = TextEditingController();
  final inspNotesCtrl = TextEditingController();
  final permitNumberCtrl = TextEditingController();
  final permitNotesCtrl = TextEditingController();
  final msdsNotesCtrl = TextEditingController();
  final halalNotesCtrl = TextEditingController();
  final coaNotesCtrl = TextEditingController();
  final specialNotesCtrl = TextEditingController();
  final sailingDateCtrl = TextEditingController();
  final assessedByCtrl = TextEditingController(text: 'كمال - استشاري التخليص الجمركي');

  void dispose() {
    hsCodeCtrl.dispose();
    descCtrl.dispose();
    originCtrl.dispose();
    currencyCtrl.dispose();
    valueCtrl.dispose();
    acidNumberCtrl.dispose();
    factoryRegCtrl.dispose();
    cooNotesCtrl.dispose();
    inspReportNoCtrl.dispose();
    inspNotesCtrl.dispose();
    permitNumberCtrl.dispose();
    permitNotesCtrl.dispose();
    msdsNotesCtrl.dispose();
    halalNotesCtrl.dispose();
    coaNotesCtrl.dispose();
    specialNotesCtrl.dispose();
    sailingDateCtrl.dispose();
    assessedByCtrl.dispose();
  }

  void clearAll() {
    hsCodeCtrl.clear();
    descCtrl.clear();
    originCtrl.clear();
    currencyCtrl.text = 'USD';
    valueCtrl.clear();
    acidNumberCtrl.clear();
    factoryRegCtrl.clear();
    cooNotesCtrl.clear();
    inspReportNoCtrl.clear();
    inspNotesCtrl.clear();
    permitNumberCtrl.clear();
    permitNotesCtrl.clear();
    msdsNotesCtrl.clear();
    halalNotesCtrl.clear();
    coaNotesCtrl.clear();
    specialNotesCtrl.clear();
    sailingDateCtrl.clear();
    assessedByCtrl.text = 'كمال - استشاري التخليص الجمركي';
  }

  void loadFromAssessment(ImportRequirementModel item) {
    acidNumberCtrl.text = item.acidNumber ?? '';
    sailingDateCtrl.text = item.sailingDate ?? '';
    assessedByCtrl.text = item.assessedBy;
    if (item.hsCodeItems.isEmpty) {
      hsCodeCtrl.text = item.hsCode ?? '';
      descCtrl.text = item.commodityDescription ?? '';
      originCtrl.text = item.countryOfOrigin ?? '';
      currencyCtrl.text = item.currency ?? 'USD';
      valueCtrl.text = item.shipmentValue.toStringAsFixed(2);
      factoryRegCtrl.text = item.factoryRegistrationNo ?? '';
      cooNotesCtrl.text = item.cooNotes ?? '';
      inspReportNoCtrl.text = item.inspectionReportNo ?? '';
      inspNotesCtrl.text = item.inspectionNotes ?? '';
      permitNumberCtrl.text = item.permitNumber ?? '';
      permitNotesCtrl.text = item.permitNotes ?? '';
      msdsNotesCtrl.text = item.msdsNotes ?? '';
      halalNotesCtrl.text = item.halalCertNotes ?? '';
      coaNotesCtrl.text = item.coaNotes ?? '';
      specialNotesCtrl.text = item.assessmentNotes ?? '';
    }
  }

  void loadFromPrefill(ImportRequirementPrefillModel prefill) {
    acidNumberCtrl.text = prefill.acidNumber ?? '';
    originCtrl.text = prefill.countryOfOrigin ?? 'China';
    currencyCtrl.text = prefill.currency ?? '';
    valueCtrl.text = prefill.shipmentValue != null ? prefill.shipmentValue!.toStringAsFixed(2) : '';
    factoryRegCtrl.text = prefill.factoryRegistrationNo ?? prefill.foreignExporterId ?? '';
    if (prefill.hsCodeItems.isEmpty) {
      hsCodeCtrl.text = prefill.hsCode ?? '';
      descCtrl.text = prefill.commodityDescription ?? '';
      cooNotesCtrl.text = prefill.cooNotes ?? '';
      inspNotesCtrl.text = prefill.inspectionNotes ?? '';
      permitNotesCtrl.text = prefill.permitNotes ?? '';
      specialNotesCtrl.text = prefill.specialNotes ?? '';
    }
  }

  void loadFromHsItem(ImportRequirementHSCodeItemModel itm) {
    hsCodeCtrl.text = itm.hsCode;
    descCtrl.text = itm.commodityDescription ?? '';
    originCtrl.text = itm.countryOfOrigin ?? originCtrl.text;
    currencyCtrl.text = itm.currency ?? currencyCtrl.text;
    valueCtrl.text = itm.itemValue > 0 ? itm.itemValue.toStringAsFixed(2) : valueCtrl.text;
    factoryRegCtrl.text = itm.factoryRegistrationNo ?? factoryRegCtrl.text;
    cooNotesCtrl.text = itm.cooNotes ?? '';
    inspReportNoCtrl.text = itm.inspectionReportNo ?? '';
    inspNotesCtrl.text = itm.inspectionNotes ?? '';
    permitNumberCtrl.text = itm.permitNumber ?? '';
    permitNotesCtrl.text = itm.permitNotes ?? '';
    msdsNotesCtrl.text = itm.msdsNotes ?? '';
    halalNotesCtrl.text = itm.halalCertNotes ?? '';
    coaNotesCtrl.text = itm.coaNotes ?? '';
    specialNotesCtrl.text = itm.specialNotes ?? '';
  }
}
