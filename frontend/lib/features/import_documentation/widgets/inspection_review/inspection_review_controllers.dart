import 'package:flutter/material.dart';

import '../../../import_files/models/import_file_model.dart';
import '../../models/import_documentation_model.dart';

class InspectionReviewControllers {
  final TextEditingController certNumberCtrl = TextEditingController();
  final TextEditingController importerCtrl = TextEditingController();
  final TextEditingController exporterCtrl = TextEditingController();
  final TextEditingController authorityCtrl = TextEditingController();
  final TextEditingController invoiceNoCtrl = TextEditingController();
  final TextEditingController acidCtrl = TextEditingController();
  final TextEditingController originCountryCtrl = TextEditingController();
  final TextEditingController specCtrl = TextEditingController();
  final TextEditingController rawTextCtrl = TextEditingController();
  final TextEditingController overrideReasonCtrl = TextEditingController();

  void dispose() {
    certNumberCtrl.dispose();
    importerCtrl.dispose();
    exporterCtrl.dispose();
    authorityCtrl.dispose();
    invoiceNoCtrl.dispose();
    acidCtrl.dispose();
    originCountryCtrl.dispose();
    specCtrl.dispose();
    rawTextCtrl.dispose();
    overrideReasonCtrl.dispose();
  }

  static String normalizeInspAgency(String raw) {
    final r = raw.trim().toLowerCase();
    if (r.contains('tuv') || r.contains('tüv') || r.contains('rheinland')) return 'TÜV Rheinland';
    if (r.contains('bureau') || r.contains('veritas') || r.contains('bv')) return 'Bureau Veritas';
    if (r.contains('intertek')) return 'Intertek';
    if (r.contains('cotecna')) return 'Cotecna';
    if (r.contains('sgs')) return 'SGS';
    return 'SGS';
  }

  static String normalizeInspType(String raw) {
    final r = raw.trim().toLowerCase();
    if (r.contains('analysis') || r.contains('coa')) return 'COA (Certificate of Analysis)';
    if (r.contains('verification') || r.contains('voc')) return 'VOC (Verification of Conformity)';
    if (r.contains('pre-shipment') || r.contains('psi')) return 'PSI (Pre-Shipment Inspection)';
    return 'COC (Certificate of Conformity)';
  }

  void applyFileSnapshot(ImportFileModel file) {
    importerCtrl.text = file.companyName;
    exporterCtrl.text = file.supplierName;
    invoiceNoCtrl.text = file.piNumber ?? '';
    if (file.acidNumber != null && file.acidNumber!.isNotEmpty) {
      acidCtrl.text = file.acidNumber!;
    }
  }

  void applyDraftTemplate(Map<String, dynamic> template, List<String> standards) {
    if (template['coc_number'] != null) certNumberCtrl.text = template['coc_number'].toString();
    if (template['exporter_name_and_address'] != null) {
      exporterCtrl.text = template['exporter_name_and_address'].toString();
    }
    if (template['importer_name_and_address'] != null) {
      importerCtrl.text = template['importer_name_and_address'].toString();
    }
    if (template['acid_number'] != null) acidCtrl.text = template['acid_number'].toString();
    if (template['country_of_origin'] != null) originCountryCtrl.text = template['country_of_origin'].toString();
    if (standards.isNotEmpty) specCtrl.text = standards.join('\n');
  }

  void applyDialogDraftTemplate(Map<String, dynamic> template, List<String> standards) {
    if (template['coc_number'] != null) certNumberCtrl.text = template['coc_number'].toString();
    if (template['regulatory_authority'] != null) authorityCtrl.text = template['regulatory_authority'].toString();
    if (template['exporter_name_and_address'] != null) {
      exporterCtrl.text = template['exporter_name_and_address'].toString();
    }
    if (template['importer_name_and_address'] != null) {
      importerCtrl.text = template['importer_name_and_address'].toString();
    }
    if (standards.isNotEmpty) specCtrl.text = standards.join('\n');
  }

  void applySmartUpload(Map<String, dynamic> fields, void Function(String agency) onAgencyFound) {
    if (fields['certificate_number'] != null && fields['certificate_number'].toString().isNotEmpty) {
      certNumberCtrl.text = fields['certificate_number'].toString();
    }
    if (fields['importer_name'] != null && fields['importer_name'].toString().isNotEmpty) {
      importerCtrl.text = fields['importer_name'].toString();
    }
    if (fields['exporter_name'] != null && fields['exporter_name'].toString().isNotEmpty) {
      exporterCtrl.text = fields['exporter_name'].toString();
    }
    if (fields['acid_number'] != null && fields['acid_number'].toString().isNotEmpty) {
      acidCtrl.text = fields['acid_number'].toString();
    }
    if (fields['country_of_origin'] != null && fields['country_of_origin'].toString().isNotEmpty) {
      originCountryCtrl.text = fields['country_of_origin'].toString();
    } else if (fields['origin_country'] != null && fields['origin_country'].toString().isNotEmpty) {
      originCountryCtrl.text = fields['origin_country'].toString();
    }
    if (fields['invoice_number'] != null && fields['invoice_number'].toString().isNotEmpty) {
      invoiceNoCtrl.text = fields['invoice_number'].toString();
    }
    if (fields['inspection_agency'] != null && fields['inspection_agency'].toString().isNotEmpty) {
      onAgencyFound(normalizeInspAgency(fields['inspection_agency'].toString()));
    }
    if (fields['regulatory_authority'] != null && fields['regulatory_authority'].toString().isNotEmpty) {
      authorityCtrl.text = fields['regulatory_authority'].toString();
    } else if (fields['inspector_name'] != null && fields['inspector_name'].toString().isNotEmpty) {
      authorityCtrl.text = fields['inspector_name'].toString();
    }
    if (fields['standard_specification'] != null && fields['standard_specification'].toString().isNotEmpty) {
      specCtrl.text = fields['standard_specification'].toString();
    } else if (fields['standards'] != null && (fields['standards'] as List).isNotEmpty) {
      specCtrl.text = (fields['standards'] as List).join(' + ');
    } else if (fields['product_description'] != null && fields['product_description'].toString().isNotEmpty) {
      specCtrl.text = fields['product_description'].toString();
    }
  }

  void applyOcrExtracted(Map<String, dynamic> extracted, void Function(String agency, String type) onMetaFound) {
    if (extracted['coc_number'] != null && extracted['coc_number'].toString().isNotEmpty) {
      certNumberCtrl.text = extracted['coc_number'].toString();
    } else if (extracted['certificate_number'] != null && extracted['certificate_number'].toString().isNotEmpty) {
      certNumberCtrl.text = extracted['certificate_number'].toString();
    }
    if (extracted['exporter_name'] != null && extracted['exporter_name'].toString().isNotEmpty) {
      exporterCtrl.text = extracted['exporter_name'].toString();
    }
    if (extracted['importer_name'] != null && extracted['importer_name'].toString().isNotEmpty) {
      importerCtrl.text = extracted['importer_name'].toString();
    }
    if (extracted['invoice_number'] != null && extracted['invoice_number'].toString().isNotEmpty) {
      invoiceNoCtrl.text = extracted['invoice_number'].toString();
    } else if (extracted['invoices'] != null && (extracted['invoices'] as List).isNotEmpty) {
      final invList = (extracted['invoices'] as List)
          .map((i) => i is Map ? (i['invoice_number'] ?? '').toString() : i.toString())
          .where((s) => s.isNotEmpty)
          .toList();
      if (invList.isNotEmpty) invoiceNoCtrl.text = invList.join(', ');
    }
    if (extracted['regulatory_authority'] != null && extracted['regulatory_authority'].toString().isNotEmpty) {
      authorityCtrl.text = extracted['regulatory_authority'].toString();
    }
    String? foundAgency;
    if (extracted['inspection_agency'] != null && extracted['inspection_agency'].toString().isNotEmpty) {
      foundAgency = normalizeInspAgency(extracted['inspection_agency'].toString());
    }
    String? foundType;
    if (extracted['certificate_type'] != null && extracted['certificate_type'].toString().isNotEmpty) {
      foundType = normalizeInspType(extracted['certificate_type'].toString());
    } else if (extracted['inspection_type'] != null && extracted['inspection_type'].toString().isNotEmpty) {
      foundType = normalizeInspType(extracted['inspection_type'].toString());
    }
    if (foundAgency != null || foundType != null) {
      onMetaFound(foundAgency ?? 'SGS', foundType ?? 'COC (Certificate of Conformity)');
    }
    if (extracted['acid_number'] != null && extracted['acid_number'].toString().isNotEmpty) {
      acidCtrl.text = extracted['acid_number'].toString();
    }
    if (extracted['country_of_origin'] != null && extracted['country_of_origin'].toString().isNotEmpty) {
      originCountryCtrl.text = extracted['country_of_origin'].toString();
    } else if (extracted['origin_country'] != null && extracted['origin_country'].toString().isNotEmpty) {
      originCountryCtrl.text = extracted['origin_country'].toString();
    }
    if (extracted['testing_standards'] != null && (extracted['testing_standards'] as List).isNotEmpty) {
      specCtrl.text = (extracted['testing_standards'] as List).join(' + ');
    } else if (extracted['standards_tested'] != null && (extracted['standards_tested'] as List).isNotEmpty) {
      specCtrl.text = (extracted['standards_tested'] as List).join(' + ');
    }
  }

  void loadSession(InspectionCertificateReviewModel r) {
    final rawTxt = r.rawText ?? r.draftInputData?['raw_text'] ?? '';
    final overrideReason = r.notes ?? r.draftInputData?['override_reason'] ?? '';
    certNumberCtrl.text = r.certificateNumber;
    rawTextCtrl.text = rawTxt;
    overrideReasonCtrl.text = overrideReason;
  }

  Map<String, dynamic> buildDraftFields(String inspType, String inspAgency) {
    return {
      'inspection_type': inspType,
      'inspection_agency': inspAgency,
      'certificate_number': certNumberCtrl.text.trim(),
      'importer_name': importerCtrl.text.trim(),
      'exporter_name': exporterCtrl.text.trim(),
      'acid_number': acidCtrl.text.trim(),
      'country_of_origin': originCountryCtrl.text.trim(),
      'regulatory_authority': authorityCtrl.text.trim(),
      'invoice_number': invoiceNoCtrl.text.trim(),
      'standard_specification': specCtrl.text.trim(),
    };
  }

  Map<String, dynamic> buildExportTemplate({
    required Map<String, dynamic>? activeDraftTemplate,
    required String effectiveAcid,
  }) {
    return activeDraftTemplate ?? {
      'coc_number': certNumberCtrl.text.trim(),
      'importer_name_and_address': importerCtrl.text.trim(),
      'exporter_name_and_address': exporterCtrl.text.trim(),
      'acid_number': acidCtrl.text.trim().isNotEmpty ? acidCtrl.text.trim() : effectiveAcid,
      'country_of_origin': originCountryCtrl.text.trim(),
      'regulatory_authority': authorityCtrl.text.trim(),
      'invoice_number': invoiceNoCtrl.text.trim(),
      'standards': specCtrl.text.trim().split('\n').where((s) => s.isNotEmpty).toList(),
    };
  }
}
