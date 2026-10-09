import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/stored_text.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../customs_clearance/models/customs_clearance_model.dart';
import '../../customs_clearance/providers/customs_clearance_provider.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../currencies/models/currency_model.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../freight_booking/providers/freight_booking_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../providers/import_documentation_provider.dart';
import '../services/customs_declaration46_calculator.dart';
import '../widgets/form46_figures_panel.dart';
import '../widgets/idoc_ui_b.dart';
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
  final double? fobForeign;
  final String currency;
  final double? exchangeRate;
  final double? fobEgp;
  final double? freightEgp;
  final double? insuranceEgp;
  final double? cifEgp;
  final double? dutyRate;
  final double? importDutyEgp;
  final double? devRate;
  final double? devFeeEgp;
  final double? serviceRate;
  final double? serviceFeeEgp;
  final double? otherFeesEgp;
  final double? vatRate;
  final double? scheduleTaxEgp;
  final double? importFeeEgp;
  final double? vatBaseEgp;
  final double? vatEgp;
  final double? totalDutiesEgp;
  final bool hasExemption;
  final String exemptionTitle;
  final String registrationDate;
  final String status;

  /// Missing inputs (`tariff`, `fx_rate`, `fob`); empty when fully computed.
  final List<String> missing;

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
    this.fobForeign,
    required this.currency,
    this.exchangeRate,
    this.fobEgp,
    this.freightEgp,
    this.insuranceEgp,
    this.cifEgp,
    this.dutyRate,
    this.importDutyEgp,
    this.devRate,
    this.devFeeEgp,
    this.serviceRate,
    this.serviceFeeEgp,
    this.otherFeesEgp,
    this.vatRate,
    this.scheduleTaxEgp,
    this.importFeeEgp,
    this.vatBaseEgp,
    this.vatEgp,
    this.totalDutiesEgp,
    required this.hasExemption,
    required this.exemptionTitle,
    required this.registrationDate,
    required this.status,
    this.missing = const [],
  });

  bool get isComplete => missing.isEmpty;
}

class _DeclarationRegistryItem {
  final CustomsClearanceModel record;
  final ImportFileModel? file;
  final CustomsDeclarationAssessment? estimate;

  const _DeclarationRegistryItem({
    required this.record,
    required this.file,
    this.estimate,
  });

  String get declarationNo => record.declaration46No ?? '-';
  String get importFileCode => file?.importFileCode ?? (record.importFileId > 0 ? 'IMP-${record.importFileId}' : '-');
  String get primaryNameWithCode => file?.primaryNameWithCode ?? importFileCode;
  String get supplierName => file?.supplierName ?? '-';
  String get declarationDate => record.declaration46Date != null && record.declaration46Date!.length >= 10
      ? record.declaration46Date!.substring(0, 10)
      : '—';
  String get customsOffice => record.customsOfficeName.trim().isNotEmpty ? record.customsOfficeName : '—';
  String get channel => record.channelType;
  String get status => record.status;
  double? get effectiveDutyTotal => record.effectiveDutyTotal;
  double? get estimatedDutyTotal => estimate?.totalDutiesEgp;
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
  final TextEditingController _declaration46NoCtrl = TextEditingController();
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

  DateTime _declarationDate = DateTime.now();
  String _selectedOffice = 'Alexandria Port Customs';
  String _selectedChannel = 'Red Channel';

  static const List<String> _customsOffices = [
    'Alexandria Port Customs',
    'El Dekheila Port Customs',
    'Port Said Customs',
    'Damietta Port Customs',
    'Sokhna Port Customs',
    'Cairo Airport Cargo Customs',
    '6th of October Dry Port Customs',
    '10th of Ramadan Dry Port Customs',
    'Adabiya Port Customs',
  ];

  static const List<String> _channelOptions = [
    'Red Channel',
    'Yellow Channel',
    'Green Channel',
  ];

  static String _officeLabel(AppLocalizations l, int index) {
    switch (index) {
      case 0:
        return l.ccDecOffice0;
      case 1:
        return l.ccDecOffice1;
      case 2:
        return l.ccDecOffice2;
      case 3:
        return l.ccDecOffice3;
      case 4:
        return l.ccDecOffice4;
      case 5:
        return l.ccDecOffice5;
      case 6:
        return l.ccDecOffice6;
      case 7:
        return l.ccDecOffice7;
      default:
        return l.ccDecOffice8;
    }
  }

  static String _channelLabel(AppLocalizations l, String code) {
    switch (code) {
      case 'Red Channel':
        return l.ccDecChRed;
      case 'Yellow Channel':
        return l.ccDecChYellow;
      case 'Green Channel':
        return l.ccDecChGreen;
      default:
        return code;
    }
  }

  Future<void> _selectSubmissionDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _declarationDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _declarationDate = picked;
        _submissionDateCtrl.text = picked.toIso8601String().substring(0, 10);
      });
    }
  }

  // Compliance & HS Code Tariff States
  List<CustomsTariffModel> _matchedTariffs = [];
  bool _hasExemption = false;
  double? _appliedDutyRate;
  List<String> _figuresMissing = const [];
  List<Map<String, dynamic>> _regulatoryApprovals = [];

  String _searchQuery = '';
  Timer? _searchDebounceTimer;
  final TextEditingController _searchCtrl = TextEditingController();
  Map<int, CustomsDeclarationAssessment> _cachedAssessments = {};
  int _lastInputsHash = 0;
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
    if (!ref.read(customsClearanceProvider).isLoading) {
      ref.read(customsClearanceProvider.notifier).fetchRecords();
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
    _searchDebounceTimer?.cancel();
    _searchCtrl.dispose();
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
      _declaration46NoCtrl.clear();
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
        _appliedDutyRate = null;
        _figuresMissing = const [];
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
    if (blVal.isEmpty && file.customFileNumber != null && file.customFileNumber!.isNotEmpty) {
      blVal = file.customFileNumber!;
    }
    _blNumberCtrl.text = blVal;

    _declaration46NoCtrl.text = file.form46No ?? '';
    if (file.form46Date != null && file.form46Date!.isNotEmpty) {
      final parsedDate = DateTime.tryParse(file.form46Date!);
      if (parsedDate != null) {
        _declarationDate = parsedDate;
        _submissionDateCtrl.text = parsedDate.toIso8601String().substring(0, 10);
      }
    }
    if (file.portOfDischarge != null && file.portOfDischarge!.isNotEmpty) {
      final pod = file.portOfDischarge!.toLowerCase();
      if (pod.contains('dekheila') || pod.contains('دخيلة')) {
        _selectedOffice = 'El Dekheila Port Customs';
      } else if (pod.contains('alex') || pod.contains('إسكندرية')) {
        _selectedOffice = 'Alexandria Port Customs';
      } else if (pod.contains('said') || pod.contains('بورسعيد')) {
        _selectedOffice = 'Port Said Customs';
      } else if (pod.contains('damietta') || pod.contains('دمياط')) {
        _selectedOffice = 'Damietta Port Customs';
      } else if (pod.contains('sokhna') || pod.contains('سخنة')) {
        _selectedOffice = 'Sokhna Port Customs';
      }
    }

    // 4. Extract HS codes and compute duties from backend tariff + customs FX only
    final allTariffs = ref.read(customsTariffProvider).valueOrNull ?? [];
    final List<String> fileHsCodes = [];
    final poState = ref.read(purchaseOrdersProvider);
    final linkedPos = poState.purchaseOrders.where((p) => p.importFileId == fileId).toList();
    for (var po in linkedPos) {
      for (var item in po.items) {
        if (item.hsCode != null && item.hsCode!.trim().isNotEmpty) {
          fileHsCodes.add(item.hsCode!.trim());
        }
      }
    }

    // No fallback HS code and no arbitrary tariff: no match means "tariff missing".
    final primaryTariff = Form46Calculator.matchTariff(fileHsCodes, allTariffs);
    _matchedTariffs = Form46Calculator.matchTariffs(fileHsCodes, allTariffs);

    final fobRes = Form46Calculator.invoiceFob(List<InvoiceItemModel>.from(file.invoicesData as List));
    final figures = Form46Calculator.compute(
      fobForeign: fobRes.amount,
      fobIssue: fobRes.issue,
      customsFxRate: Form46Calculator.customsRateFor(
        fobRes.currency,
        ref.read(currenciesProvider).valueOrNull ?? [],
      ),
      tariff: primaryTariff,
    );
    _appliedDutyRate = figures.dutyRate;
    _figuresMissing = figures.missing;

    // Missing figures stay empty (shown as missing); nothing is invented.
    _customsValueEgpCtrl.text = figures.cifEgp?.toStringAsFixed(2) ?? '';
    _importDutyEgpCtrl.text = figures.importDutyEgp?.toStringAsFixed(2) ?? '';
    _vatEgpCtrl.text = figures.vatEgp?.toStringAsFixed(2) ?? '';
    _otherFeesEgpCtrl.text = figures.otherFeesEgp?.toStringAsFixed(2) ?? '';
    _totalDutyAndTaxesCtrl.text = figures.totalDutiesEgp?.toStringAsFixed(2) ?? '';

    // 5. Exemption: only when the backend tariff says duty is 0 (no port-name guess)
    _hasExemption = figures.hasExemption;

    // 6. Regulatory Approvals & Inspections Board (only real tariff rows)
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
      });
    }

    setState(() {});
  }

  void _calculateTotalDuties() {
    _totalDutyAndTaxesCtrl.text = Form46Calculator.totalOfComponents(
      [_importDutyEgpCtrl.text, _vatEgpCtrl.text, _otherFeesEgpCtrl.text],
    );
  }

  Future<void> _openSearchAndCloneDialog() async {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final acids = ref.read(acidSessionsProvider).valueOrNull ?? [];
    final bankDocs = ref.read(bankingDocumentsProvider).valueOrNull ?? [];
    final reviews = ref.read(draftBLReviewsProvider).valueOrNull ?? [];
    final bookings = ref.read(freightBookingProvider).valueOrNull ?? [];
    final tariffs = ref.read(customsTariffProvider).valueOrNull ?? [];
    final pos = ref.read(purchaseOrdersProvider).purchaseOrders;
    final clearanceRecords = ref.read(customsClearanceProvider).valueOrNull ?? [];

    final assessments = files.map((f) {
      final clearance = clearanceRecords.where((c) => c.importFileId == f.importFileId).firstOrNull;
      return _calculateAssessment(
        f,
        context.l10n,
        declarationNo: clearance?.declaration46No ?? f.form46No ?? '',
        registrationDate: clearance?.declaration46Date ?? f.form46Date ?? '',
        status: clearance?.status ?? '',
        cachedAcids: acids,
        cachedBankDocs: bankDocs,
        cachedReviews: reviews,
        cachedBookings: bookings,
        cachedTariffs: tariffs,
        cachedPos: pos,
      );
    }).toList();

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
    final l = context.l10n;

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isAr ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: CloneEntityReviewDialog(
            entityType: l.idocBCloneDecl46Entity,
            sourceCode: a.declarationNo,
            sourceTitle: '${a.primaryNameWithCode} — ${a.supplierName}',
            suggestedNewCode: '46-DRAFT-${a.importFileCode}',
            copiedFieldsSummary: {
              l.idocBCloneFieldImportFile: a.primaryNameWithCode,
              l.idocBCloneFieldSupplier: a.supplierName,
              l.idocBCloneFieldCompany: a.companyName,
              l.idocBCloneFieldHsCode: '${a.hsCode} (${a.hsDescription})',
              l.idocBCloneFieldCif: a.cifEgp.egpOrMissing(_miss),
              l.idocBCloneFieldTotalDuties: a.totalDutiesEgp.egpOrMissing(_miss),
              l.idocBCloneFieldExemption: a.exemptionTitle,
            },
            mandatorilyResetFields: [
              l.idocBCloneReset1,
              l.idocBCloneReset2,
              l.idocBCloneReset3,
              l.idocBCloneReset4,
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
                _customsValueEgpCtrl.text = a.cifEgp?.toStringAsFixed(2) ?? '';
                _importDutyEgpCtrl.text = a.importDutyEgp?.toStringAsFixed(2) ?? '';
                _vatEgpCtrl.text = a.vatEgp?.toStringAsFixed(2) ?? '';
                _otherFeesEgpCtrl.text = a.otherFeesEgp?.toStringAsFixed(2) ?? '';
                _totalDutyAndTaxesCtrl.text = a.totalDutiesEgp?.toStringAsFixed(2) ?? '';
                _appliedDutyRate = a.dutyRate;
                _hasExemption = a.hasExemption;
                _notesCtrl.text = (notes != null && notes.isNotEmpty)
                    ? notes
                    : storedText.idocBCloneDeclNote(a.declarationNo);
                // Rebuilt from the real tariff row only; nothing is assumed.
                _regulatoryApprovals = (ref.read(customsTariffProvider).valueOrNull ?? [])
                    .where((t) => t.hsCode == a.hsCode)
                    .map((t) => <String, dynamic>{
                          'hs_code': t.hsCode,
                          'description': t.hsDescription,
                          'authority': t.regulatoryAuthority,
                          'requires_inspection': t.requiresInspection,
                          'requires_coo': t.requiresCoo,
                          'requires_acid': t.requiresAcid,
                          'note': t.priorApprovalNote,
                        })
                    .toList();
                _figuresMissing = a.missing;
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

  /// Real status of an approval row; '-' when the data carries none.
  String _approvalStatusText(Map<String, dynamic> appr, AppLocalizations l) {
    final raw = (appr['status'] ?? '').toString().trim();
    if (raw.isEmpty) return '-';
    final up = raw.toUpperCase();
    if (up == 'APPROVED' || up == 'FULFILLED') return l.customsDeclStatusFulfilled;
    return raw;
  }

  String get _miss => context.l10n.idocBMissing;

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
    final String statusText = _approvalStatusText(appr, l);

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
      final String statusText = _approvalStatusText(appr, l);
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
      final String statusText = _approvalStatusText(appr, l);
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
      final String statusText = _approvalStatusText(appr, l);
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
        subtitle: l.customsDeclExportSubtitleWithFile(_declaration46NoCtrl.text, fileCode),
        metadata: {
          l.customsDeclColDeclarationNo: _declaration46NoCtrl.text,
          l.customsDeclColFileNumber: fileCode,
          l.customsDeclSubmissionDateLabel.replaceAll('*', '').trim(): _submissionDateCtrl.text,
          l.customsDeclColSupplier: file?.supplierName ?? '-',
        },
      ),
    );
  }

  /// Read/write field with a leading icon and a copy button.
  Widget _copyField(
    Key key,
    TextEditingController ctrl,
    String label,
    IconData icon,
    AppLocalizations l, {
    bool bold = false,
    bool ltr = false,
    Color? accent,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      key: key,
      controller: ctrl,
      textDirection: ltr ? TextDirection.ltr : null,
      style: bold ? TextStyle(fontWeight: FontWeight.bold, color: accent) : null,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: accent),
        suffixIcon: IconButton(
          icon: const Icon(Icons.copy, size: 16),
          tooltip: l.customsDeclCopyValueTooltip,
          onPressed: () => CopyHelper.copy(context, ctrl.text),
        ),
        border: const OutlineInputBorder(),
      ),
    );
  }

  /// Fields side by side, stacked below [breakpoint].
  Widget _fieldsRow(double maxWidth, double breakpoint, List<Widget> fields, {List<int>? flex}) {
    if (maxWidth < breakpoint) {
      return Column(
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            fields[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(flex: flex?[i] ?? 1, child: fields[i]),
        ],
      ],
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
              icon: Icon(Icons.copy_all, color: AppTheme.cloudWhite, size: density.buttonIconSize),
              tooltip: l.searchAndCloneCustomsDeclBtn,
              onPressed: _openSearchAndCloneDialog,
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: AppTheme.cloudWhite, size: density.buttonIconSize),
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
        : l.customsDeclMfnExemptionTitle(_appliedDutyRate.fixedOrMissing(1, _miss));

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
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: AppButton(key: const Key('subtab0SearchAndCloneBtn'), label: l.searchAndCloneCustomsDeclBtn, onPressed: _openSearchAndCloneDialog, variant: AppButtonVariant.secondary, icon: Icons.copy_all),
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
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        AppButton(key: const Key('subtab0SearchAndCloneBtn'), label: l.searchAndCloneCustomsDeclBtn, onPressed: _openSearchAndCloneDialog, variant: AppButtonVariant.secondary, icon: Icons.copy_all),
                      ],
                    ),
              const SizedBox(height: 14),

              // Informational Alert
              IdocBNotice(
                message: l.customsDeclInfoBanner,
                icon: Icons.verified_outlined,
                margin: const EdgeInsetsDirectional.only(bottom: 16),
              ),

              // File Selector
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecorationOf(context),
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

              // Declaration attributes: numbers and dates
              IdocBSectionCard(
                icon: Icons.assignment_outlined,
                title: l.customsDeclAttributesHeader,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldsRow(
                      constraints.maxWidth,
                      600,
                      [
                        _copyField(
                          const Key('decl46NoField'),
                          _declaration46NoCtrl,
                          l.customsDeclDeclarationNoLabel,
                          Icons.pin,
                          l,
                          bold: true,
                          accent: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return l.customsDeclRequiredField;
                            }
                            if (val.trim().length < 3) {
                              return l.customsDeclMinLength;
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          key: const Key('decl46DateField'),
                          controller: _submissionDateCtrl,
                          readOnly: true,
                          onTap: _selectSubmissionDate,
                          validator: (val) => val == null || val.trim().isEmpty ? l.customsDeclRequiredField : null,
                          decoration: InputDecoration(
                            labelText: l.customsDeclSubmissionDateLabel,
                            prefixIcon: const Icon(Icons.calendar_today),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_month, size: 18),
                              tooltip: l.customsDeclPickDateTooltip,
                              onPressed: _selectSubmissionDate,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                      flex: const [2, 1],
                    ),
                    const SizedBox(height: 16),
                    _fieldsRow(
                      constraints.maxWidth,
                      768,
                      [
                        SearchableDropdownField<String>(
                          key: const Key('decl46OfficeDropdown'),
                          labelText: l.ccDecOfficeLabel,
                          hintText: l.ccDecOfficeHint,
                          items: [
                            for (var i = 0; i < _customsOffices.length; i++)
                              SearchableDropdownItem<String>(
                                value: _customsOffices[i],
                                label: _officeLabel(l, i) == _customsOffices[i]
                                    ? _customsOffices[i]
                                    : '${_officeLabel(l, i)} (${_customsOffices[i]})',
                              ),
                          ],
                          value: _selectedOffice,
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedOffice = val);
                          },
                        ),
                        SearchableDropdownField<String>(
                          key: const Key('decl46ChannelDropdown'),
                          labelText: l.customsDeclChannelLabel,
                          items: [
                            for (final ch in _channelOptions)
                              SearchableDropdownItem<String>(
                                value: ch,
                                label: '${_channelLabel(l, ch)} ($ch)',
                              ),
                          ],
                          value: _selectedChannel,
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedChannel = val);
                          },
                        ),
                      ],
                      flex: const [1, 1],
                    ),
                    const SizedBox(height: 16),
                    _fieldsRow(
                      constraints.maxWidth,
                      768,
                      [
                        _copyField(const Key('decl46AcidField'), _acidNumberCtrl, l.customsDeclAcidNumberLabel, Icons.qr_code, l, ltr: true),
                        _copyField(const Key('decl46Form4Field'), _form4NumberCtrl, l.customsDeclForm4NumberLabel, Icons.account_balance, l),
                        _copyField(const Key('decl46BlField'), _blNumberCtrl, l.customsDeclBlNumberLabel, Icons.assignment, l, ltr: true),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Duties & taxes: itemised, right-aligned money table
              IdocBSectionCard(
                icon: Icons.receipt_long_outlined,
                title: l.customsDeclDutiesHeader,
                child: Form46FiguresPanel(
                  cifCtrl: _customsValueEgpCtrl,
                  dutyCtrl: _importDutyEgpCtrl,
                  vatCtrl: _vatEgpCtrl,
                  totalCtrl: _totalDutyAndTaxesCtrl,
                  missing: _figuresMissing,
                  hasFile: _selectedImportFileId != null,
                  appliedDutyRate: _appliedDutyRate,
                  onComponentChanged: _calculateTotalDuties,
                ),
              ),
              const SizedBox(height: 16),

              // Exemption & trade agreement
              if (_selectedImportFileId != null) ...[
                IdocBSectionCard(
                  icon: _hasExemption ? Icons.verified : Icons.info_outline,
                  accent: _hasExemption ? AppTheme.emerald : AppTheme.cobalt,
                  title: l.customsDeclExemptionHeader,
                  trailing: IdocBStatusChip(
                    label: _hasExemption ? l.idocBExemptionApplied : l.idocBExemptionNone,
                    severity: _hasExemption ? AppSeverity.success : AppSeverity.info,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.severityBackgroundOf(context, _hasExemption ? AppSeverity.success : AppSeverity.info),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: AppTheme.borderOf(context)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_offer,
                              size: 18,
                              color: _hasExemption ? AppTheme.emerald : AppTheme.cobalt,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CopyableText(
                                exemptionTitle,
                                isSelectable: false,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.textPrimaryOf(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l.customsDeclExemptionConditionsHeader,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: DisplayDensityMode.clampFontSize(12.5),
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...exemptionConditions.map((cond) => Padding(
                            padding: const EdgeInsetsDirectional.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                  color: _hasExemption ? AppTheme.emerald : AppTheme.textMutedOf(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: CopyableText(
                                    cond,
                                    isSelectable: false,
                                    style: TextStyle(
                                      fontSize: DisplayDensityMode.clampFontSize(12.0),
                                      color: AppTheme.textPrimaryOf(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],

              // Regulatory approvals, inspections & prior approvals
              if (_regulatoryApprovals.isNotEmpty) ...[
                IdocBSectionCard(
                  icon: Icons.policy_outlined,
                  title: l.customsDeclRegulatoryHeader,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          AppButton(key: const Key('copyRegulatoryTableTsvBtn'), label: l.customsDeclExportTsvButton, onPressed: () => _copyApprovalTable(l), variant: AppButtonVariant.secondary, size: AppButtonSize.small, icon: Icons.copy_all),
                          AppButton(key: const Key('exportRegulatoryExcelBtn'), label: l.exportExcelApprovalsTooltip, onPressed: () => _exportApprovalsToExcel(l), variant: AppButtonVariant.secondary, size: AppButtonSize.small, icon: Icons.table_chart_outlined),
                          AppButton(key: const Key('exportRegulatoryPdfBtn'), label: l.exportPdfApprovalsTooltip, onPressed: () => _exportApprovalsToPdf(l), variant: AppButtonVariant.secondary, size: AppButtonSize.small, icon: Icons.picture_as_pdf_outlined),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkInputBackground : AppTheme.surfaceAlt),
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
                            final String statusText = _approvalStatusText(appr, l);
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
                                        color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
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
                                        color: isDark ? AppTheme.darkTextPrimary : null,
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
                                      color: appr['requires_inspection'] == true ? AppTheme.warningForeground : AppTheme.textMuted,
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
                                      color: appr['requires_coo'] == true ? AppTheme.flatEmerald : AppTheme.textMuted,
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
                                        color: isDark ? AppTheme.darkTextPrimary : null,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  CopyableTableCell(
                                    value: statusText,
                                    rowSummary: rowSummary,
                                    child: IdocBStatusChip(label: statusText, severity: AppSeverity.success),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    key: Key('copyApprovalRowBtn_$hsCode'),
                                    icon: const Icon(Icons.copy_rounded, size: 17),
                                    tooltip: l.copyApprovalRowSuccess,
                                    color: isDark ? AppTheme.darkHyperlink : AppTheme.wcagCobalt,
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

              // Action bar: save (primary) + preview / copy / clone
              IdocBActionBar(
                secondary: [
                  AppButton(key: const Key('printPreviewDeclaration46Btn'), label: l.customsDeclPrintPreviewButton, onPressed: () => _showDeclarationSummaryDialog(l), variant: AppButtonVariant.secondary, icon: Icons.visibility_outlined),
                  AppButton(key: const Key('exportDeclaration46TsvBtn'), label: l.customsDeclExportTsvButton, onPressed: () => _copyDeclarationAsTsv(l), variant: AppButtonVariant.secondary, icon: Icons.table_chart_outlined),
                  AppButton(key: const Key('bottomSearchAndCloneDeclBtn'), label: l.searchAndCloneCustomsDeclBtn, onPressed: _openSearchAndCloneDialog, variant: AppButtonVariant.secondary, icon: Icons.copy_all),
                ],
                primary: [
                  AppButton(key: const Key('saveDeclaration46Btn'), label: _isSavingDeclaration ? l.customsDeclSavingProgress : l.customsDeclSaveButton, onPressed: _isSavingDeclaration ? null : () => _saveDeclaration46(l), variant: AppButtonVariant.success, icon: Icons.save, isLoading: _isSavingDeclaration),
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
    String? declarationNo,
    String? registrationDate,
    String? status,
    List<dynamic>? cachedAcids,
    List<dynamic>? cachedBankDocs,
    List<dynamic>? cachedReviews,
    List<dynamic>? cachedBookings,
    List<CustomsTariffModel>? cachedTariffs,
    List<dynamic>? cachedPos,
    List<CurrencyModel>? cachedCurrencies,
  }) {
    final int fileId = file.importFileId;
    final String declNo = declarationNo ?? file.form46No ?? '';
    final String regDate = registrationDate ?? file.form46Date ?? '';
    final String declStatus = status ?? '';

    // 1. ACID
    String acidVal = file.acidNumber ?? '';
    if (acidVal.isEmpty) {
      final acids = cachedAcids ?? ref.read(acidSessionsProvider).valueOrNull ?? [];
      final matchedAcid = acids.where((a) => a.importFileId == fileId).firstOrNull;
      if (matchedAcid != null && matchedAcid.acidNumber.isNotEmpty) {
        acidVal = matchedAcid.acidNumber;
      }
    }

    // 2. Form 4
    String f4Val = file.form4No ?? '';
    if (f4Val.isEmpty) {
      final bankDocs = cachedBankDocs ?? ref.read(bankingDocumentsProvider).valueOrNull ?? [];
      final matchedF4 = bankDocs.where((d) => d.importFileId == fileId && d.docType == 'Form 4').firstOrNull;
      if (matchedF4 != null && matchedF4.docReferenceNumber != 'PENDING' && matchedF4.docReferenceNumber.isNotEmpty) {
        f4Val = matchedF4.docReferenceNumber;
      }
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
    if (blVal.isEmpty && file.customFileNumber != null && file.customFileNumber!.isNotEmpty) {
      blVal = file.customFileNumber!;
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
    final primaryTariff = Form46Calculator.matchTariff(fileHsCodes, allTariffs);

    final String hsCode = primaryTariff?.hsCode ?? (fileHsCodes.isNotEmpty ? fileHsCodes.first : '');
    final String hsDesc = primaryTariff?.hsDescription ?? l.customsDeclDefaultItemDesc;

    final fobRes = Form46Calculator.invoiceFob(List<InvoiceItemModel>.from(file.invoicesData as List));
    final String currency = fobRes.currency;
    final f = Form46Calculator.compute(
      fobForeign: fobRes.amount,
      fobIssue: fobRes.issue,
      customsFxRate: Form46Calculator.customsRateFor(
        currency,
        cachedCurrencies ?? ref.read(currenciesProvider).valueOrNull ?? [],
      ),
      tariff: primaryTariff,
    );

    final bool isEuropeanOrExempt = f.hasExemption;
    final String exemptionTitle = f.dutyRate == null
        ? ''
        : (isEuropeanOrExempt
            ? l.customsDeclEur1ExemptionTitle
            : l.customsDeclMfnExemptionTitle(f.dutyRate!.toStringAsFixed(1)));

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
      fobForeign: f.fobForeign,
      currency: currency,
      exchangeRate: f.exchangeRate,
      fobEgp: f.fobEgp,
      cifEgp: f.cifEgp,
      dutyRate: f.dutyRate,
      importDutyEgp: f.importDutyEgp,
      devRate: f.devRate,
      devFeeEgp: f.devFeeEgp,
      serviceRate: f.serviceRate,
      serviceFeeEgp: f.serviceFeeEgp,
      otherFeesEgp: f.otherFeesEgp,
      vatRate: f.vatRate,
      scheduleTaxEgp: f.scheduleTaxEgp,
      importFeeEgp: f.importFeeEgp,
      vatBaseEgp: f.vatBaseEgp,
      vatEgp: f.vatEgp,
      totalDutiesEgp: f.totalDutiesEgp,
      missing: f.missing,
      hasExemption: isEuropeanOrExempt,
      exemptionTitle: exemptionTitle,
      registrationDate: regDate,
      status: declStatus,
    );
  }

  CustomsDeclarationAssessment? _getOrComputeAssessment(
    ImportFileModel? file,
    AppLocalizations l, {
    required List<dynamic> acids,
    required List<dynamic> bankDocs,
    required List<dynamic> reviews,
    required List<dynamic> bookings,
    required List<CustomsTariffModel> allTariffs,
    required List<dynamic> pos,
    required List<CurrencyModel> currencies,
    String? declarationNo,
    String? registrationDate,
    String? status,
  }) {
    if (file == null) return null;
    final fileId = file.importFileId;
    if (_cachedAssessments.containsKey(fileId)) {
      return _cachedAssessments[fileId];
    }
    final assessment = _calculateAssessment(
      file,
      l,
      declarationNo: declarationNo ?? file.form46No ?? '',
      registrationDate: registrationDate ?? file.form46Date ?? '',
      status: status ?? '',
      cachedAcids: acids,
      cachedBankDocs: bankDocs,
      cachedReviews: reviews,
      cachedBookings: bookings,
      cachedTariffs: allTariffs,
      cachedPos: pos,
      cachedCurrencies: currencies,
    );
    _cachedAssessments[fileId] = assessment;
    return assessment;
  }

  /// Money cell: right-aligned LTR digits, or the red missing marker.
  Widget _figureText(double? value, Color color, {required bool bold}) {
    if (value == null) return IdocBMissingMark(label: _miss);
    return LtrText(
      '${IdocBFormat.money(value)} ${context.l10n.egpCurrency}',
      textAlign: TextAlign.end,
      style: TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.w600,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _buildDeclarationRegistryView(AppLocalizations l) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final clearanceAsync = ref.watch(customsClearanceProvider);
    final clearanceRecords = clearanceAsync.valueOrNull ?? [];
    final acids = ref.watch(acidSessionsProvider).valueOrNull ?? [];
    final bankDocs = ref.watch(bankingDocumentsProvider).valueOrNull ?? [];
    final reviews = ref.watch(draftBLReviewsProvider).valueOrNull ?? [];
    final bookings = ref.watch(freightBookingProvider).valueOrNull ?? [];
    final allTariffs = ref.watch(customsTariffProvider).valueOrNull ?? [];
    final pos = ref.watch(purchaseOrdersProvider).purchaseOrders;
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];

    final realDeclarations = clearanceRecords.where((r) {
      final no = r.declaration46No?.trim();
      return no != null && no.isNotEmpty;
    }).toList();

    final currentHash = Object.hash(
      importFiles.length,
      clearanceRecords.length,
      acids.length,
      bankDocs.length,
      reviews.length,
      bookings.length,
      allTariffs.length,
      pos.length,
      currencies.length,
    );
    if (_lastInputsHash != currentHash) {
      _lastInputsHash = currentHash;
      _cachedAssessments = {};
    }

    final fileMap = {for (final f in importFiles) f.importFileId: f};

    final allItems = realDeclarations.map((record) {
      final file = fileMap[record.importFileId];
      final estimate = _getOrComputeAssessment(
        file,
        l,
        acids: acids,
        bankDocs: bankDocs,
        reviews: reviews,
        bookings: bookings,
        allTariffs: allTariffs,
        pos: pos,
        currencies: currencies,
        declarationNo: record.declaration46No,
        registrationDate: record.declaration46Date,
        status: record.status,
      );
      return _DeclarationRegistryItem(
        record: record,
        file: file,
        estimate: estimate,
      );
    }).toList();

    final filteredItems = allItems.where((item) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final dNo = item.declarationNo.toLowerCase();
      final fCode = item.importFileCode.toLowerCase();
      final supp = item.supplierName.toLowerCase();
      final pName = item.primaryNameWithCode.toLowerCase();
      final off = item.customsOffice.toLowerCase();
      return dNo.contains(q) ||
          fCode.contains(q) ||
          supp.contains(q) ||
          pName.contains(q) ||
          off.contains(q);
    }).toList();

    final totalCount = filteredItems.length;
    final totalStoredDuties = filteredItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.effectiveDutyTotal ?? 0.0),
    );
    final totalEstimatedDuties = filteredItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.estimatedDutyTotal ?? 0.0),
    );
    final totalExemptions = filteredItems.where((item) => item.estimate?.hasExemption == true).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI strip
        IdocBUi.metrics([
          MetricCardData(
            title: l.customsDeclMetricTotalDeclarations,
            value: totalCount.toString(),
            icon: Icons.assignment_turned_in_outlined,
            color: AppTheme.cobalt,
          ),
          MetricCardData(
            title: l.customsDeclMetricTotalDuties,
            value: '${IdocBFormat.money(totalStoredDuties)} ${l.egpCurrency}',
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.crimson,
          ),
          MetricCardData(
            title: l.customsDeclMetricEstimatedDuties,
            value: '${IdocBFormat.money(totalEstimatedDuties)} ${l.egpCurrency}',
            icon: Icons.analytics_outlined,
            color: AppTheme.cobalt,
          ),
          MetricCardData(
            title: l.customsDeclMetricExemptions,
            value: totalExemptions.toString(),
            icon: Icons.verified_outlined,
            color: AppTheme.emerald,
          ),
        ]),
        const SizedBox(height: 18),

        // Search and Actions Toolbar (Task A, Task J)
        LayoutBuilder(
          builder: (context, constraints) {
            final searchField = TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: l.customsDeclRegistrySearchHint,
                hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.border),
                ),
                filled: true,
                fillColor: isDark ? AppTheme.darkCardBackground : AppTheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
              onChanged: (val) {
                _searchDebounceTimer?.cancel();
                _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _searchQuery = val.trim());
                });
              },
            );

            final actionButtons = [
              AppButton(key: const Key('copyRegistryTableTsvBtn'), label: l.customsDeclExportTsvButton, onPressed: () => _exportRegistryTsv(filteredItems, l), variant: AppButtonVariant.secondary, icon: Icons.copy),
              AppButton(key: const Key('exportRegistryExcelBtn'), label: l.exportRegistryExcelTooltip, onPressed: () => _exportRegistryExcel(filteredItems, l), variant: AppButtonVariant.secondary, icon: Icons.table_view_outlined),
              AppButton(key: const Key('exportRegistryPdfBtn'), label: l.exportRegistryPdfTooltip, onPressed: () => _exportRegistryPdf(filteredItems, l), variant: AppButtonVariant.secondary, icon: Icons.picture_as_pdf_outlined),
              AppButton(key: const Key('registerNewDeclBtn'), label: l.customsDeclRegisterNewButton, onPressed: () => setState(() => _selectedSubTab = 0), icon: Icons.add),
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

        // Registry table (assessment, row copy and clone actions)
        if (filteredItems.isEmpty)
          IdocBStateView.empty(
            key: const Key('decl46RegistryEmpty'),
            message: _searchQuery.isNotEmpty
                ? l.idocBNoDeclarations
                : l.customsDeclRegistryEmptyMessage,
            icon: Icons.assignment_outlined,
            actionLabel: l.customsDeclRegisterNewButton,
            onAction: () => setState(() => _selectedSubTab = 0),
          )
        else
        Container(
          width: double.infinity,
          decoration: AppTheme.cardDecorationOf(context),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkInputBackground : AppTheme.surfaceAlt),
              columns: [
                DataColumn(
                  label: Text(
                    l.customsDeclColActions,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.customsDeclColDeclarationNo,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.customsDeclColFileNumber,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.customsDeclColSupplier,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.customsDeclColRegistrationDate,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.ccDecOfficeLabel,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.customsDeclChannelLabel,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.customsDeclColDeclarationStatus,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    l.customsDeclColTariffEstimate,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                  ),
                ),
              ],
              rows: filteredItems.map((item) {
                final rowSummary = '${item.declarationNo}\t${item.importFileCode}\t${item.supplierName}\t${item.declarationDate}\t${item.customsOffice}\t${item.channel}\t${item.status}\t${item.estimatedDutyTotal.fixedOrMissing(2, _miss)}';

                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.estimate != null)
                            IconButton(
                              key: Key('viewAssessmentBtn_${item.declarationNo}'),
                              icon: const Icon(Icons.analytics_outlined, color: AppTheme.cobalt, size: 18),
                              tooltip: l.customsDeclViewAssessmentTooltip,
                              onPressed: () => _showTariffAssessmentDialog(item.estimate!, l),
                            ),
                          IconButton(
                            key: Key('copyRegistryRowBtn_${item.declarationNo}'),
                            icon: Icon(Icons.copy, size: 16, color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt),
                            tooltip: l.copyRegistryRowSuccess,
                            onPressed: () {
                              final headers = [
                                l.customsDeclColDeclarationNo,
                                l.customsDeclColFileNumber,
                                l.customsDeclColSupplier,
                                l.customsDeclColRegistrationDate,
                                l.ccDecOfficeLabel,
                                l.customsDeclChannelLabel,
                                l.customsDeclColDeclarationStatus,
                                l.customsDeclColTariffEstimate,
                              ];
                              final values = [
                                item.declarationNo,
                                item.importFileCode,
                                item.supplierName,
                                item.declarationDate,
                                item.customsOffice,
                                item.channel,
                                item.status,
                                item.estimatedDutyTotal.fixedOrMissing(2, _miss),
                              ];
                              TableCopyHelper.copyRow(context, values, headers: headers);
                            },
                          ),
                          if (item.estimate != null)
                            IconButton(
                              key: Key('cloneRegistryRowBtn_${item.declarationNo}'),
                              icon: Icon(Icons.copy_all, size: 18, color: isDark ? AppTheme.emerald : AppTheme.flatEmerald),
                              tooltip: l.cloneCustomsDeclRowTooltip,
                              onPressed: () => _onCloneDeclarationSelected(item.estimate!),
                            ),
                        ],
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: item.declarationNo,
                        rowSummary: rowSummary,
                        child: Text(
                          item.declarationNo,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: item.importFileCode,
                        rowSummary: rowSummary,
                        child: Text(
                          item.importFileCode,
                          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: item.supplierName,
                        rowSummary: rowSummary,
                        child: Text(
                          item.supplierName,
                          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: item.declarationDate,
                        rowSummary: rowSummary,
                        child: Text(
                          item.declarationDate,
                          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: item.customsOffice,
                        rowSummary: rowSummary,
                        child: Text(
                          item.customsOffice,
                          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: item.channel,
                        rowSummary: rowSummary,
                        child: Builder(
                          builder: (context) {
                            final ch = CcUi.channelStyle(l, item.channel);
                            return IdocBStatusChip(
                              label: ch.label,
                              severity: ch.severity,
                              icon: ch.icon,
                            );
                          },
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: item.status,
                        rowSummary: rowSummary,
                        child: Builder(
                          builder: (context) {
                            final st = CcUi.statusStyle(l, item.status);
                            return IdocBStatusChip(
                              label: st.label,
                              severity: st.severity,
                            );
                          },
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: item.estimatedDutyTotal.fixedOrMissing(2, _miss),
                        rowSummary: rowSummary,
                        child: _figureText(item.estimatedDutyTotal, AppTheme.crimson, bold: true),
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
${l.customsDeclFxRateLabel}: ${a.exchangeRate.fixedOrMissing(4, _miss)}
${l.customsDeclFobForeignLabel}: ${a.fobForeign.fixedOrMissing(2, _miss)} ${a.currency} (${a.fobEgp.egpOrMissing(_miss)})
${l.customsDeclFreightEgpLabel}: ${a.freightEgp.egpOrMissing(_miss)}
${l.customsDeclInsuranceEgpLabel}: ${a.insuranceEgp.egpOrMissing(_miss)}
${l.customsDeclCifTotalEgpLabel}: ${a.cifEgp.egpOrMissing(_miss)}
--------------------------------------------------
[${l.customsDeclTariffTaxesHeader}]
${l.customsDeclColHsCode}: ${a.hsCode} (${a.hsDescription})
${l.customsDeclImportDutyRateLabel} (${a.dutyRate.fixedOrMissing(1, _miss)}%): ${a.importDutyEgp.egpOrMissing(_miss)}
${l.customsDeclCustomsServicesFeeLabel} (${a.serviceRate.fixedOrMissing(1, _miss)}%): ${a.serviceFeeEgp.egpOrMissing(_miss)}
${(a.devRate ?? 0) > 0 ? '${l.customsDeclDevFeeLabel} (${a.devRate.fixedOrMissing(1, _miss)}%): ${a.devFeeEgp.egpOrMissing(_miss)}\n' : ''}${l.customsDeclVatBaseLabel}: ${a.vatBaseEgp.egpOrMissing(_miss)}
${l.customsDeclVatRateLabel} (${a.vatRate.fixedOrMissing(1, _miss)}%): ${a.vatEgp.egpOrMissing(_miss)}
${l.customsDeclTotalDutiesLabel}: ${a.totalDutiesEgp.egpOrMissing(_miss)}
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
        '${a.fobForeign.fixedOrMissing(2, _miss)} ${a.currency}',
        a.freightEgp.fixedOrMissing(2, _miss),
        a.insuranceEgp.fixedOrMissing(2, _miss),
        a.cifEgp.fixedOrMissing(2, _miss),
        a.importDutyEgp.fixedOrMissing(2, _miss),
        a.serviceFeeEgp.fixedOrMissing(2, _miss),
        a.devFeeEgp.fixedOrMissing(2, _miss),
        a.vatBaseEgp.fixedOrMissing(2, _miss),
        a.vatEgp.fixedOrMissing(2, _miss),
        a.totalDutiesEgp.fixedOrMissing(2, _miss),
        a.exemptionTitle,
      ].join('\t')
    ].join('\n');

    String rateCaption(double? rate) => rate == null ? '' : l.idocBRateCaption(rate.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: isAr ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: IdocBDialogShell(
            title: l.customsDeclAssessmentTitle,
            subtitle: l.customsDeclAssessmentSubtitle,
            icon: Icons.analytics_outlined,
            badge: a.declarationNo,
            body: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!a.isComplete)
                    IdocBNotice(
                      key: const Key('assessmentMissingBanner'),
                      severity: AppSeverity.danger,
                      message: Form46FiguresPanel.missingItemsText(l, a.missing),
                    ),

                  // 1. Shipment particulars
                  IdocBSectionCard(
                    title: l.customsDeclShipmentParticularsHeader,
                    icon: Icons.inventory_2_outlined,
                    child: Column(
                      children: [
                        _buildAssessmentRow(l.customsDeclColDeclarationNo, a.declarationNo, isDark: isDark),
                        _buildAssessmentRow(l.customsDeclColFileNumber, a.primaryNameWithCode, isDark: isDark),
                        _buildAssessmentRow(l.customsDeclColSupplier, a.supplierName, isDark: isDark),
                        _buildAssessmentRow(l.customsDeclAcidNumberLabel, a.acidNumber, isDark: isDark),
                        _buildAssessmentRow(l.customsDeclForm4NumberLabel, a.form4Number, isDark: isDark),
                        _buildAssessmentRow(l.customsDeclBlNumberLabel, a.blNumber, isDark: isDark),
                      ],
                    ),
                  ),

                  // 2. Valuation breakdown (CIF)
                  IdocBSectionCard(
                    title: l.customsDeclValuationBreakdownHeader,
                    icon: Icons.monetization_on_outlined,
                    child: IdocBMoneyTable(
                      itemHeader: l.idocBFigureItemHeader,
                      amountHeader: l.idocBFigureAmountHeader,
                      lines: [
                        IdocBMoneyLine(
                          label: l.customsDeclFobForeignLabel,
                          caption: '${l.customsDeclFxRateLabel}: ${a.exchangeRate.fixedOrMissing(4, _miss)} EGP/${a.currency}',
                          amount: a.fobForeign,
                          currency: a.currency,
                          missingLabel: _miss,
                        ),
                        IdocBMoneyLine(label: l.idocBFobEgpLabel, amount: a.fobEgp, missingLabel: _miss),
                        IdocBMoneyLine(label: l.customsDeclFreightEgpLabel, amount: a.freightEgp, missingLabel: l.idocBNotRecorded),
                        IdocBMoneyLine(label: l.customsDeclInsuranceEgpLabel, amount: a.insuranceEgp, missingLabel: l.idocBNotRecorded),
                        IdocBMoneyLine(
                          label: l.customsDeclCifTotalEgpLabel,
                          kind: IdocBMoneyKind.subtotal,
                          amount: a.cifEgp,
                          missingLabel: _miss,
                        ),
                      ],
                    ),
                  ),

                  // 3. Tariff taxes and duties
                  IdocBSectionCard(
                    title: l.customsDeclTariffTaxesHeader,
                    icon: Icons.receipt_long_outlined,
                    accent: AppTheme.crimson,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAssessmentRow(l.customsDeclColHsCode, '${a.hsCode} (${a.hsDescription})', isDark: isDark),
                        const SizedBox(height: 8),
                        IdocBMoneyTable(
                          itemHeader: l.idocBFigureItemHeader,
                          amountHeader: l.idocBFigureAmountHeader,
                          lines: [
                            IdocBMoneyLine(label: l.customsDeclImportDutyRateLabel, caption: rateCaption(a.dutyRate), amount: a.importDutyEgp, missingLabel: _miss),
                            IdocBMoneyLine(label: l.customsDeclCustomsServicesFeeLabel, caption: rateCaption(a.serviceRate), amount: a.serviceFeeEgp, missingLabel: _miss),
                            if ((a.devRate ?? 0) > 0)
                              IdocBMoneyLine(label: l.customsDeclDevFeeLabel, caption: rateCaption(a.devRate), amount: a.devFeeEgp, missingLabel: _miss),
                            IdocBMoneyLine(label: l.idocBScheduleTaxLabel, amount: a.scheduleTaxEgp, missingLabel: _miss),
                            IdocBMoneyLine(label: l.idocBImportFeeLabel, amount: a.importFeeEgp, missingLabel: _miss),
                            IdocBMoneyLine(label: l.customsDeclVatBaseLabel, kind: IdocBMoneyKind.subtotal, amount: a.vatBaseEgp, missingLabel: _miss),
                            IdocBMoneyLine(label: l.customsDeclVatRateLabel, caption: rateCaption(a.vatRate), amount: a.vatEgp, missingLabel: _miss),
                            IdocBMoneyLine(
                              label: l.customsDeclTotalDutiesLabel,
                              kind: IdocBMoneyKind.total,
                              amount: a.totalDutiesEgp,
                              missingLabel: _miss,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 4. Exemption & trade agreement
                  IdocBSectionCard(
                    title: l.customsDeclExemptionHeader,
                    icon: a.hasExemption ? Icons.verified : Icons.info_outline,
                    accent: a.hasExemption ? AppTheme.emerald : AppTheme.cobalt,
                    margin: EdgeInsets.zero,
                    child: a.exemptionTitle.isEmpty
                        ? IdocBMissingMark(label: _miss)
                        : Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: IdocBStatusChip(
                              label: a.exemptionTitle,
                              severity: a.hasExemption ? AppSeverity.success : AppSeverity.info,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              IdocBDialogAction(
                buttonKey: const Key('copyAssessmentSummaryBtn'),
                label: l.customsDeclCopySummarySuccess,
                icon: Icons.copy,
                onPressed: () => CopyHelper.copy(context, assessmentSummaryText, customMessage: l.customsDeclAssessmentCopySuccess),
              ),
              IdocBDialogAction(
                buttonKey: const Key('copyAssessmentTsvBtn'),
                label: l.customsDeclExportTsvButton,
                icon: Icons.table_chart_outlined,
                onPressed: () => CopyHelper.copy(context, tsvText, customMessage: l.customsDeclExportSuccess),
              ),
              IdocBDialogAction(
                buttonKey: const Key('dialogCloneDeclBtn'),
                label: l.cloneFromAssessmentBtn,
                icon: Icons.copy_all,
                variant: AppButtonVariant.primary,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _onCloneDeclarationSelected(a);
                },
              ),
              IdocBDialogAction(
                label: l.customsDeclCloseDialog,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 450;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: isCompact ? 130 : 200,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
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
                    color: valueColor ?? AppTheme.textPrimaryOf(context),
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
${_hasExemption ? l.customsDeclEur1ExemptionTitle : l.customsDeclMfnExemptionTitle(_appliedDutyRate.fixedOrMissing(1, _miss))}
==================================================
''';

    final isAr = l.isArabic;

    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: isAr ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: IdocBDialogShell(
            title: l.customsDeclPreviewTitle,
            icon: Icons.description_outlined,
            badge: _declaration46NoCtrl.text,
            maxWidth: 640,
            body: SelectionArea(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsetsDirectional.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAltOf(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.borderOf(context)),
                ),
                child: Text(
                  declSummaryText,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.5,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
            ),
            actions: [
              IdocBDialogAction(
                label: l.customsDeclCopySummarySuccess,
                icon: Icons.copy,
                onPressed: () => CopyHelper.copy(context, declSummaryText, customMessage: l.customsDeclCopySummarySuccess),
              ),
              IdocBDialogAction(
                label: l.customsDeclCloseDialog,
                variant: AppButtonVariant.primary,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
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
      _hasExemption ? l.customsDeclEur1ExemptionTitle : l.customsDeclMfnExemptionTitle(_appliedDutyRate.fixedOrMissing(1, _miss)),
    ].join('\t');

    final tsv = '$headers\n$values';
    CopyHelper.copy(context, tsv, customMessage: l.customsDeclExportSuccess);
  }

  void _exportRegistryTsv(List<_DeclarationRegistryItem> items, AppLocalizations l) {
    final headers = [
      l.customsDeclColDeclarationNo,
      l.customsDeclColFileNumber,
      l.customsDeclColSupplier,
      l.customsDeclColRegistrationDate,
      l.ccDecOfficeLabel,
      l.customsDeclChannelLabel,
      l.customsDeclColDeclarationStatus,
      l.customsDeclColTariffEstimate,
    ];

    final rows = items.map((a) => [
      a.declarationNo,
      a.importFileCode,
      a.supplierName,
      a.declarationDate,
      a.customsOffice,
      a.channel,
      a.status,
      a.estimatedDutyTotal.fixedOrMissing(2, _miss),
    ]).toList();

    TableCopyHelper.copyTable(context, headers, rows);
  }

  Future<void> _exportRegistryExcel(List<_DeclarationRegistryItem> items, AppLocalizations l) async {
    final headers = [
      l.customsDeclColDeclarationNo,
      l.customsDeclColFileNumber,
      l.customsDeclColSupplier,
      l.customsDeclColRegistrationDate,
      l.ccDecOfficeLabel,
      l.customsDeclChannelLabel,
      l.customsDeclColDeclarationStatus,
      l.customsDeclColTariffEstimate,
    ];

    final rows = items.map((a) => [
      a.declarationNo,
      a.importFileCode,
      a.supplierName,
      a.declarationDate,
      a.customsOffice,
      a.channel,
      a.status,
      a.estimatedDutyTotal.fixedOrMissing(2, _miss),
    ]).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'Customs Declarations 46 Registry',
      importFileNameOrCode: 'ALL-FILES',
    );
  }

  Future<void> _exportRegistryPdf(List<_DeclarationRegistryItem> items, AppLocalizations l) async {
    final headers = [
      l.customsDeclColDeclarationNo,
      l.customsDeclColFileNumber,
      l.customsDeclColSupplier,
      l.customsDeclColRegistrationDate,
      l.ccDecOfficeLabel,
      l.customsDeclChannelLabel,
      l.customsDeclColDeclarationStatus,
      l.customsDeclColTariffEstimate,
    ];

    final rows = items.map((a) => [
      a.declarationNo,
      a.importFileCode,
      a.supplierName,
      a.declarationDate,
      a.customsOffice,
      a.channel,
      a.status,
      a.estimatedDutyTotal.egpOrMissing(_miss),
    ]).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'Customs Declarations 46 Registry',
      importFileNameOrCode: 'ALL-FILES',
      headerContext: TableExportHeaderContext(
        title: l.customsDeclTabRegistry,
        subtitle: l.customsDeclExportSubtitle,
        metadata: {
          l.customsDeclExportMetaTotal: items.length.toString(),
          l.customsDeclExportMetaGeneratedAt: DateTime.now().toString().substring(0, 19),
        },
      ),
    );
  }

  Future<void> _saveDeclaration46(AppLocalizations l) async {
    if (!_declarationFormKey.currentState!.validate()) return;
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.customsDeclSelectFileWarning, severity: AppSeverity.danger),
      );
      return;
    }

    setState(() => _isSavingDeclaration = true);
    try {
      final payload = <String, dynamic>{
        'import_file_id': _selectedImportFileId!,
        'declaration_46_no': _declaration46NoCtrl.text.trim(),
        'declaration_46_date': _declarationDate.toIso8601String(),
        'customs_office_name': _selectedOffice,
        'channel_type': _selectedChannel,
        'regulatory_bodies': <String>[],
        'mts_certificate_number': null,
        'customs_tariff_items_count': _matchedTariffs.isNotEmpty ? _matchedTariffs.length : 1,
        'inspection_notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      };

      await ref.read(customsClearanceProvider.notifier).registerDeclaration46(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l.customsDeclSaveSuccess, severity: AppSeverity.success),
        );
        ref.invalidate(importFilesProvider);
        setState(() => _selectedSubTab = 1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l.ccDecError(ApiErrorText.of(l, e)), severity: AppSeverity.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingDeclaration = false);
      }
    }
  }
}
