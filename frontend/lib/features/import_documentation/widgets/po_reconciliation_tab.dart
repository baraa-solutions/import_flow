import 'package:frontend/core/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../../../core/localization/api_error_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/helpers/file_picker_helper.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/localization/stored_text.dart';
import '../../../core/localization/system_messages/coded_item_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/import_documentation_model.dart';
import '../models/po_reconciliation_session_model.dart';
import '../providers/import_documentation_provider.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/services/table_export_service.dart';
import 'search_and_clone_po_reconciliation_dialog.dart';
import '../utils/po_reconciliation_payload_builder.dart';
import '../../audit_logs/widgets/row_history_dialog.dart';
import '../../purchase_orders/utils/po_packing_matcher.dart';
import 'idoc_ui.dart';
import '../../purchase_orders/models/purchase_order_model.dart' as po_models;

class POReconciliationTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  const POReconciliationTab({super.key, this.initialImportFileId});

  @override
  ConsumerState<POReconciliationTab> createState() => POReconciliationTabState();
}

class POReconciliationTabState extends ConsumerState<POReconciliationTab> {
  static String _formatWeight(double val) => PoPackingMatcher.formatWeight(val);
  String _getLocalizedCheckField(BuildContext context, String fieldName, [String? fieldNameAr]) {
    final l = context.l10n;
    if (l.isArabic && fieldNameAr != null && fieldNameAr.isNotEmpty) {
      return fieldNameAr;
    }
    switch (fieldName) {
      case 'invoice_number':
        return l.poRecCheckFieldInvoiceNumber;
      case 'acid_number':
        return l.poRecCheckFieldAcidNumber;
      case 'total_amount':
        return l.poRecCheckFieldTotalAmount;
      case 'total_packages':
        return l.poRecCheckFieldTotalPackages;
      case 'gross_weight':
        return l.poRecCheckFieldGrossWeight;
      case 'supplier_name':
        return l.poRecCheckFieldSupplierName;
      case 'importer_name':
        return l.poRecCheckFieldImporterName;
      case 'hs_code':
        return l.poRecCheckFieldHsCode;
      case 'tax_id':
        return l.poRecCheckFieldTaxId;
      default:
        return fieldNameAr ?? fieldName;
    }
  }

  String _getLocalizedCheckMessage(BuildContext context, String fieldName, String status, String? rawMessage) {
    final l = context.l10n;
    if (rawMessage != null && rawMessage.isNotEmpty) {
      return rawMessage;
    }
    if (status == 'MATCH') {
      switch (fieldName) {
        case 'invoice_number':
          return l.poRecCheckMsgInvoiceMatched;
        case 'acid_number':
          return l.poRecCheckMsgAcidMatched;
        case 'total_amount':
          return l.poRecCheckMsgTotalAmountMatched;
        default:
          return l.poRecOk;
      }
    }
    return rawMessage ?? '';
  }

  String _getLocalizedSessionStatus(BuildContext context, String status) {
    final l = context.l10n;
    switch (status) {
      case 'FULLY_MATCHED':
        return l.poRecMatchStatusMatched;
      case 'ACCEPTED_WITH_WARNINGS':
        return l.poRecMatchStatusWarning;
      case 'CRITICAL_DISCREPANCY':
        return l.poRecMatchStatusCritical;
      default:
        return status;
    }
  }

  final ScrollController _mainScrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  int? _selectedImportFileId;
  final TextEditingController _finalInvNumberCtrl = TextEditingController();
  final TextEditingController _finalPLNumberCtrl = TextEditingController();

  List<POReconciliationItemModel> _invoiceItems = [];
  List<POReconciliationItemModel> _packingItems = [];
  bool _isSubmitting = false;
  bool _isSavingSession = false;

  // Active loaded session (if loaded from history)
  int? _activeSessionId;
  String? _activeSessionCode;

  // --- SMART EXTRACTION & 3-WAY RECONCILIATION TOOL STATE ---
  bool _showSmartExtractionTool = true;
  bool _isExtracting = false;
  final TextEditingController _invoiceTextCtrl = TextEditingController();
  final TextEditingController _packingTextCtrl = TextEditingController();
  String? _selectedInvoiceFileName;
  String? _selectedPackingFileName;
  Uint8List? _invoiceFileBytes;
  Uint8List? _packingFileBytes;
  Map<String, dynamic>? _extractedReconciliationData;

  // --- HISTORY TAB FILTERS ---
  final TextEditingController _searchHistoryCtrl = TextEditingController();
  String _statusFilter = 'All';

  static const String sampleGIIndustrialInvoice = '''
G.I. INDUSTRIAL HOLDING SPA
Via G. Agnelli, 7 - 33053 Latisana (UD) - Italy
P.IVA IT01982510305
COMMERCIAL INVOICE Date 30/06/2026 Page 1
V1/ 2562
Client id. no. 801765
V.A.T. ID Number 200183044
Messrs
ECO ASSOCIATES
7 HOSNI OSMAN ST., SEFARAT DISTRICT
11471 NASR CITY, CAIRO
Egitto
Payment condition 100% AVV. MERCE PRONTA-PICK UP CONF.
Bank IT80Q0503412301USD100004026
SWIFT BAPPIT21682
Shipping - Delivery terms - As per INCOTERMS 2020
EX WORKS EXTRA UE

Your order ECO/049/2026/REV00
Our order confirmation M26 413 date 5/03/26
Commessa 27/360012
CYK4R6018210001 RTAXT/K/EC/MS 182 IM/RFM/RFL/PF/NS DOUBLE SKIN PACKAGED ROOF TOP 84158200 2,000 NR 18.602,37500 37.204,75 NI
QCR12026802R AG - RUBBER SHOCK ABSORBERS 2,000 NR 268,12500 536,25 NI

ACID NR. 2001830441013710010
IMPORTER TAX ID: 200183044
EXPORTER REGISTRATION NUMBER: 01982510305

Total goods 37.741,00
TOTAL INVOICE AMOUNT 37.741,00 EUR
Net weight kg 2.254,000
Gross weight kg 2.274,000
Packages 4
''';

  static const String sampleGIIndustrialPackingList = '''
Latisana, 30/06/2026
ECO ASSOCIATES
7 HOSNI OSMAN ST. SEFARAT DISTRICT
11471 NASR CITY, CAIRO
EGYPT

NOSTRO ORDINE / OUR ORDER M26 413
COMMESSA 27/360012
VOSTRO ORDINE / YOUR ORDER ECO/049/2026/REV00
ACID NUMBER 2001830441013710010

PACKING AND WEIGHT LIST
DESCRIZIONE / DESCRIPTION Q.TY (NO) LENGTH (mm.) WIDTH (mm.) HEIGHT (mm.) NET (KG) GROSS (KG) (NO) (TYPE)
RTAXT/K/EC/MS 182 IM/RFM/RFL/PF/NS 2 3950 2250 2250 2250 2270 2 PACKAGE
QCR12026802R 1 275 265 160 4 4 2 BOX
KG / COLLI 2254,0 2274,0 4,0 TOTAL
''';

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    Future.microtask(() async {
      if (!ref.read(importFilesProvider).isLoading) {
        await ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
      if (!ref.read(purchaseOrdersProvider).isLoading) {
        await ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      }
      if (!ref.read(poReconciliationSessionsProvider).isLoading) {
        await ref.read(poReconciliationSessionsProvider.notifier).fetchSessions();
      }
      if (_selectedImportFileId == null && mounted) {
        final files = ref.read(importFilesProvider).valueOrNull ?? [];
        if (files.isNotEmpty) {
          setState(() {
            _selectedImportFileId = files.first.importFileId;
          });
        }
      }
      if (_selectedImportFileId != null && mounted) {
        final sessionsList = ref.read(poReconciliationSessionsProvider).valueOrNull ?? [];
        final existing = sessionsList.where((s) => s.importFileId == _selectedImportFileId && s.isActive).firstOrNull;
        if (existing != null) {
          _loadSessionIntoEditor(existing);
        } else {
          _loadPOItems(_selectedImportFileId!);
        }
      }
    });
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    _finalInvNumberCtrl.dispose();
    _finalPLNumberCtrl.dispose();
    _invoiceTextCtrl.dispose();
    _packingTextCtrl.dispose();
    _searchHistoryCtrl.dispose();
    super.dispose();
  }


  void _loadSampleData() {
    setState(() {
      _invoiceTextCtrl.text = sampleGIIndustrialInvoice.trim();
      _packingTextCtrl.text = sampleGIIndustrialPackingList.trim();
      _selectedInvoiceFileName = 'Commercial_Invoice_V1_2562.pdf';
      _selectedPackingFileName = 'Packing_and_Weight_List_M26_413.pdf';
      _invoiceFileBytes = null;
      _packingFileBytes = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.poRecSampleLoadedSuccess),
    );
  }

  Future<void> _pickFile(bool isInvoice) async {
    final l = context.l10n;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'tif', 'tiff', 'txt', 'csv', 'xlsx', 'docx', 'doc', 'xls'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileBytes = FilePickerHelper.getBytes(file);
        final text = (FilePickerHelper.isPlainTextFile(file.name)
                ? FilePickerHelper.tryDecodeText(fileBytes)
                : null) ??
            l.poRecExtractedDigitalFileNotice(file.name);

        setState(() {
          if (isInvoice) {
            _selectedInvoiceFileName = file.name;
            _invoiceFileBytes = fileBytes;
            _invoiceTextCtrl.text = text;
          } else {
            _selectedPackingFileName = file.name;
            _packingFileBytes = fileBytes;
            _packingTextCtrl.text = text;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, l.poRecFileSelected(file.name, (file.size / 1024).toStringAsFixed(1))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.poRecFilePickFailed(e.toString()), severity: AppSeverity.info));
      }
    }
  }

  void _showInputValidationDialog({
    required String title,
    required List<String> issues,
    required List<String> recommendations,
  }) {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.poRecInputValidationDesc,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.severityBackgroundOf(context, AppSeverity.danger),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.crimsonBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: issues.map((issue) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.cancel, color: AppTheme.crimson, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(issue, style: const TextStyle(fontSize: 12.5, color: AppTheme.crimson))),
                      ],
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 14),
              Text(l.poRecInputValidationRecHeader, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.emeraldBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: recommendations.map((rec) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle, color: AppTheme.emerald, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(rec, style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary))),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IdocUi.fit(AppButton(
            label: l.poRecInputValidationGotIt,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx),
          )),
        ],
      ),
    );
  }

  Future<void> _runSmartExtractionAndComparison() async {
    final l = context.l10n;
    final invText = _invoiceTextCtrl.text.trim();
    final plText = _packingTextCtrl.text.trim();

    final List<String> inputIssues = [];
    final List<String> inputRecommendations = [];

    if (_selectedImportFileId == null) {
      inputIssues.add(l.poRecIssueNoFileSelected);
      inputRecommendations.add(l.poRecRecSelectFileFromList);
    }

    final hasInvoiceInput = (_invoiceFileBytes != null) || (invText.isNotEmpty && !invText.startsWith('['));
    final hasPackingInput = (_packingFileBytes != null) || (plText.isNotEmpty && !plText.startsWith('['));

    if (!hasInvoiceInput && !hasPackingInput) {
      inputIssues.add(l.poRecIssueEmptyInputs);
      inputRecommendations.add(l.poRecRecProvideInputs);
    }

    if (inputIssues.isNotEmpty) {
      _showInputValidationDialog(
        title: l.poRecInputValidationTitle,
        issues: inputIssues,
        recommendations: inputRecommendations,
      );
      return;
    }

    setState(() => _isExtracting = true);

    try {
      final dio = ref.read(uploadDioProvider);

      FormData? formData;
      Map<String, dynamic>? jsonPayload;

      final bool hasBinaryFiles = _invoiceFileBytes != null || _packingFileBytes != null;

      if (hasBinaryFiles) {
        final formMap = <String, dynamic>{
          if (_selectedImportFileId != null) 'import_file_id': _selectedImportFileId.toString(),
        };

        if (_invoiceFileBytes != null) {
          formMap['invoice_file'] = MultipartFile.fromBytes(
            _invoiceFileBytes!,
            filename: _selectedInvoiceFileName ?? 'invoice.pdf',
          );
        } else if (invText.isNotEmpty && !invText.startsWith('[')) {
          formMap['invoice_text'] = invText;
        }

        if (_packingFileBytes != null) {
          formMap['packing_file'] = MultipartFile.fromBytes(
            _packingFileBytes!,
            filename: _selectedPackingFileName ?? 'packing_list.pdf',
          );
        } else if (plText.isNotEmpty && !plText.startsWith('[')) {
          formMap['packing_text'] = plText;
        }

        formData = FormData.fromMap(formMap);
      } else {
        jsonPayload = {
          'import_file_id': _selectedImportFileId,
          'invoice_raw_text': invText,
          'packing_list_raw_text': plText,
          'system_items': _invoiceItems.map((i) => i.toJson()).toList(),
          'system_packing_items': _packingItems.map((i) => i.toJson()).toList(),
        };
      }

      final endpoint = hasBinaryFiles
          ? '${ApiConstants.baseUrl}/import-documentation/po-reconciliation/extract-files-and-compare'
          : '${ApiConstants.baseUrl}/import-documentation/po-reconciliation/extract-and-compare';

      final response = await dio.post(
        endpoint,
        data: hasBinaryFiles ? formData : jsonPayload,
      );

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _extractedReconciliationData = response.data as Map<String, dynamic>;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, l.poRecServerSuccessNotice, severity: AppSeverity.success),
          );
        }
      }
    } catch (e) {
      debugPrint('[PO_RECONCILIATION] Backend extraction error: $e');
      final fallbackResult = _performClientSideFallbackExtraction(invText, plText);
      setState(() {
        _extractedReconciliationData = fallbackResult;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l.poRecFallbackSuccessNotice, severity: AppSeverity.success),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Map<String, dynamic> _performClientSideFallbackExtraction(String invText, String plText) {
    final invData = _parseInvoiceClientSide(invText);
    final plData = _parsePackingClientSide(plText);

    // Retrieve real system values for the selected file & PO
    final allFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final currentFile = allFiles.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;
    final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
    final linkedPOs = allPOs.where((po) => po.importFileId == _selectedImportFileId).toList();
    final linkedPO = linkedPOs.firstOrNull;

    String? nonEmpty(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    num? asNum(Object? v) => v is num ? v : num.tryParse('${v ?? ''}');

    final String? sysInvNum = nonEmpty(_finalInvNumberCtrl.text) ?? nonEmpty(linkedPO?.poNumber);
    final String? sysAcid = nonEmpty(currentFile?.acidNumber);
    final double sysTotalAmt = linkedPO?.totalAmountFob ?? 0.0;
    final String sysCurrency = linkedPO?.currencyCode ?? currentFile?.estimatedCostCurrency ?? 'USD';
    final double sysTotalPkgs = (linkedPO != null && linkedPO.totalPackagesCount > 0)
        ? linkedPO.totalPackagesCount.toDouble()
        : _packingItems.fold(0.0, (s, i) => s + i.initialPackagesCount);
    final double sysGrossWt = (linkedPO != null && linkedPO.totalGrossWeightKg > 0)
        ? linkedPO.totalGrossWeightKg
        : _packingItems.fold(0.0, (s, i) => s + i.initialGrossWeightKg);

    // The items mirror the backend reconciliation (ai_document_parser.reconcile_po_documents_with_system):
    // English text + `details_code` / `details_params` + `structured_values`, so the UI renders them in
    // the user's language and nothing language-dependent is stored.
    final List<Map<String, dynamic>> headerDiscrepancies = [];
    Object orPlaceholder(String? v, String placeholder) => v ?? CodedPlaceholder(placeholder);
    final notSetText = DomainEnums.label(storedText, DomainEnumType.valuePlaceholder, 'NOT_SET');

    void addCheck({
      required String field,
      required String fieldAr,
      required String status,
      required Object system,
      required Object extracted,
      Object? systemInvoice,
      Object? systemPacking,
      Object? uploadedInvoice,
      Object? uploadedPacking,
      required Map<String, dynamic> details,
    }) {
      headerDiscrepancies.add(CodedItemText.finalize({
        'field_name': field,
        'field_name_ar': fieldAr,
        'system_value': system,
        'extracted_value': extracted,
        'system_invoice_value': systemInvoice ?? system,
        'system_packing_value': systemPacking ?? system,
        'uploaded_invoice_value': uploadedInvoice ?? extracted,
        'uploaded_packing_value': uploadedPacking ?? extracted,
        'status': status,
        ...details,
      }));
    }

    // Reading failures have no system message: the English text is stored as is.
    Map<String, dynamic> unreadable(String english) => {'details': english};
    bool contains(String a, String b) => a.toLowerCase().contains(b.toLowerCase());

    // Check Invoice Number
    final extractedInvNum = nonEmpty(invData['invoice_number'] as String?);
    final bool invNumMatched = extractedInvNum != null &&
        sysInvNum != null &&
        (extractedInvNum.toLowerCase() == sysInvNum.toLowerCase() ||
            contains(sysInvNum, extractedInvNum) ||
            contains(extractedInvNum, sysInvNum));
    addCheck(
      field: 'invoice_number',
      fieldAr: 'رقم الفاتورة التجارية النهائية',
      status: extractedInvNum == null ? 'WARNING' : (invNumMatched ? 'MATCH' : 'DISCREPANCY'),
      system: orPlaceholder(sysInvNum, 'NOT_SET'),
      extracted: orPlaceholder(extractedInvNum, 'NOT_IN_DOCUMENT'),
      uploadedPacking: orPlaceholder(nonEmpty(plData['invoice_number'] as String?), 'NOT_IN_DOCUMENT'),
      details: extractedInvNum == null
          ? unreadable('Could not read the invoice number from the uploaded file')
          : CodedItemText.coded(
              'details',
              invNumMatched ? 'DOC_CHK_INVOICE_NO_MATCH' : 'DOC_CHK_INVOICE_NO_MISMATCH',
              invNumMatched ? const {} : {'document_value': extractedInvNum, 'system_value': sysInvNum ?? notSetText}),
    );

    // Check ACID
    final extractedAcid = nonEmpty(plData['acid_number'] as String?) ?? nonEmpty(invData['acid_number'] as String?);
    final bool acidMatched = extractedAcid != null && sysAcid != null && extractedAcid == sysAcid;
    addCheck(
      field: 'acid_number',
      fieldAr: 'رقم القيد الجمركي المبدئي (ACID)',
      status: extractedAcid == null ? 'WARNING' : (acidMatched ? 'MATCH' : 'DISCREPANCY'),
      system: orPlaceholder(sysAcid, 'NOT_SET'),
      extracted: orPlaceholder(extractedAcid, 'NOT_IN_DOCUMENT'),
      uploadedInvoice: orPlaceholder(nonEmpty(invData['acid_number'] as String?), 'NOT_IN_DOCUMENT'),
      uploadedPacking: orPlaceholder(nonEmpty(plData['acid_number'] as String?), 'NOT_IN_DOCUMENT'),
      details: extractedAcid == null
          ? unreadable('Could not read the ACID number from the uploaded documents')
          : CodedItemText.coded('details', acidMatched ? 'DOC_CHK_ACID_MATCH' : 'DOC_CHK_ACID_MISMATCH'),
    );

    // Check Currency & Total Amount
    final double? totalInvAmt = (invData['total_amount'] as num?)?.toDouble();
    final String extCurr = (invData['currency'] as String?) ?? sysCurrency;
    final bool currencyMatched = extCurr.toUpperCase() == sysCurrency.toUpperCase();
    final bool amtMatched = totalInvAmt != null && (totalInvAmt - sysTotalAmt).abs() < 1.0 && currencyMatched;
    final double amtDiff = totalInvAmt == null ? 0 : (totalInvAmt - sysTotalAmt).abs();
    final String sysAmountText = '${CodedItemText.formatGrouped(sysTotalAmt, 2)} $sysCurrency';
    final String? extAmountText =
        totalInvAmt == null ? null : '${CodedItemText.formatGrouped(totalInvAmt, 2)} $extCurr';
    addCheck(
      field: 'total_amount',
      fieldAr: 'إجمالي قيمة الفاتورة التجارية',
      status: totalInvAmt == null ? 'WARNING' : (amtMatched ? 'MATCH' : 'DISCREPANCY'),
      system: sysAmountText,
      extracted: orPlaceholder(extAmountText, 'NOT_IN_DOCUMENT'),
      systemPacking: const CodedPlaceholder('NOT_IN_PACKING_LIST'),
      uploadedPacking: '—',
      details: totalInvAmt == null
          ? unreadable('Could not read the total amount from the document')
          : (amtMatched
              ? CodedItemText.coded('details', 'DOC_CHK_AMOUNT_MATCH')
              : (!currencyMatched
                  ? CodedItemText.coded('details', 'DOC_CHK_CURRENCY_MISMATCH',
                      {'system_currency': sysCurrency, 'document_currency': extCurr})
                  : CodedItemText.coded('details', 'DOC_CHK_AMOUNT_VARIANCE', {
                      'variance_amount': double.parse(amtDiff.toStringAsFixed(2)),
                      'currency': sysCurrency,
                      'variance_pct': sysTotalAmt > 0 ? double.parse((amtDiff / sysTotalAmt * 100).toStringAsFixed(2)) : 0,
                    }))),
    );

    // Check Total Packages
    final double? totalPlPkgs = (plData['total_packages'] as num?)?.toDouble();
    final bool pkgsMatched = totalPlPkgs != null && (totalPlPkgs - sysTotalPkgs).abs() < 0.01;
    final num? invQtyPkg = asNum(invData['qty_pkg']);
    addCheck(
      field: 'total_packages',
      fieldAr: 'إجمالي عدد الطرود',
      status: totalPlPkgs == null ? 'WARNING' : (pkgsMatched ? 'MATCH' : 'DISCREPANCY'),
      system: CodedMeasure(sysTotalPkgs.toInt(), 'PACKAGES', decimals: null),
      extracted: totalPlPkgs == null
          ? const CodedPlaceholder('NOT_IN_DOCUMENT')
          : CodedMeasure(totalPlPkgs.toInt(), 'PACKAGES', decimals: null),
      uploadedInvoice: invQtyPkg == null
          ? const CodedPlaceholder('NOT_IN_INVOICE')
          : CodedMeasure(invQtyPkg, 'PACKAGES', decimals: null),
      details: totalPlPkgs == null
          ? unreadable('Could not read the package count from the packing list')
          : (pkgsMatched
              ? CodedItemText.coded('details', 'DOC_CHK_PACKAGES_MATCH')
              : CodedItemText.coded('details', 'DOC_CHK_PACKAGES_VARIANCE', {
                  'difference_count': (totalPlPkgs - sysTotalPkgs).abs().toInt(),
                })),
    );

    // Check Gross Weight
    final double? totalPlGross = (plData['total_gross_weight_kg'] as num?)?.toDouble();
    final bool grossMatched = totalPlGross != null && (totalPlGross - sysGrossWt).abs() < 1.0;
    final num? invGross = asNum(invData['total_gross_weight_kg']);
    final double grossDiff = totalPlGross == null ? 0 : (totalPlGross - sysGrossWt).abs();
    addCheck(
      field: 'gross_weight',
      fieldAr: 'الوزن الإجمالي القائم',
      status: totalPlGross == null ? 'WARNING' : (grossMatched ? 'MATCH' : 'DISCREPANCY'),
      system: CodedMeasure(sysGrossWt, 'KG'),
      extracted: totalPlGross == null ? const CodedPlaceholder('NOT_IN_DOCUMENT') : CodedMeasure(totalPlGross, 'KG'),
      uploadedInvoice: invGross == null ? const CodedPlaceholder('NOT_IN_INVOICE') : CodedMeasure(invGross, 'KG'),
      details: totalPlGross == null
          ? unreadable('Could not read the gross weight from the packing list')
          : (grossMatched
              ? CodedItemText.coded('details', 'DOC_CHK_GROSS_WEIGHT_MATCH')
              : CodedItemText.coded('details', 'DOC_CHK_GROSS_WEIGHT_VARIANCE', {
                  'difference_qty': double.parse(grossDiff.toStringAsFixed(2)),
                  'difference_pct': sysGrossWt > 0 ? double.parse((grossDiff / sysGrossWt * 100).toStringAsFixed(2)) : 0,
                })),
    );

    // Check Supplier Name
    final String? extractedSupplier =
        nonEmpty(invData['supplier_name'] as String?) ?? nonEmpty(invData['shipper_name'] as String?);
    final String? sysSupplier = nonEmpty(linkedPO?.supplierName);
    final bool supplierMatched = extractedSupplier != null && sysSupplier != null
        ? contains(extractedSupplier, sysSupplier) || contains(sysSupplier, extractedSupplier)
        : true;
    addCheck(
      field: 'supplier_name',
      fieldAr: 'اسم المورد الأجنبي',
      status: extractedSupplier == null ? 'WARNING' : (supplierMatched ? 'MATCH' : 'DISCREPANCY'),
      system: orPlaceholder(sysSupplier, 'NOT_SET'),
      extracted: orPlaceholder(extractedSupplier, 'NOT_IN_DOCUMENT'),
      uploadedPacking:
          orPlaceholder(nonEmpty((plData['supplier_name'] ?? plData['shipper_name']) as String?), 'NOT_IN_DOCUMENT'),
      details: extractedSupplier == null
          ? unreadable('Could not read the supplier name from the document')
          : CodedItemText.coded(
              'details',
              supplierMatched ? 'DOC_CHK_SUPPLIER_MATCH' : 'DOC_CHK_SUPPLIER_MISMATCH',
              supplierMatched ? const {} : {'document_value': extractedSupplier, 'system_value': sysSupplier}),
    );

    // Check Importer Name
    final String? extractedImporter =
        nonEmpty(invData['importer_name'] as String?) ?? nonEmpty(invData['consignee_name'] as String?);
    final String? sysImporter = nonEmpty(currentFile?.companyName);
    final bool importerMatched = extractedImporter != null && sysImporter != null
        ? contains(extractedImporter, sysImporter) || contains(sysImporter, extractedImporter)
        : true;
    addCheck(
      field: 'importer_name',
      fieldAr: 'اسم الشركة المستوردة',
      status: extractedImporter == null ? 'WARNING' : (importerMatched ? 'MATCH' : 'DISCREPANCY'),
      system: orPlaceholder(sysImporter, 'NOT_SET'),
      extracted: orPlaceholder(extractedImporter, 'NOT_IN_DOCUMENT'),
      uploadedPacking:
          orPlaceholder(nonEmpty((plData['importer_name'] ?? plData['consignee_name']) as String?), 'NOT_IN_DOCUMENT'),
      details: extractedImporter == null
          ? unreadable('Could not read the importer name from the document')
          : CodedItemText.coded(
              'details',
              importerMatched ? 'DOC_CHK_IMPORTER_MATCH' : 'DOC_CHK_IMPORTER_MISMATCH',
              importerMatched ? const {} : {'document_value': extractedImporter, 'system_value': sysImporter}),
    );

    // Check HS Code
    final String? extractedHs = nonEmpty(invData['hs_code'] as String?);
    final String? sysHs = _packingItems.isNotEmpty ? nonEmpty(_packingItems.first.hsCode) : null;
    final bool hsMatched = extractedHs != null && sysHs != null
        ? extractedHs.replaceAll('.', '') == sysHs.replaceAll('.', '') ||
            extractedHs.contains(sysHs) ||
            sysHs.contains(extractedHs)
        : true;
    addCheck(
      field: 'hs_code',
      fieldAr: 'البند الجمركي (HS Code)',
      status: extractedHs == null ? 'WARNING' : (hsMatched ? 'MATCH' : 'DISCREPANCY'),
      system: orPlaceholder(sysHs, 'NOT_SET'),
      extracted: orPlaceholder(extractedHs, 'NOT_IN_DOCUMENT'),
      uploadedPacking: orPlaceholder(nonEmpty(plData['hs_code'] as String?), 'NOT_IN_DOCUMENT'),
      details: extractedHs == null
          ? unreadable('Could not read the HS code from the document')
          : CodedItemText.coded(
              'details',
              hsMatched ? 'DOC_CHK_HS_CODE_MATCH' : 'DOC_CHK_HS_CODE_MISMATCH',
              hsMatched ? const {} : {'document_value': extractedHs, 'system_value': sysHs}),
    );

    // Reconciled items from loaded system data
    final List<Map<String, dynamic>> reconciledInvItems = _invoiceItems.map((i) => i.toJson()).toList();
    final List<Map<String, dynamic>> reconciledPackingItems = _packingItems.map((i) => i.toJson()).toList();

    final int critCount = headerDiscrepancies.where((d) => d['status'] == 'DISCREPANCY').length;
    final int warnCount = headerDiscrepancies.where((d) => d['status'] == 'WARNING').length;
    final String overallStatus = critCount > 0
        ? 'CRITICAL_DISCREPANCY'
        : (warnCount > 0 ? 'ACCEPTED_WITH_WARNINGS' : 'FULLY_MATCHED');

    return {
      'overall_status': overallStatus,
      'is_safe_for_certification': critCount == 0,
      'critical_discrepancies_count': critCount,
      'warning_discrepancies_count': warnCount,
      'header_discrepancies': headerDiscrepancies,
      'reconciled_invoice_items': reconciledInvItems,
      'reconciled_packing_items': reconciledPackingItems,
      'extracted_invoice_data': invData,
      'extracted_packing_data': plData,
    };
  }

  Map<String, dynamic> _parseInvoiceClientSide(String text) {
    String? invNum;
    String? acid;
    double? totalAmt;
    String? currency;

    final invMatch = RegExp(r'(?:COMMERCIAL\s+INVOICE|INV(?:OICE)?\.?\s*(?:NO|NR|NUMBER)?:?)[\s\S]*?([A-Z0-9]+[/-][A-Z0-9-]+)', caseSensitive: false).firstMatch(text);
    if (invMatch != null) invNum = invMatch.group(1)?.replaceAll(RegExp(r'\s+'), '');

    final acidMatch = RegExp(r'(?:ACID|A\.C\.I\.D)[\s\S]*?(\d{19})', caseSensitive: false).firstMatch(text);
    if (acidMatch != null) acid = acidMatch.group(1);

    final amtMatch = RegExp(r'(?:TOTAL\s+INVOICE\s+AMOUNT|TOTAL\s+AMOUNT|SAY\s+TOTAL\s+(?:USD|EUR)|TOTAL)[\s:]*([A-Z]{3})?\s*([\d.,]+)\s*([A-Z]{3})?', caseSensitive: false).firstMatch(text);
    if (amtMatch != null) {
      String rawVal = (amtMatch.group(2) ?? amtMatch.group(1) ?? '').replaceAll(',', '');
      totalAmt = double.tryParse(rawVal);
      if (amtMatch.group(3) != null) {
        currency = amtMatch.group(3)!;
      } else if (amtMatch.group(1) != null && amtMatch.group(1)!.length == 3) {
        currency = amtMatch.group(1)!;
      }
    }

    if (currency == null) {
      if (text.contains('USD') || text.contains(r'$')) {
        currency = 'USD';
      } else if (text.contains('EUR') || text.contains('€')) {
        currency = 'EUR';
      }
    }

    return {
      if (invNum != null) 'invoice_number': invNum,
      if (acid != null) 'acid_number': acid,
      if (totalAmt != null) 'total_amount': totalAmt,
      if (currency != null) 'currency': currency,
      'items': [],
    };
  }

  Map<String, dynamic> _parsePackingClientSide(String text) {
    String? acid;
    double? netW;
    double? grossW;
    double? pkgs;

    final acidMatch = RegExp(r'(?:ACID|A\.C\.I\.D)[\s\S]*?(\d{19})', caseSensitive: false).firstMatch(text);
    if (acidMatch != null) acid = acidMatch.group(1);

    final netMatch = RegExp(r'(?:Net\s+weight|TOTAL\s+NET)[\s\w]*?([\d.,]+)', caseSensitive: false).firstMatch(text);
    if (netMatch != null) netW = double.tryParse(netMatch.group(1)!.replaceAll(',', ''));

    final grossMatch = RegExp(r'(?:Gross\s+weight|TOTAL\s+GROSS)[\s\w]*?([\d.,]+)', caseSensitive: false).firstMatch(text);
    if (grossMatch != null) grossW = double.tryParse(grossMatch.group(1)!.replaceAll(',', ''));

    final pkgMatch = RegExp(r'(?:Packages|TOTAL(?:\s+PKG|\s+PACKAGES)?)[\s\w]*?([\d.,]+)', caseSensitive: false).firstMatch(text);
    if (pkgMatch != null) pkgs = double.tryParse(pkgMatch.group(1)!.replaceAll(',', ''));

    return {
      if (acid != null) 'acid_number': acid,
      if (netW != null) 'total_net_weight_kg': netW,
      if (grossW != null) 'total_gross_weight_kg': grossW,
      if (pkgs != null) 'total_packages': pkgs,
      'items': [],
    };
  }

  void _applyExtractedDataToTables() {
    if (_extractedReconciliationData == null) return;

    final invData = _extractedReconciliationData!['extracted_invoice_data'] as Map<String, dynamic>?;
    final plData = _extractedReconciliationData!['extracted_packing_data'] as Map<String, dynamic>?;
    final rawRecInv = _extractedReconciliationData!['reconciled_invoice_items'] as List<dynamic>?;
    final rawRecPl = _extractedReconciliationData!['reconciled_packing_items'] as List<dynamic>?;

    setState(() {
      if (invData != null && invData['invoice_number'] != null) {
        _finalInvNumberCtrl.text = invData['invoice_number'].toString();
      }
      if (plData != null) {
        _finalPLNumberCtrl.text = plData['packing_list_number']?.toString() ?? 'PL-${_finalInvNumberCtrl.text}';
      }

      if (rawRecInv != null && rawRecInv.isNotEmpty) {
        _invoiceItems = rawRecInv
            .map((j) => POReconciliationItemModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }

      if (rawRecPl != null && rawRecPl.isNotEmpty) {
        _packingItems = rawRecPl
            .map((j) => POReconciliationItemModel.fromJson(j as Map<String, dynamic>))
            .toList();
      } else {
        _packingItems = [];
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, context.l10n.poRecApplyExtractedSuccess, severity: AppSeverity.info));
  }

  @override
  void didUpdateWidget(covariant POReconciliationTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImportFileId != oldWidget.initialImportFileId && widget.initialImportFileId != null) {
      _selectedImportFileId = widget.initialImportFileId;
      _loadPOItems(_selectedImportFileId!);
    }
  }

  void _loadPOItems(int importFileId) {
    final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
    final linkedPOs = allPOs.where((po) => po.importFileId == importFileId).toList();

    List<POReconciliationItemModel> invList = [];
    List<POReconciliationItemModel> plList = [];

    for (var po in linkedPOs) {
      // Build a quick lookup map: itemCode -> packing list item
      final pkgMap = <String, po_models.PackingListItemModel>{};
      for (var plItm in po.packingListItems) {
        final code = plItm.itemCode.trim().toLowerCase();
        if (code.isNotEmpty) pkgMap[code] = plItm;
      }

      for (var itm in po.items) {
        final itmCode = itm.itemCode ?? 'ITEM-${itm.itemId ?? 0}';
        final itmDesc = itm.descriptionAr.isNotEmpty ? itm.descriptionAr : (itm.descriptionEn ?? 'PO Line Item');

        // Look up packing qty from matching packing list item
        final matchedPl = pkgMap[itmCode.trim().toLowerCase()];
        final double pkgCountFromPl = (matchedPl != null && matchedPl.qtyPkg > 0)
            ? matchedPl.qtyPkg.toDouble()
            : 0.0;

        final recItem = POReconciliationItemModel(
          poItemId: itm.itemId,
          itemCode: itmCode,
          description: itmDesc,
          hsCode: itm.hsCode,
          initialQuantity: itm.quantity,
          finalQuantity: itm.quantity,
          initialUnitPrice: itm.unitPrice,
          unitPrice: itm.unitPrice,
          finalUnitPrice: itm.unitPrice,
          initialPackagesCount: pkgCountFromPl,
          finalPackagesCount: pkgCountFromPl,
          initialGrossWeightKg: itm.grossWeightKg,
          finalGrossWeightKg: itm.grossWeightKg,
          initialNetWeightKg: itm.netWeightKg,
          finalNetWeightKg: itm.netWeightKg,
          initialCbm: itm.totalCbm,
          finalCbm: itm.totalCbm,
        );
        invList.add(recItem);
      }

      if (po.packingListItems.isNotEmpty) {
        for (var plItm in po.packingListItems) {
          final itmCode = plItm.itemCode.isNotEmpty ? plItm.itemCode : 'ITEM-${plItm.packingItemId ?? 0}';
          final matchingPoItem = po.items.where((i) => i.itemCode?.trim().toLowerCase() == itmCode.trim().toLowerCase()).firstOrNull;
          final itmDesc = (plItm.description?.isNotEmpty == true)
              ? plItm.description!
              : (matchingPoItem?.descriptionAr.isNotEmpty == true
                  ? matchingPoItem!.descriptionAr
                  : (matchingPoItem?.descriptionEn ?? itmCode));
          final double poPkgQty = plItm.qtyPkg > 0 ? plItm.qtyPkg : 1.0;
          final plRecItem = POReconciliationItemModel(
            // po_item_id and packing_item_id are different id spaces (C4): never reuse one for the other.
            poItemId: matchingPoItem?.itemId,
            packingItemId: plItm.packingItemId,
            itemCode: itmCode,
            description: itmDesc,
            hsCode: plItm.hsCode.isNotEmpty ? plItm.hsCode : matchingPoItem?.hsCode,
            packageType: plItm.packageType.isNotEmpty ? plItm.packageType : 'Carton',
            initialQuantity: plItm.qtyPcs > 0 ? plItm.qtyPcs : (matchingPoItem?.quantity ?? 0.0),
            finalQuantity: plItm.qtyPcs > 0 ? plItm.qtyPcs : (matchingPoItem?.quantity ?? 0.0),
            initialUnitPrice: matchingPoItem?.unitPrice ?? 0.0,
            unitPrice: matchingPoItem?.unitPrice ?? 0.0,
            finalUnitPrice: matchingPoItem?.unitPrice ?? 0.0,
            initialPackagesCount: poPkgQty,
            finalPackagesCount: poPkgQty,
            initialGrossWeightKg: plItm.totalGrossWeightKg > 0 ? plItm.totalGrossWeightKg : (matchingPoItem?.grossWeightKg ?? 0.0),
            finalGrossWeightKg: plItm.totalGrossWeightKg > 0 ? plItm.totalGrossWeightKg : (matchingPoItem?.grossWeightKg ?? 0.0),
            initialNetWeightKg: plItm.totalNetWeightKg > 0 ? plItm.totalNetWeightKg : (matchingPoItem?.netWeightKg ?? 0.0),
            finalNetWeightKg: plItm.totalNetWeightKg > 0 ? plItm.totalNetWeightKg : (matchingPoItem?.netWeightKg ?? 0.0),
            initialCbm: (plItm.calculatedCbm > 0 ? plItm.calculatedCbm : plItm.totalCbm) > 0
                ? (plItm.calculatedCbm > 0 ? plItm.calculatedCbm : plItm.totalCbm)
                : (matchingPoItem?.totalCbm ?? 0.0),
            finalCbm: (plItm.calculatedCbm > 0 ? plItm.calculatedCbm : plItm.totalCbm) > 0
                ? (plItm.calculatedCbm > 0 ? plItm.calculatedCbm : plItm.totalCbm)
                : (matchingPoItem?.totalCbm ?? 0.0),
          );
          plList.add(plRecItem);
        }
      }
    }

    setState(() {
      _invoiceItems = invList;
      _packingItems = plList;
    });
  }


  // --- SAVE RECONCILIATION SESSION LOGIC ---
  Future<void> _saveReconciliationSession() async {
    final l = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.poRecSaveSessionSelectFileWarning, severity: AppSeverity.info));
      return;
    }

    double totalAmount = _invoiceItems.fold(0.0, (s, itm) => s + (itm.finalQuantity * (itm.finalUnitPrice > 0 ? itm.finalUnitPrice : itm.unitPrice)));
    double totalPackages = _packingItems.fold(0.0, (s, itm) => s + itm.finalPackagesCount);
    double totalGrossWeight = _packingItems.fold(0.0, (s, itm) => s + itm.finalGrossWeightKg);
    double totalNetWeight = _packingItems.fold(0.0, (s, itm) => s + itm.finalNetWeightKg);
    double totalCbm = _packingItems.fold(0.0, (s, itm) => s + itm.finalCbm);

    final sessionsList = ref.read(poReconciliationSessionsProvider).valueOrNull ?? [];
    final existingSession = sessionsList
        .where((s) => s.importFileId == _selectedImportFileId && s.sessionId != _activeSessionId && s.isActive)
        .firstOrNull;

    if (existingSession != null) {
      final isDraft = existingSession.overallStatus.toUpperCase() == 'DRAFT';
      final statusLabel = isDraft ? context.l10n.idocADraft3 : context.l10n.idocASavedApprovedStatus(existingSession.overallStatus);
      final updater = existingSession.certifiedBy?.isNotEmpty == true ? existingSession.certifiedBy! : context.l10n.idocADocumentsReviewer;
      final updatedTime = _formatSessionDate(existingSession.updatedAt ?? existingSession.createdAt);

      final confirmUpdate = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 28),
              const SizedBox(width: 10),
              Text(context.l10n.idocANoticeASessionIsAlreadyRegistered, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            context.l10n.idocAExistingSessionUpdateBody(statusLabel, updater, updatedTime, existingSession.sessionCode),
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            IdocUi.fit(AppButton(
              label: l.cancel,
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.pop(ctx, false),
            )),
            IdocUi.fit(AppButton(
              label: l.poRecUpdateExistingSessionButton,
              icon: Icons.update,
              variant: AppButtonVariant.primary,
              onPressed: () => Navigator.pop(ctx, true),
            )),
          ],
        ),
      );

      if (confirmUpdate != true) return;

      await _executeUpdateSession(existingSession.sessionId!, totalAmount, totalPackages, totalGrossWeight, totalNetWeight, totalCbm);
      return;
    }

    if (_activeSessionId != null) {
      await _executeUpdateSession(_activeSessionId!, totalAmount, totalPackages, totalGrossWeight, totalNetWeight, totalCbm);
      return;
    }

    await _executeCreateSession(totalAmount, totalPackages, totalGrossWeight, totalNetWeight, totalCbm);
  }

  Future<void> _executeCreateSession(
    double totalAmount,
    double totalPackages,
    double totalGrossWeight,
    double totalNetWeight,
    double totalCbm,
  ) async {
    final l = context.l10n;
    setState(() => _isSavingSession = true);
    try {
      final filesList = ref.read(importFilesProvider).value ?? [];
      final currentFile = filesList.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;
      final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
      final linkedPO = allPOs.where((po) => po.importFileId == _selectedImportFileId).firstOrNull;
      final dynamicShipper = _extractedReconciliationData?['extracted_invoice_data']?['shipper']?.toString().trim() ??
          _extractedReconciliationData?['extracted_packing_data']?['shipper']?.toString().trim() ??
          currentFile?.supplierName ??
          '';

      final sessionModel = POReconciliationSessionModel(
        importFileId: _selectedImportFileId!,
        finalInvoiceNumber: _finalInvNumberCtrl.text.trim(),
        finalPackingListNumber: _finalPLNumberCtrl.text.trim(),
        acidNumber: _extractedReconciliationData?['extracted_packing_data']?['acid_number'] ??
            _extractedReconciliationData?['extracted_invoice_data']?['acid_number'] ??
            currentFile?.acidNumber,
        shipperName: dynamicShipper.isNotEmpty ? dynamicShipper : null,
        totalInvoiceAmount: totalAmount,
        currency: _extractedReconciliationData?['extracted_invoice_data']?['currency'] ??
            linkedPO?.currencyCode ??
            currentFile?.estimatedCostCurrency ??
            'USD',
        totalPackages: totalPackages,
        totalNetWeightKg: totalNetWeight,
        totalGrossWeightKg: totalGrossWeight,
        totalCbm: totalCbm,
        overallStatus: _extractedReconciliationData?['overall_status'] ?? 'FULLY_MATCHED',
        isSafeForCertification: _extractedReconciliationData?['is_safe_for_certification'] ?? true,
        criticalDiscrepanciesCount: _extractedReconciliationData?['critical_discrepancies_count'] ?? 0,
        warningDiscrepanciesCount: _extractedReconciliationData?['warning_discrepancies_count'] ?? 0,
        headerDiscrepancies: _extractedReconciliationData?['header_discrepancies'] as List<dynamic>?,
        reconciledInvoiceItems: _invoiceItems.map((i) => i.toJson()).toList(),
        reconciledPackingItems: _packingItems.map((i) => i.toJson()).toList(),
        extractedInvoiceData: _extractedReconciliationData?['extracted_invoice_data'] as Map<String, dynamic>?,
        extractedPackingData: _extractedReconciliationData?['extracted_packing_data'] as Map<String, dynamic>?,
      );

      final created = await ref.read(poReconciliationSessionsProvider.notifier).createSession(sessionModel);

      setState(() {
        _activeSessionId = created.sessionId;
        _activeSessionCode = created.sessionCode;
      });

      if (mounted) {
        _showSaveSuccessReportDialog(context, created);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.poRecSaveSessionError(ApiErrorText.of(l, e)), severity: AppSeverity.info));
      }
    } finally {
      if (mounted) setState(() => _isSavingSession = false);
    }
  }

  Future<void> _executeUpdateSession(
    int sessionId,
    double totalAmount,
    double totalPackages,
    double totalGrossWeight,
    double totalNetWeight,
    double totalCbm,
  ) async {
    final l = context.l10n;
    setState(() => _isSavingSession = true);
    try {
      final updateData = {
        'final_invoice_number': _finalInvNumberCtrl.text.trim(),
        'final_packing_list_number': _finalPLNumberCtrl.text.trim(),
        'total_invoice_amount': totalAmount,
        'total_packages': totalPackages,
        'total_net_weight_kg': totalNetWeight,
        'total_gross_weight_kg': totalGrossWeight,
        'total_cbm': totalCbm,
        'overall_status': _extractedReconciliationData?['overall_status'] ?? 'FULLY_MATCHED',
        'is_safe_for_certification': _extractedReconciliationData?['is_safe_for_certification'] ?? true,
        'critical_discrepancies_count': _extractedReconciliationData?['critical_discrepancies_count'] ?? 0,
        'warning_discrepancies_count': _extractedReconciliationData?['warning_discrepancies_count'] ?? 0,
        'header_discrepancies': _extractedReconciliationData?['header_discrepancies'] as List<dynamic>?,
        'reconciled_invoice_items': _invoiceItems.map((i) => i.toJson()).toList(),
        'reconciled_packing_items': _packingItems.map((i) => i.toJson()).toList(),
        'extracted_invoice_data': _extractedReconciliationData?['extracted_invoice_data'] as Map<String, dynamic>?,
        'extracted_packing_data': _extractedReconciliationData?['extracted_packing_data'] as Map<String, dynamic>?,
      };

      final updated = await ref.read(poReconciliationSessionsProvider.notifier).updateSession(sessionId, updateData);

      setState(() {
        _activeSessionId = updated.sessionId;
        _activeSessionCode = updated.sessionCode;
      });

      if (mounted) {
        _showSaveSuccessReportDialog(context, updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.poRecSaveSessionError(ApiErrorText.of(l, e)), severity: AppSeverity.info));
      }
    } finally {
      if (mounted) setState(() => _isSavingSession = false);
    }
  }

  Future<void> _submitCertification() async {
    final l = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.poRecSelectFileRequired, severity: AppSeverity.info));
      return;
    }

    // Check for any variances in items
    final hasInvoiceVariance = _invoiceItems.any((i) =>
        (i.finalQuantity - i.initialQuantity).abs() > 0.001 ||
        (i.finalUnitPrice - i.initialUnitPrice).abs() > 0.001);
    final hasPackingVariance = _packingItems.any((p) =>
        (p.finalQuantity - p.initialQuantity).abs() > 0.001 ||
        (p.finalGrossWeightKg - p.initialGrossWeightKg).abs() > 0.001);

    if (hasInvoiceVariance || hasPackingVariance) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 24),
              const SizedBox(width: 8),
              Text(l.poRecVarianceAlertTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            l.poRecVarianceAlertContent,
            style: const TextStyle(fontSize: 12.5, height: 1.6),
          ),
          actions: [
            IdocUi.fit(AppButton(
              label: l.poRecCancelAndReview,
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.pop(ctx, false),
            )),
            IdocUi.fit(AppButton(
              label: l.poRecConfirmCertifyButton,
              icon: Icons.verified,
              variant: AppButtonVariant.success,
              onPressed: () => Navigator.pop(ctx, true),
            )),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payload = POReconciliationPayloadBuilder.buildPayload(
        importFileId: _selectedImportFileId!,
        finalInvoiceNumber: _finalInvNumberCtrl.text,
        finalPackingListNumber: _finalPLNumberCtrl.text,
        invoiceItems: _invoiceItems,
        packingItems: _packingItems,
      );

      final result = await ref.read(poReconciliationProvider).submitPOFinalReconciliation(payload);

      ref.invalidate(importFilesProvider);
      ref.invalidate(purchaseOrdersProvider);
      invalidateImportDocDependentsW(ref);

      // Also auto-save/update session in background
      await _saveReconciliationSession();

      if (mounted) {
        String successMsg = l.poRecCertificationSuccess;
        if (result.totalFinalAmountByCurrency != null && result.totalFinalAmountByCurrency!.isNotEmpty) {
          final curBreakdown = result.totalFinalAmountByCurrency!.entries
              .map((e) => '${e.value.toStringAsFixed(2)} ${e.key}')
              .join(' | ');
          successMsg = '$successMsg ($curBreakdown)';
        }
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, successMsg, severity: AppSeverity.info));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.poRecCertificationError(ApiErrorText.of(l, e)), severity: AppSeverity.info));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatSessionDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return context.l10n.idocANotSpecified;
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$y/$m/$d $h:$min';
    } catch (_) {
      return dateStr;
    }
  }

  void _resetFormState() {
    _activeSessionId = null;
    _activeSessionCode = null;
    _finalInvNumberCtrl.clear();
    _finalPLNumberCtrl.clear();
    _invoiceItems = [];
    _packingItems = [];
    _invoiceTextCtrl.clear();
    _packingTextCtrl.clear();
    _selectedInvoiceFileName = null;
    _selectedPackingFileName = null;
    _invoiceFileBytes = null;
    _packingFileBytes = null;
    _extractedReconciliationData = null;
  }

  Widget _buildDuplicateDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleImportFileChanged(int fileId) async {
    final sessionsList = ref.read(poReconciliationSessionsProvider).valueOrNull ?? [];
    final existing = sessionsList.where((s) => s.importFileId == fileId && s.isActive).firstOrNull;

    if (existing != null) {
      final isDraft = existing.overallStatus.toUpperCase() == 'DRAFT';
      final statusLabel = isDraft ? context.l10n.idocADraft3 : context.l10n.idocASavedApprovedStatus(existing.overallStatus);
      final updater = existing.certifiedBy?.isNotEmpty == true ? existing.certifiedBy! : context.l10n.idocADocumentsReviewer;
      final updatedTime = _formatSessionDate(existing.updatedAt ?? existing.createdAt);

      final shouldOpen = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.severityBackgroundOf(context, AppSeverity.warning),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.idocANoticeAReconciliationSessionIsAlready,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                ),
              ),
            ],
          ),
          content: Container(
            width: (MediaQuery.of(context).size.width - 32).clamp(320.0, 520.0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.severityBackgroundOf(context, AppSeverity.warning).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.orange),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.idocAExistingSessionBody(statusLabel, updater, updatedTime),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.severityForegroundOf(context, AppSeverity.warning), height: 1.5),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceOf(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderOf(context)),
                  ),
                  child: Column(
                    children: [
                      _buildDuplicateDetailRow(context.l10n.idocASessionCode, existing.sessionCode),
                      if (existing.finalInvoiceNumber != null && existing.finalInvoiceNumber!.isNotEmpty)
                        _buildDuplicateDetailRow(context.l10n.idocAFinalInvoiceNumber, existing.finalInvoiceNumber!),
                      _buildDuplicateDetailRow(context.l10n.idocASessionStatus, statusLabel),
                      _buildDuplicateDetailRow(context.l10n.idocAResponsibleUser, updater),
                      _buildDuplicateDetailRow(context.l10n.idocASaveDateAndTime, updatedTime),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.idocAYouCanOpenAndContinueThe,
                  style: const TextStyle(fontSize: 12, color: AppTheme.charcoal, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            IdocUi.fit(AppButton(
              label: context.l10n.idocAClearSelection,
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.pop(ctx, false),
            )),
            IdocUi.fit(AppButton(
              label: context.l10n.idocAOpenAndContinueTheCurrentSession,
              icon: Icons.folder_open_rounded,
              variant: AppButtonVariant.primary,
              onPressed: () => Navigator.pop(ctx, true),
            )),
          ],
        ),
      );

      if (shouldOpen == true) {
        _loadSessionIntoEditor(existing);
        return;
      } else {
        setState(() {
          _selectedImportFileId = null;
          _resetFormState();
        });
        return;
      }
    }

    setState(() {
      _selectedImportFileId = fileId;
      _resetFormState();
      _selectedImportFileId = fileId;
    });
    _loadPOItems(fileId);
  }

  Widget _buildActiveSessionAuditBar(BuildContext context) {
    if (_activeSessionId == null) return const SizedBox.shrink();
    final sessionsList = ref.watch(poReconciliationSessionsProvider).valueOrNull ?? [];
    final session = sessionsList.where((s) => s.sessionId == _activeSessionId).firstOrNull;

    final updater = session?.certifiedBy?.isNotEmpty == true ? session!.certifiedBy! : context.l10n.idocADocumentsReviewer;
    final updatedTime = _formatSessionDate(session?.updatedAt ?? session?.createdAt);
    final isDraft = session?.overallStatus.toUpperCase() == 'DRAFT';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.history_toggle_off_rounded, color: isDark ? AppTheme.cobaltLight : AppTheme.textSecondaryOf(context), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDraft ? AppTheme.severityBackgroundOf(context, AppSeverity.warning) : AppTheme.severityBackgroundOf(context, AppSeverity.success),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDraft ? AppTheme.severityForegroundOf(context, AppSeverity.warning) : AppTheme.severityForegroundOf(context, AppSeverity.success)),
                  ),
                  child: Text(
                    isDraft ? context.l10n.idocADraft3 : 'جلسة نشطة (${_activeSessionCode ?? ''})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDraft ? AppTheme.severityForegroundOf(context, AppSeverity.warning) : AppTheme.severityForegroundOf(context, AppSeverity.success),
                    ),
                  ),
                ),
                Text(
                  context.l10n.idocALastModifiedByOn(updater, updatedTime),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          IdocUi.fit(AppButton(
            label: context.l10n.idocAFullAuditLog,
            icon: Icons.manage_history_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () {
              RowHistoryDialog.show(
                context,
                entityType: 'POPackingReconciliationSession',
                entityId: _activeSessionId!,
                entityTitle: 'جلسة المطابقة ${_activeSessionCode ?? ''}',
              );
            },
          )),
        ],
      ),
    );
  }

  void _loadSessionIntoEditor(POReconciliationSessionModel session) {
    final l = context.l10n;
    setState(() {
      _activeSessionId = session.sessionId;
      _activeSessionCode = session.sessionCode;
      _selectedImportFileId = session.importFileId;
      _finalInvNumberCtrl.text = session.finalInvoiceNumber ?? '';
      _finalPLNumberCtrl.text = session.finalPackingListNumber ?? '';
      _invoiceTextCtrl.clear();
      _packingTextCtrl.clear();
      _selectedInvoiceFileName = null;
      _selectedPackingFileName = null;
      _invoiceFileBytes = null;
      _packingFileBytes = null;

      if (session.reconciledInvoiceItems != null && session.reconciledInvoiceItems!.isNotEmpty) {
        _invoiceItems = session.reconciledInvoiceItems!
            .map((j) => POReconciliationItemModel.fromJson(j as Map<String, dynamic>))
            .toList();
      } else {
        _invoiceItems = [];
      }

      if (session.reconciledPackingItems != null && session.reconciledPackingItems!.isNotEmpty) {
        _packingItems = session.reconciledPackingItems!
            .map((j) => POReconciliationItemModel.fromJson(j as Map<String, dynamic>))
            .toList();
      } else {
        _packingItems = [];
      }

      _extractedReconciliationData = {
        'overall_status': session.overallStatus,
        'is_safe_for_certification': session.isSafeForCertification,
        'critical_discrepancies_count': session.criticalDiscrepanciesCount,
        'warning_discrepancies_count': session.warningDiscrepanciesCount,
        'header_discrepancies': session.headerDiscrepancies,
        'reconciled_invoice_items': session.reconciledInvoiceItems,
        'reconciled_packing_items': session.reconciledPackingItems,
        'extracted_invoice_data': session.extractedInvoiceData,
        'extracted_packing_data': session.extractedPackingData,
      };
    });

    // Auto-repair: if session packing data looks corrupted (all items sum < 100 kg total gross),
    // reload from system PO packing list
    final totalGwFromSession = _packingItems.fold<double>(0.0, (sum, i) => sum + i.initialGrossWeightKg);
    if (totalGwFromSession < 100.0 && _selectedImportFileId != null) {
      _loadPOItems(_selectedImportFileId!);
    }

    if (_mainScrollController.hasClients) {
      _mainScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.poRecSessionLoadedInEditor(session.sessionCode), severity: AppSeverity.info));
  }

  void openSearchAndCloneDialog() {
    final sessions = ref.read(poReconciliationSessionsProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (dialogCtx) => SearchAndClonePoReconciliationDialog(
        sessions: sessions,
        onSelectSession: (sourceSession) {
          _cloneSession(sourceSession);
        },
      ),
    );
  }

  void _cloneSession(POReconciliationSessionModel sourceSession) {
    final l = context.l10n;
    final suggestedCode = 'REC-2026-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    showDialog(
      context: context,
      builder: (dialogCtx) => CloneEntityReviewDialog(
        entityType: l.searchAndClonePoReconDialogTitle,
        sourceCode: sourceSession.sessionCode,
        sourceTitle: '${sourceSession.finalInvoiceNumber ?? "INV"} / ${sourceSession.finalPackingListNumber ?? "PL"}',
        suggestedNewCode: suggestedCode,
        copiedFieldsSummary: {
          context.l10n.idocAInvoiceNumber: sourceSession.finalInvoiceNumber ?? '—',
          context.l10n.idocAPackingListNumber: sourceSession.finalPackingListNumber ?? '—',
          context.l10n.idocATotalValue: '${sourceSession.totalInvoiceAmount.toStringAsFixed(2)} ${sourceSession.currency}',
          context.l10n.idocATotalPackages: '${sourceSession.totalPackages.toStringAsFixed(0)} ${l.poRecPackagesUnit}',
          context.l10n.idocATotalWeight: '${_formatWeight(sourceSession.totalGrossWeightKg)} ${l.poRecKgUnit}',
          context.l10n.idocATotalVolume: '${sourceSession.totalCbm.toStringAsFixed(2)} ${l.poRecCbmUnit}',
        },
        mandatorilyResetFields: [
          l.poReconClonedResetNotice,
          'معرّف الجلسة: تعيين إلى مسودة جديدة غير محفوظة (null)',
          'حالة التوثيق والاعتماد: إعادة تعيين إلى غير معتمد (Draft/Pending)',
          context.l10n.idocACloneNoteSignature,
        ],
        allowCopyLineItems: true,
        allowCopyAttachments: false,
        onConfirm: ({
          required String newCode,
          required String newTitle,
          required bool copyLineItems,
          required bool copyAttachments,
          String? notes,
        }) async {
          _loadClonedSessionIntoEditor(sourceSession, newCode: newCode, copyLineItems: copyLineItems);
        },
      ),
    );
  }

  void _loadClonedSessionIntoEditor(
    POReconciliationSessionModel session, {
    required String newCode,
    bool copyLineItems = true,
  }) {
    final l = context.l10n;
    setState(() {
      _activeSessionId = null; // Strict invariant: new session!
      _activeSessionCode = newCode;
      _selectedImportFileId = session.importFileId;
      _finalInvNumberCtrl.text = session.finalInvoiceNumber != null ? '${session.finalInvoiceNumber}${TableRowCloneHelper.copyCodeSuffix}' : '';
      _finalPLNumberCtrl.text = session.finalPackingListNumber != null ? '${session.finalPackingListNumber}${TableRowCloneHelper.copyCodeSuffix}' : '';

      if (copyLineItems) {
        if (session.reconciledInvoiceItems != null && session.reconciledInvoiceItems!.isNotEmpty) {
          _invoiceItems = session.reconciledInvoiceItems!
              .map((j) => POReconciliationItemModel.fromJson(j as Map<String, dynamic>))
              .toList();
        }
        if (session.reconciledPackingItems != null && session.reconciledPackingItems!.isNotEmpty) {
          _packingItems = session.reconciledPackingItems!
              .map((j) => POReconciliationItemModel.fromJson(j as Map<String, dynamic>))
              .toList();
        }
      }

      _extractedReconciliationData = {
        'overall_status': 'DRAFT',
        'is_safe_for_certification': false,
        'critical_discrepancies_count': session.criticalDiscrepanciesCount,
        'warning_discrepancies_count': session.warningDiscrepanciesCount,
        'header_discrepancies': session.headerDiscrepancies,
        'reconciled_invoice_items': session.reconciledInvoiceItems,
        'reconciled_packing_items': session.reconciledPackingItems,
        'extracted_invoice_data': session.extractedInvoiceData,
        'extracted_packing_data': session.extractedPackingData,
      };
    });

    if (_mainScrollController.hasClients) {
      _mainScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.clonePoReconSuccess, severity: AppSeverity.info));
  }

  void _cloneInvoiceItem(POReconciliationItemModel item) {
    final index = _invoiceItems.indexOf(item);
    final cloned = item.copyWith(
      itemCode: '${item.itemCode}${TableRowCloneHelper.copyCodeSuffix}',
      description: '${item.description}${TableRowCloneHelper.copySuffix}',
    );
    setState(() {
      if (index >= 0) {
        _invoiceItems.insert(index + 1, cloned);
      } else {
        _invoiceItems.add(cloned);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.idocAItemClonedSuccessfully(item.itemCode), severity: AppSeverity.success),
    );
  }

  void _clonePackingItem(POReconciliationItemModel item) {
    final index = _packingItems.indexOf(item);
    final cloned = item.copyWith(
      itemCode: '${item.itemCode}${TableRowCloneHelper.copyCodeSuffix}',
      description: '${item.description}${TableRowCloneHelper.copySuffix}',
    );
    setState(() {
      if (index >= 0) {
        _packingItems.insert(index + 1, cloned);
      } else {
        _packingItems.add(cloned);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.idocAPackageClonedSuccessfully(item.itemCode), severity: AppSeverity.success),
    );
  }

  // --- Task J: Copy & Export Helpers ---
  void _copySessionsTable(List<POReconciliationSessionModel> sessions) {
    final l = context.l10n;
    final headers = [
      '#',
      l.poRecHistoryColSessionCode,
      l.poRecHistoryColImportFileImporter,
      l.poRecHistoryColInvoicePacking,
      l.poRecHistoryColTotalValue,
      l.poRecHistoryColPackagesWeight,
      l.poRecHistoryColCbm,
      l.poRecHistoryColStatus,
      l.poRecHistoryColSavedDate,
    ];
    final rows = sessions.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final sess = entry.value;
      final dateStr = (sess.createdAt != null && sess.createdAt!.length >= 10) ? sess.createdAt!.substring(0, 10) : '—';
      return [
        '$idx',
        sess.sessionCode,
        '${sess.importFileCode ?? ""} - ${sess.importerName ?? ""}',
        '${sess.finalInvoiceNumber ?? ""} | ${sess.finalPackingListNumber ?? ""}',
        '${sess.totalInvoiceAmount.toStringAsFixed(2)} ${sess.currency}',
        '${sess.totalPackages.toStringAsFixed(0)} | ${_formatWeight(sess.totalGrossWeightKg)} kg',
        '${sess.totalCbm.toStringAsFixed(3)} m³',
        _getLocalizedSessionStatus(context, sess.overallStatus),
        dateStr,
      ];
    }).toList();
    TableCopyHelper.copyTable(context, headers, rows);
  }

  Future<void> _exportSessionsToExcel(List<POReconciliationSessionModel> sessions) async {
    final headers = [
      '#',
      context.l10n.idocASessionCodeAlt,
      context.l10n.idocAImportFileImporter,
      context.l10n.idocAInvoicePackingList,
      context.l10n.idocATotalValue,
      context.l10n.idocAPackagesWeight,
      context.l10n.idocAVolumeCBM,
      context.l10n.status,
      context.l10n.idocASavedDate,
    ];
    final rows = sessions.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final sess = entry.value;
      final dateStr = (sess.createdAt != null && sess.createdAt!.length >= 10) ? sess.createdAt!.substring(0, 10) : '—';
      return [
        '$idx',
        sess.sessionCode,
        '${sess.importFileCode ?? ""} - ${sess.importerName ?? ""}',
        '${sess.finalInvoiceNumber ?? ""} | ${sess.finalPackingListNumber ?? ""}',
        '${sess.totalInvoiceAmount.toStringAsFixed(2)} ${sess.currency}',
        '${sess.totalPackages.toStringAsFixed(0)} | ${_formatWeight(sess.totalGrossWeightKg)} kg',
        '${sess.totalCbm.toStringAsFixed(3)} m³',
        _getLocalizedSessionStatus(context, sess.overallStatus),
        dateStr,
      ];
    }).toList();
    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocAPOReconciliationSessions,
      importFileNameOrCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : 'PO_Reconciliations',
    );
  }

  Future<void> _exportSessionsToPdf(List<POReconciliationSessionModel> sessions) async {
    final headers = [
      '#',
      context.l10n.idocACodeAlt,
      context.l10n.idocAFileAlt,
      context.l10n.idocAInvoice,
      context.l10n.idocAValue,
      context.l10n.idocAPackages,
      context.l10n.status,
    ];
    final rows = sessions.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final sess = entry.value;
      return [
        '$idx',
        sess.sessionCode,
        sess.importFileCode ?? '-',
        sess.finalInvoiceNumber ?? '-',
        '${sess.totalInvoiceAmount.toStringAsFixed(0)} ${sess.currency}',
        sess.totalPackages.toStringAsFixed(0),
        _getLocalizedSessionStatus(context, sess.overallStatus),
      ];
    }).toList();
    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocAPOReconciliationSessionsAlt,
      importFileNameOrCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : 'PO_Reconciliations',
    );
  }

  void _copyInvoiceItemsTable() {
    final l = context.l10n;
    final headers = [
      l.poRecColItemCode,
      l.poRecColDescription,
      l.poRecColPoQty,
      l.poRecColFinalQty,
      l.poRecColQtyVariance,
      l.poRecColPoUnitPrice,
      l.poRecColFinalUnitPrice,
      l.poRecColPriceVariance,
      l.poRecColFinalTotal,
      l.poRecColHsCode,
    ];
    final rows = _invoiceItems.map((itm) {
      final qtyVariance = itm.finalQuantity - itm.initialQuantity;
      final priceVariance = itm.finalUnitPrice - itm.initialUnitPrice;
      final totalRow = itm.finalQuantity * (itm.finalUnitPrice > 0 ? itm.finalUnitPrice : itm.unitPrice);
      return [
        itm.itemCode,
        itm.description,
        '${itm.initialQuantity}',
        '${itm.finalQuantity}',
        '$qtyVariance',
        '${itm.initialUnitPrice}',
        '${itm.finalUnitPrice}',
        '$priceVariance',
        totalRow.toStringAsFixed(2),
        itm.hsCode ?? '',
      ];
    }).toList();
    TableCopyHelper.copyTable(context, headers, rows);
  }

  Future<void> _exportInvoiceItemsToExcel() async {
    final headers = [
      context.l10n.idocAItemCode,
      context.l10n.idocADescription,
      context.l10n.idocAPOQty,
      context.l10n.idocAFinalQty,
      context.l10n.idocAQtyVariance,
      context.l10n.idocAPOUnitPrice,
      context.l10n.idocAFinalUnitPrice,
      context.l10n.idocAPriceVariance,
      context.l10n.idocAFinalTotal,
      context.l10n.idocAHSCode,
    ];
    final rows = _invoiceItems.map((itm) {
      final qtyVariance = itm.finalQuantity - itm.initialQuantity;
      final priceVariance = itm.finalUnitPrice - itm.initialUnitPrice;
      final totalRow = itm.finalQuantity * (itm.finalUnitPrice > 0 ? itm.finalUnitPrice : itm.unitPrice);
      return [
        itm.itemCode,
        itm.description,
        '${itm.initialQuantity}',
        '${itm.finalQuantity}',
        '$qtyVariance',
        '${itm.initialUnitPrice}',
        '${itm.finalUnitPrice}',
        '$priceVariance',
        totalRow.toStringAsFixed(2),
        itm.hsCode ?? '',
      ];
    }).toList();
    if (_invoiceItems.isNotEmpty) {
      final totalPoQty = _invoiceItems.fold(0.0, (s, i) => s + i.initialQuantity);
      final totalFinQty = _invoiceItems.fold(0.0, (s, i) => s + i.finalQuantity);
      final totalPoAmt = _invoiceItems.fold(0.0, (s, i) => s + (i.initialQuantity * i.initialUnitPrice));
      final totalFinAmt = _invoiceItems.fold(0.0, (s, i) => s + (i.finalQuantity * (i.finalUnitPrice > 0 ? i.finalUnitPrice : i.unitPrice)));
      rows.add([
        context.l10n.idocATotal,
        '${_invoiceItems.length} items',
        '$totalPoQty',
        '$totalFinQty',
        '${totalFinQty - totalPoQty}',
        totalPoAmt.toStringAsFixed(2),
        '—',
        '${totalFinAmt - totalPoAmt}',
        totalFinAmt.toStringAsFixed(2),
        '',
      ]);
    }
    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocAInvoiceItemsReconciliation,
      importFileNameOrCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : 'Invoice_Items',
    );
  }

  Future<void> _exportInvoiceItemsToPdf() async {
    final headers = [
      context.l10n.idocACode,
      context.l10n.idocADescription,
      context.l10n.idocAPOQtyAlt,
      context.l10n.idocAFinalQtyAlt,
      context.l10n.idocAUnitPrice,
      context.l10n.idocATotalAlt,
    ];
    final rows = _invoiceItems.map((itm) {
      final totalRow = itm.finalQuantity * (itm.finalUnitPrice > 0 ? itm.finalUnitPrice : itm.unitPrice);
      return [
        itm.itemCode,
        itm.description,
        '${itm.initialQuantity}',
        '${itm.finalQuantity}',
        '${itm.finalUnitPrice > 0 ? itm.finalUnitPrice : itm.unitPrice}',
        totalRow.toStringAsFixed(2),
      ];
    }).toList();
    if (_invoiceItems.isNotEmpty) {
      final totalPoQty = _invoiceItems.fold(0.0, (s, i) => s + i.initialQuantity);
      final totalFinQty = _invoiceItems.fold(0.0, (s, i) => s + i.finalQuantity);
      final totalFinAmt = _invoiceItems.fold(0.0, (s, i) => s + (i.finalQuantity * (i.finalUnitPrice > 0 ? i.finalUnitPrice : i.unitPrice)));
      rows.add([
        context.l10n.idocATotalAlt,
        '${_invoiceItems.length} items',
        '$totalPoQty',
        '$totalFinQty',
        '—',
        totalFinAmt.toStringAsFixed(2),
      ]);
    }
    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocAInvoiceItems,
      importFileNameOrCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : 'Invoice_Items',
    );
  }

  void _copyPackingItemsTable() {
    final l = context.l10n;
    final headers = [
      l.poRecColItemCode,
      l.poRecColDescription,
      l.poRecColPackageType,
      l.poRecColPoPackagesCount,
      l.poRecColFinalPackagesCount,
      l.poRecColPkgVariance,
      l.poRecColGrossWeight,
      l.poRecColNetWeight,
      l.poRecColCbm,
    ];
    final rows = _packingItems.map((itm) {
      final double initP = itm.initialPackagesCount;
      final double finP = itm.finalPackagesCount;
      final double varPct = initP > 0 ? ((finP - initP) / initP) * 100.0 : 0.0;
      return [
        itm.itemCode,
        itm.description,
        itm.packageType,
        '${initP.toInt() == initP ? initP.toInt() : initP}',
        '${finP.toInt() == finP ? finP.toInt() : finP}',
        '${varPct.toStringAsFixed(1)}%',
        '${itm.finalGrossWeightKg}',
        '${itm.finalNetWeightKg}',
        '${itm.finalCbm}',
      ];
    }).toList();
    TableCopyHelper.copyTable(context, headers, rows);
  }

  Future<void> _exportPackingItemsToExcel() async {
    final headers = [
      context.l10n.idocAItemCode,
      context.l10n.idocADescription,
      context.l10n.idocAPackageType,
      context.l10n.idocAPOPackages,
      context.l10n.idocAFinalPackages,
      context.l10n.idocAPackagesVariance,
      context.l10n.idocAGrossWeightKg,
      context.l10n.idocANetWeightKg,
      context.l10n.idocACBM,
    ];
    final rows = _packingItems.map((itm) {
      final double initP = itm.initialPackagesCount;
      final double finP = itm.finalPackagesCount;
      final double varPct = initP > 0 ? ((finP - initP) / initP) * 100.0 : 0.0;
      return [
        itm.itemCode,
        itm.description,
        itm.packageType,
        '${initP.toInt() == initP ? initP.toInt() : initP}',
        '${finP.toInt() == finP ? finP.toInt() : finP}',
        '${varPct.toStringAsFixed(1)}%',
        '${itm.finalGrossWeightKg}',
        '${itm.finalNetWeightKg}',
        '${itm.finalCbm}',
      ];
    }).toList();
    if (_packingItems.isNotEmpty) {
      final totalPoPkgs = _packingItems.fold(0.0, (s, i) => s + i.initialPackagesCount);
      final totalPkgs = _packingItems.fold(0.0, (s, i) => s + i.finalPackagesCount);
      final totalGross = _packingItems.fold(0.0, (s, i) => s + i.finalGrossWeightKg);
      final totalNet = _packingItems.fold(0.0, (s, i) => s + i.finalNetWeightKg);
      final totalCbm = _packingItems.fold(0.0, (s, i) => s + i.finalCbm);
      final overallVar = totalPoPkgs > 0 ? ((totalPkgs - totalPoPkgs) / totalPoPkgs) * 100.0 : 0.0;
      rows.add([
        context.l10n.idocATotal,
        '${_packingItems.length} items',
        '—',
        '${totalPoPkgs.toInt() == totalPoPkgs ? totalPoPkgs.toInt() : totalPoPkgs}',
        '${totalPkgs.toInt() == totalPkgs ? totalPkgs.toInt() : totalPkgs}',
        '${overallVar.toStringAsFixed(1)}%',
        _formatWeight(totalGross),
        _formatWeight(totalNet),
        totalCbm.toStringAsFixed(3),
      ]);
    }
    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocAPackingListReconciliation,
      importFileNameOrCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : 'Packing_Items',
    );
  }

  Future<void> _exportPackingItemsToPdf() async {
    final headers = [
      context.l10n.idocACode,
      context.l10n.idocADescription,
      context.l10n.idocAPOPkgs,
      context.l10n.idocAFinalPkgs,
      context.l10n.idocAVariance,
      context.l10n.idocAGrossWt,
      context.l10n.idocANetWt,
      context.l10n.idocACBMAlt,
    ];
    final rows = _packingItems.map((itm) {
      final double initP = itm.initialPackagesCount;
      final double finP = itm.finalPackagesCount;
      final double varPct = initP > 0 ? ((finP - initP) / initP) * 100.0 : 0.0;
      return [
        itm.itemCode,
        itm.description,
        '${initP.toInt() == initP ? initP.toInt() : initP}',
        '${finP.toInt() == finP ? finP.toInt() : finP}',
        '${varPct.toStringAsFixed(1)}%',
        '${_formatWeight(itm.finalGrossWeightKg)} kg',
        '${_formatWeight(itm.finalNetWeightKg)} kg',
        '${itm.finalCbm} m³',
      ];
    }).toList();
    if (_packingItems.isNotEmpty) {
      final totalPoPkgs = _packingItems.fold(0.0, (s, i) => s + i.initialPackagesCount);
      final totalPkgs = _packingItems.fold(0.0, (s, i) => s + i.finalPackagesCount);
      final totalGross = _packingItems.fold(0.0, (s, i) => s + i.finalGrossWeightKg);
      final totalNet = _packingItems.fold(0.0, (s, i) => s + i.finalNetWeightKg);
      final totalCbm = _packingItems.fold(0.0, (s, i) => s + i.finalCbm);
      final overallVar = totalPoPkgs > 0 ? ((totalPkgs - totalPoPkgs) / totalPoPkgs) * 100.0 : 0.0;
      rows.add([
        context.l10n.idocATotalAlt,
        '${_packingItems.length} items',
        '${totalPoPkgs.toInt() == totalPoPkgs ? totalPoPkgs.toInt() : totalPoPkgs}',
        '${totalPkgs.toInt() == totalPkgs ? totalPkgs.toInt() : totalPkgs}',
        '${overallVar.toStringAsFixed(1)}%',
        '${_formatWeight(totalGross)} kg',
        '${_formatWeight(totalNet)} kg',
        '${totalCbm.toStringAsFixed(3)} m³',
      ]);
    }
    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocAPackingListItems,
      importFileNameOrCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : 'Packing_Items',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final density = ref.watch(displayDensityProvider);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final sessionsState = ref.watch(poReconciliationSessionsProvider);
    final sessionsList = sessionsState.valueOrNull ?? [];

    double totalAmount = _invoiceItems.fold(0.0, (s, itm) => s + (itm.finalQuantity * (itm.finalUnitPrice > 0 ? itm.finalUnitPrice : itm.unitPrice)));
    double totalPackages = _packingItems.fold(0.0, (s, itm) => s + itm.finalPackagesCount);
    double totalGrossWeight = _packingItems.fold(0.0, (s, itm) => s + itm.finalGrossWeightKg);
    double totalNetWeight = _packingItems.fold(0.0, (s, itm) => s + itm.finalNetWeightKg);
    double totalCbm = _packingItems.fold(0.0, (s, itm) => s + itm.finalCbm);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () => openSearchAndCloneDialog(),
      },
      child: Focus(
        autofocus: true,
        child: SingleChildScrollView(
          controller: _mainScrollController,
          padding: density.contentPadding,
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // PART 1: ACTIVE RECONCILIATION & AUDIT EDITOR
                // ==========================================
                _buildReconciliationEditorTab(
                  importFiles,
                  totalAmount,
                  totalPackages,
                  totalGrossWeight,
                  totalNetWeight,
                  totalCbm,
                  isDark,
                ),

                const SizedBox(height: 36),

                // ==========================================
                // PART 2: SAVED SESSIONS HISTORY REGISTRY
                // ==========================================
                _buildSavedSessionsHistorySection(sessionsList, importFiles, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // ==========================================
  // TAB 1: RECONCILIATION EDITOR
  // ==========================================
  Widget _buildReconciliationEditorTab(
    List<dynamic> importFiles,
    double totalAmount,
    double totalPackages,
    double totalGrossWeight,
    double totalNetWeight,
    double totalCbm,
    bool isDark,
  ) {
    final l = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final selectedFile = importFiles.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;
    final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
    final linkedPO = allPOs.where((po) => po.importFileId == _selectedImportFileId).firstOrNull;
    final rawCurr = _extractedReconciliationData?['extracted_invoice_data']?['currency']?.toString() ??
        linkedPO?.currencyCode ??
        selectedFile?.estimatedCostCurrency ??
        'USD';
    final currencyStr = rawCurr == 'USD' ? r'$' : (rawCurr == 'EUR' ? 'EUR' : rawCurr);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Card
          Card(
            elevation: 2,
            color: AppTheme.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: AppTheme.borderOf(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 650;
                      final titleRow = Row(
                        children: [
                          const Icon(Icons.fact_check, color: AppTheme.cobalt, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _activeSessionCode != null
                                  ? l.poRecEditSessionTitle(_activeSessionCode!)
                                  : l.poRecNewSessionTitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );

                      final actionsRow = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (_activeSessionCode != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.cobalt),
                              ),
                              child: Text(
                                _activeSessionCode!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.cobalt,
                                ),
                              ),
                            ),
                          IdocUi.fit(AppButton(
                            key: const Key('editorSearchAndCloneBtn'),
                            label: l.searchAndClonePoReconBtn,
                            icon: Icons.copy_all,
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.small,
                            onPressed: openSearchAndCloneDialog,
                          )),
                        ],
                      );

                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleRow,
                            const SizedBox(height: 10),
                            actionsRow,
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: titleRow),
                          const SizedBox(width: 12),
                          actionsRow,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.poRecHeaderDescription,
                    style: TextStyle(
                      color: AppTheme.textSecondaryOf(context),
                      fontSize: 12.5,
                    ),
                  ),
                  const Divider(height: 24),
                  _buildActiveSessionAuditBar(context),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 750;
                      final fileDropdown = SearchableDropdownField<int?>(
                        value: _selectedImportFileId,
                        hintText: l.poRecSearchFileHint,
                        labelText: l.poRecImportFileLabel,
                        items: importFiles
                            .map((f) => SearchableDropdownItem<int?>(
                                  value: f.importFileId,
                                  label: '${f.primaryNameWithCode} - ${f.companyName}',
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val == null) {
                            setState(() {
                              _selectedImportFileId = null;
                              _resetFormState();
                            });
                            return;
                          }
                          _handleImportFileChanged(val);
                        },
                        validator: (v) => v == null ? l.poRecSelectFileRequired : null,
                      );
                      final invField = TextFormField(
                        controller: _finalInvNumberCtrl,
                        decoration: InputDecoration(
                          labelText: l.poRecFinalInvoiceNoLabel,
                          hintText: l.poRecFinalInvoiceNoHint,
                          prefixIcon: const Icon(Icons.receipt_long),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? l.poRecRequired : null,
                      );
                      final plField = TextFormField(
                        controller: _finalPLNumberCtrl,
                        decoration: InputDecoration(
                          labelText: l.poRecFinalPackingListNoLabel,
                          hintText: l.poRecFinalPackingListNoHint,
                          prefixIcon: const Icon(Icons.inventory_2),
                          border: const OutlineInputBorder(),
                        ),
                        validator: null,
                      );

                      if (isCompact) {
                        return Column(
                          children: [
                            fileDropdown,
                            const SizedBox(height: 12),
                            invField,
                            const SizedBox(height: 12),
                            plField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(flex: 3, child: fileDropdown),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: invField),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: plField),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // SMART EXTRACTION & 3-WAY RECONCILIATION TOOL CARD
          _buildSmartExtractionCard(isDark),
          const SizedBox(height: 20),

          // Summary Metrics Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 950;
              final kpiCards = [
                _buildSummaryCard(l.poRecKpiTotalInvoice, '${totalAmount.toStringAsFixed(2)} \$', Icons.monetization_on, AppTheme.cobalt, isDark),
                _buildSummaryCard(l.poRecKpiTotalPackages, '${totalPackages.toStringAsFixed(0)} ${l.poRecPackagesUnit}', Icons.all_inbox, AppTheme.charcoal, isDark),
                _buildSummaryCard(l.poRecKpiTotalGrossWeight, '${_formatWeight(totalGrossWeight)} ${l.poRecKgUnit}', Icons.scale, AppTheme.orange, isDark),
                _buildSummaryCard(l.poRecKpiTotalNetWeight, '${_formatWeight(totalNetWeight)} ${l.poRecKgUnit}', Icons.fitness_center, AppTheme.emerald, isDark),
                _buildSummaryCard(l.poRecKpiTotalCbm, '${totalCbm.toStringAsFixed(3)} ${l.poRecCbmUnit}', Icons.view_in_ar, AppTheme.cobalt, isDark),
              ];
              if (isDesktop) {
                return Row(
                  children: kpiCards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: kpiCards.map((c) => SizedBox(
                  width: constraints.maxWidth > 550 ? (constraints.maxWidth - 24) / 2 : constraints.maxWidth,
                  child: c,
                )).toList(),
              );
            },
          ),
          const SizedBox(height: 20),

          // SECTION 1: INVOICE & PRICE RECONCILIATION TABLE
          Card(
            elevation: 2,
            color: AppTheme.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: AppTheme.borderOf(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final titleWidget = Row(
                        children: [
                          const Icon(Icons.receipt, color: AppTheme.cobalt),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.poRecInvoiceSectionTitle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                            ),
                          ),
                        ],
                      );

                      final actionsWidget = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IdocUi.fit(AppButton(
                            key: const Key('copyInvoiceItemsBtn'),
                            label: l.copyPoReconBtn,
                            icon: Icons.copy,
                            variant: AppButtonVariant.secondary,
                            onPressed: _invoiceItems.isEmpty ? null : _copyInvoiceItemsTable,
                          )),
                          IdocUi.fit(AppButton(
                            key: const Key('exportInvoiceItemsExcelBtn'),
                            label: l.exportPoReconExcelBtn,
                            icon: Icons.table_view_outlined,
                            variant: AppButtonVariant.secondary,
                            onPressed: _invoiceItems.isEmpty ? null : _exportInvoiceItemsToExcel,
                          )),
                          IdocUi.fit(AppButton(
                            key: const Key('exportInvoiceItemsPdfBtn'),
                            label: l.exportPoReconPdfBtn,
                            icon: Icons.picture_as_pdf_outlined,
                            variant: AppButtonVariant.danger,
                            onPressed: _invoiceItems.isEmpty ? null : _exportInvoiceItemsToPdf,
                          )),
                          IdocUi.fit(AppButton(
                            label: l.poRecResetToOriginalValuesButton,
                            icon: Icons.restart_alt,
                            variant: AppButtonVariant.secondary,
                            onPressed: () {
                              if (_selectedImportFileId != null) {
                                _loadPOItems(_selectedImportFileId!);
                              }
                            },
                          )),
                          // SAVE SESSION BUTTON
                          IdocUi.fit(AppButton(
                            label: _activeSessionId != null ? l.poRecUpdateSessionButton : l.poRecSaveSessionButton,
                            icon: Icons.save_rounded,
                            variant: AppButtonVariant.success,
                            isLoading: _isSavingSession,
                            onPressed: _isSavingSession ? null : _saveReconciliationSession,
                          )),
                          // CERTIFY BUTTON
                          IdocUi.fit(AppButton(
                            label: l.poRecCertifyFinalDataButton,
                            icon: Icons.verified,
                            variant: AppButtonVariant.primary,
                            isLoading: _isSubmitting,
                            onPressed: _isSubmitting ? null : _submitCertification,
                          )),
                        ],
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleWidget,
                          const SizedBox(height: 12),
                          actionsWidget,
                        ],
                      );
                    },
                  ),
                  const Divider(height: 20),
                  if (_invoiceItems.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Text(l.poRecSelectFileToViewPoItems, style: TextStyle(color: AppTheme.textMutedOf(context))),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        dataRowMinHeight: density.tableRowHeight - 4,
                        dataRowMaxHeight: density.tableRowHeight + 6,
                        headingRowHeight: density.tableHeadingHeight,
                        columnSpacing: density.byDensity<double>(16, 12, 10),
                        horizontalMargin: density.byDensity<double>(16, 12, 8),
                        columns: [
                          DataColumn(label: Text(l.actions, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text(l.poRecColItemCode)),
                          DataColumn(label: Text(l.poRecColDescription)),
                          DataColumn(label: Text(l.poRecColPoQty)),
                          DataColumn(label: Text(l.poRecColFinalQty)),
                          DataColumn(label: Text(l.poRecColQtyVariance)),
                          DataColumn(label: Text(l.poRecColPoUnitPrice)),
                          DataColumn(label: Text(l.poRecColFinalUnitPrice)),
                          DataColumn(label: Text(l.poRecColPriceVariance)),
                          DataColumn(label: Text(l.poRecColFinalTotal)),
                          DataColumn(label: Text(l.poRecColHsCode)),
                        ],
                        rows: [
                          ..._invoiceItems.asMap().entries.map((entry) {
                            int idx = entry.key;
                            var itm = entry.value;
                            double initQty = itm.initialQuantity;
                            double finQty = itm.finalQuantity;
                            double initPrice = itm.initialUnitPrice;
                            double finPrice = itm.finalUnitPrice > 0 ? itm.finalUnitPrice : itm.unitPrice;
                            double qtyVariancePct = initQty > 0 ? ((finQty - initQty) / initQty) * 100.0 : 0.0;
                            double priceVariancePct = initPrice > 0 ? ((finPrice - initPrice) / initPrice) * 100.0 : 0.0;
                            double totalRow = finQty * finPrice;
                            final rowSummary = [
                              itm.itemCode,
                              itm.description,
                              '$initQty',
                              '$finQty',
                              '${qtyVariancePct.toStringAsFixed(1)}%',
                              '$initPrice',
                              '$finPrice',
                              '${priceVariancePct.toStringAsFixed(1)}%',
                              '${totalRow.toStringAsFixed(2)} $currencyStr',
                              itm.hsCode ?? '',
                            ].join('\t');

                            return DataRow(cells: [
                              DataCell(
                                IconButton(
                                  key: Key('cloneInvoiceItemRowBtn_${itm.itemCode}'),
                                  icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                                  tooltip: l.clonePoReconRecordTooltip,
                                  onPressed: () => _cloneInvoiceItem(itm),
                                ),
                              ),
                              DataCell(CopyableTableCell(value: itm.itemCode, rowSummary: rowSummary, child: Text(itm.itemCode, style: const TextStyle(fontWeight: FontWeight.bold)))),
                              DataCell(CopyableTableCell(value: itm.description, rowSummary: rowSummary, child: SizedBox(width: 160, child: Text(itm.description, overflow: TextOverflow.ellipsis)))),
                              DataCell(CopyableTableCell(value: '$initQty', rowSummary: rowSummary, child: Text('$initQty'))),
                              DataCell(
                                SizedBox(
                                  width: 85,
                                  child: TextFormField(
                                    key: ValueKey('inv_qty_${idx}_${itm.itemCode}'),
                                    initialValue: '$finQty',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                                    onChanged: (val) {
                                      double? parsed = double.tryParse(val);
                                      if (parsed != null) {
                                        final cur = _invoiceItems[idx];
                                        final qPct = cur.initialQuantity > 0 ? ((parsed - cur.initialQuantity) / cur.initialQuantity) * 100.0 : 0.0;
                                        final curP = cur.finalUnitPrice > 0 ? cur.finalUnitPrice : cur.unitPrice;
                                        final pPct = cur.initialUnitPrice > 0 ? ((curP - cur.initialUnitPrice) / cur.initialUnitPrice) * 100.0 : 0.0;
                                        setState(() {
                                          _invoiceItems[idx] = cur.copyWith(
                                            finalQuantity: parsed,
                                            variancePercentage: qPct,
                                            priceVariancePercentage: pPct,
                                          );
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              DataCell(CopyableTableCell(value: '${qtyVariancePct.toStringAsFixed(1)}%', rowSummary: rowSummary, child: _buildVarianceBadge(qtyVariancePct))),
                              DataCell(CopyableTableCell(value: '$initPrice', rowSummary: rowSummary, child: Text('$initPrice'))),
                              DataCell(
                                SizedBox(
                                  width: 85,
                                  child: TextFormField(
                                    key: ValueKey('inv_price_${idx}_${itm.itemCode}'),
                                    initialValue: '$finPrice',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                                    onChanged: (val) {
                                      double? parsed = double.tryParse(val);
                                      if (parsed != null) {
                                        final cur = _invoiceItems[idx];
                                        final qPct = cur.initialQuantity > 0 ? ((cur.finalQuantity - cur.initialQuantity) / cur.initialQuantity) * 100.0 : 0.0;
                                        final pPct = cur.initialUnitPrice > 0 ? ((parsed - cur.initialUnitPrice) / cur.initialUnitPrice) * 100.0 : 0.0;
                                        setState(() {
                                          _invoiceItems[idx] = cur.copyWith(
                                            finalUnitPrice: parsed,
                                            unitPrice: parsed,
                                            variancePercentage: qPct,
                                            priceVariancePercentage: pPct,
                                          );
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              DataCell(CopyableTableCell(value: '${priceVariancePct.toStringAsFixed(1)}%', rowSummary: rowSummary, child: _buildVarianceBadge(priceVariancePct))),
                              DataCell(CopyableTableCell(value: '${totalRow.toStringAsFixed(2)} $currencyStr', rowSummary: rowSummary, child: Text('${totalRow.toStringAsFixed(2)} $currencyStr', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)))),
                              DataCell(
                                SizedBox(
                                  width: 100,
                                  child: TextFormField(
                                    key: ValueKey('inv_hs_${idx}_${itm.itemCode}'),
                                    initialValue: itm.hsCode ?? '',
                                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                                    onChanged: (val) {
                                      final cur = _invoiceItems[idx];
                                      setState(() {
                                        _invoiceItems[idx] = cur.copyWith(hsCode: val);
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ]);
                          }),
                          if (_invoiceItems.isNotEmpty) ...[
                            () {
                              final totalPoQty = _invoiceItems.fold(0.0, (s, i) => s + i.initialQuantity);
                              final totalFinQty = _invoiceItems.fold(0.0, (s, i) => s + i.finalQuantity);
                              final totalPoAmt = _invoiceItems.fold(0.0, (s, i) => s + (i.initialQuantity * i.initialUnitPrice));
                              final overallQtyVarPct = totalPoQty > 0 ? ((totalFinQty - totalPoQty) / totalPoQty) * 100.0 : 0.0;
                              final overallPriceVarPct = totalPoAmt > 0 ? ((totalAmount - totalPoAmt) / totalPoAmt) * 100.0 : 0.0;
                              return DataRow(
                                color: WidgetStateProperty.all(isDark ? AppTheme.textSecondaryOf(context).withValues(alpha: 0.2) : AppTheme.infoBackground),
                                cells: [
                                  const DataCell(SizedBox()),
                                  DataCell(Text(l.poRecTotalSummaryRow, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 13))),
                                  DataCell(Text('${_invoiceItems.length} ${l.poRecPackagesUnit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  DataCell(Text(totalPoQty.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  DataCell(Text(totalFinQty.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 13))),
                                  DataCell(_buildVarianceBadge(overallQtyVarPct)),
                                  DataCell(Text('${totalPoAmt.toStringAsFixed(2)} $currencyStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  const DataCell(Text('—', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(_buildVarianceBadge(overallPriceVarPct)),
                                  DataCell(Text('${totalAmount.toStringAsFixed(2)} $currencyStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt))),
                                  const DataCell(Text('—')),
                                ],
                              );
                            }(),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // SECTION 2: PACKING LIST & WEIGHTS RECONCILIATION TABLE
          Card(
            elevation: 2,
            color: AppTheme.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: AppTheme.borderOf(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final titleWidget = Row(
                        children: [
                          const Icon(Icons.inventory, color: AppTheme.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.poRecPackingSectionTitle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                            ),
                          ),
                        ],
                      );

                      final actionsWidget = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IdocUi.fit(AppButton(
                            key: const Key('copyPackingItemsBtn'),
                            label: l.copyPoReconBtn,
                            icon: Icons.copy,
                            variant: AppButtonVariant.secondary,
                            onPressed: _packingItems.isEmpty ? null : _copyPackingItemsTable,
                          )),
                          IdocUi.fit(AppButton(
                            key: const Key('exportPackingItemsExcelBtn'),
                            label: l.exportPoReconExcelBtn,
                            icon: Icons.table_view_outlined,
                            variant: AppButtonVariant.secondary,
                            onPressed: _packingItems.isEmpty ? null : _exportPackingItemsToExcel,
                          )),
                          IdocUi.fit(AppButton(
                            key: const Key('exportPackingItemsPdfBtn'),
                            label: l.exportPoReconPdfBtn,
                            icon: Icons.picture_as_pdf_outlined,
                            variant: AppButtonVariant.danger,
                            onPressed: _packingItems.isEmpty ? null : _exportPackingItemsToPdf,
                          )),
                        ],
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleWidget,
                          const SizedBox(height: 10),
                          actionsWidget,
                        ],
                      );
                    },
                  ),

                  const Divider(height: 20),
                  if (_packingItems.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Text(l.poRecSelectFileToViewPackingItems, style: TextStyle(color: AppTheme.textMutedOf(context))),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        dataRowMinHeight: density.tableRowHeight - 4,
                        dataRowMaxHeight: density.tableRowHeight + 6,
                        headingRowHeight: density.tableHeadingHeight,
                        columnSpacing: density.byDensity<double>(16, 12, 10),
                        horizontalMargin: density.byDensity<double>(16, 12, 8),
                        columns: [
                          DataColumn(label: Text(l.actions, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text(l.poRecColItemCode)),
                          DataColumn(label: Text(l.poRecColPackageType)),
                          DataColumn(label: Text(l.poRecColPoPackagesCount)),
                          DataColumn(label: Text(l.poRecColFinalPackagesCount)),
                          DataColumn(label: Text(l.poRecColPkgVariance)),
                          DataColumn(label: Text(l.poRecColGrossWeight)),
                          DataColumn(label: Text(l.poRecColNetWeight)),
                          DataColumn(label: Text(l.poRecColCbm)),
                        ],
                        rows: [
                          ..._packingItems.asMap().entries.map((entry) {
                            int idx = entry.key;
                            var itm = entry.value;
                            double initPkgs = itm.initialPackagesCount;
                            double finPkgs = itm.finalPackagesCount;
                            double pkgVarPct = initPkgs > 0
                                ? ((finPkgs - initPkgs) / initPkgs) * 100.0
                                : 0.0;
                            final rowSummary = [
                              itm.itemCode,
                              itm.packageType,
                              '${initPkgs.toInt() == initPkgs ? initPkgs.toInt() : initPkgs}',
                              '${finPkgs.toInt() == finPkgs ? finPkgs.toInt() : finPkgs}',
                              '${pkgVarPct.toStringAsFixed(1)}%',
                              '${itm.finalGrossWeightKg}',
                              '${itm.finalNetWeightKg}',
                              '${itm.finalCbm}',
                            ].join('\t');

                            return DataRow(cells: [
                              DataCell(
                                IconButton(
                                  key: Key('clonePackingItemRowBtn_${itm.itemCode}'),
                                  icon: const Icon(Icons.copy, size: 16, color: AppTheme.orange),
                                  tooltip: l.clonePoReconRecordTooltip,
                                  onPressed: () => _clonePackingItem(itm),
                                ),
                              ),
                              DataCell(CopyableTableCell(value: itm.itemCode, rowSummary: rowSummary, child: Text(itm.itemCode, style: const TextStyle(fontWeight: FontWeight.bold)))),
                              DataCell(
                                SizedBox(
                                  width: 100,
                                  child: TextFormField(
                                    key: ValueKey('pl_pkg_type_${idx}_${itm.itemCode}'),
                                    initialValue: itm.packageType,
                                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                                    onChanged: (val) {
                                      final cur = _packingItems[idx];
                                      setState(() {
                                        _packingItems[idx] = cur.copyWith(packageType: val);
                                      });
                                    },
                                  ),
                                ),
                              ),
                              DataCell(
                                CopyableTableCell(
                                  value: '${initPkgs.toInt() == initPkgs ? initPkgs.toInt() : initPkgs}',
                                  rowSummary: rowSummary,
                                  child: Text(
                                    '${initPkgs.toInt() == initPkgs ? initPkgs.toInt() : initPkgs}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryOf(context)),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 85,
                                  child: TextFormField(
                                    key: ValueKey('pl_pkg_count_${idx}_${itm.itemCode}'),
                                    initialValue: '${finPkgs.toInt() == finPkgs ? finPkgs.toInt() : finPkgs}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                                    onChanged: (val) {
                                      double? parsed = double.tryParse(val);
                                      if (parsed != null) {
                                        final cur = _packingItems[idx];
                                        setState(() {
                                          _packingItems[idx] = cur.copyWith(finalPackagesCount: parsed);
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              DataCell(
                                CopyableTableCell(
                                  value: '${pkgVarPct.toStringAsFixed(1)}%',
                                  rowSummary: rowSummary,
                                  child: _buildVarianceBadge(pkgVarPct),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 100,
                                  child: TextFormField(
                                    key: ValueKey('pl_gross_wt_${idx}_${itm.itemCode}'),
                                    initialValue: '${itm.finalGrossWeightKg}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                                    onChanged: (val) {
                                      double? parsed = double.tryParse(val);
                                      if (parsed != null) {
                                        final cur = _packingItems[idx];
                                        setState(() {
                                          _packingItems[idx] = cur.copyWith(finalGrossWeightKg: parsed);
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 100,
                                  child: TextFormField(
                                    key: ValueKey('pl_net_wt_${idx}_${itm.itemCode}'),
                                    initialValue: '${itm.finalNetWeightKg}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                                    onChanged: (val) {
                                      double? parsed = double.tryParse(val);
                                      if (parsed != null) {
                                        final cur = _packingItems[idx];
                                        setState(() {
                                          _packingItems[idx] = cur.copyWith(finalNetWeightKg: parsed);
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 85,
                                  child: TextFormField(
                                    key: ValueKey('pl_cbm_${idx}_${itm.itemCode}'),
                                    initialValue: '${itm.finalCbm}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                                    onChanged: (val) {
                                      double? parsed = double.tryParse(val);
                                      if (parsed != null) {
                                        final cur = _packingItems[idx];
                                        setState(() {
                                          _packingItems[idx] = cur.copyWith(finalCbm: parsed);
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ]);
                          }),
                          if (_packingItems.isNotEmpty) ...[
                            () {
                              final totalPoPkgs = _packingItems.fold(0.0, (s, i) => s + i.initialPackagesCount);
                              final totalPkgs = _packingItems.fold(0.0, (s, i) => s + i.finalPackagesCount);
                              final totalGross = _packingItems.fold(0.0, (s, i) => s + i.finalGrossWeightKg);
                              final totalNet = _packingItems.fold(0.0, (s, i) => s + i.finalNetWeightKg);
                              final totalCbmVal = _packingItems.fold(0.0, (s, i) => s + i.finalCbm);
                              final overallPkgVar = totalPoPkgs > 0 ? ((totalPkgs - totalPoPkgs) / totalPoPkgs) * 100.0 : 0.0;
                              return DataRow(
                                color: WidgetStateProperty.all(isDark ? AppTheme.textSecondaryOf(context).withValues(alpha: 0.2) : AppTheme.infoBackground),
                                cells: [
                                  const DataCell(SizedBox()),
                                  DataCell(Text(l.poRecTotalSummaryRow, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 13))),
                                  DataCell(Text(context.l10n.idocAItemsCount(_packingItems.length), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  DataCell(Text('${totalPoPkgs.toStringAsFixed(0)} ${l.poRecPackagesUnit}', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context), fontSize: 13))),
                                  DataCell(Text('${totalPkgs.toStringAsFixed(0)} ${l.poRecPackagesUnit}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 13))),
                                  DataCell(_buildVarianceBadge(overallPkgVar)),
                                  DataCell(Text('${_formatWeight(totalGross)} ${l.poRecKgUnit}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 13))),
                                  DataCell(Text('${_formatWeight(totalNet)} ${l.poRecKgUnit}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 13))),
                                  DataCell(Text('${totalCbmVal.toStringAsFixed(3)} ${l.poRecCbmUnit}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange, fontSize: 13))),
                                ],
                              );
                            }(),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PART 2: SAVED SESSIONS HISTORY SECTION
  // ==========================================
  Widget _buildSavedSessionsHistorySection(
    List<POReconciliationSessionModel> allSessions,
    List<ImportFileModel> importFiles,
    bool isDark,
  ) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    // Apply filters
    var filtered = allSessions.where((s) {
      if (_statusFilter != 'All' && s.overallStatus != _statusFilter) return false;
      if (_searchHistoryCtrl.text.isNotEmpty) {
        final q = _searchHistoryCtrl.text.trim().toLowerCase();
        final code = s.sessionCode.toLowerCase();
        final fCode = (s.importFileCode ?? '').toLowerCase();
        final rawFileCode = s.importFileCode ?? 'IMP-${s.importFileId}';
        final shipmentTitle = rawFileCode.isNotEmpty
            ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isAr).toLowerCase()
            : '';
        final imp = (s.importerName ?? '').toLowerCase();
        final inv = (s.finalInvoiceNumber ?? '').toLowerCase();
        final pl = (s.finalPackingListNumber ?? '').toLowerCase();
        final acid = (s.acidNumber ?? '').toLowerCase();
        return code.contains(q) || fCode.contains(q) || shipmentTitle.contains(q) || imp.contains(q) || inv.contains(q) || pl.contains(q) || acid.contains(q);
      }
      return true;
    }).toList();

    // Stats calculations
    final matchedSessions = allSessions.where((s) => s.overallStatus == 'FULLY_MATCHED').length;
    final varianceSessions = allSessions.where((s) => s.overallStatus != 'FULLY_MATCHED').length;
    final totalVal = allSessions.fold(0.0, (sum, s) => sum + s.totalInvoiceAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. SECTION HEADER CARD
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.borderOf(context)),
          ),
          color: isDark ? AppTheme.darkCardBackground : AppTheme.cloudWhite,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.charcoal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_shared_rounded, color: AppTheme.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.poRecHistorySectionTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.poRecHistorySectionSubtitle,
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryOf(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l.poRecHistoryTotalSessionsBadge(allSessions.length),
                    style: const TextStyle(color: AppTheme.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. STATS BAR (Identical to Shipping Scenarios _histStatCard)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IdocUi.metrics([
              MetricCardData(
                title: l.poRecHistoryKpiTotalSessions,
                shortTitle: l.poRecHistoryKpiTotalSessions,
                value: '${allSessions.length}',
                icon: Icons.all_inbox_rounded,
                color: AppTheme.cobalt,
              ),
              MetricCardData(
                title: l.poRecHistoryKpiFullMatch,
                shortTitle: l.poRecHistoryKpiFullMatch,
                value: '$matchedSessions',
                icon: Icons.check_circle_rounded,
                color: AppTheme.emerald,
              ),
              MetricCardData(
                title: l.poRecHistoryKpiWithVariances,
                shortTitle: l.poRecHistoryKpiWithVariances,
                value: '$varianceSessions',
                icon: Icons.warning_amber_rounded,
                color: AppTheme.orange,
              ),
              MetricCardData(
                title: l.poRecHistoryKpiTotalCertifiedValue,
                shortTitle: l.poRecHistoryKpiTotalCertifiedValue,
                value: totalVal.toStringAsFixed(0),
                icon: Icons.monetization_on_rounded,
                color: AppTheme.wcagEmerald,
              ),
            ]),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IdocUi.fit(AppButton(
                label: l.poRecHistoryNewSessionButton,
                icon: Icons.add_rounded,
                variant: AppButtonVariant.primary,
                onPressed: () {
                  setState(() {
                    _activeSessionId = null;
                    _activeSessionCode = null;
                  });
                  if (_mainScrollController.hasClients) {
                    _mainScrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              )),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. SEARCH & FILTER TOOLBAR
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 950;
            final searchField = TextField(
              controller: _searchHistoryCtrl,
              decoration: InputDecoration(
                hintText: l.poRecHistorySearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchHistoryCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() => _searchHistoryCtrl.clear());
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (_) => setState(() {}),
            );

            final chipsAndActions = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildStatusFilterChip('All', l.poRecHistoryFilterAll(allSessions.length)),
                _buildStatusFilterChip('FULLY_MATCHED', l.poRecHistoryFilterMatched),
                _buildStatusFilterChip('ACCEPTED_WITH_WARNINGS', l.poRecHistoryFilterWarnings),
                _buildStatusFilterChip('CRITICAL_DISCREPANCY', l.poRecHistoryFilterCritical),
                IconButton(
                  key: const Key('copySessionsBtn'),
                  icon: const Icon(Icons.copy_all, color: AppTheme.cobalt),
                  tooltip: l.copyPoReconBtn,
                  onPressed: filtered.isEmpty ? null : () => _copySessionsTable(filtered),
                ),
                IconButton(
                  key: const Key('exportSessionsExcelBtn'),
                  icon: const Icon(Icons.table_view_outlined, color: AppTheme.emerald),
                  tooltip: l.exportPoReconExcelBtn,
                  onPressed: filtered.isEmpty ? null : () => _exportSessionsToExcel(filtered),
                ),
                IconButton(
                  key: const Key('exportSessionsPdfBtn'),
                  icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson),
                  tooltip: l.exportPoReconPdfBtn,
                  onPressed: filtered.isEmpty ? null : () => _exportSessionsToPdf(filtered),
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: AppTheme.textPrimaryOf(context)),
                  tooltip: l.poRecHistoryRefreshTooltip,
                  onPressed: () {
                    ref.read(poReconciliationSessionsProvider.notifier).fetchSessions();
                  },
                ),
              ],
            );

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderOf(context)),
              ),
              child: isCompact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 10),
                        chipsAndActions,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(flex: 3, child: searchField),
                        const SizedBox(width: 16),
                        Expanded(flex: 5, child: chipsAndActions),
                      ],
                    ),
            );
          },
        ),
        const SizedBox(height: 16),

        // 4. DATA TABLE OR EMPTY STATE
        filtered.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open_rounded, size: 64, color: AppTheme.textMutedOf(context)),
                      const SizedBox(height: 16),
                      Text(
                        allSessions.isEmpty
                            ? l.poRecHistoryEmptyTitle
                            : l.poRecHistoryNoMatchFilter,
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryOf(context)),
                      ),
                      const SizedBox(height: 12),
                      IdocUi.fit(AppButton(
                        label: l.poRecHistoryCreateFirstSessionButton,
                        icon: Icons.add,
                        variant: AppButtonVariant.primary,
                        onPressed: () {
                          if (_mainScrollController.hasClients) {
                            _mainScrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                      )),
                    ],
                  ),
                ),
              )
            : EnterpriseDataTable<POReconciliationSessionModel>(
                data: filtered,
                storageKey: 'po_reconciliation_sessions_table',
                columns: [
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'actions',
                    title: l.poRecHistoryColActions,
                    width: 245,
                    isSortable: false,
                    isSearchable: false,
                    cellBuilder: (context, sess, index) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_rounded, size: 18, color: AppTheme.cobalt),
                            tooltip: l.poRecHistoryViewDetailsTooltip,
                            onPressed: () => _showSessionDetailsModal(context, sess),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, size: 20, color: AppTheme.emerald),
                            tooltip: l.poRecHistoryLoadIntoEditorTooltip,
                            onPressed: () => _loadSessionIntoEditor(sess),
                          ),
                          IconButton(
                            key: Key('cloneSessionRowBtn_${sess.sessionId}'),
                            icon: const Icon(Icons.copy_all_rounded, size: 18, color: AppTheme.cobalt),
                            tooltip: l.clonePoReconRecordTooltip,
                            onPressed: () => _cloneSession(sess),
                          ),
                          IconButton(
                            icon: Icon(Icons.print_rounded, size: 18, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                            tooltip: l.poRecHistoryPrintTooltip,
                            onPressed: () => _showPrintReportDialog(context, sess),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.crimson),
                            tooltip: l.poRecHistoryDeleteTooltip,
                            onPressed: () => _confirmDeleteSession(context, sess),
                          ),
                        ],
                      );
                    },
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'index',
                    title: l.poRecHistoryColIndex,
                    width: 60,
                    isSortable: false,
                    searchValue: (sess) => '${filtered.indexOf(sess) + 1}',
                    cellBuilder: (context, sess, index) => Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'session_code',
                    title: l.poRecHistoryColSessionCode,
                    width: 215,
                    isSortable: true,
                    searchValue: (sess) => sess.sessionCode,
                    exportValue: (sess) => sess.sessionCode,
                    cellBuilder: (context, sess, index) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              sess.sessionCode,
                              style: const TextStyle(
                                color: AppTheme.cobalt,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.cobalt),
                            tooltip: l.copy,
                            onPressed: () => CopyHelper.copy(
                              context,
                              sess.sessionCode,
                              
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'import_file',
                    title: l.poRecHistoryColImportFileImporter,
                    width: 180,
                    isSortable: true,
                    searchValue: (sess) {
                      final rawFileCode = sess.importFileCode ?? 'IMP-${sess.importFileId}';
                      final shipmentTitle = rawFileCode.isNotEmpty
                          ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isAr)
                          : (sess.importerName ?? '—');
                      return '$shipmentTitle $rawFileCode ${sess.importerName ?? ""}';
                    },
                    exportValue: (sess) {
                      final rawFileCode = sess.importFileCode ?? 'IMP-${sess.importFileId}';
                      final shipmentTitle = rawFileCode.isNotEmpty
                          ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isAr)
                          : (sess.importerName ?? '—');
                      return '$shipmentTitle ($rawFileCode) - ${sess.importerName ?? ""}';
                    },
                    cellBuilder: (context, sess, index) {
                      final rawFileCode = sess.importFileCode ?? 'IMP-${sess.importFileId}';
                      final shipmentTitle = rawFileCode.isNotEmpty
                          ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isAr)
                          : (sess.importerName ?? '—');
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shipmentTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                            ),
                          ),
                          if (rawFileCode.isNotEmpty && rawFileCode != shipmentTitle)
                            Text(
                              rawFileCode,
                              style: const TextStyle(fontSize: 10.5, color: AppTheme.cobalt, fontWeight: FontWeight.w600),
                            ),
                          if (sess.importerName != null && sess.importerName!.isNotEmpty)
                            Text(
                              sess.importerName!,
                              style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                            ),
                        ],
                      );
                    },
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'invoice_packing',
                    title: l.poRecHistoryColInvoicePacking,
                    width: 150,
                    isSortable: true,
                    searchValue: (sess) => '${sess.finalInvoiceNumber ?? ""} ${sess.finalPackingListNumber ?? ""}',
                    exportValue: (sess) => '${sess.finalInvoiceNumber ?? ""} | ${sess.finalPackingListNumber ?? ""}',
                    cellBuilder: (context, sess, index) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INV: ${sess.finalInvoiceNumber ?? "—"}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'PL: ${sess.finalPackingListNumber ?? "—"}',
                            style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                          ),
                        ],
                      );
                    },
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'total_value',
                    title: l.poRecHistoryColTotalValue,
                    width: 130,
                    isSortable: true,
                    searchValue: (sess) => '${sess.totalInvoiceAmount} ${sess.currency}',
                    exportValue: (sess) => '${sess.totalInvoiceAmount.toStringAsFixed(2)} ${sess.currency}',
                    cellBuilder: (context, sess, index) {
                      return Text(
                        '${sess.totalInvoiceAmount.toStringAsFixed(2)} ${sess.currency}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
                      );
                    },
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'packages_weight',
                    title: l.poRecHistoryColPackagesWeight,
                    width: 140,
                    isSortable: true,
                    searchValue: (sess) => '${sess.totalPackages} ${sess.totalGrossWeightKg}',
                    exportValue: (sess) => '${sess.totalPackages.toStringAsFixed(0)} | ${_formatWeight(sess.totalGrossWeightKg)} kg',
                    cellBuilder: (context, sess, index) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${sess.totalPackages.toStringAsFixed(0)} ${l.poRecPackagesUnit}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${_formatWeight(sess.totalGrossWeightKg)} ${l.poRecKgUnit}', style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted)),
                        ],
                      );
                    },
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'cbm',
                    title: l.poRecHistoryColCbm,
                    width: 100,
                    isSortable: true,
                    searchValue: (sess) => '${sess.totalCbm}',
                    exportValue: (sess) => '${sess.totalCbm.toStringAsFixed(3)} m³',
                    cellBuilder: (context, sess, index) => Text('${sess.totalCbm.toStringAsFixed(3)} ${l.poRecCbmUnit}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'status',
                    title: l.poRecHistoryColStatus,
                    width: 120,
                    isSortable: true,
                    searchValue: (sess) => _getLocalizedSessionStatus(context, sess.overallStatus),
                    exportValue: (sess) => _getLocalizedSessionStatus(context, sess.overallStatus),
                    cellBuilder: (context, sess, index) => _buildSessionStatusBadge(sess.overallStatus),
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'saved_date',
                    title: l.poRecHistoryColSavedDate,
                    width: 110,
                    isSortable: true,
                    searchValue: (sess) => sess.createdAt ?? '',
                    exportValue: (sess) => (sess.createdAt != null && sess.createdAt!.length >= 10) ? sess.createdAt!.substring(0, 10) : '—',
                    cellBuilder: (context, sess, index) {
                      final dateStr = (sess.createdAt != null && sess.createdAt!.length >= 10) ? sess.createdAt!.substring(0, 10) : '—';
                      return Text(dateStr, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted));
                    },
                  ),
                ],
              ),
      ],
    );
  }


  Widget _buildStatusFilterChip(String value, String label) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppTheme.cobalt.withValues(alpha: 0.2),
      onSelected: (selected) {
        if (selected) setState(() => _statusFilter = value);
      },
    );
  }

  Widget _buildSessionStatusBadge(String status) {
    final l = context.l10n;
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case 'FULLY_MATCHED':
        bg = AppTheme.severityBackgroundOf(context, AppSeverity.success);
        fg = AppTheme.severityForegroundOf(context, AppSeverity.success);
        label = l.poRecMatchStatusMatched;
        icon = Icons.check_circle;
        break;
      case 'ACCEPTED_WITH_WARNINGS':
        bg = AppTheme.severityBackgroundOf(context, AppSeverity.warning);
        fg = AppTheme.severityForegroundOf(context, AppSeverity.warning);
        label = l.poRecMatchStatusWarning;
        icon = Icons.warning_amber;
        break;
      case 'CRITICAL_DISCREPANCY':
        bg = AppTheme.severityBackgroundOf(context, AppSeverity.danger);
        fg = AppTheme.severityForegroundOf(context, AppSeverity.danger);
        label = l.poRecMatchStatusCritical;
        icon = Icons.error_outline;
        break;
      default:
        bg = AppTheme.surfaceAltOf(context);
        fg = AppTheme.textPrimaryOf(context);
        label = status;
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  // --- POPUP DIALOGS ---
  void _showSaveSuccessReportDialog(BuildContext context, POReconciliationSessionModel sess) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final rawFileCode = sess.importFileCode ?? 'IMP-${sess.importFileId}';
    final shipmentTitle = rawFileCode.isNotEmpty
        ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isAr)
        : '';
    final fileDisplay = shipmentTitle.isNotEmpty && shipmentTitle != rawFileCode
        ? '$shipmentTitle ($rawFileCode)'
        : (rawFileCode.isNotEmpty ? rawFileCode : 'N/A');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.poRecHistorySavedDialogTitle(sess.sessionCode),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SelectionArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${l.poRecImportFileLabel}: $fileDisplay - ${sess.importerName ?? "N/A"}'),
                const SizedBox(height: 6),
                Text('${l.poRecFinalInvoiceNoLabel}: ${sess.finalInvoiceNumber ?? "N/A"} | ${l.poRecFinalPackingListNoLabel}: ${sess.finalPackingListNumber ?? "N/A"}'),
                const SizedBox(height: 6),
                Text('${l.poRecKpiTotalInvoice}: ${sess.totalInvoiceAmount.toStringAsFixed(2)} ${sess.currency} | ${l.poRecKpiTotalPackages}: ${sess.totalPackages.toStringAsFixed(0)} | ${l.poRecKpiTotalCbm}: ${sess.totalCbm.toStringAsFixed(3)} ${l.poRecCbmUnit}'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.emeraldBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_rounded, color: AppTheme.emerald, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.poRecHistorySavedUniqueNotice,
                          style: const TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IdocUi.fit(AppButton(
            label: l.close,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(dialogCtx),
          )),
          IdocUi.fit(AppButton(
            label: l.poRecHistoryCopyReportButton,
            icon: Icons.print_rounded,
            variant: AppButtonVariant.primary,
            onPressed: () {
              Navigator.pop(dialogCtx);
              _showPrintReportDialog(context, sess);
            },
          )),
        ],
      ),
    );
  }

  void _showSessionDetailsModal(BuildContext context, POReconciliationSessionModel sess) {
    final isDark = AppTheme.isDark(context);
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final rawFileCode = sess.importFileCode ?? 'IMP-${sess.importFileId}';
    final shipmentTitle = rawFileCode.isNotEmpty
        ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isAr)
        : '';
    final fileDisplay = shipmentTitle.isNotEmpty && shipmentTitle != rawFileCode
        ? '$shipmentTitle ($rawFileCode)'
        : (rawFileCode.isNotEmpty ? rawFileCode : '—');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.transparent),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_rounded, color: AppTheme.cobalt, size: 26),
                const SizedBox(width: 10),
                Text(
                  l.poRecHistoryDetailsModalTitle(sess.sessionCode),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
            _buildSessionStatusBadge(sess.overallStatus),
          ],
        ),
        content: SizedBox(
          width: 750,
          child: SelectionArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Info Grid
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAltOf(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderOf(context)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final pills = [
                          _buildExtractedPill(l.poRecImportFileLabel, fileDisplay, Icons.folder_rounded, isDark),
                          _buildExtractedPill(l.poRecFinalInvoiceNoLabel, sess.finalInvoiceNumber ?? '—', Icons.receipt_long, isDark),
                          _buildExtractedPill(l.poRecFinalPackingListNoLabel, sess.finalPackingListNumber ?? '—', Icons.inventory_2, isDark),
                          _buildExtractedPill(l.poRecExtractedAcid, sess.acidNumber ?? '—', Icons.tag, isDark),
                        ];
                        if (constraints.maxWidth >= 750) {
                          return Row(
                            children: pills.map((p) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: p))).toList(),
                          );
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: pills.map((p) => SizedBox(
                            width: constraints.maxWidth > 400 ? (constraints.maxWidth - 8) / 2 : constraints.maxWidth,
                            child: p,
                          )).toList(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Metrics Row
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final mCards = [
                        _buildSummaryCard(l.poRecKpiTotalInvoice, '${sess.totalInvoiceAmount.toStringAsFixed(2)} ${sess.currency}', Icons.monetization_on, AppTheme.cobalt, isDark),
                        _buildSummaryCard(l.poRecKpiTotalPackages, '${sess.totalPackages.toStringAsFixed(0)} ${l.poRecPackagesUnit}', Icons.all_inbox, AppTheme.charcoal, isDark),
                        _buildSummaryCard(l.poRecKpiTotalGrossWeight, '${_formatWeight(sess.totalGrossWeightKg)} ${l.poRecKgUnit}', Icons.scale, AppTheme.orange, isDark),
                        _buildSummaryCard(l.poRecKpiTotalCbm, '${sess.totalCbm.toStringAsFixed(3)} ${l.poRecCbmUnit}', Icons.view_in_ar, AppTheme.emerald, isDark),
                      ];
                      if (constraints.maxWidth >= 750) {
                        return Row(
                          children: mCards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
                        );
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: mCards.map((c) => SizedBox(
                          width: constraints.maxWidth > 400 ? (constraints.maxWidth - 8) / 2 : constraints.maxWidth,
                          child: c,
                        )).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Items list summary
                  if (sess.reconciledInvoiceItems != null && sess.reconciledInvoiceItems!.isNotEmpty) ...[
                    Text(l.poRecHistoryDetailsCertifiedItemsTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Table(
                      border: TableBorder.all(color: AppTheme.borderOf(context)),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.08)),
                          children: [
                            Padding(padding: const EdgeInsets.all(6), child: Text(l.poRecColItemCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(l.poRecColDescription, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(l.poRecColFinalQty, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(l.poRecColFinalUnitPrice, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(l.poRecColFinalTotal, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                          ],
                        ),
                        ...sess.reconciledInvoiceItems!.map((itm) {
                          final map = itm as Map<String, dynamic>;
                          final qty = (map['final_quantity'] as num?)?.toDouble() ?? 1.0;
                          final price = (map['final_unit_price'] as num?)?.toDouble() ?? 0.0;
                          final total = (map['total_amount'] as num?)?.toDouble() ?? (qty * price);
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(6), child: CopyableText(map['item_code']?.toString() ?? '—', isSelectable: false, style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: CopyableText(map['description']?.toString() ?? '—', isSelectable: false, style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: CopyableText('$qty', isSelectable: false, style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: CopyableText('$price', isSelectable: false, style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: CopyableText('${total.toStringAsFixed(2)} ${sess.currency}', isSelectable: false, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                          );
                        }),
                        TableRow(
                          decoration: BoxDecoration(color: AppTheme.cobalt.withValues(alpha: 0.08)),
                          children: [
                            Padding(padding: const EdgeInsets.all(6), child: Text(l.poRecTotalSummaryRow, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.cobalt))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.idocAItemsCount(sess.reconciledInvoiceItems!.length), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(
                              sess.reconciledInvoiceItems!.fold(0.0, (s, i) => s + (((i as Map<String, dynamic>)['final_quantity'] as num?)?.toDouble() ?? 0.0)).toStringAsFixed(0),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.cobalt),
                            )),
                            const Padding(padding: EdgeInsets.all(6), child: Text('—', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: const EdgeInsets.all(6), child: Text('${sess.totalInvoiceAmount.toStringAsFixed(2)} ${sess.currency}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.cobalt))),
                          ],
                        ),
                      ],
                    ),
                  ],

                  // Certified Packing List & Physical Measurements in Session
                  if (sess.reconciledPackingItems != null && sess.reconciledPackingItems!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(l.poRecHistoryDetailsCertifiedPackingTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Table(
                      border: TableBorder.all(color: AppTheme.borderOf(context)),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.08)),
                          children: [
                            Padding(padding: const EdgeInsets.all(6), child: Text(l.poRecColItemCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(l.poRecColPackageType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(l.poRecColFinalPackagesCount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(l.poRecColGrossWeight, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(l.poRecColNetWeight, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(l.poRecColCbm, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                          ],
                        ),
                        ...sess.reconciledPackingItems!.map((itm) {
                          final map = itm as Map<String, dynamic>;
                          final pkgs = (map['final_packages_count'] as num?)?.toDouble() ?? 0.0;
                          final gross = (map['final_gross_weight_kg'] as num?)?.toDouble() ?? 0.0;
                          final net = (map['final_net_weight_kg'] as num?)?.toDouble() ?? 0.0;
                          final cbm = (map['final_cbm'] as num?)?.toDouble() ?? 0.0;
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(6), child: CopyableText(map['item_code']?.toString() ?? '—', isSelectable: false, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: CopyableText(map['package_type']?.toString() ?? '—', isSelectable: false, style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: CopyableText('${pkgs.toStringAsFixed(0)} ${l.poRecPackagesUnit}', isSelectable: false, style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: CopyableText('${_formatWeight(gross)} ${l.poRecKgUnit}', isSelectable: false, style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: CopyableText('${_formatWeight(net)} ${l.poRecKgUnit}', isSelectable: false, style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: CopyableText('${cbm.toStringAsFixed(3)} ${l.poRecCbmUnit}', isSelectable: false, style: const TextStyle(fontSize: 11))),
                            ],
                          );
                        }),
                        TableRow(
                          decoration: BoxDecoration(color: AppTheme.emerald.withValues(alpha: 0.08)),
                          children: [
                            Padding(padding: const EdgeInsets.all(6), child: Text(l.poRecTotalSummaryRow, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.emerald))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.idocAItemsCount(sess.reconciledPackingItems!.length), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6), child: Text('${sess.totalPackages.toStringAsFixed(0)} ${l.poRecPackagesUnit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.cobalt))),
                            Padding(padding: const EdgeInsets.all(6), child: Text('${_formatWeight(sess.totalGrossWeightKg)} ${l.poRecKgUnit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.emerald))),
                            Padding(padding: const EdgeInsets.all(6), child: Text('${_formatWeight(sess.totalNetWeightKg)} ${l.poRecKgUnit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.cobalt))),
                            Padding(padding: const EdgeInsets.all(6), child: Text('${sess.totalCbm.toStringAsFixed(3)} ${l.poRecCbmUnit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.orange))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          IdocUi.fit(AppButton(
            label: l.close,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(dialogCtx),
          )),
          IdocUi.fit(AppButton(
            label: l.poRecHistoryLoadInEditorButton,
            icon: Icons.edit_note_rounded,
            variant: AppButtonVariant.primary,
            onPressed: () {
              Navigator.pop(dialogCtx);
              _loadSessionIntoEditor(sess);
            },
          )),
        ],
      ),
    );
  }

  void _showPrintReportDialog(BuildContext context, POReconciliationSessionModel sess) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final rawFileCode = sess.importFileCode ?? 'IMP-${sess.importFileId}';
    final shipmentTitle = rawFileCode.isNotEmpty
        ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isAr)
        : '';
    final fileDisplay = shipmentTitle.isNotEmpty && shipmentTitle != rawFileCode
        ? '$shipmentTitle ($rawFileCode)'
        : (rawFileCode.isNotEmpty ? rawFileCode : 'N/A');

    final buffer = StringBuffer();
    buffer.writeln('================================================================');
    buffer.writeln(l.poRecReportTitle);
    buffer.writeln('${l.poRecReportSessionCode}: ${sess.sessionCode}');
    buffer.writeln('${l.poRecReportImportFile}: $fileDisplay | ${l.poRecReportImporter}: ${sess.importerName ?? "N/A"}');
    buffer.writeln('${l.poRecReportShipper}: ${sess.shipperName ?? "N/A"} | ${l.poRecReportAcid}: ${sess.acidNumber ?? "N/A"}');
    buffer.writeln('${l.poRecReportInvoiceNo}: ${sess.finalInvoiceNumber ?? "N/A"} | ${l.poRecReportPackingNo}: ${sess.finalPackingListNumber ?? "N/A"}');
    buffer.writeln('${l.poRecReportTotalValue}: ${sess.totalInvoiceAmount.toStringAsFixed(2)} ${sess.currency}');
    buffer.writeln('${l.poRecReportPackages}: ${sess.totalPackages.toStringAsFixed(0)} ${l.poRecPackagesUnit} | ${l.poRecReportGrossWeight}: ${_formatWeight(sess.totalGrossWeightKg)} ${l.poRecKgUnit} | ${l.poRecReportNetWeight}: ${_formatWeight(sess.totalNetWeightKg)} ${l.poRecKgUnit}');
    buffer.writeln('${l.poRecReportTotalCbm}: ${sess.totalCbm.toStringAsFixed(3)} ${l.poRecCbmUnit}');
    buffer.writeln('${l.poRecReportOverallStatus}: ${_getLocalizedSessionStatus(context, sess.overallStatus)} | ${l.poRecReportCertifiedBy}: ${sess.certifiedBy ?? "N/A"}');
    buffer.writeln('================================================================\n');
    buffer.writeln(l.poRecReportCsvHeader);

    if (sess.reconciledInvoiceItems != null) {
      for (var itm in sess.reconciledInvoiceItems!) {
        final map = itm as Map<String, dynamic>;
        buffer.writeln('"${map['item_code']}","${map['description']}","${map['hs_code'] ?? ''}",${map['final_quantity']},${map['final_unit_price']},${map['total_amount'] ?? 0.0},${map['final_packages_count'] ?? 1.0},${map['final_gross_weight_kg'] ?? 0.0},${map['final_net_weight_kg'] ?? 0.0},${map['final_cbm'] ?? 0.0}');
      }
    }

    if (sess.reconciledPackingItems != null && sess.reconciledPackingItems!.isNotEmpty) {
      buffer.writeln('\n================================================================');
      buffer.writeln(l.poRecHistoryDetailsCertifiedPackingTitle);
      buffer.writeln('"Item Code","Package Type","Packages","Gross Wt (kg)","Net Wt (kg)","CBM (m³)"');
      for (var itm in sess.reconciledPackingItems!) {
        final map = itm as Map<String, dynamic>;
        buffer.writeln('"${map['item_code']}","${map['package_type'] ?? ''}",${map['final_packages_count'] ?? 0},${map['final_gross_weight_kg'] ?? 0},${map['final_net_weight_kg'] ?? 0},${map['final_cbm'] ?? 0}');
      }
      buffer.writeln('----------------------------------------------------------------');
      buffer.writeln('TOTAL PACKAGES: ${sess.totalPackages.toStringAsFixed(0)} ${l.poRecPackagesUnit} | TOTAL GROSS WT: ${_formatWeight(sess.totalGrossWeightKg)} ${l.poRecKgUnit} | TOTAL NET WT: ${_formatWeight(sess.totalNetWeightKg)} ${l.poRecKgUnit} | TOTAL CBM: ${sess.totalCbm.toStringAsFixed(3)} ${l.poRecCbmUnit}');
    }

    final reportText = buffer.toString();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.print_rounded, color: AppTheme.cobalt, size: 24),
            const SizedBox(width: 8),
            Text(l.poRecReportPreviewTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 700,
          height: 400,
          child: SelectionArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAltOf(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderOf(context)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  reportText,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
                ),
              ),
            ),
          ),
        ),
        actions: [
          IdocUi.fit(AppButton(
            label: l.close,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(dialogCtx),
          )),
          IdocUi.fit(AppButton(
            label: l.poRecHistoryCopyReportButton,
            icon: Icons.copy_rounded,
            variant: AppButtonVariant.primary,
            onPressed: () {
              CopyHelper.copy(context, reportText, customMessage: l.poRecHistoryPrintCopiedSuccess);
              Navigator.pop(dialogCtx);
            },
          )),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSession(BuildContext context, POReconciliationSessionModel sess) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: AppTheme.crimson, size: 28),
            const SizedBox(width: 10),
            Text(l.poRecHistoryDeleteConfirmTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          l.poRecHistoryDeleteConfirmContent(sess.sessionCode, sess.importFileCode ?? sess.importFileId.toString()),
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          IdocUi.fit(AppButton(
            label: l.cancel,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx, false),
          )),
          IdocUi.fit(AppButton(
            label: l.poRecHistoryDeletePermanent,
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.pop(ctx, true),
          )),
        ],
      ),
    );

    if (confirm == true && sess.sessionId != null) {
      await ref.read(poReconciliationSessionsProvider.notifier).deleteSession(sess.sessionId!);
      if (context.mounted) messenger.showSnackBar(AppTheme.snackBar(context, l.poRecHistoryDeletedSuccess(sess.sessionCode), severity: AppSeverity.success));
    }
  }



  // --- SMART EXTRACTION WIDGETS ---
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, [bool isDark = false]) {
    const cardBg = AppTheme.white;
    final labelColor = AppTheme.textSecondaryOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: labelColor, height: 1.2)),
                const SizedBox(height: 3),
                CopyableText(
                  value,
                  isSelectable: false,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVarianceBadge(double variance) {
    bool isZero = variance == 0.0;
    bool isPositive = variance > 0;
    Color color = isZero ? AppTheme.textMutedOf(context) : (isPositive ? AppTheme.emerald : AppTheme.crimson);
    String text = isZero ? '0.0%' : '${isPositive ? '+' : ''}${variance.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildSmartExtractionCard([bool isDark = false]) {
    final l = context.l10n;
    return Card(
      elevation: 3,
      color: AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.cobalt.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 750;
                final titleBlock = Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome, color: AppTheme.cobalt, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.poRecExtractorTitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.poRecExtractorSubtitle,
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (kDebugMode)
                    IdocUi.fit(AppButton(
                      label: l.poRecLoadSampleDemoButton,
                      icon: Icons.dataset_linked,
                      variant: AppButtonVariant.success,
                      size: AppButtonSize.small,
                      onPressed: _loadSampleData,
                    )),
                    IconButton(
                      icon: Icon(
                        _showSmartExtractionTool ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                      tooltip: _showSmartExtractionTool ? l.poRecHideTool : l.poRecShowTool,
                      onPressed: () {
                        setState(() => _showSmartExtractionTool = !_showSmartExtractionTool);
                      },
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      const SizedBox(height: 10),
                      actionButtons,
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    actionButtons,
                  ],
                );
              },
            ),

            if (_showSmartExtractionTool) ...[
              const Divider(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 750;
                  final invoiceSide = Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAltOf(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderOf(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.receipt_long, color: AppTheme.cobalt, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      l.poRecExtractorTabInvoice,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppTheme.textPrimaryOf(context),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IdocUi.fit(AppButton(
                              label: _selectedInvoiceFileName != null ? l.poRecChangeFile : l.poRecUploadFile,
                              icon: Icons.upload_file,
                              variant: AppButtonVariant.secondary,
                              size: AppButtonSize.small,
                              onPressed: () => _pickFile(true),
                            )),
                          ],
                        ),
                        if (_selectedInvoiceFileName != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.severityBackgroundOf(context, AppSeverity.info), borderRadius: BorderRadius.circular(4)),
                            child: Row(
                              children: [
                                const Icon(Icons.attach_file, size: 14, color: AppTheme.cobalt),
                                const SizedBox(width: 4),
                                Expanded(child: Text(_selectedInvoiceFileName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppTheme.cobalt, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _invoiceTextCtrl,
                          maxLines: 8,
                          style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.textPrimaryOf(context)),
                          decoration: InputDecoration(
                            hintText: l.poRecPasteInvoiceHint,
                            filled: true,
                            fillColor: AppTheme.surfaceOf(context),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppTheme.borderOf(context))),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                        ),
                      ],
                    ),
                  );

                  final packingSide = Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAltOf(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderOf(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.inventory_2, color: AppTheme.orange, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      l.poRecExtractorTabPacking,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppTheme.textPrimaryOf(context),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IdocUi.fit(AppButton(
                              label: _selectedPackingFileName != null ? l.poRecChangeFile : l.poRecUploadFile,
                              icon: Icons.upload_file,
                              variant: AppButtonVariant.secondary,
                              size: AppButtonSize.small,
                              onPressed: () => _pickFile(false),
                            )),
                          ],
                        ),

                        if (_selectedPackingFileName != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.severityBackgroundOf(context, AppSeverity.warning), borderRadius: BorderRadius.circular(4)),
                            child: Row(
                              children: [
                                const Icon(Icons.attach_file, size: 14, color: AppTheme.orange),
                                const SizedBox(width: 4),
                                Expanded(child: Text(_selectedPackingFileName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppTheme.orange, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _packingTextCtrl,
                          maxLines: 8,
                          style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.textPrimaryOf(context)),
                          decoration: InputDecoration(
                            hintText: l.poRecPastePackingHint,
                            filled: true,
                            fillColor: AppTheme.surfaceOf(context),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppTheme.borderOf(context))),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (isCompact) {
                    return Column(
                      children: [
                        invoiceSide,
                        const SizedBox(height: 16),
                        packingSide,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: invoiceSide),
                      const SizedBox(width: 16),
                      Expanded(child: packingSide),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: IdocUi.fit(AppButton(
                  label: _isExtracting ? l.poRecExtractingProgress : l.poRecExecuteSmartExtractionButton,
                  icon: Icons.compare_arrows,
                  variant: AppButtonVariant.primary,
                  isLoading: _isExtracting,
                  onPressed: _isExtracting ? null : _runSmartExtractionAndComparison,
                )),
              ),

              if (_extractedReconciliationData != null) ...[
                const SizedBox(height: 20),
                _buildDiscrepanciesResultSection(isDark),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiscrepanciesResultSection([bool isDark = false]) {
    final l = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final data = _extractedReconciliationData!;
    final overallStatus = data['overall_status'] as String? ?? 'FULLY_MATCHED';
    final critCount = data['critical_discrepancies_count'] as int? ?? 0;
    final warnCount = data['warning_discrepancies_count'] as int? ?? 0;
    final headerDiscrepancies = data['header_discrepancies'] as List<dynamic>? ?? [];
    final invData = data['extracted_invoice_data'] as Map<String, dynamic>? ?? {};
    final plData = data['extracted_packing_data'] as Map<String, dynamic>? ?? {};

    Color statusColor;
    IconData statusIcon;
    String statusTitle;

    if (overallStatus == 'FULLY_MATCHED') {
      statusColor = AppTheme.emerald;
      statusIcon = Icons.check_circle;
      statusTitle = l.poRecStatusFullyMatchedTitle;
    } else if (overallStatus == 'ACCEPTED_WITH_WARNINGS') {
      statusColor = AppTheme.orange;
      statusIcon = Icons.warning_amber;
      statusTitle = l.poRecStatusWarningsTitle(warnCount);
    } else {
      statusColor = AppTheme.crimson;
      statusIcon = Icons.cancel;
      statusTitle = l.poRecStatusCriticalTitle(critCount);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final statusTitleRow = Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusTitle,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: statusColor),
                    ),
                  ),
                ],
              );
              final applyButton = IdocUi.fit(AppButton(
                label: l.poRecApplyExtractedToTablesButton,
                icon: Icons.playlist_add_check,
                variant: AppButtonVariant.success,
                onPressed: _applyExtractedDataToTables,
              ));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  statusTitleRow,
                  const SizedBox(height: 10),
                  applyButton,
                ],
              );
            },
          ),
          const Divider(height: 20),
          Text(l.poRecHeaderComplianceChecksTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryOf(context))),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: density.tableHeadingHeight,
              dataRowMinHeight: density.tableRowHeight - 4,
              dataRowMaxHeight: density.tableRowHeight + 6,
              columnSpacing: density.byDensity<double>(20, 16, 12),
              horizontalMargin: density.byDensity<double>(16, 12, 8),
              columns: [
                DataColumn(label: Text(l.poRecColCheckItem)),
                DataColumn(label: Text(context.l10n.idocAColSystemValueInvoice)),
                DataColumn(label: Text(context.l10n.idocAColSystemValuePacking)),
                DataColumn(label: Text(context.l10n.idocAColUploadedValueInvoice)),
                DataColumn(label: Text(context.l10n.idocAColUploadedValuePacking)),
                DataColumn(label: Text(l.poRecColMatchStatus)),
                DataColumn(label: Text(l.poRecColDetails)),
              ],
              rows: headerDiscrepancies.map((d) {
                // Coded details / structured values render in the user's language; legacy rows keep their text.
                final map = CodedItemText.localizeRow(d as Map, l);
                final status = map['status'] as String? ?? 'MATCH';
                final fieldName = map['field_name'] as String? ?? '';
                final fieldNameAr = map['field_name_ar'] as String? ?? '';
                final localizedFieldName = _getLocalizedCheckField(context, fieldName, fieldNameAr);
                final systemVal = map['system_value']?.toString() ?? '—';
                final extractedVal = map['extracted_value']?.toString() ?? '—';
                final rawMsg = (map['message'] ?? map['details'])?.toString();
                final localizedMsg = _getLocalizedCheckMessage(context, fieldName, status, rawMsg);
                final localizedStatus = _getLocalizedSessionStatus(context, status);
                final rowSummary = [localizedFieldName, systemVal, extractedVal, localizedStatus, localizedMsg].join('\t');

                // Extract 4-way values (fall back to system_value / extracted_value for backwards compatibility)
                final sysInvVal = (map['system_invoice_value'] ?? map['system_value'] ?? '—').toString();
                final sysPlVal  = (map['system_packing_value']  ?? map['system_value'] ?? '—').toString();
                final uplInvVal = (map['uploaded_invoice_value'] ?? map['extracted_value'] ?? '—').toString();
                final uplPlVal  = (map['uploaded_packing_value']  ?? map['extracted_value'] ?? '—').toString();

                return DataRow(cells: [
                  DataCell(CopyableTableCell(value: localizedFieldName, rowSummary: rowSummary, child: Text(localizedFieldName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)))),
                  DataCell(CopyableTableCell(value: sysInvVal, rowSummary: rowSummary, child: Text(sysInvVal, style: TextStyle(color: AppTheme.textPrimaryOf(context), fontSize: 12)))),
                  DataCell(CopyableTableCell(value: sysPlVal,  rowSummary: rowSummary, child: Text(sysPlVal,  style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 12)))),
                  DataCell(CopyableTableCell(value: uplInvVal, rowSummary: rowSummary, child: Text(uplInvVal, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt)))),
                  DataCell(CopyableTableCell(value: uplPlVal,  rowSummary: rowSummary, child: Text(uplPlVal,  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt)))),
                  DataCell(CopyableTableCell(value: localizedStatus, rowSummary: rowSummary, child: _buildMatchStatusBadge(status))),
                  DataCell(CopyableTableCell(value: localizedMsg, rowSummary: rowSummary, child: Text(localizedMsg, style: TextStyle(fontSize: 12, color: status == 'MATCH' ? AppTheme.severityForegroundOf(context, AppSeverity.success) : AppTheme.severityForegroundOf(context, AppSeverity.danger))))),
                ]);
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text(l.poRecExtractedDocMetadataTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryOf(context))),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final pills = [
                _buildExtractedPill(l.poRecExtractedInvNo, invData['invoice_number']?.toString() ?? '—', Icons.receipt_long, isDark),
                _buildExtractedPill(l.poRecExtractedInvAmount, '${invData['total_amount'] ?? "—"} ${invData['currency'] ?? ""}', Icons.monetization_on, isDark),
                _buildExtractedPill(l.poRecExtractedAcid, plData['acid_number']?.toString() ?? invData['acid_number']?.toString() ?? '—', Icons.tag, isDark),
                _buildExtractedPill(l.poRecExtractedPackagesWeight, '${plData['total_packages'] ?? "—"} ${l.poRecPackagesUnit} - ${plData['total_gross_weight_kg'] ?? "—"} ${l.poRecKgUnit}', Icons.inventory_2, isDark),
              ];
              if (constraints.maxWidth >= 750) {
                return Row(
                  children: pills.map((p) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: p))).toList(),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pills.map((p) => SizedBox(
                  width: constraints.maxWidth > 400 ? (constraints.maxWidth - 8) / 2 : constraints.maxWidth,
                  child: p,
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMatchStatusBadge(String status) {
    final l = context.l10n;
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'MATCH':
        bg = AppTheme.severityBackgroundOf(context, AppSeverity.success);
        fg = AppTheme.severityForegroundOf(context, AppSeverity.success);
        label = l.poRecMatchStatusMatched;
        break;
      case 'WARNING':
        bg = AppTheme.severityBackgroundOf(context, AppSeverity.warning);
        fg = AppTheme.severityForegroundOf(context, AppSeverity.warning);
        label = l.poRecMatchStatusWarning;
        break;
      case 'CRITICAL':
      default:
        bg = AppTheme.severityBackgroundOf(context, AppSeverity.danger);
        fg = AppTheme.severityForegroundOf(context, AppSeverity.danger);
        label = l.poRecMatchStatusCritical;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildExtractedPill(String label, String value, IconData icon, [bool isDark = false]) {
    const pillBg = AppTheme.white;
    final pillBorder = AppTheme.borderOf(context);
    final labelColor = AppTheme.textSecondaryOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: pillBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.cobalt),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: labelColor)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
