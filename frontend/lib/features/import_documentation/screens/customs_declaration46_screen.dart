import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../freight_booking/providers/freight_booking_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../providers/import_documentation_provider.dart';
import '../widgets/search_and_clone_customs_declaration46_dialog.dart';

class CustomsDeclarationAssessment {
  final String declarationNo;
  final String importFileCode;
  final String primaryNameWithCode;
  final String supplierName;
  final String companyName;
  final String acidNumber;
  final String form4Number;
  final String blNumber;
  final String hsCode;
  final String hsDescription;
  final double fobForeign;
  final String currency;
  final double exchangeRate;
  final double fobEgp;
  final double freightEgp;
  final double insuranceEgp;
  final double cifEgp;
  final double dutyRate;
  final double importDutyEgp;
  final double devRate;
  final double devFeeEgp;
  final double serviceRate;
  final double serviceFeeEgp;
  final double otherFeesEgp;
  final double vatRate;
  final double vatBaseEgp;
  final double vatEgp;
  final double totalDutiesEgp;
  final bool hasExemption;
  final String exemptionTitle;
  final String registrationDate;
  final String status;

  const CustomsDeclarationAssessment({
    required this.declarationNo,
    required this.importFileCode,
    required this.primaryNameWithCode,
    required this.supplierName,
    required this.companyName,
    required this.acidNumber,
    required this.form4Number,
    required this.blNumber,
    required this.hsCode,
    required this.hsDescription,
    required this.fobForeign,
    required this.currency,
    required this.exchangeRate,
    required this.fobEgp,
    required this.freightEgp,
    required this.insuranceEgp,
    required this.cifEgp,
    required this.dutyRate,
    required this.importDutyEgp,
    required this.devRate,
    required this.devFeeEgp,
    required this.serviceRate,
    required this.serviceFeeEgp,
    required this.otherFeesEgp,
    required this.vatRate,
    required this.vatBaseEgp,
    required this.vatEgp,
    required this.totalDutiesEgp,
    required this.hasExemption,
    required this.exemptionTitle,
    required this.registrationDate,
    required this.status,
  });
}

class CustomsDeclaration46Screen extends ConsumerStatefulWidget {
  final int initialSubTab;
  final int? initialImportFileId;

  const CustomsDeclaration46Screen({
    super.key,
    this.initialSubTab = 0,
    this.initialImportFileId,
  });

  @override
  ConsumerState<CustomsDeclaration46Screen> createState() => _CustomsDeclaration46ScreenState();
}

class _CustomsDeclaration46ScreenState extends ConsumerState<CustomsDeclaration46Screen> {
  // Active Vertical Sub-Tab:
  // 0: Initial Declaration 46 Registration
  // 1: Declaration 46 Registry & Tracking
  int _selectedSubTab = 0;
  int? _selectedImportFileId;

  final _declarationFormKey = GlobalKey<FormState>();
  final TextEditingController _declaration46NoCtrl = TextEditingController(text: '46-EG-2026-');
  final TextEditingController _acidNumberCtrl = TextEditingController();
  final TextEditingController _form4NumberCtrl = TextEditingController();
  final TextEditingController _blNumberCtrl = TextEditingController();
  final TextEditingController _customsValueEgpCtrl = TextEditingController(text: '0.00');
  final TextEditingController _importDutyEgpCtrl = TextEditingController(text: '0.00');
  final TextEditingController _vatEgpCtrl = TextEditingController(text: '0.00');
  final TextEditingController _otherFeesEgpCtrl = TextEditingController(text: '0.00');
  final TextEditingController _totalDutyAndTaxesCtrl = TextEditingController(text: '0.00');
  final TextEditingController _submissionDateCtrl = TextEditingController(text: DateTime.now().toString().substring(0, 10));
  final TextEditingController _notesCtrl = TextEditingController();

  // Compliance & HS Code Tariff States
  List<CustomsTariffModel> _matchedTariffs = [];
  bool _hasExemption = false;
  double _appliedDutyRate = 5.0;
  List<Map<String, dynamic>> _regulatoryApprovals = [];

  String _searchQuery = '';
  bool _isSavingDeclaration = false;

  @override
  void initState() {
    super.initState();
    _selectedSubTab = widget.initialSubTab;
    _selectedImportFileId = widget.initialImportFileId;
    Future.microtask(() {
      _refreshData();
      if (_selectedImportFileId != null) {
        _onImportFileSelected(_selectedImportFileId);
      }
    });
  }

  void _refreshData() {
    if (!ref.read(importFilesProvider).isLoading) {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    if (!ref.read(acidSessionsProvider).isLoading) {
      ref.read(acidSessionsProvider.notifier).fetchAcidSessions();
    }
    if (!ref.read(bankingDocumentsProvider).isLoading) {
      ref.read(bankingDocumentsProvider.notifier).fetchBankingDocuments();
    }
    if (!ref.read(customsTariffProvider).isLoading) {
      ref.read(customsTariffProvider.notifier).fetchTariffs();
    }
    if (!ref.read(purchaseOrdersProvider).isLoading) {
      ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
    }
    if (!ref.read(draftBLReviewsProvider).isLoading) {
      ref.read(draftBLReviewsProvider.notifier).fetchReviews();
    }
    if (!ref.read(freightBookingProvider).isLoading) {
      ref.read(freightBookingProvider.notifier).fetchBookings();
    }
  }

  @override
  void dispose() {
    _declaration46NoCtrl.dispose();
    _acidNumberCtrl.dispose();
    _form4NumberCtrl.dispose();
    _blNumberCtrl.dispose();
    _customsValueEgpCtrl.dispose();
    _importDutyEgpCtrl.dispose();
    _vatEgpCtrl.dispose();
    _otherFeesEgpCtrl.dispose();
    _totalDutyAndTaxesCtrl.dispose();
    _submissionDateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onImportFileSelected(int? fileId) {
    setState(() => _selectedImportFileId = fileId);
    if (fileId == null) {
      _acidNumberCtrl.clear();
      _form4NumberCtrl.clear();
      _blNumberCtrl.clear();
      _customsValueEgpCtrl.text = '0.00';
      _importDutyEgpCtrl.text = '0.00';
      _vatEgpCtrl.text = '0.00';
      _otherFeesEgpCtrl.text = '0.00';
      _totalDutyAndTaxesCtrl.text = '0.00';
      setState(() {
        _matchedTariffs = [];
        _regulatoryApprovals = [];
        _hasExemption = false;
        _appliedDutyRate = 5.0;
      });
      return;
    }

    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == fileId).firstOrNull;
    if (file == null) return;

    // 1. Auto load ACID number
    String acidVal = file.acidNumber ?? '';
    if (acidVal.isEmpty) {
      final acids = ref.read(acidSessionsProvider).valueOrNull ?? [];
      final matchedAcid = acids.where((a) => a.importFileId == fileId).firstOrNull;
      if (matchedAcid != null && matchedAcid.acidNumber.isNotEmpty) {
        acidVal = matchedAcid.acidNumber;
      }
    }
    _acidNumberCtrl.text = acidVal;

    // 2. Auto load Form 4 number
    String f4Val = file.form4No ?? '';
    if (f4Val.isEmpty) {
      final bankDocs = ref.read(bankingDocumentsProvider).valueOrNull ?? [];
      final matchedF4 = bankDocs.where((d) => d.importFileId == fileId && d.docType == 'Form 4').firstOrNull;
      if (matchedF4 != null && matchedF4.docReferenceNumber != 'PENDING' && matchedF4.docReferenceNumber.isNotEmpty) {
        f4Val = matchedF4.docReferenceNumber;
      }
    }
    if (f4Val.isEmpty) {
      f4Val = file.swiftNo != null && file.swiftNo!.isNotEmpty ? 'F4-${file.swiftNo}' : 'F4-ALX-${file.importFileCode}';
    }
    _form4NumberCtrl.text = f4Val;

    // 3. Auto load B/L number
    String blVal = '';
    final reviews = ref.read(draftBLReviewsProvider).valueOrNull ?? [];
    final linkedReview = reviews.where((r) => r.importFileId == fileId).firstOrNull;
    if (linkedReview != null) {
      final extractedBl = linkedReview.draftExtractedData?['draft_bl_number'] ??
          linkedReview.draftExtractedData?['bl_number'] ??
          linkedReview.systemDataSnapshot?['draft_bl_number'] ??
          linkedReview.draftBlNumber;
      if (extractedBl != null && extractedBl.toString().trim().isNotEmpty) {
        blVal = extractedBl.toString().trim();
      }
    }
    if (blVal.isEmpty) {
      final bookings = ref.read(freightBookingProvider).valueOrNull ?? [];
      final linkedBooking = bookings.where((b) => b.importFileId == fileId).firstOrNull;
      if (linkedBooking != null) {
        blVal = linkedBooking.bookingConfirmationNo ?? linkedBooking.bookingCode;
      }
    }
    if (blVal.isEmpty) {
      blVal = file.customFileNumber != null && file.customFileNumber!.isNotEmpty
          ? file.customFileNumber!
          : 'MEDUST-${file.importFileCode}';
    }
    _blNumberCtrl.text = blVal;

    _declaration46NoCtrl.text = '46-ALX-${file.importFileCode}';

    // 4. Extract HS Codes and calculate Customs Base & Duties (from Customs Duty Estimator logic)
    final allTariffs = ref.read(customsTariffProvider).valueOrNull ?? [];
    List<String> fileHsCodes = [];
    final poState = ref.read(purchaseOrdersProvider);
    final linkedPos = poState.purchaseOrders.where((p) => p.importFileId == fileId).toList();
    for (var po in linkedPos) {
      for (var item in po.items) {
        if (item.hsCode != null && item.hsCode!.trim().isNotEmpty) {
          fileHsCodes.add(item.hsCode!.trim());
        }
      }
    }
    if (fileHsCodes.isEmpty) {
      fileHsCodes = ['8471.30.00', '8517.62.00'];
    }

    final matched = allTariffs.where((t) => fileHsCodes.any((c) => t.hsCode.contains(c) || c.contains(t.hsCode))).toList();
    _matchedTariffs = matched.isNotEmpty ? matched : (allTariffs.isNotEmpty ? [allTariffs.first] : []);

    final primaryTariff = _matchedTariffs.isNotEmpty ? _matchedTariffs.first : null;
    final dutyRate = primaryTariff != null ? primaryTariff.customsDutyRate : 5.0;
    _appliedDutyRate = dutyRate;
    final vatRate = primaryTariff != null ? primaryTariff.vatRate : 14.0;
    final devRate = primaryTariff != null ? primaryTariff.developmentFeeRate : 0.0;
    final serviceRate = primaryTariff != null ? primaryTariff.customsServiceFeeRate : 1.0;

    // Calculate CIF in EGP
    const exchangeRate = 50.7917;
    final fobForeign = file.estimatedCost > 0
        ? file.estimatedCost
        : (file.invoicesData.isNotEmpty
            ? file.invoicesData.fold<double>(0.0, (sum, i) => sum + i.amount)
            : 12500.0);
    final fobEgp = fobForeign * exchangeRate;
    final freightEgp = fobEgp * 0.02; // 2% freight base
    final insuranceEgp = fobEgp * 0.025; // 2.5% deemed insurance
    final cifEgp = fobEgp + freightEgp + insuranceEgp;

    // Calculate Duty and Taxes
    final importDutyEgp = cifEgp * (dutyRate / 100.0);
    final devFeeEgp = cifEgp * (devRate / 100.0);
    final serviceFeeEgp = cifEgp * (serviceRate / 100.0);
    final otherFeesEgp = devFeeEgp + serviceFeeEgp;
    final vatBaseEgp = cifEgp + importDutyEgp + otherFeesEgp;
    final vatEgp = vatBaseEgp * (vatRate / 100.0);
    final totalDutiesEgp = importDutyEgp + vatEgp + otherFeesEgp;

    _customsValueEgpCtrl.text = cifEgp.toStringAsFixed(2);
    _importDutyEgpCtrl.text = importDutyEgp.toStringAsFixed(2);
    _vatEgpCtrl.text = vatEgp.toStringAsFixed(2);
    _otherFeesEgpCtrl.text = otherFeesEgp.toStringAsFixed(2);
    _totalDutyAndTaxesCtrl.text = totalDutiesEgp.toStringAsFixed(2);

    // 5. Exemption & Preferential Tariff Status
    final bool isEuropeanOrExempt = dutyRate == 0.0 || (file.portOfLoading != null && (file.portOfLoading!.contains('IT') || file.portOfLoading!.contains('FR') || file.portOfLoading!.contains('DE') || file.portOfLoading!.contains('ES')));
    _hasExemption = isEuropeanOrExempt;

    // 6. Regulatory Approvals & Inspections Board
    _regulatoryApprovals = [];
    for (var t in _matchedTariffs) {
      _regulatoryApprovals.add({
        'hs_code': t.hsCode,
        'description': t.hsDescription,
        'authority': t.regulatoryAuthority,
        'requires_inspection': t.requiresInspection,
        'requires_coo': t.requiresCoo,
        'requires_acid': t.requiresAcid,
        'note': t.priorApprovalNote,
        'status': 'APPROVED',
      });
    }

    if (_regulatoryApprovals.isEmpty) {
      _regulatoryApprovals.add({
        'hs_code': fileHsCodes.first,
        'description': null,
        'authority': null,
        'requires_inspection': true,
        'requires_coo': true,
        'requires_acid': true,
        'note': null,
        'status': 'APPROVED',
      });
    }

    setState(() {});
  }

  void _calculateTotalDuties() {
    final duty = double.tryParse(_importDutyEgpCtrl.text) ?? 0.0;
    final vat = double.tryParse(_vatEgpCtrl.text) ?? 0.0;
    final other = double.tryParse(_otherFeesEgpCtrl.text) ?? 0.0;
    final total = duty + vat + other;
    _totalDutyAndTaxesCtrl.text = total.toStringAsFixed(2);
  }

  Future<void> _openSearchAndCloneDialog() async {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final acids = ref.read(acidSessionsProvider).valueOrNull ?? [];
    final bankDocs = ref.read(bankingDocumentsProvider).valueOrNull ?? [];
    final reviews = ref.read(draftBLReviewsProvider).valueOrNull ?? [];
    final bookings = ref.read(freightBookingProvider).valueOrNull ?? [];
    final tariffs = ref.read(customsTariffProvider).valueOrNull ?? [];
    final pos = ref.read(purchaseOrdersProvider).purchaseOrders;

    final assessments = files.map((f) => _calculateAssessment(
      f,
      context.l10n,
      cachedAcids: acids,
      cachedBankDocs: bankDocs,
      cachedReviews: reviews,
      cachedBookings: bookings,
      cachedTariffs: tariffs,
      cachedPos: pos,
    )).toList();

    CustomsDeclarationAssessment? selected;
    await showDialog(
      context: context,
      builder: (ctx) => SearchAndCloneCustomsDeclaration46Dialog(
        assessments: assessments,
        onSelectDeclaration: (decl) {
          selected = decl;
        },
      ),
    );

    if (selected != null && mounted) {
      _onCloneDeclarationSelected(selected!);
    }
  }

  void _onCloneDeclarationSelected(CustomsDeclarationAssessment a) {
    final isAr = context.l10n.isArabic;

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isAr ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: CloneEntityReviewDialog(
            entityType: isAr
                ? 'إقرار جمركي مبدئي شهادة 46 (Customs Declaration 46)'
                : 'Initial Customs Declaration 46',
            sourceCode: a.declarationNo,
            sourceTitle: '${a.primaryNameWithCode} — ${a.supplierName}',
            suggestedNewCode: '46-DRAFT-${a.importFileCode}',
            copiedFieldsSummary: {
              isAr ? 'ملف الشحنة' : 'Import File': a.primaryNameWithCode,
              isAr ? 'المورد الأجنبي' : 'Supplier': a.supplierName,
              isAr ? 'الشركة المستوردة' : 'Company': a.companyName,
              isAr ? 'بند التعريفة الجمركية' : 'HS Code': '${a.hsCode} (${a.hsDescription})',
              isAr ? 'القيمة للأغراض الجمركية CIF' : 'Customs CIF Base': '${a.cifEgp.toStringAsFixed(2)} EGP',
              isAr ? 'إجمالي الضرائب والرسوم المقدرة' : 'Estimated Total Duties': '${a.totalDutiesEgp.toStringAsFixed(2)} EGP',
              isAr ? 'موقف الإعفاء والاتفاقية' : 'Exemption Status': a.exemptionTitle,
            },
            mandatorilyResetFields: isAr
                ? const [
                    'رقم الإقرار الجمركي: يتم تصفيره وتعيينه كمسودة جديدة (Draft)',
                    'تاريخ القيد المبدئي: يعاد ضبطه تلقائياً إلى تاريخ اليوم',
                    'حالة الشهادة والإفراج: تعاد إلى قيد الإعداد المبدئي (Draft)',
                    'أرقام السداد الإلكتروني وإيصالات نافذة: تم فك الارتباط',
                  ]
                : const [
                    'Declaration No: Reset to a new draft code (Draft)',
                    'Registration Date: Auto-reset to current date',
                    'Customs Release Status: Reset to Draft / Unreleased',
                    'Payment & Receipt References: Cleared and unlinked',
                  ],
            allowCopyLineItems: false,
            allowCopyAttachments: false,
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              final files = ref.read(importFilesProvider).valueOrNull ?? [];
              final matchedFile = files.where((f) => f.importFileCode == a.importFileCode).firstOrNull;

              setState(() {
                _selectedSubTab = 0;
                if (matchedFile != null) {
                  _selectedImportFileId = matchedFile.importFileId;
                }
                _declaration46NoCtrl.text = newCode;
                _submissionDateCtrl.text = DateTime.now().toString().substring(0, 10);
                _acidNumberCtrl.text = a.acidNumber;
                _form4NumberCtrl.text = a.form4Number;
                _blNumberCtrl.text = a.blNumber;
                _customsValueEgpCtrl.text = a.cifEgp.toStringAsFixed(2);
                _importDutyEgpCtrl.text = a.importDutyEgp.toStringAsFixed(2);
                _vatEgpCtrl.text = a.vatEgp.toStringAsFixed(2);
                _otherFeesEgpCtrl.text = a.otherFeesEgp.toStringAsFixed(2);
                _totalDutyAndTaxesCtrl.text = a.totalDutiesEgp.toStringAsFixed(2);
                _appliedDutyRate = a.dutyRate;
                _hasExemption = a.hasExemption;
                _notesCtrl.text = (notes != null && notes.isNotEmpty)
                    ? notes
                    : '(مستنسخ كمسودة من الإقرار ${a.declarationNo})';
                _regulatoryApprovals = [
                  {
                    'hs_code': a.hsCode,
                    'description': a.hsDescription,
                    'authority': null,
                    'requires_inspection': true,
                    'requires_coo': true,
                    'requires_acid': true,
                    'note': null,
                    'status': 'APPROVED',
                  }
                ];
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.cloneCustomsDeclSuccess),
                    backgroundColor: AppTheme.wcagEmerald,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  void _copyApprovalRow(Map<String, dynamic> appr, AppLocalizations l) {
    final String hsCode = appr['hs_code'] ?? '-';
    final String authorityText = (appr['authority'] != null && appr['authority'].toString().trim().isNotEmpty)
        ? appr['authority'].toString()
        : l.customsDeclDefaultAuthority;
    final String inspectionText = appr['requires_inspection'] == true ? l.customsDeclColInspection : '-';
    final String cooText = appr['requires_coo'] == true ? l.customsDeclColCoo : '-';
    final String noteText = (appr['note'] != null && appr['note'].toString().trim().isNotEmpty)
        ? appr['note'].toString()
        : (appr['requires_inspection'] == true ? l.customsDeclDefaultNote : l.customsDeclVisualInspectionNote);
    final String statusText = l.customsDeclStatusFulfilled;

    final headers = [
      l.customsDeclColHsCode,
      l.customsDeclColAuthority,
      l.customsDeclColInspection,
      l.customsDeclColCoo,
      l.customsDeclColRequirements,
      l.customsDeclColApprovalStatus,
    ];
    final values = [hsCode, authorityText, inspectionText, cooText, noteText, statusText];
    TableCopyHelper.copyRow(context, values, headers: headers);
  }

  void _copyApprovalTable(AppLocalizations l) {
    final headers = [
      l.customsDeclColHsCode,
      l.customsDeclColAuthority,
      l.customsDeclColInspection,
      l.customsDeclColCoo,
      l.customsDeclColRequirements,
      l.customsDeclColApprovalStatus,
    ];
    final rows = _regulatoryApprovals.map((appr) {
      final String hsCode = appr['hs_code'] ?? '-';
      final String authorityText = (appr['authority'] != null && appr['authority'].toString().trim().isNotEmpty)
          ? appr['authority'].toString()
          : l.customsDeclDefaultAuthority;
      final String inspectionText = appr['requires_inspection'] == true ? l.customsDeclColInspection : '-';
      final String cooText = appr['requires_coo'] == true ? l.customsDeclColCoo : '-';
      final String noteText = (appr['note'] != null && appr['note'].toString().trim().isNotEmpty)
          ? appr['note'].toString()
          : (appr['requires_inspection'] == true ? l.customsDeclDefaultNote : l.customsDeclVisualInspectionNote);
      final String statusText = l.customsDeclStatusFulfilled;
      return [hsCode, authorityText, inspectionText, cooText, noteText, statusText];
    }).toList();

    TableCopyHelper.copyTable(context, headers, rows);
  }

  Future<void> _exportApprovalsToExcel(AppLocalizations l) async {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;
    final fileCode = file?.importFileCode ?? 'DRAFT';

    final headers = [
      l.customsDeclColHsCode,
      l.customsDeclColAuthority,
      l.customsDeclColInspection,
      l.customsDeclColCoo,
      l.customsDeclColRequirements,
      l.customsDeclColApprovalStatus,
    ];
    final rows = _regulatoryApprovals.map((appr) {
      final String hsCode = appr['hs_code'] ?? '-';
      final String authorityText = (appr['authority'] != null && appr['authority'].toString().trim().isNotEmpty)
          ? appr['authority'].toString()
          : l.customsDeclDefaultAuthority;
      final String inspectionText = appr['requires_inspection'] == true ? l.customsDeclColInspection : '-';
      final String cooText = appr['requires_coo'] == true ? l.customsDeclColCoo : '-';
      final String noteText = (appr['note'] != null && appr['note'].toString().trim().isNotEmpty)
          ? appr['note'].toString()
          : (appr['requires_inspection'] == true ? l.customsDeclDefaultNote : l.customsDeclVisualInspectionNote);
      final String statusText = l.customsDeclStatusFulfilled;
      return [hsCode, authorityText, inspectionText, cooText, noteText, statusText];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'Customs Regulatory Approvals',
      importFileNameOrCode: fileCode,
    );
  }

  Future<void> _exportApprovalsToPdf(AppLocalizations l) async {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;
    final fileCode = file?.importFileCode ?? 'DRAFT';

    final headers = [
      l.customsDeclColHsCode,
      l.customsDeclColAuthority,
      l.customsDeclColInspection,
      l.customsDeclColCoo,
      l.customsDeclColApprovalStatus,
    ];
    final rows = _regulatoryApprovals.map((appr) {
      final String hsCode = appr['hs_code'] ?? '-';
      final String authorityText = (appr['authority'] != null && appr['authority'].toString().trim().isNotEmpty)
          ? appr['authority'].toString()
          : l.customsDeclDefaultAuthority;
      final String inspectionText = appr['requires_inspection'] == true ? l.customsDeclColInspection : '-';
      final String cooText = appr['requires_coo'] == true ? l.customsDeclColCoo : '-';
      final String statusText = l.customsDeclStatusFulfilled;
      return [hsCode, authorityText, inspectionText, cooText, statusText];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'Customs Regulatory Approvals',
      importFileNameOrCode: fileCode,
      headerContext: TableExportHeaderContext(
        title: l.customsDeclRegulatoryHeader,
        subtitle: 'Declaration 46: ${_declaration46NoCtrl.text} — Import File: $fileCode',
        metadata: {
          l.customsDeclColDeclarationNo: _declaration46NoCtrl.text,
          l.customsDeclColFileNumber: fileCode,
          l.customsDeclSubmissionDateLabel.replaceAll('*', '').trim(): _submissionDateCtrl.text,
          l.customsDeclColSupplier: file?.supplierName ?? '-',
        },
      ),
    );
  }

  Widget _buildCustomsValueField(AppLocalizations l) {
    return TextFormField(
      key: const Key('decl46CifField'),
      controller: _customsValueEgpCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: l.customsDeclCifValueLabel,
        prefixIcon: const Icon(Icons.monetization_on),
        suffixIcon: IconButton(
          icon: const Icon(Icons.copy, size: 16),
          tooltip: l.customsDeclCopyValueTooltip,
          onPressed: () => CopyHelper.copy(context, _customsValueEgpCtrl.text),
        ),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildImportDutyField(AppLocalizations l) {
    return TextFormField(
      key: const Key('decl46DutyField'),
      controller: _importDutyEgpCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: l.customsDeclImportDutyLabel,
        suffixIcon: IconButton(
          icon: const Icon(Icons.copy, size: 16),
          tooltip: l.customsDeclCopyValueTooltip,
          onPressed: () => CopyHelper.copy(context, _importDutyEgpCtrl.text),
        ),
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => _calculateTotalDuties(),
    );
  }

  Widget _buildVatField(AppLocalizations l) {
    return TextFormField(
      key: const Key('decl46VatField'),
      controller: _vatEgpCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: l.customsDeclVatLabel,
        suffixIcon: IconButton(
          icon: const Icon(Icons.copy, size: 16),
          tooltip: l.customsDeclCopyValueTooltip,
          onPressed: () => CopyHelper.copy(context, _vatEgpCtrl.text),
        ),
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => _calculateTotalDuties(),
    );
  }

  Widget _buildTotalDutiesField(AppLocalizations l, bool isDark) {
    return TextFormField(
      key: const Key('decl46TotalDutiesField'),
      controller: _totalDutyAndTaxesCtrl,
      readOnly: true,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: isDark ? const Color(0xFFF87171) : AppTheme.crimson,
      ),
      decoration: InputDecoration(
        labelText: l.customsDeclTotalDutiesLabel,
        suffixIcon: IconButton(
          icon: const Icon(Icons.copy, size: 16),
          tooltip: l.customsDeclCopyValueTooltip,
          onPressed: () => CopyHelper.copy(context, _totalDutyAndTaxesCtrl.text),
        ),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final density = ref.watch(displayDensityProvider);

    final tabs = [
      const VerticalNavTabItem(
        icon: Icons.assignment_outlined,
        titleEn: 'Initial Declaration 46 Form',
        titleAr: 'قيد الإقرار الجمركي المبدئي',
      ),
      const VerticalNavTabItem(
        icon: Icons.history_edu_outlined,
        titleEn: 'Declaration 46 Registry',
        titleAr: 'سجل شهادات 46 ومتابعتها',
      ),
    ];

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): _openSearchAndCloneDialog,
      },
      child: Focus(
        autofocus: true,
        child: VerticalStageScaffold(
          stageCode: 'PHASE-5: STEP_13',
          titleEn: 'Customs Declaration 46 Registration',
          titleAr: 'الإقرار الجمركي المبدئي وشهادة 46 ك.م',
          headerIcon: Icons.description_outlined,
          headerColor: AppTheme.cobalt,
          tabs: tabs,
          selectedIndex: _selectedSubTab,
          onTabSelected: (index) => setState(() => _selectedSubTab = index),
          selectedImportFileId: _selectedImportFileId,
          onShipmentStatusChanged: _refreshData,
          headerActions: [
            IconButton(
              key: const Key('searchAndCloneDeclHeaderBtn'),
              icon: Icon(Icons.copy_all, color: Colors.white70, size: density.buttonIconSize),
              tooltip: l.searchAndCloneCustomsDeclBtn,
              onPressed: _openSearchAndCloneDialog,
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white70, size: density.buttonIconSize),
              tooltip: l.customsDeclRefreshTooltip,
              onPressed: _refreshData,
            ),
          ],
          body: SelectionArea(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 92),
              child: _selectedSubTab == 0 ? _buildInitialDeclarationView(l) : _buildDeclarationRegistryView(l),
            ),
          ),
        ),
      ),
    );
  }

  // --- SUB-VIEW 0: INITIAL DECLARATION FORM ---
  Widget _buildInitialDeclarationView(AppLocalizations l) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String exemptionTitle = _hasExemption
        ? l.customsDeclEur1ExemptionTitle
        : l.customsDeclMfnExemptionTitle(_appliedDutyRate.toStringAsFixed(1));

    final List<String> exemptionConditions = _hasExemption
        ? [
            l.customsDeclEur1Condition1,
            l.customsDeclEur1Condition2,
            l.customsDeclEur1Condition3,
          ]
        : [
            l.customsDeclMfnCondition1,
            l.customsDeclMfnCondition2,
          ];

    return Form(
      key: _declarationFormKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1000;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action Header Bar
              constraints.maxWidth < 650
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l.customsDeclTabInitialForm,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: OutlinedButton.icon(
                            key: const Key('subtab0SearchAndCloneBtn'),
                            icon: const Icon(Icons.copy_all, size: 16),
                            label: Text(l.searchAndCloneCustomsDeclBtn),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.wcagCobalt,
                              side: const BorderSide(color: AppTheme.wcagCobalt),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            onPressed: _openSearchAndCloneDialog,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            l.customsDeclTabInitialForm,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          key: const Key('subtab0SearchAndCloneBtn'),
                          icon: const Icon(Icons.copy_all, size: 16),
                          label: Text(l.searchAndCloneCustomsDeclBtn),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.wcagCobalt,
                            side: const BorderSide(color: AppTheme.wcagCobalt),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onPressed: _openSearchAndCloneDialog,
                        ),
                      ],
                    ),
              const SizedBox(height: 14),

              // Informational Alert
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1B4B) : Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF4338CA) : Colors.indigo.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_outlined, color: isDark ? const Color(0xFF818CF8) : Colors.indigo, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l.customsDeclInfoBanner,
                        style: TextStyle(
                          color: isDark ? const Color(0xFFE0E7FF) : Colors.indigo.shade900,
                          fontSize: DisplayDensityMode.clampFontSize(13.0),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // File Selector
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                ),
                child: SearchableDropdownField<int>(
                  labelText: l.customsDeclSelectFileLabel,
                  hintText: l.customsDeclSearchFileHint,
                  value: _selectedImportFileId,
                  isRequired: true,
                  items: importFiles.map((f) => SearchableDropdownItem<int>(
                    value: f.importFileId,
                    label: '${f.primaryNameWithCode} — ${f.supplierName} (${f.companyName})',
                  )).toList(),
                  onChanged: _onImportFileSelected,
                ),
              ),
              const SizedBox(height: 20),

              // Form Fields Card 1: Declaration Attributes
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.customsDeclAttributesHeader,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                      ),
                    ),
                    Divider(height: 24, color: isDark ? const Color(0xFF334155) : null),
                    isMobile
                        ? Column(
                            children: [
                              TextFormField(
                                key: const Key('decl46NoField'),
                                controller: _declaration46NoCtrl,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF818CF8) : Colors.indigo,
                                ),
                                decoration: InputDecoration(
                                  labelText: l.customsDeclDeclarationNoLabel,
                                  prefixIcon: Icon(Icons.pin, color: isDark ? const Color(0xFF818CF8) : Colors.indigo),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy, size: 16),
                                    tooltip: l.customsDeclCopyValueTooltip,
                                    onPressed: () => CopyHelper.copy(context, _declaration46NoCtrl.text),
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? l.customsDeclRequiredField : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                key: const Key('decl46DateField'),
                                controller: _submissionDateCtrl,
                                decoration: InputDecoration(
                                  labelText: l.customsDeclSubmissionDateLabel,
                                  prefixIcon: const Icon(Icons.calendar_today),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy, size: 16),
                                    tooltip: l.customsDeclCopyValueTooltip,
                                    onPressed: () => CopyHelper.copy(context, _submissionDateCtrl.text),
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  key: const Key('decl46NoField'),
                                  controller: _declaration46NoCtrl,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFF818CF8) : Colors.indigo,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: l.customsDeclDeclarationNoLabel,
                                    prefixIcon: Icon(Icons.pin, color: isDark ? const Color(0xFF818CF8) : Colors.indigo),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      tooltip: l.customsDeclCopyValueTooltip,
                                      onPressed: () => CopyHelper.copy(context, _declaration46NoCtrl.text),
                                    ),
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (val) => val == null || val.trim().isEmpty ? l.customsDeclRequiredField : null,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextFormField(
                                  key: const Key('decl46DateField'),
                                  controller: _submissionDateCtrl,
                                  decoration: InputDecoration(
                                    labelText: l.customsDeclSubmissionDateLabel,
                                    prefixIcon: const Icon(Icons.calendar_today),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      tooltip: l.customsDeclCopyValueTooltip,
                                      onPressed: () => CopyHelper.copy(context, _submissionDateCtrl.text),
                                    ),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 16),
                    constraints.maxWidth < 768
                        ? Column(
                            children: [
                              TextFormField(
                                key: const Key('decl46AcidField'),
                                controller: _acidNumberCtrl,
                                textDirection: TextDirection.ltr,
                                decoration: InputDecoration(
                                  labelText: l.customsDeclAcidNumberLabel,
                                  prefixIcon: const Icon(Icons.qr_code),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy, size: 16),
                                    tooltip: l.customsDeclCopyValueTooltip,
                                    onPressed: () => CopyHelper.copy(context, _acidNumberCtrl.text),
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                key: const Key('decl46Form4Field'),
                                controller: _form4NumberCtrl,
                                decoration: InputDecoration(
                                  labelText: l.customsDeclForm4NumberLabel,
                                  prefixIcon: const Icon(Icons.account_balance),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy, size: 16),
                                    tooltip: l.customsDeclCopyValueTooltip,
                                    onPressed: () => CopyHelper.copy(context, _form4NumberCtrl.text),
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                key: const Key('decl46BlField'),
                                controller: _blNumberCtrl,
                                textDirection: TextDirection.ltr,
                                decoration: InputDecoration(
                                  labelText: l.customsDeclBlNumberLabel,
                                  prefixIcon: const Icon(Icons.assignment),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy, size: 16),
                                    tooltip: l.customsDeclCopyValueTooltip,
                                    onPressed: () => CopyHelper.copy(context, _blNumberCtrl.text),
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  key: const Key('decl46AcidField'),
                                  controller: _acidNumberCtrl,
                                  textDirection: TextDirection.ltr,
                                  decoration: InputDecoration(
                                    labelText: l.customsDeclAcidNumberLabel,
                                    prefixIcon: const Icon(Icons.qr_code),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      tooltip: l.customsDeclCopyValueTooltip,
                                      onPressed: () => CopyHelper.copy(context, _acidNumberCtrl.text),
                                    ),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextFormField(
                                  key: const Key('decl46Form4Field'),
                                  controller: _form4NumberCtrl,
                                  decoration: InputDecoration(
                                    labelText: l.customsDeclForm4NumberLabel,
                                    prefixIcon: const Icon(Icons.account_balance),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      tooltip: l.customsDeclCopyValueTooltip,
                                      onPressed: () => CopyHelper.copy(context, _form4NumberCtrl.text),
                                    ),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextFormField(
                                  key: const Key('decl46BlField'),
                                  controller: _blNumberCtrl,
                                  textDirection: TextDirection.ltr,
                                  decoration: InputDecoration(
                                    labelText: l.customsDeclBlNumberLabel,
                                    prefixIcon: const Icon(Icons.assignment),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      tooltip: l.customsDeclCopyValueTooltip,
                                      onPressed: () => CopyHelper.copy(context, _blNumberCtrl.text),
                                    ),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 24),

                    Text(
                      l.customsDeclDutiesHeader,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF818CF8) : Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (isMobile)
                      Column(
                        children: [
                          _buildCustomsValueField(l),
                          const SizedBox(height: 14),
                          _buildImportDutyField(l),
                          const SizedBox(height: 14),
                          _buildVatField(l),
                          const SizedBox(height: 14),
                          _buildTotalDutiesField(l, isDark),
                        ],
                      )
                    else if (isTablet)
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildCustomsValueField(l)),
                              const SizedBox(width: 14),
                              Expanded(child: _buildImportDutyField(l)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _buildVatField(l)),
                              const SizedBox(width: 14),
                              Expanded(child: _buildTotalDutiesField(l, isDark)),
                            ],
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(child: _buildCustomsValueField(l)),
                          const SizedBox(width: 14),
                          Expanded(child: _buildImportDutyField(l)),
                          const SizedBox(width: 14),
                          Expanded(child: _buildVatField(l)),
                          const SizedBox(width: 14),
                          Expanded(child: _buildTotalDutiesField(l, isDark)),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Exemption & Trade Agreement Card
              if (_selectedImportFileId != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? (_hasExemption ? const Color(0xFF064E3B).withOpacity(0.35) : const Color(0xFF1E293B))
                        : (_hasExemption ? Colors.green.shade50 : Colors.blueGrey.shade50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? (_hasExemption ? const Color(0xFF059669) : const Color(0xFF475569))
                          : (_hasExemption ? Colors.green.shade400 : Colors.blueGrey.shade300),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _hasExemption ? Icons.verified : Icons.info_outline,
                            color: isDark
                                ? (_hasExemption ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1))
                                : (_hasExemption ? Colors.green.shade800 : Colors.blueGrey.shade800),
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l.customsDeclExemptionHeader,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark
                                    ? (_hasExemption ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1))
                                    : (_hasExemption ? Colors.green.shade900 : Colors.blueGrey.shade900),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? (_hasExemption ? const Color(0xFF047857) : const Color(0xFF334155))
                                : (_hasExemption ? Colors.green.shade300 : Colors.blueGrey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_offer,
                              size: 18,
                              color: _hasExemption ? AppTheme.flatEmerald : AppTheme.cobalt,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CopyableText(
                                exemptionTitle,
                                isSelectable: false,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark
                                      ? (_hasExemption ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1))
                                      : (_hasExemption ? Colors.green.shade900 : Colors.blueGrey.shade900),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l.customsDeclExemptionConditionsHeader,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: DisplayDensityMode.clampFontSize(12.5),
                          color: isDark
                              ? (_hasExemption ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1))
                              : (_hasExemption ? Colors.green.shade900 : Colors.blueGrey.shade800),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...exemptionConditions.map((cond) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                  color: _hasExemption ? AppTheme.flatEmerald : Colors.blueGrey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: CopyableText(
                                    cond,
                                    isSelectable: false,
                                    style: TextStyle(
                                      fontSize: DisplayDensityMode.clampFontSize(12.0),
                                      color: isDark ? const Color(0xFFCBD5E1) : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Regulatory Approvals, Inspections & Prior Approvals Card
              if (_regulatoryApprovals.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      constraints.maxWidth < 1050
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.policy_outlined, color: AppTheme.wcagCobalt, size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        l.customsDeclRegulatoryHeader,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    OutlinedButton.icon(
                                      key: const Key('copyRegulatoryTableTsvBtn'),
                                      icon: const Icon(Icons.copy_all, size: 15),
                                      label: Text(
                                        l.customsDeclExportTsvButton,
                                        style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(11.5)),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        foregroundColor: isDark ? const Color(0xFF38BDF8) : AppTheme.wcagCobalt,
                                        side: BorderSide(color: isDark ? const Color(0xFF38BDF8) : AppTheme.wcagCobalt),
                                      ),
                                      onPressed: () => _copyApprovalTable(l),
                                    ),
                                    OutlinedButton.icon(
                                      key: const Key('exportRegulatoryExcelBtn'),
                                      icon: const Icon(Icons.table_chart_outlined, size: 15),
                                      label: Text(
                                        l.exportExcelApprovalsTooltip,
                                        style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(11.5)),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        foregroundColor: AppTheme.flatEmerald,
                                        side: const BorderSide(color: AppTheme.flatEmerald),
                                      ),
                                      onPressed: () => _exportApprovalsToExcel(l),
                                    ),
                                    OutlinedButton.icon(
                                      key: const Key('exportRegulatoryPdfBtn'),
                                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                                      label: Text(
                                        l.exportPdfApprovalsTooltip,
                                        style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(11.5)),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        foregroundColor: isDark ? const Color(0xFFF87171) : AppTheme.crimson,
                                        side: BorderSide(color: isDark ? const Color(0xFFF87171) : AppTheme.crimson),
                                      ),
                                      onPressed: () => _exportApprovalsToPdf(l),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                const Icon(Icons.policy_outlined, color: AppTheme.wcagCobalt, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l.customsDeclRegulatoryHeader,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    OutlinedButton.icon(
                                      key: const Key('copyRegulatoryTableTsvBtn'),
                                      icon: const Icon(Icons.copy_all, size: 15),
                                      label: Text(
                                        l.customsDeclExportTsvButton,
                                        style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(11.5)),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        foregroundColor: isDark ? const Color(0xFF38BDF8) : AppTheme.wcagCobalt,
                                        side: BorderSide(color: isDark ? const Color(0xFF38BDF8) : AppTheme.wcagCobalt),
                                      ),
                                      onPressed: () => _copyApprovalTable(l),
                                    ),
                                    OutlinedButton.icon(
                                      key: const Key('exportRegulatoryExcelBtn'),
                                      icon: const Icon(Icons.table_chart_outlined, size: 15),
                                      label: Text(
                                        l.exportExcelApprovalsTooltip,
                                        style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(11.5)),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        foregroundColor: AppTheme.flatEmerald,
                                        side: const BorderSide(color: AppTheme.flatEmerald),
                                      ),
                                      onPressed: () => _exportApprovalsToExcel(l),
                                    ),
                                    OutlinedButton.icon(
                                      key: const Key('exportRegulatoryPdfBtn'),
                                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                                      label: Text(
                                        l.exportPdfApprovalsTooltip,
                                        style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(11.5)),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        foregroundColor: isDark ? const Color(0xFFF87171) : AppTheme.crimson,
                                        side: BorderSide(color: isDark ? const Color(0xFFF87171) : AppTheme.crimson),
                                      ),
                                      onPressed: () => _exportApprovalsToPdf(l),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                      Divider(height: 24, color: isDark ? const Color(0xFF334155) : null),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : Colors.grey.shade100),
                          columns: [
                            DataColumn(label: Text(l.customsDeclColHsCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.customsDeclColAuthority, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.customsDeclColInspection, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.customsDeclColCoo, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.customsDeclColRequirements, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.customsDeclColApprovalStatus, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.customsDeclColActions, style: const TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _regulatoryApprovals.map((appr) {
                            final String hsCode = appr['hs_code'] ?? '-';
                            final String authorityText = (appr['authority'] != null && appr['authority'].toString().trim().isNotEmpty)
                                ? appr['authority'].toString()
                                : l.customsDeclDefaultAuthority;
                            final String inspectionText = appr['requires_inspection'] == true ? l.customsDeclColInspection : '-';
                            final String cooText = appr['requires_coo'] == true ? l.customsDeclColCoo : '-';
                            final String noteText = (appr['note'] != null && appr['note'].toString().trim().isNotEmpty)
                                ? appr['note'].toString()
                                : (appr['requires_inspection'] == true ? l.customsDeclDefaultNote : l.customsDeclVisualInspectionNote);
                            final String statusText = l.customsDeclStatusFulfilled;
                            final String rowSummary = '$hsCode\t$authorityText\t$inspectionText\t$cooText\t$noteText\t$statusText';

                            return DataRow(
                              cells: [
                                DataCell(
                                  CopyableTableCell(
                                    value: hsCode,
                                    rowSummary: rowSummary,
                                    child: Text(
                                      hsCode,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFF818CF8) : AppTheme.cobalt,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  CopyableTableCell(
                                    value: authorityText,
                                    rowSummary: rowSummary,
                                    child: Text(
                                      authorityText,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFE2E8F0) : null,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  CopyableTableCell(
                                    value: inspectionText,
                                    rowSummary: rowSummary,
                                    child: Icon(
                                      appr['requires_inspection'] == true ? Icons.check_circle : Icons.remove_circle_outline,
                                      color: appr['requires_inspection'] == true ? Colors.amber.shade800 : Colors.grey,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  CopyableTableCell(
                                    value: cooText,
                                    rowSummary: rowSummary,
                                    child: Icon(
                                      appr['requires_coo'] == true ? Icons.check_circle : Icons.remove_circle_outline,
                                      color: appr['requires_coo'] == true ? AppTheme.flatEmerald : Colors.grey,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  CopyableTableCell(
                                    value: noteText,
                                    rowSummary: rowSummary,
                                    child: Text(
                                      noteText,
                                      style: TextStyle(
                                        fontSize: DisplayDensityMode.clampFontSize(12.0),
                                        color: isDark ? const Color(0xFFCBD5E1) : null,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  CopyableTableCell(
                                    value: statusText,
                                    rowSummary: rowSummary,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF064E3B) : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF059669) : Colors.green.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          fontSize: DisplayDensityMode.clampFontSize(11.0),
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? const Color(0xFFA7F3D0) : Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    key: Key('copyApprovalRowBtn_$hsCode'),
                                    icon: const Icon(Icons.copy_rounded, size: 17),
                                    tooltip: l.copyApprovalRowSuccess,
                                    color: isDark ? const Color(0xFF38BDF8) : AppTheme.wcagCobalt,
                                    onPressed: () => _copyApprovalRow(appr, l),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Action Buttons (Save, Preview Summary, Export TSV, Clone)
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    key: const Key('saveDeclaration46Btn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSavingDeclaration ? null : () => _saveDeclaration46(l),
                    icon: _isSavingDeclaration
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(
                      _isSavingDeclaration ? l.customsDeclSavingProgress : l.customsDeclSaveButton,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('printPreviewDeclaration46Btn'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      side: BorderSide(color: isDark ? const Color(0xFF818CF8) : Colors.indigo),
                      foregroundColor: isDark ? const Color(0xFF818CF8) : Colors.indigo,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(Icons.visibility_outlined, color: isDark ? const Color(0xFF818CF8) : Colors.indigo),
                    label: Text(
                      l.customsDeclPrintPreviewButton,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF818CF8) : Colors.indigo,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _showDeclarationSummaryDialog(l),
                  ),
                  OutlinedButton.icon(
                    key: const Key('exportDeclaration46TsvBtn'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      side: const BorderSide(color: AppTheme.flatEmerald),
                      foregroundColor: AppTheme.flatEmerald,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.table_chart_outlined, color: AppTheme.flatEmerald),
                    label: Text(
                      l.customsDeclExportTsvButton,
                      style: const TextStyle(color: AppTheme.flatEmerald, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _copyDeclarationAsTsv(l),
                  ),
                  OutlinedButton.icon(
                    key: const Key('bottomSearchAndCloneDeclBtn'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      side: const BorderSide(color: AppTheme.wcagCobalt),
                      foregroundColor: AppTheme.wcagCobalt,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.copy_all, color: AppTheme.wcagCobalt),
                    label: Text(
                      l.searchAndCloneCustomsDeclBtn,
                      style: const TextStyle(color: AppTheme.wcagCobalt, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _openSearchAndCloneDialog,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // --- SUB-VIEW 1: REGISTRY & TARIFF ASSESSMENT VIEW (SCREEN 24) ---
  CustomsDeclarationAssessment _calculateAssessment(
    dynamic file,
    AppLocalizations l, {
    List<dynamic>? cachedAcids,
    List<dynamic>? cachedBankDocs,
    List<dynamic>? cachedReviews,
    List<dynamic>? cachedBookings,
    List<CustomsTariffModel>? cachedTariffs,
    List<dynamic>? cachedPos,
  }) {
    final int fileId = file.importFileId;
    final String declNo = '46-ALX-${file.importFileCode}';

    // 1. ACID
    String acidVal = file.acidNumber ?? '';
    if (acidVal.isEmpty) {
      final acids = cachedAcids ?? ref.read(acidSessionsProvider).valueOrNull ?? [];
      final matchedAcid = acids.where((a) => a.importFileId == fileId).firstOrNull;
      if (matchedAcid != null && matchedAcid.acidNumber.isNotEmpty) {
        acidVal = matchedAcid.acidNumber;
      }
    }
    if (acidVal.isEmpty) acidVal = '46-ACID-${file.importFileCode}';

    // 2. Form 4
    String f4Val = file.form4No ?? '';
    if (f4Val.isEmpty) {
      final bankDocs = cachedBankDocs ?? ref.read(bankingDocumentsProvider).valueOrNull ?? [];
      final matchedF4 = bankDocs.where((d) => d.importFileId == fileId && d.docType == 'Form 4').firstOrNull;
      if (matchedF4 != null && matchedF4.docReferenceNumber != 'PENDING' && matchedF4.docReferenceNumber.isNotEmpty) {
        f4Val = matchedF4.docReferenceNumber;
      }
    }
    if (f4Val.isEmpty) {
      f4Val = file.swiftNo != null && file.swiftNo!.isNotEmpty ? 'F4-${file.swiftNo}' : 'F4-ALX-${file.importFileCode}';
    }

    // 3. B/L
    String blVal = '';
    final reviews = cachedReviews ?? ref.read(draftBLReviewsProvider).valueOrNull ?? [];
    final linkedReview = reviews.where((r) => r.importFileId == fileId).firstOrNull;
    if (linkedReview != null) {
      final extractedBl = linkedReview.draftExtractedData?['draft_bl_number'] ??
          linkedReview.draftExtractedData?['bl_number'] ??
          linkedReview.systemDataSnapshot?['draft_bl_number'] ??
          linkedReview.draftBlNumber;
      if (extractedBl != null && extractedBl.toString().trim().isNotEmpty) {
        blVal = extractedBl.toString().trim();
      }
    }
    if (blVal.isEmpty) {
      final bookings = cachedBookings ?? ref.read(freightBookingProvider).valueOrNull ?? [];
      final linkedBooking = bookings.where((b) => b.importFileId == fileId).firstOrNull;
      if (linkedBooking != null) {
        blVal = linkedBooking.bookingConfirmationNo ?? linkedBooking.bookingCode;
      }
    }
    if (blVal.isEmpty) {
      blVal = file.customFileNumber != null && file.customFileNumber!.isNotEmpty
          ? file.customFileNumber!
          : 'MEDUST-${file.importFileCode}';
    }

    // 4. HS Codes and Tariffs
    final allTariffs = cachedTariffs ?? ref.read(customsTariffProvider).valueOrNull ?? [];
    List<String> fileHsCodes = [];
    final linkedPos = (cachedPos != null)
        ? cachedPos.where((p) => p.importFileId == fileId).toList()
        : ref.read(purchaseOrdersProvider).purchaseOrders.where((p) => p.importFileId == fileId).toList();
    for (var po in linkedPos) {
      for (var item in po.items) {
        if (item.hsCode != null && item.hsCode!.trim().isNotEmpty) {
          fileHsCodes.add(item.hsCode!.trim());
        }
      }
    }
    if (fileHsCodes.isEmpty) {
      fileHsCodes = ['8471.30.00', '8517.62.00'];
    }

    final matched = allTariffs.where((t) => fileHsCodes.any((c) => t.hsCode.contains(c) || c.contains(t.hsCode))).toList();
    final primaryTariff = matched.isNotEmpty ? matched.first : (allTariffs.isNotEmpty ? allTariffs.first : null);

    final String hsCode = primaryTariff?.hsCode ?? fileHsCodes.first;
    final String hsDesc = primaryTariff?.hsDescription ?? l.customsDeclDefaultItemDesc;
    final double dutyRate = primaryTariff != null ? primaryTariff.customsDutyRate : 5.0;
    final double vatRate = primaryTariff != null ? primaryTariff.vatRate : 14.0;
    final double devRate = primaryTariff != null ? primaryTariff.developmentFeeRate : 0.0;
    final double serviceRate = primaryTariff != null ? primaryTariff.customsServiceFeeRate : 1.0;

    // CIF in EGP
    const exchangeRate = 50.7917;
    final double fobForeign = file.estimatedCost > 0
        ? file.estimatedCost
        : (file.invoicesData.isNotEmpty
            ? file.invoicesData.fold<double>(0.0, (sum, i) => sum + i.amount)
            : 12500.0);
    final String currency = (file.estimatedCostCurrency != null && file.estimatedCostCurrency.toString().trim().isNotEmpty)
        ? file.estimatedCostCurrency.toString()
        : 'USD';
    final double fobEgp = fobForeign * exchangeRate;
    final double freightEgp = fobEgp * 0.02;
    final double insuranceEgp = fobEgp * 0.025;
    final double cifEgp = fobEgp + freightEgp + insuranceEgp;

    // Duties & Taxes
    final double importDutyEgp = cifEgp * (dutyRate / 100.0);
    final double devFeeEgp = cifEgp * (devRate / 100.0);
    final double serviceFeeEgp = cifEgp * (serviceRate / 100.0);
    final double otherFeesEgp = devFeeEgp + serviceFeeEgp;
    final double vatBaseEgp = cifEgp + importDutyEgp + otherFeesEgp;
    final double vatEgp = vatBaseEgp * (vatRate / 100.0);
    final double totalDutiesEgp = importDutyEgp + vatEgp + otherFeesEgp;

    // Exemption
    final bool isEuropeanOrExempt = dutyRate == 0.0 ||
        (file.portOfLoading != null &&
            (file.portOfLoading!.contains('IT') ||
                file.portOfLoading!.contains('FR') ||
                file.portOfLoading!.contains('DE') ||
                file.portOfLoading!.contains('ES')));
    final String exemptionTitle = isEuropeanOrExempt
        ? l.customsDeclEur1ExemptionTitle
        : l.customsDeclMfnExemptionTitle(dutyRate.toStringAsFixed(1));

    return CustomsDeclarationAssessment(
      declarationNo: declNo,
      importFileCode: file.importFileCode,
      primaryNameWithCode: file.primaryNameWithCode,
      supplierName: file.supplierName,
      companyName: file.companyName,
      acidNumber: acidVal,
      form4Number: f4Val,
      blNumber: blVal,
      hsCode: hsCode,
      hsDescription: hsDesc,
      fobForeign: fobForeign,
      currency: currency,
      exchangeRate: exchangeRate,
      fobEgp: fobEgp,
      freightEgp: freightEgp,
      insuranceEgp: insuranceEgp,
      cifEgp: cifEgp,
      dutyRate: dutyRate,
      importDutyEgp: importDutyEgp,
      devRate: devRate,
      devFeeEgp: devFeeEgp,
      serviceRate: serviceRate,
      serviceFeeEgp: serviceFeeEgp,
      otherFeesEgp: otherFeesEgp,
      vatRate: vatRate,
      vatBaseEgp: vatBaseEgp,
      vatEgp: vatEgp,
      totalDutiesEgp: totalDutiesEgp,
      hasExemption: isEuropeanOrExempt,
      exemptionTitle: exemptionTitle,
      registrationDate: DateTime.now().toString().substring(0, 10),
      status: l.customsDeclStatusRegisteredNafeza,
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                CopyableText(
                  value,
                  isSelectable: false,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeclarationRegistryView(AppLocalizations l) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final acids = ref.watch(acidSessionsProvider).valueOrNull ?? [];
    final bankDocs = ref.watch(bankingDocumentsProvider).valueOrNull ?? [];
    final reviews = ref.watch(draftBLReviewsProvider).valueOrNull ?? [];
    final bookings = ref.watch(freightBookingProvider).valueOrNull ?? [];
    final allTariffs = ref.watch(customsTariffProvider).valueOrNull ?? [];
    final pos = ref.watch(purchaseOrdersProvider).purchaseOrders;

    final filtered = importFiles.where((f) {
      if (_searchQuery.isEmpty) return true;
      return f.importFileCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f.supplierName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f.primaryNameWithCode.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final assessments = filtered.map((f) => _calculateAssessment(
      f,
      l,
      cachedAcids: acids,
      cachedBankDocs: bankDocs,
      cachedReviews: reviews,
      cachedBookings: bookings,
      cachedTariffs: allTariffs,
      cachedPos: pos,
    )).toList();

    final totalCif = assessments.fold<double>(0.0, (sum, a) => sum + a.cifEgp);
    final totalDuties = assessments.fold<double>(0.0, (sum, a) => sum + a.totalDutiesEgp);
    final totalExemptions = assessments.where((a) => a.hasExemption).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Metrics Row (Task A Responsive & Task B Dark Mode)
        LayoutBuilder(
          builder: (context, constraints) {
            final card1 = _buildMetricCard(
              title: l.customsDeclMetricTotalDeclarations,
              value: assessments.length.toString(),
              icon: Icons.assignment_turned_in_outlined,
              color: Colors.indigo,
              isDark: isDark,
            );
            final card2 = _buildMetricCard(
              title: l.customsDeclMetricTotalCif,
              value: '${totalCif.toStringAsFixed(2)} EGP',
              icon: Icons.monetization_on_outlined,
              color: AppTheme.cobalt,
              isDark: isDark,
            );
            final card3 = _buildMetricCard(
              title: l.customsDeclMetricTotalDuties,
              value: '${totalDuties.toStringAsFixed(2)} EGP',
              icon: Icons.account_balance_wallet_outlined,
              color: AppTheme.crimson,
              isDark: isDark,
            );
            final card4 = _buildMetricCard(
              title: l.customsDeclMetricExemptions,
              value: totalExemptions.toString(),
              icon: Icons.verified_outlined,
              color: AppTheme.flatEmerald,
              isDark: isDark,
            );

            if (constraints.maxWidth < 650) {
              final halfWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(width: halfWidth, child: card1),
                  SizedBox(width: halfWidth, child: card2),
                  SizedBox(width: halfWidth, child: card3),
                  SizedBox(width: halfWidth, child: card4),
                ],
              );
            } else if (constraints.maxWidth < 950) {
              final halfWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: halfWidth, child: card1),
                  SizedBox(width: halfWidth, child: card2),
                  SizedBox(width: halfWidth, child: card3),
                  SizedBox(width: halfWidth, child: card4),
                ],
              );
            } else {
              return Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 12),
                  Expanded(child: card2),
                  const SizedBox(width: 12),
                  Expanded(child: card3),
                  const SizedBox(width: 12),
                  Expanded(child: card4),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 18),

        // Search and Actions Toolbar (Task A, Task J)
        LayoutBuilder(
          builder: (context, constraints) {
            final searchField = TextField(
              decoration: InputDecoration(
                hintText: l.customsDeclRegistrySearchHint,
                hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: TextStyle(color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)),
              onChanged: (val) => setState(() => _searchQuery = val),
            );

            final actionButtons = [
              OutlinedButton.icon(
                key: const Key('copyRegistryTableTsvBtn'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFF93C5FD) : AppTheme.cobalt,
                  side: BorderSide(color: isDark ? const Color(0xFF3B82F6) : AppTheme.cobalt),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _exportRegistryTsv(assessments, l),
                icon: const Icon(Icons.copy, size: 16),
                label: Text(l.customsDeclExportTsvButton, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                key: const Key('exportRegistryExcelBtn'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFF6EE7B7) : AppTheme.flatEmerald,
                  side: BorderSide(color: isDark ? const Color(0xFF10B981) : AppTheme.flatEmerald),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _exportRegistryExcel(assessments, l),
                icon: const Icon(Icons.table_view_outlined, size: 16),
                label: Text(l.exportRegistryExcelTooltip, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                key: const Key('exportRegistryPdfBtn'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFFFCA5A5) : AppTheme.crimson,
                  side: BorderSide(color: isDark ? const Color(0xFFEF4444) : AppTheme.crimson),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _exportRegistryPdf(assessments, l),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: Text(l.exportRegistryPdfTooltip, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              ElevatedButton.icon(
                key: const Key('registerNewDeclBtn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => setState(() => _selectedSubTab = 0),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l.customsDeclRegisterNewButton),
              ),
            ];

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 260,
                    maxWidth: constraints.maxWidth < 600 ? constraints.maxWidth : 380,
                  ),
                  child: searchField,
                ),
                ...actionButtons,
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // Enhanced DataTable with Assessment, Row Copy & Record Clone Actions (Task B, Task D, Task E)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : Colors.grey.shade100),
              columns: [
                DataColumn(
                  label: Text(
                    l.customsDeclColActions,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.customsDeclColDeclarationNo,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.customsDeclColFileNumber,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.customsDeclColSupplier,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.customsDeclColHsCode,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.customsDeclCifValueLabel,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.customsDeclTotalDutiesLabel,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.customsDeclColDeclarationStatus,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)),
                  ),
                ),
              ],
              rows: assessments.map((a) {
                final rowSummary = '${a.declarationNo}\t${a.primaryNameWithCode}\t${a.supplierName}\t${a.hsCode}\t${a.cifEgp.toStringAsFixed(2)}\t${a.totalDutiesEgp.toStringAsFixed(2)}\t${a.registrationDate}\t${a.status}';

                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: Key('viewAssessmentBtn_${a.declarationNo}'),
                            icon: const Icon(Icons.analytics_outlined, color: Colors.indigo, size: 18),
                            tooltip: l.customsDeclViewAssessmentTooltip,
                            onPressed: () => _showTariffAssessmentDialog(a, l),
                          ),
                          IconButton(
                            key: Key('copyRegistryRowBtn_${a.declarationNo}'),
                            icon: Icon(Icons.copy, size: 16, color: isDark ? const Color(0xFF93C5FD) : AppTheme.cobalt),
                            tooltip: l.copyRegistryRowSuccess,
                            onPressed: () {
                              final headers = [
                                l.customsDeclColDeclarationNo,
                                l.customsDeclColFileNumber,
                                l.customsDeclColSupplier,
                                l.customsDeclColHsCode,
                                l.customsDeclCifValueLabel,
                                l.customsDeclTotalDutiesLabel,
                                l.customsDeclColRegistrationDate,
                                l.customsDeclColDeclarationStatus,
                              ];
                              final values = [
                                a.declarationNo,
                                a.primaryNameWithCode,
                                a.supplierName,
                                a.hsCode,
                                a.cifEgp.toStringAsFixed(2),
                                a.totalDutiesEgp.toStringAsFixed(2),
                                a.registrationDate,
                                a.status,
                              ];
                              TableCopyHelper.copyRow(context, values, headers: headers);
                            },
                          ),
                          IconButton(
                            key: Key('cloneRegistryRowBtn_${a.declarationNo}'),
                            icon: Icon(Icons.copy_all, size: 18, color: isDark ? const Color(0xFF6EE7B7) : AppTheme.flatEmerald),
                            tooltip: l.cloneCustomsDeclRowTooltip,
                            onPressed: () => _onCloneDeclarationSelected(a),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: a.declarationNo,
                        rowSummary: rowSummary,
                        child: Text(
                          a.declarationNo,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF93C5FD) : Colors.indigo,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: a.primaryNameWithCode,
                        rowSummary: rowSummary,
                        child: Text(
                          a.primaryNameWithCode,
                          style: TextStyle(color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: a.supplierName,
                        rowSummary: rowSummary,
                        child: Text(
                          a.supplierName,
                          style: TextStyle(color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: a.hsCode,
                        rowSummary: rowSummary,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isDark ? const Color(0xFF475569) : Colors.blueGrey.shade200),
                          ),
                          child: Text(
                            a.hsCode,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: isDark ? const Color(0xFF93C5FD) : Colors.blueGrey.shade900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: a.cifEgp.toStringAsFixed(2),
                        rowSummary: rowSummary,
                        child: Text(
                          '${a.cifEgp.toStringAsFixed(2)} EGP',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF60A5FA) : AppTheme.cobalt,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: a.totalDutiesEgp.toStringAsFixed(2),
                        rowSummary: rowSummary,
                        child: Text(
                          '${a.totalDutiesEgp.toStringAsFixed(2)} EGP',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFF87171) : AppTheme.crimson,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: a.status,
                        rowSummary: rowSummary,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E3A8A).withOpacity(0.4) : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isDark ? const Color(0xFF3B82F6).withOpacity(0.5) : Colors.blue.shade300),
                          ),
                          child: Text(
                            a.status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF93C5FD) : Colors.indigo,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  void _showTariffAssessmentDialog(CustomsDeclarationAssessment a, AppLocalizations l) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = l.isArabic;
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 768;
    final dialogWidth = (media.size.width - 32).clamp(320.0, 740.0);

    final assessmentSummaryText = '''
==================================================
${l.customsDeclAssessmentTitle}
${a.declarationNo} — ${a.primaryNameWithCode}
==================================================
[${l.customsDeclShipmentParticularsHeader}]
${l.customsDeclColDeclarationNo}: ${a.declarationNo}
${l.customsDeclColFileNumber}: ${a.primaryNameWithCode}
${l.customsDeclColSupplier}: ${a.supplierName}
${l.customsDeclAcidNumberLabel}: ${a.acidNumber}
${l.customsDeclForm4NumberLabel}: ${a.form4Number}
${l.customsDeclBlNumberLabel}: ${a.blNumber}
${l.customsDeclColRegistrationDate}: ${a.registrationDate}
--------------------------------------------------
[${l.customsDeclValuationBreakdownHeader}]
${l.customsDeclFxRateLabel}: ${a.exchangeRate.toStringAsFixed(4)}
${l.customsDeclFobForeignLabel}: ${a.fobForeign.toStringAsFixed(2)} ${a.currency} (${a.fobEgp.toStringAsFixed(2)} EGP)
${l.customsDeclFreightEgpLabel}: ${a.freightEgp.toStringAsFixed(2)} EGP
${l.customsDeclInsuranceEgpLabel}: ${a.insuranceEgp.toStringAsFixed(2)} EGP
${l.customsDeclCifTotalEgpLabel}: ${a.cifEgp.toStringAsFixed(2)} EGP
--------------------------------------------------
[${l.customsDeclTariffTaxesHeader}]
${l.customsDeclColHsCode}: ${a.hsCode} (${a.hsDescription})
${l.customsDeclImportDutyRateLabel} (${a.dutyRate.toStringAsFixed(1)}%): ${a.importDutyEgp.toStringAsFixed(2)} EGP
${l.customsDeclCustomsServicesFeeLabel} (${a.serviceRate.toStringAsFixed(1)}%): ${a.serviceFeeEgp.toStringAsFixed(2)} EGP
${a.devRate > 0 ? '${l.customsDeclDevFeeLabel} (${a.devRate.toStringAsFixed(1)}%): ${a.devFeeEgp.toStringAsFixed(2)} EGP\n' : ''}${l.customsDeclVatBaseLabel}: ${a.vatBaseEgp.toStringAsFixed(2)} EGP
${l.customsDeclVatRateLabel} (${a.vatRate.toStringAsFixed(1)}%): ${a.vatEgp.toStringAsFixed(2)} EGP
${l.customsDeclTotalDutiesLabel}: ${a.totalDutiesEgp.toStringAsFixed(2)} EGP
--------------------------------------------------
[${l.customsDeclExemptionHeader}]
${a.exemptionTitle}
==================================================
''';

    final tsvText = [
      [
        l.customsDeclColDeclarationNo,
        l.customsDeclColFileNumber,
        l.customsDeclColSupplier,
        l.customsDeclAcidNumberLabel,
        l.customsDeclForm4NumberLabel,
        l.customsDeclBlNumberLabel,
        l.customsDeclColHsCode,
        l.customsDeclFobForeignLabel,
        l.customsDeclFreightEgpLabel,
        l.customsDeclInsuranceEgpLabel,
        l.customsDeclCifTotalEgpLabel,
        l.customsDeclImportDutyRateLabel,
        l.customsDeclCustomsServicesFeeLabel,
        l.customsDeclDevFeeLabel,
        l.customsDeclVatBaseLabel,
        l.customsDeclVatRateLabel,
        l.customsDeclTotalDutiesLabel,
        l.customsDeclExemptionHeader,
      ].join('\t'),
      [
        a.declarationNo,
        a.primaryNameWithCode,
        a.supplierName,
        a.acidNumber,
        a.form4Number,
        a.blNumber,
        a.hsCode,
        '${a.fobForeign.toStringAsFixed(2)} ${a.currency}',
        a.freightEgp.toStringAsFixed(2),
        a.insuranceEgp.toStringAsFixed(2),
        a.cifEgp.toStringAsFixed(2),
        a.importDutyEgp.toStringAsFixed(2),
        a.serviceFeeEgp.toStringAsFixed(2),
        a.devFeeEgp.toStringAsFixed(2),
        a.vatBaseEgp.toStringAsFixed(2),
        a.vatEgp.toStringAsFixed(2),
        a.totalDutiesEgp.toStringAsFixed(2),
        a.exemptionTitle,
      ].join('\t')
    ].join('\n');

    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: isAr ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 16),
            title: Row(
              children: [
                Icon(Icons.analytics_outlined, color: isDark ? const Color(0xFF818CF8) : Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.customsDeclAssessmentTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF312E81) : Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? const Color(0xFF4338CA) : Colors.indigo.shade200),
                  ),
                  child: Text(
                    a.declarationNo,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFA5B4FC) : Colors.indigo,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: dialogWidth,
              child: SelectionArea(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.customsDeclAssessmentSubtitle,
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                      ),
                      const SizedBox(height: 16),

                      // 1. Shipment Particulars Card
                      _buildAssessmentCard(
                        title: l.customsDeclShipmentParticularsHeader,
                        icon: Icons.inventory_2_outlined,
                        color: Colors.indigo,
                        isDark: isDark,
                        children: [
                          _buildAssessmentRow(l.customsDeclColDeclarationNo, a.declarationNo, isDark: isDark),
                          _buildAssessmentRow(l.customsDeclColFileNumber, a.primaryNameWithCode, isDark: isDark),
                          _buildAssessmentRow(l.customsDeclColSupplier, a.supplierName, isDark: isDark),
                          _buildAssessmentRow(l.customsDeclAcidNumberLabel, a.acidNumber, isDark: isDark),
                          _buildAssessmentRow(l.customsDeclForm4NumberLabel, a.form4Number, isDark: isDark),
                          _buildAssessmentRow(l.customsDeclBlNumberLabel, a.blNumber, isDark: isDark),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2. Valuation Breakdown Card (CIF)
                      _buildAssessmentCard(
                        title: l.customsDeclValuationBreakdownHeader,
                        icon: Icons.monetization_on_outlined,
                        color: AppTheme.cobalt,
                        isDark: isDark,
                        children: [
                          _buildAssessmentRow(l.customsDeclFxRateLabel, '${a.exchangeRate.toStringAsFixed(4)} EGP/USD', isDark: isDark),
                          _buildAssessmentRow(l.customsDeclFobForeignLabel, '${a.fobForeign.toStringAsFixed(2)} ${a.currency} (${a.fobEgp.toStringAsFixed(2)} EGP)', isDark: isDark),
                          _buildAssessmentRow(l.customsDeclFreightEgpLabel, '${a.freightEgp.toStringAsFixed(2)} EGP', isDark: isDark),
                          _buildAssessmentRow(l.customsDeclInsuranceEgpLabel, '${a.insuranceEgp.toStringAsFixed(2)} EGP', isDark: isDark),
                          Divider(height: 16, color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                          _buildAssessmentRow(l.customsDeclCifTotalEgpLabel, '${a.cifEgp.toStringAsFixed(2)} EGP', isBold: true, valueColor: AppTheme.cobalt, isDark: isDark),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. Tariff Taxes & Duties Card (MD-008 Engine)
                      _buildAssessmentCard(
                        title: l.customsDeclTariffTaxesHeader,
                        icon: Icons.receipt_long_outlined,
                        color: AppTheme.crimson,
                        isDark: isDark,
                        children: [
                          _buildAssessmentRow(l.customsDeclColHsCode, '${a.hsCode} (${a.hsDescription})', isDark: isDark),
                          _buildAssessmentRow('${l.customsDeclImportDutyRateLabel} (${a.dutyRate.toStringAsFixed(1)}%)', '${a.importDutyEgp.toStringAsFixed(2)} EGP', isDark: isDark),
                          _buildAssessmentRow('${l.customsDeclCustomsServicesFeeLabel} (${a.serviceRate.toStringAsFixed(1)}%)', '${a.serviceFeeEgp.toStringAsFixed(2)} EGP', isDark: isDark),
                          if (a.devRate > 0)
                            _buildAssessmentRow('${l.customsDeclDevFeeLabel} (${a.devRate.toStringAsFixed(1)}%)', '${a.devFeeEgp.toStringAsFixed(2)} EGP', isDark: isDark),
                          _buildAssessmentRow(l.customsDeclVatBaseLabel, '${a.vatBaseEgp.toStringAsFixed(2)} EGP', isDark: isDark),
                          _buildAssessmentRow('${l.customsDeclVatRateLabel} (${a.vatRate.toStringAsFixed(1)}%)', '${a.vatEgp.toStringAsFixed(2)} EGP', isDark: isDark),
                          Divider(height: 16, color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                          _buildAssessmentRow(l.customsDeclTotalDutiesLabel, '${a.totalDutiesEgp.toStringAsFixed(2)} EGP', isBold: true, valueColor: AppTheme.crimson, isDark: isDark),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 4. Exemption & Trade Agreement Card
                      _buildAssessmentCard(
                        title: l.customsDeclExemptionHeader,
                        icon: a.hasExemption ? Icons.verified : Icons.info_outline,
                        color: a.hasExemption ? AppTheme.flatEmerald : Colors.blueGrey,
                        isDark: isDark,
                        children: [
                          _buildAssessmentRow(
                            l.customsDeclExemptionHeader,
                            a.exemptionTitle,
                            isBold: true,
                            valueColor: a.hasExemption ? AppTheme.flatEmerald : (isDark ? const Color(0xFFCBD5E1) : Colors.blueGrey.shade800),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    key: const Key('copyAssessmentSummaryBtn'),
                    onPressed: () {
                      CopyHelper.copy(context, assessmentSummaryText, customMessage: l.customsDeclAssessmentCopySuccess);
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(l.customsDeclCopySummarySuccess),
                  ),
                  TextButton.icon(
                    key: const Key('copyAssessmentTsvBtn'),
                    onPressed: () {
                      CopyHelper.copy(context, tsvText, customMessage: l.customsDeclExportSuccess);
                    },
                    icon: const Icon(Icons.table_chart_outlined, size: 16),
                    label: Text(l.customsDeclExportTsvButton),
                  ),
                  ElevatedButton.icon(
                    key: const Key('dialogCloneDeclBtn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.wcagCobalt,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _onCloneDeclarationSelected(a);
                    },
                    icon: const Icon(Icons.copy_all, size: 16),
                    label: Text(l.cloneFromAssessmentBtn),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l.customsDeclCloseDialog),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Divider(height: 18, color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
          ...children,
        ],
      ),
    );
  }

  Widget _buildAssessmentRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 450;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: isCompact ? 140 : 220,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Expanded(
                child: CopyableText(
                  value,
                  isSelectable: false,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                    color: valueColor ?? (isDark ? const Color(0xFFF1F5F9) : Colors.grey.shade900),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeclarationSummaryDialog(AppLocalizations l) {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;

    final declSummaryText = '''
==================================================
${l.customsDeclPreviewTitle}
==================================================
${l.customsDeclColDeclarationNo}: ${_declaration46NoCtrl.text}
${l.customsDeclSubmissionDateLabel.replaceAll('*', '').trim()}: ${_submissionDateCtrl.text}
${l.customsDeclColFileNumber}: ${file?.primaryNameWithCode ?? '-'}
${l.customsDeclColSupplier}: ${file?.supplierName ?? '-'}
${l.customsDeclAcidNumberLabel}: ${_acidNumberCtrl.text}
${l.customsDeclForm4NumberLabel}: ${_form4NumberCtrl.text}
${l.customsDeclBlNumberLabel}: ${_blNumberCtrl.text}
--------------------------------------------------
${l.customsDeclDutiesHeader}
${l.customsDeclCifValueLabel}: ${_customsValueEgpCtrl.text}
${l.customsDeclImportDutyLabel}: ${_importDutyEgpCtrl.text}
${l.customsDeclVatLabel}: ${_vatEgpCtrl.text}
${l.customsDeclTotalDutiesLabel}: ${_totalDutyAndTaxesCtrl.text}
--------------------------------------------------
${l.customsDeclExemptionHeader}
${_hasExemption ? l.customsDeclEur1ExemptionTitle : l.customsDeclMfnExemptionTitle(_appliedDutyRate.toStringAsFixed(1))}
==================================================
''';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.description, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.customsDeclPreviewTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SelectionArea(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                ),
                child: Text(
                  declSummaryText,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              CopyHelper.copy(context, declSummaryText, customMessage: l.customsDeclCopySummarySuccess);
            },
            icon: const Icon(Icons.copy, size: 18),
            label: Text(l.customsDeclCopySummarySuccess),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.customsDeclCloseDialog),
          ),
        ],
      ),
    );
  }

  void _copyDeclarationAsTsv(AppLocalizations l) {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;

    final headers = [
      l.customsDeclColDeclarationNo,
      l.customsDeclSubmissionDateLabel.replaceAll('*', '').trim(),
      l.customsDeclColFileNumber,
      l.customsDeclColSupplier,
      l.customsDeclAcidNumberLabel,
      l.customsDeclForm4NumberLabel,
      l.customsDeclBlNumberLabel,
      l.customsDeclCifValueLabel,
      l.customsDeclImportDutyLabel,
      l.customsDeclVatLabel,
      l.customsDeclTotalDutiesLabel,
      l.customsDeclExemptionHeader.replaceAll(':', '').trim(),
    ].join('\t');

    final values = [
      _declaration46NoCtrl.text,
      _submissionDateCtrl.text,
      file?.primaryNameWithCode ?? '-',
      file?.supplierName ?? '-',
      _acidNumberCtrl.text,
      _form4NumberCtrl.text,
      _blNumberCtrl.text,
      _customsValueEgpCtrl.text,
      _importDutyEgpCtrl.text,
      _vatEgpCtrl.text,
      _totalDutyAndTaxesCtrl.text,
      _hasExemption ? l.customsDeclEur1ExemptionTitle : l.customsDeclMfnExemptionTitle(_appliedDutyRate.toStringAsFixed(1)),
    ].join('\t');

    final tsv = '$headers\n$values';
    CopyHelper.copy(context, tsv, customMessage: l.customsDeclExportSuccess);
  }

  void _exportRegistryTsv(List<CustomsDeclarationAssessment> items, AppLocalizations l) {
    final headers = [
      l.customsDeclColDeclarationNo,
      l.customsDeclColFileNumber,
      l.customsDeclColSupplier,
      l.customsDeclColHsCode,
      l.customsDeclCifValueLabel,
      l.customsDeclImportDutyLabel,
      l.customsDeclVatLabel,
      l.customsDeclTotalDutiesLabel,
      l.customsDeclColRegistrationDate,
      l.customsDeclColDeclarationStatus,
    ];

    final rows = items.map((a) => [
      a.declarationNo,
      a.primaryNameWithCode,
      a.supplierName,
      a.hsCode,
      a.cifEgp.toStringAsFixed(2),
      a.importDutyEgp.toStringAsFixed(2),
      a.vatEgp.toStringAsFixed(2),
      a.totalDutiesEgp.toStringAsFixed(2),
      a.registrationDate,
      a.status,
    ]).toList();

    TableCopyHelper.copyTable(context, headers, rows);
  }

  Future<void> _exportRegistryExcel(List<CustomsDeclarationAssessment> items, AppLocalizations l) async {
    final headers = [
      l.customsDeclColDeclarationNo,
      l.customsDeclColFileNumber,
      l.customsDeclColSupplier,
      l.customsDeclColHsCode,
      l.customsDeclCifValueLabel,
      l.customsDeclImportDutyLabel,
      l.customsDeclVatLabel,
      l.customsDeclTotalDutiesLabel,
      l.customsDeclColRegistrationDate,
      l.customsDeclColDeclarationStatus,
    ];

    final rows = items.map((a) => [
      a.declarationNo,
      a.primaryNameWithCode,
      a.supplierName,
      a.hsCode,
      a.cifEgp.toStringAsFixed(2),
      a.importDutyEgp.toStringAsFixed(2),
      a.vatEgp.toStringAsFixed(2),
      a.totalDutiesEgp.toStringAsFixed(2),
      a.registrationDate,
      a.status,
    ]).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'Customs Declarations 46 Registry',
      importFileNameOrCode: 'ALL-FILES',
    );
  }

  Future<void> _exportRegistryPdf(List<CustomsDeclarationAssessment> items, AppLocalizations l) async {
    final headers = [
      l.customsDeclColDeclarationNo,
      l.customsDeclColFileNumber,
      l.customsDeclColSupplier,
      l.customsDeclColHsCode,
      l.customsDeclCifValueLabel,
      l.customsDeclTotalDutiesLabel,
      l.customsDeclColDeclarationStatus,
    ];

    final rows = items.map((a) => [
      a.declarationNo,
      a.primaryNameWithCode,
      a.supplierName,
      a.hsCode,
      '${a.cifEgp.toStringAsFixed(2)} EGP',
      '${a.totalDutiesEgp.toStringAsFixed(2)} EGP',
      a.status,
    ]).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'Customs Declarations 46 Registry',
      importFileNameOrCode: 'ALL-FILES',
      headerContext: TableExportHeaderContext(
        title: l.customsDeclTabRegistry,
        subtitle: 'Sorour Logistics ERP — Customs Clearance Follow-up',
        metadata: {
          'Total Declarations': items.length.toString(),
          'Generated At': DateTime.now().toString().substring(0, 19),
        },
      ),
    );
  }

  Future<void> _saveDeclaration46(AppLocalizations l) async {
    if (!_declarationFormKey.currentState!.validate()) return;
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.customsDeclSelectFileWarning), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    setState(() => _isSavingDeclaration = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isSavingDeclaration = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.customsDeclSaveSuccess), backgroundColor: AppTheme.emerald),
      );
      setState(() => _selectedSubTab = 1);
    }
  }
}
