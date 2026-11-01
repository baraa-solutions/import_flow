import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../currencies/models/currency_model.dart';
import '../../../external_service_providers/models/partner_model.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../purchase_orders/models/purchase_order_model.dart';
import '../../models/customs_consultation_model.dart';

/// Helper utilities and pure business logic for Customs Consultation Calculator.
class ConsultationCalcLogicHelper {
  /// Initializes the default compliance and documentation checklist.
  static List<CustomsChecklistItemModel> createDefaultChecklist() {
    return [
      CustomsChecklistItemModel(
        documentType: 'Proforma Invoice',
        isRequired: true,
        isBlockingShipment: true,
        responsibleParty: 'Supplier / Exporter',
        status: 'Approved',
        remarks: 'الفاتورة المبدئية معتمدة ومطابقة للبند الجمركي.',
      ),
      CustomsChecklistItemModel(
        documentType: 'Packing List',
        isRequired: true,
        isBlockingShipment: true,
        responsibleParty: 'Supplier / Exporter',
        status: 'Approved',
        remarks: 'محدثة بإجمالي الأوزان الأحجام والطرود.',
      ),
      CustomsChecklistItemModel(
        documentType: 'Certificate of Origin',
        isRequired: true,
        isBlockingShipment: true,
        responsibleParty: 'Customs Broker',
        status: 'Pending',
        remarks: 'مطلوب توثيق السفارة والغرفة التجارية.',
      ),
      CustomsChecklistItemModel(
        documentType: 'GOEIC Inspection',
        isRequired: true,
        isBlockingShipment: true,
        responsibleParty: 'Customs Broker',
        regulatoryAgency: 'GOEIC',
        status: 'Pending',
        remarks: 'يتطلب فحص ظاهري وعينات المعمل فور الوصول.',
      ),
      CustomsChecklistItemModel(
        documentType: 'NTRA Telecommunications Approval',
        isRequired: false,
        isBlockingShipment: false,
        responsibleParty: 'Importer Team',
        regulatoryAgency: 'NTRA',
        status: 'Pending',
        remarks: 'تنطبق في حال وجود وحدات تحكم لاسلكية.',
      ),
    ];
  }

  /// Localizes checklist document types according to active language.
  static String getLocalizedDocType(String docType, AppLocalizations l) {
    if (docType == 'Proforma Invoice' || docType == 'الفاتورة المبدئية') {
      return l.proformaInvoiceDoc;
    }
    if (docType == 'Packing List' || docType == 'بيان التعبئة') {
      return l.packingListDoc;
    }
    if (docType == 'Certificate of Origin' || docType == 'شهادة المنشأ') {
      return l.certificateOfOriginDoc;
    }
    if (docType == 'GOEIC Inspection' ||
        docType == 'فحص هيئة الرقابة على الصادرات والواردات (GOEIC)') {
      return l.goeicInspectionDoc;
    }
    if (docType == 'NTRA Telecommunications Approval' ||
        docType == 'موافقة الجهاز القومي لتنظيم الاتصالات (NTRA)') {
      return l.ntraApprovalDoc;
    }
    if (docType.contains('ACID') || docType.contains('قيد رقم ACID')) {
      return l.acidShipmentDoc;
    }
    if (docType.contains('COO') ||
        docType.contains('شهادة المنشأ الموثقة') ||
        docType.contains('Certificate of Origin')) {
      return l.cooShipmentDoc;
    }
    if (docType.contains('GOEIC') || docType.contains('عرض وفحص هيئة الرقابة')) {
      return l.goeicShipmentDoc;
    }
    if (docType.contains('موافقة') && docType.contains('الفنية المسبقة')) {
      final authority =
          docType.replaceAll('موافقة', '').replaceAll('الفنية المسبقة', '').trim();
      return l.priorAuthorityApprovalDoc(authority);
    }
    if (docType.startsWith('Prior Technical Approval from ')) {
      final authority =
          docType.replaceFirst('Prior Technical Approval from ', '').trim();
      return l.priorAuthorityApprovalDoc(authority);
    }
    return docType;
  }

  /// Localizes remarks without bilingual stacking.
  static String getLocalizedRemarks(String? remarks, AppLocalizations l) {
    if (remarks == null || remarks.isEmpty) return '';
    if (remarks.contains('الفاتورة المبدئية') ||
        remarks.contains('Proforma invoice approved')) {
      return l.proformaInvoiceApprovedRemark;
    }
    if (remarks.contains('محدثة بإجمالي') ||
        remarks.contains('Updated with total weights')) {
      return l.packingListUpdatedRemark;
    }
    if (remarks.contains('توثيق السفارة') ||
        remarks.contains('Embassy and chamber of commerce')) {
      return l.embassyLegalizationRemark;
    }
    if (remarks.contains('فحص ظاهري وعينات المعمل') ||
        remarks.contains('Visual inspection and laboratory')) {
      return l.visualLabInspectionRemark;
    }
    if (remarks.contains('وحدات تحكم لاسلكية') ||
        remarks.contains('wireless remote control')) {
      return l.wirelessModuleRemark;
    }
    return remarks;
  }

  /// Automatically detects currency from matched POs or import file invoices.
  static String detectCurrency({
    required ImportFileModel file,
    required List<PurchaseOrderModel> allPOs,
    required List<CurrencyModel> currencies,
  }) {
    final matchingPOs = allPOs
        .where((p) =>
            (p.importFileId != null && p.importFileId == file.importFileId) ||
            (file.importFileCode.isNotEmpty &&
                p.importFileCode != null &&
                p.importFileCode == file.importFileCode) ||
            (file.poIds != null && p.poId != null && file.poIds!.contains(p.poId)))
        .toList();

    String? detected;
    for (final po in matchingPOs) {
      if (po.currencyId > 0) {
        final c = currencies.where((c) => c.currencyId == po.currencyId).firstOrNull;
        if (c != null && c.currencyCode.isNotEmpty) {
          detected = c.currencyCode;
          break;
        }
      }
      if (po.currencyCode != null && po.currencyCode!.isNotEmpty) {
        detected = po.currencyCode;
        break;
      }
    }

    if (detected == null || detected.isEmpty) {
      if (file.invoicesData.isNotEmpty) {
        final firstInv = file.invoicesData.first;
        if (firstInv.currency.isNotEmpty) {
          detected = firstInv.currency;
        }
      } else if (file.estimatedCostCurrency.isNotEmpty) {
        detected = file.estimatedCostCurrency;
      }
    }

    return detected ?? 'USD';
  }

  /// Upserts AI extracted quotation items into broker quote items.
  static void applyExtractedQuotation({
    required Map<String, dynamic> extracted,
    required List<CustomsBrokerQuoteItemModel> quoteItems,
    required List<PartnerModel> partners,
    required void Function(int? brokerId, String brokerName) onBrokerMatched,
  }) {
    final brokerName = extracted['broker_name']?.toString().toLowerCase() ?? '';
    if (brokerName.isNotEmpty) {
      final matched = partners.where((p) =>
          p.partnerName.toLowerCase().contains(brokerName) ||
          brokerName.contains(p.partnerName.toLowerCase())).firstOrNull;
      if (matched != null) {
        onBrokerMatched(matched.partnerId, matched.partnerName);
      }
    }

    void upsert(String name, String category, double amount, {String currency = 'EGP'}) {
      if (amount <= 0) return;
      final idx = quoteItems.indexWhere((i) =>
          i.expenseName.toLowerCase().trim() == name.toLowerCase().trim() ||
          i.category.toLowerCase().trim() == category.toLowerCase().trim());
      if (idx != -1) {
        final itm = quoteItems[idx];
        quoteItems[idx] = itm.copyWith(
          unitPrice: amount,
          currency: currency,
          qty: 1.0,
          isApplicable: true,
          totalAmount: amount,
        );
      } else {
        quoteItems.insert(
          0,
          CustomsBrokerQuoteItemModel(
            expenseName: name,
            category: category,
            unitType: 'Fixed',
            unitPrice: amount,
            currency: currency,
            qty: 1.0,
            isApplicable: true,
            totalAmount: amount,
          ),
        );
      }
    }

    if (extracted['expenses_catalog'] is List &&
        (extracted['expenses_catalog'] as List).isNotEmpty) {
      for (final item in (extracted['expenses_catalog'] as List)) {
        if (item is Map) {
          final name = item['expense_name']?.toString() ?? '';
          final cat = item['category']?.toString() ?? 'Other Fees';
          final amt = (item['amount'] is num)
              ? (item['amount'] as num).toDouble()
              : (double.tryParse(item['amount']?.toString() ?? '') ?? 0.0);
          final curr = item['currency']?.toString() ?? 'EGP';
          if (name.isNotEmpty && amt > 0) {
            upsert(name, cat, amt, currency: curr);
          }
        }
      }
    }

    final clearanceFee = (extracted['clearance_fee'] is num)
        ? (extracted['clearance_fee'] as num).toDouble()
        : (double.tryParse(extracted['clearance_fee']?.toString() ?? '') ?? 0.0);
    final inlandFee = (extracted['inland_transport_fee'] is num)
        ? (extracted['inland_transport_fee'] as num).toDouble()
        : (double.tryParse(extracted['inland_transport_fee']?.toString() ?? '') ?? 0.0);
    final inspectionFee = (extracted['inspection_fee'] is num)
        ? (extracted['inspection_fee'] as num).toDouble()
        : (double.tryParse(extracted['inspection_fee']?.toString() ?? '') ?? 0.0);
    final portExp = (extracted['port_expenses'] is num)
        ? (extracted['port_expenses'] as num).toDouble()
        : (double.tryParse(extracted['port_expenses']?.toString() ?? '') ?? 0.0);
    final miscFee = (extracted['miscellaneous_fee'] is num)
        ? (extracted['miscellaneous_fee'] as num).toDouble()
        : (double.tryParse(extracted['miscellaneous_fee']?.toString() ?? '') ?? 0.0);

    if (clearanceFee > 0) upsert('Clearance Fees', 'Clearance Agency Fees', clearanceFee);
    if (inlandFee > 0) upsert('Inland Transport', 'Inland Transportation', inlandFee);
    if (inspectionFee > 0) upsert('Customs Inspection', 'Customs Inspection', inspectionFee);
    if (portExp > 0) upsert('Port & Handling', 'Port & Terminal', portExp);
    if (miscFee > 0) upsert('Other Fees', 'Miscellaneous', miscFee);
  }

  /// Builds field change items to compare old vs updated consultation.
  static List<FieldChangeItem> buildFieldChangesDiff({
    required CustomsConsultationModel oldConsultation,
    required String titleToSave,
    required String selectedBrokerName,
    required double estimatedDuties,
    required int? selectedImportFileId,
    required int checklistLength,
    required AppLocalizations l,
  }) {
    final List<FieldChangeItem> changes = [];

    if (FieldChangeItem.isDifferent(oldConsultation.title, titleToSave)) {
      changes.add(FieldChangeItem(
        section: l.diffSectionGeneralData,
        fieldName: l.titleField,
        oldValue: oldConsultation.title,
        newValue: titleToSave,
      ));
    }

    if (FieldChangeItem.isDifferent(oldConsultation.brokerName, selectedBrokerName)) {
      changes.add(FieldChangeItem(
        section: l.diffSectionCustomsBroker,
        fieldName: l.customsBrokerFieldValidation,
        oldValue: oldConsultation.brokerName,
        newValue: selectedBrokerName,
      ));
    }

    if (FieldChangeItem.isDifferent(oldConsultation.estimatedDutiesEgp, estimatedDuties)) {
      changes.add(FieldChangeItem(
        section: l.diffSectionFinancialEstimates,
        fieldName: l.diffFieldEstimatedDuties,
        oldValue: '${oldConsultation.estimatedDutiesEgp.toStringAsFixed(2)} EGP',
        newValue: '${estimatedDuties.toStringAsFixed(2)} EGP',
      ));
    }

    if (FieldChangeItem.isDifferent(oldConsultation.importFileId, selectedImportFileId)) {
      changes.add(FieldChangeItem(
        section: l.diffSectionOperationalLink,
        fieldName: l.diffFieldLinkedImportFile,
        oldValue: oldConsultation.importFileCode ??
            (oldConsultation.importFileId != null
                ? 'ID: ${oldConsultation.importFileId}'
                : null),
        newValue: selectedImportFileId != null ? 'ID: $selectedImportFileId' : null,
      ));
    }

    if (FieldChangeItem.isDifferent(
        oldConsultation.checklistItems.length, checklistLength)) {
      changes.add(FieldChangeItem(
        section: l.diffSectionChecklist,
        fieldName: l.diffFieldTotalChecklistDocs,
        oldValue: '${oldConsultation.checklistItems.length}',
        newValue: '$checklistLength',
      ));
    }

    return changes;
  }

  /// Validates required data before saving consultation study.
  static List<ValidationIssueItem> validateConsultationForm({
    required String title,
    required bool isTaxReviewMode,
    required int? selectedBrokerId,
    required List<CustomsChecklistItemModel> checklist,
    required AppLocalizations l,
  }) {
    final validationErrors = <ValidationIssueItem>[];

    if (title.isEmpty) {
      validationErrors.add(ValidationIssueItem(
        fieldName: l.consultationTitleFieldValidation,
        issueDescription: l.consultationTitleFieldIssue,
        recommendation: l.consultationTitleFieldRec,
        isBlocking: true,
      ));
    }

    if (!isTaxReviewMode && selectedBrokerId == null) {
      validationErrors.add(ValidationIssueItem(
        fieldName: l.customsBrokerFieldValidation,
        issueDescription: l.customsBrokerFieldIssue,
        recommendation: l.customsBrokerFieldRec,
        isBlocking: true,
      ));
    }

    if (!isTaxReviewMode && checklist.isEmpty) {
      validationErrors.add(ValidationIssueItem(
        fieldName: l.checklistFieldValidation,
        issueDescription: l.checklistFieldIssue,
        recommendation: l.checklistFieldRec,
        isBlocking: true,
      ));
    }

    return validationErrors;
  }
}
