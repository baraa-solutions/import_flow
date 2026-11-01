import 'package:flutter/material.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/import_documentation_model.dart';

class CooReviewControllers {
  final TextEditingController certNumber = TextEditingController();
  final TextEditingController exporter = TextEditingController();
  final TextEditingController exporterRegId = TextEditingController();
  final TextEditingController importer = TextEditingController();
  final TextEditingController originCountry = TextEditingController();
  final TextEditingController destCountry = TextEditingController();
  final TextEditingController invoiceNo = TextEditingController();
  final TextEditingController rawText = TextEditingController();
  final TextEditingController overrideReason = TextEditingController();
  final TextEditingController registrySearch = TextEditingController();

  void applyImportFileSnapshot(ImportFileModel file) {
    importer.text = file.companyName;
    exporter.text = file.supplierName;
    invoiceNo.text = file.piNumber ?? 'INV-FINAL-${file.importFileCode}';
  }

  void applyExtractedFields(Map<String, dynamic> fields) {
    if (fields['certificate_number']?.toString().isNotEmpty == true) {
      certNumber.text = fields['certificate_number'].toString();
    }
    if (fields['origin_country']?.toString().isNotEmpty == true) {
      originCountry.text = fields['origin_country'].toString();
    }
    if (fields['exporter_name']?.toString().isNotEmpty == true) {
      exporter.text = fields['exporter_name'].toString();
    }
    if (fields['exporter_reg_id']?.toString().isNotEmpty == true) {
      exporterRegId.text = fields['exporter_reg_id'].toString();
    }
    if (fields['consignee_name']?.toString().isNotEmpty == true) {
      importer.text = fields['consignee_name'].toString();
    }
    if (fields['importer_name']?.toString().isNotEmpty == true) {
      importer.text = fields['importer_name'].toString();
    }
    if (fields['invoice_number']?.toString().isNotEmpty == true) {
      invoiceNo.text = fields['invoice_number'].toString();
    }
  }

  void applyClonedSession({
    required CertificateOfOriginReviewModel session,
    required String newCode,
    required String suggestedCode,
  }) {
    final expName = session.draftInputData?['exporter_name'] ??
        session.draftInputData?['box_1_exporter'] ??
        session.systemSnapshotData?['supplier_name'] ??
        '—';
    final impName = session.draftInputData?['importer_name'] ??
        session.draftInputData?['box_2_consignee'] ??
        session.systemSnapshotData?['company_name'] ??
        '—';
    final origin = session.draftInputData?['country_of_origin'] ??
        session.draftInputData?['box_3_country_of_origin'] ??
        '—';
    final dest = session.draftInputData?['destination_country'] ??
        session.draftInputData?['box_4_country_of_destination'] ??
        '—';
    final inv = session.draftInputData?['invoice_number'] ??
        session.draftInputData?['box_10_invoice_number_and_date'] ??
        '—';

    certNumber.text = newCode.isNotEmpty ? newCode : suggestedCode;
    exporter.text = expName != '—' ? expName.toString() : '';
    importer.text = impName != '—' ? impName.toString() : '';
    originCountry.text = origin != '—' ? origin.toString() : 'Germany';
    destCountry.text = dest != '—' ? dest.toString() : 'Egypt';
    invoiceNo.text = inv != '—' ? inv.toString() : '';
    rawText.text = session.rawText ?? session.draftInputData?['raw_text'] ?? '';
    overrideReason.clear();
  }

  Map<String, dynamic>? loadSessionIntoEditor(CertificateOfOriginReviewModel session) {
    final expName = session.draftInputData?['exporter_name'] ??
        session.draftInputData?['box_1_exporter'] ??
        session.systemSnapshotData?['supplier_name'] ??
        '';
    final impName = session.draftInputData?['importer_name'] ??
        session.draftInputData?['box_2_consignee'] ??
        session.systemSnapshotData?['company_name'] ??
        '';
    final origin = session.draftInputData?['country_of_origin'] ??
        session.draftInputData?['box_3_country_of_origin'] ??
        'Germany';
    final dest = session.draftInputData?['destination_country'] ??
        session.draftInputData?['box_4_country_of_destination'] ??
        'Egypt';
    final inv = session.draftInputData?['invoice_number'] ??
        session.draftInputData?['box_10_invoice_number_and_date'] ??
        '';

    certNumber.text = session.certificateNumber;
    exporter.text = expName.toString();
    importer.text = impName.toString();
    originCountry.text = origin.toString();
    destCountry.text = dest.toString();
    invoiceNo.text = inv.toString();
    rawText.text = session.rawText ?? session.draftInputData?['raw_text'] ?? '';
    overrideReason.text = session.notes ?? session.draftInputData?['override_reason'] ?? '';

    if (session.comparisonMatrix.isNotEmpty) {
      return {
        'comparison_matrix': session.comparisonMatrix,
        'has_discrepancies': session.hasDiscrepancies,
        'has_critical_mismatch': session.hasCriticalMismatch,
        'system_snapshot_data': session.systemSnapshotData,
        'draft_input_data': session.draftInputData,
      };
    }
    return null;
  }

  void dispose() {
    certNumber.dispose();
    exporter.dispose();
    exporterRegId.dispose();
    importer.dispose();
    originCountry.dispose();
    destCountry.dispose();
    invoiceNo.dispose();
    rawText.dispose();
    overrideReason.dispose();
    registrySearch.dispose();
  }
}
