import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/stored_text.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../customs_clearance/providers/customs_clearance_provider.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../freight_booking/providers/freight_booking_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/customs_declaration_assessment.dart';
import '../providers/import_documentation_provider.dart';
import '../services/customs_declaration46_calculator.dart';
import 'form46_figures_panel.dart';
import 'idoc_ui_b.dart';

class CustomsDeclaration46FormTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final CustomsDeclarationAssessment? clonedAssessment;
  final VoidCallback onSaved;
  final VoidCallback onSwitchToRegistry;
  final VoidCallback onOpenSearchAndClone;
  final VoidCallback onRefresh;
  final ValueChanged<bool>? onDirtyChanged;

  const CustomsDeclaration46FormTab({
    super.key,
    this.initialImportFileId,
    this.clonedAssessment,
    required this.onSaved,
    required this.onSwitchToRegistry,
    required this.onOpenSearchAndClone,
    required this.onRefresh,
    this.onDirtyChanged,
  });

  @override
  ConsumerState<CustomsDeclaration46FormTab> createState() => _CustomsDeclaration46FormTabState();
}

class _CustomsDeclaration46FormTabState extends ConsumerState<CustomsDeclaration46FormTab> {
  final _declarationFormKey = GlobalKey<FormState>();
  bool _isDirty = false;

  void _setDirty(bool dirty) {
    if (_isDirty != dirty && mounted) {
      setState(() => _isDirty = dirty);
      if (widget.onDirtyChanged != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onDirtyChanged?.call(dirty);
          }
        });
      }
    }
  }

  late final TextEditingController _declaration46NoCtrl;
  late final TextEditingController _acidNumberCtrl;
  late final TextEditingController _form4NumberCtrl;
  late final TextEditingController _blNumberCtrl;
  late final TextEditingController _customsValueEgpCtrl;
  late final TextEditingController _importDutyEgpCtrl;
  late final TextEditingController _vatEgpCtrl;
  late final TextEditingController _otherFeesEgpCtrl;
  late final TextEditingController _totalDutyAndTaxesCtrl;
  late final TextEditingController _submissionDateCtrl;
  late final TextEditingController _notesCtrl;

  int? _selectedImportFileId;
  DateTime _declarationDate = DateTime.now();
  String? _selectedOffice;
  String? _selectedChannel;

  List<CustomsTariffModel> _matchedTariffs = [];
  bool _hasExemption = false;
  double? _appliedDutyRate;
  List<String> _figuresMissing = const [];
  List<Map<String, dynamic>> _regulatoryApprovals = [];
  bool _isSavingDeclaration = false;

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

  String get _miss => context.l10n.idocBMissing;

  @override
  void initState() {
    super.initState();
    _declaration46NoCtrl = TextEditingController();
    _acidNumberCtrl = TextEditingController();
    _form4NumberCtrl = TextEditingController();
    _blNumberCtrl = TextEditingController();
    _customsValueEgpCtrl = TextEditingController();
    _importDutyEgpCtrl = TextEditingController();
    _vatEgpCtrl = TextEditingController();
    _otherFeesEgpCtrl = TextEditingController();
    _totalDutyAndTaxesCtrl = TextEditingController();
    _submissionDateCtrl = TextEditingController(text: DateTime.now().toString().substring(0, 10));
    _notesCtrl = TextEditingController();

    void onCtrlChange() {
      if (!_isDirty && mounted) {
        _setDirty(true);
      }
    }
    _declaration46NoCtrl.addListener(onCtrlChange);
    _acidNumberCtrl.addListener(onCtrlChange);
    _form4NumberCtrl.addListener(onCtrlChange);
    _blNumberCtrl.addListener(onCtrlChange);
    _customsValueEgpCtrl.addListener(onCtrlChange);
    _notesCtrl.addListener(onCtrlChange);


    _selectedImportFileId = widget.initialImportFileId;
    if (widget.clonedAssessment != null) {
      _applyClonedAssessment(widget.clonedAssessment!);
    } else if (_selectedImportFileId != null) {
      Future.microtask(() => _onImportFileSelected(_selectedImportFileId));
    }
  }

  @override
  void didUpdateWidget(CustomsDeclaration46FormTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clonedAssessment != oldWidget.clonedAssessment && widget.clonedAssessment != null) {
      _applyClonedAssessment(widget.clonedAssessment!);
    } else if (widget.initialImportFileId != oldWidget.initialImportFileId && widget.initialImportFileId != null) {
      _onImportFileSelected(widget.initialImportFileId);
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

  void _applyClonedAssessment(CustomsDeclarationAssessment a) {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final matchedFile = files.where((f) => f.importFileCode == a.importFileCode).firstOrNull;

    setState(() {
      if (matchedFile != null) {
        _selectedImportFileId = matchedFile.importFileId;
      }
      _declaration46NoCtrl.text = '46-DRAFT-${a.importFileCode}';
      _declarationDate = DateTime.now();
      _submissionDateCtrl.text = _declarationDate.toIso8601String().substring(0, 10);
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
      _notesCtrl.text = storedText.idocBCloneDeclNote(a.declarationNo);

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
      _declarationDate = DateTime.now();
      _submissionDateCtrl.text = _declarationDate.toIso8601String().substring(0, 10);
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
      } else {
        _declarationDate = DateTime.now();
        _submissionDateCtrl.text = _declarationDate.toIso8601String().substring(0, 10);
      }
    } else {
      _declarationDate = DateTime.now();
      _submissionDateCtrl.text = _declarationDate.toIso8601String().substring(0, 10);
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

    _customsValueEgpCtrl.text = figures.cifEgp?.toStringAsFixed(2) ?? '';
    _importDutyEgpCtrl.text = figures.importDutyEgp?.toStringAsFixed(2) ?? '';
    _vatEgpCtrl.text = figures.vatEgp?.toStringAsFixed(2) ?? '';
    _otherFeesEgpCtrl.text = figures.otherFeesEgp?.toStringAsFixed(2) ?? '';
    _totalDutyAndTaxesCtrl.text = figures.totalDutiesEgp?.toStringAsFixed(2) ?? '';

    _hasExemption = figures.hasExemption;

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

  Future<void> _saveDeclaration46(AppLocalizations l) async {
    if (!_declarationFormKey.currentState!.validate()) return;
    if (_selectedOffice == null || _selectedChannel == null) return;
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
        'customs_office_name': _selectedOffice!,
        'channel_type': _selectedChannel!,
        'regulatory_bodies': <String>[],
        'mts_certificate_number': null,
        'customs_tariff_items_count': _matchedTariffs.isNotEmpty ? _matchedTariffs.length : 1,
        'inspection_notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      };

      await ref.read(customsClearanceProvider.notifier).registerDeclaration46(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l.customsDeclSaveSuccess,
            severity: AppSeverity.success,
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l.ccDecError(ApiErrorText.of(l, e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingDeclaration = false);
    }
  }

  String _approvalStatusText(Map<String, dynamic> appr, AppLocalizations l) {
    final raw = (appr['status'] ?? '').toString().trim();
    if (raw.isEmpty) return '-';
    final up = raw.toUpperCase();
    if (up == 'APPROVED' || up == 'FULFILLED') return l.customsDeclStatusFulfilled;
    return raw;
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
${l.ccDecOfficeLabel}: ${_selectedOffice ?? '-'}
${l.customsDeclChannelLabel}: ${_selectedChannel ?? '-'}
${l.customsDeclAcidNumberLabel}: ${_acidNumberCtrl.text}
${l.customsDeclForm4NumberLabel}: ${_form4NumberCtrl.text}
${l.customsDeclBlNumberLabel}: ${_blNumberCtrl.text}
--------------------------------------------------
[${l.customsDeclDutiesHeader}]
${l.customsDeclCifTotalEgpLabel}: ${_customsValueEgpCtrl.text}
${l.customsDeclImportDutyRateLabel}: ${_importDutyEgpCtrl.text}
${l.customsDeclVatRateLabel}: ${_vatEgpCtrl.text}
${l.customsDeclTotalDutiesLabel}: ${_totalDutyAndTaxesCtrl.text}
--------------------------------------------------
[${l.customsDeclExemptionHeader}]
${_hasExemption ? l.customsDeclEur1ExemptionTitle : l.customsDeclMfnExemptionTitle(_appliedDutyRate.fixedOrMissing(1, _miss))}
==================================================
''';

    showDialog(
      context: context,
      builder: (ctx) => IdocBDialogShell(
        title: l.customsDeclPreviewTitle,
        icon: Icons.description_outlined,
        badge: _declaration46NoCtrl.text.isNotEmpty ? _declaration46NoCtrl.text : 'DRAFT',
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
      l.ccDecOfficeLabel,
      l.customsDeclChannelLabel,
      l.customsDeclCifTotalEgpLabel,
      l.customsDeclImportDutyRateLabel,
      l.customsDeclVatRateLabel,
      l.customsDeclTotalDutiesLabel,
      l.customsDeclExemptionHeader,
    ];

    final values = [
      _declaration46NoCtrl.text,
      _submissionDateCtrl.text,
      file?.primaryNameWithCode ?? '-',
      file?.supplierName ?? '-',
      _acidNumberCtrl.text,
      _form4NumberCtrl.text,
      _blNumberCtrl.text,
      _selectedOffice ?? '-',
      _selectedChannel ?? '-',
      _customsValueEgpCtrl.text,
      _importDutyEgpCtrl.text,
      _vatEgpCtrl.text,
      _totalDutyAndTaxesCtrl.text,
      _hasExemption ? l.customsDeclEur1ExemptionTitle : l.customsDeclMfnExemptionTitle(_appliedDutyRate.fixedOrMissing(1, _miss)),
    ];

    TableCopyHelper.copyRow(context, values, headers: headers);
  }

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
                          child: AppButton(
                            key: const Key('subtab0SearchAndCloneBtn'),
                            label: l.searchAndCloneCustomsDeclBtn,
                            onPressed: widget.onOpenSearchAndClone,
                            variant: AppButtonVariant.secondary,
                            icon: Icons.copy_all,
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
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        AppButton(
                          key: const Key('subtab0SearchAndCloneBtn'),
                          label: l.searchAndCloneCustomsDeclBtn,
                          onPressed: widget.onOpenSearchAndClone,
                          variant: AppButtonVariant.secondary,
                          icon: Icons.copy_all,
                        ),
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
                  key: const Key('decl46FileDropdown'),
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
                          isRequired: true,
                          validator: (_) => _selectedOffice == null ? l.fieldRequired : null,
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
                          isRequired: true,
                          validator: (_) => _selectedChannel == null ? l.fieldRequired : null,
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
                  AppButton(key: const Key('bottomSearchAndCloneDeclBtn'), label: l.searchAndCloneCustomsDeclBtn, onPressed: widget.onOpenSearchAndClone, variant: AppButtonVariant.secondary, icon: Icons.copy_all),
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
}
