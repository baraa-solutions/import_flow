import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/helpers/file_picker_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_tab_scaffold.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import '../providers/docs_customs_approval_provider.dart';
import '../services/draft_bl_export_service.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import 'search_and_clone_draft_bl_dialog.dart';
import 'visual_draft_bl_sheet.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/services/table_export_service.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';
import '../../auth/providers/auth_provider.dart';

class DraftBLReviewTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  const DraftBLReviewTab({super.key, this.initialImportFileId});

  @override
  ConsumerState<DraftBLReviewTab> createState() => _DraftBLReviewTabState();
}

class _DraftBLReviewTabState extends ConsumerState<DraftBLReviewTab> {
  int _activeStep = 0; // 0: Review Sheet & Checklist, 1: Revision Report, 2: Version Branching, 3: Dual Approval, 4: Final Registry
  int? _selectedImportFileId;

  // Controllers for Raw Text & Draft Inputs
  final TextEditingController _rawTextCtrl = TextEditingController();
  final TextEditingController _draftBlNumberCtrl = TextEditingController();
  final TextEditingController _bookingNoCtrl = TextEditingController();
  final TextEditingController _shipperCtrl = TextEditingController();
  final TextEditingController _consigneeCtrl = TextEditingController();
  final TextEditingController _notifyPartyCtrl = TextEditingController();
  final TextEditingController _shippingLineCtrl = TextEditingController();
  final TextEditingController _vesselNameCtrl = TextEditingController();
  final TextEditingController _voyageCtrl = TextEditingController();
  final TextEditingController _polCtrl = TextEditingController();
  final TextEditingController _podCtrl = TextEditingController();
  final TextEditingController _freightTermsCtrl = TextEditingController(text: 'Freight Prepaid');
  final TextEditingController _placeOfDeliveryCtrl = TextEditingController();
  final TextEditingController _goodsDescCtrl = TextEditingController();
  final TextEditingController _grossWeightCtrl = TextEditingController();
  final TextEditingController _netWeightCtrl = TextEditingController();
  final TextEditingController _cbmCtrl = TextEditingController();
  final TextEditingController _containerNoCtrl = TextEditingController();
  final TextEditingController _sealNoCtrl = TextEditingController();
  final TextEditingController _packagesCountCtrl = TextEditingController();

  // Dual Approval Controllers
  final TextEditingController _importerApproverCtrl = TextEditingController(text: 'Kamal (Import Manager)');
  final TextEditingController _importerNotesCtrl = TextEditingController();
  final TextEditingController _brokerApproverCtrl = TextEditingController();
  final TextEditingController _brokerNotesCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isUploadingFile = false;
  String _registrySearchQuery = '';
  String _selectedStatusFilter = 'ALL'; // ALL, DRAFT, CERTIFIED
  int? _filterImportFileId;
  bool _isSavingDraft = false;
  bool _isCertifying = false;
  String? _uploadedFileName;
  int? _uploadedFileSize;
  String? _extractionStatus;
  List<dynamic> _missingCriticalFields = [];
  String? _safetyWarning;
  DraftBLComparisonResultModel? _comparisonResult;
  DraftBLReviewModel? _activeSession;
  bool _showReferenceAsVisualBL = true;

  @override
  void initState() {
    super.initState();
    // Default approver = the signed-in user (no hard-coded sample name).
    _brokerApproverCtrl.text = ref.read(authProvider).user?.fullName ?? '';
    _selectedImportFileId = widget.initialImportFileId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!ref.read(importFilesProvider).isLoading) {
        await ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
      final files = ref.read(importFilesProvider).valueOrNull ?? [];
      if (_selectedImportFileId == null && files.isNotEmpty && mounted) {
        setState(() {
          _selectedImportFileId = files.first.importFileId;
        });
      }
      if (_selectedImportFileId != null) {
        _runComparison(silent: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant DraftBLReviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImportFileId != oldWidget.initialImportFileId && widget.initialImportFileId != null) {
      _selectedImportFileId = widget.initialImportFileId;
      _runComparison(silent: true);
    }
  }

  Future<void> _runComparison({bool silent = false}) async {
    if (_selectedImportFileId == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.selectImportFileFirst), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final draftFields = <String, dynamic>{};
      if (_draftBlNumberCtrl.text.isNotEmpty) draftFields['draft_bl_number'] = _draftBlNumberCtrl.text.trim();
      if (_bookingNoCtrl.text.isNotEmpty) draftFields['booking_no'] = _bookingNoCtrl.text.trim();
      if (_shipperCtrl.text.isNotEmpty) draftFields['shipper'] = _shipperCtrl.text.trim();
      if (_consigneeCtrl.text.isNotEmpty) draftFields['consignee'] = _consigneeCtrl.text.trim();
      if (_notifyPartyCtrl.text.isNotEmpty) draftFields['notify_party'] = _notifyPartyCtrl.text.trim();
      if (_shippingLineCtrl.text.isNotEmpty) draftFields['shipping_line'] = _shippingLineCtrl.text.trim();
      if (_vesselNameCtrl.text.isNotEmpty) draftFields['vessel_name'] = _vesselNameCtrl.text.trim();
      if (_voyageCtrl.text.isNotEmpty) draftFields['voyage_number'] = _voyageCtrl.text.trim();
      if (_polCtrl.text.isNotEmpty) draftFields['pol'] = _polCtrl.text.trim();
      if (_podCtrl.text.isNotEmpty) draftFields['pod'] = _podCtrl.text.trim();
      if (_freightTermsCtrl.text.isNotEmpty) draftFields['freight_terms'] = _freightTermsCtrl.text.trim();
      if (_placeOfDeliveryCtrl.text.isNotEmpty) draftFields['place_of_delivery'] = _placeOfDeliveryCtrl.text.trim();
      if (_goodsDescCtrl.text.isNotEmpty) draftFields['goods_description'] = _goodsDescCtrl.text.trim();
      if (_grossWeightCtrl.text.isNotEmpty) draftFields['total_gross_weight_kg'] = double.tryParse(_grossWeightCtrl.text);
      if (_netWeightCtrl.text.isNotEmpty) draftFields['total_net_weight_kg'] = double.tryParse(_netWeightCtrl.text);
      if (_cbmCtrl.text.isNotEmpty) draftFields['cbm'] = double.tryParse(_cbmCtrl.text);
      if (_packagesCountCtrl.text.isNotEmpty) draftFields['qty_pkg'] = int.tryParse(_packagesCountCtrl.text);
      if (_containerNoCtrl.text.isNotEmpty) {
        draftFields['container_summary'] = '${_containerNoCtrl.text.trim()} / Seal: ${_sealNoCtrl.text.trim()}';
        draftFields['containers'] = [
          {'container_no': _containerNoCtrl.text.trim(), 'seal_no': _sealNoCtrl.text.trim()}
        ];
      }

      final res = await ref.read(draftBLReviewsProvider.notifier).compareDraftBL(
            _selectedImportFileId!,
            draftFields,
            rawText: _rawTextCtrl.text.isNotEmpty ? _rawTextCtrl.text : null,
          );

      setState(() {
        _comparisonResult = res;

        // Sync back extracted draft fields into controllers if extracted from text
        final d = res.draftData;
        if (d.isNotEmpty) {
          if (d['draft_bl_number'] != null && _draftBlNumberCtrl.text.isEmpty) _draftBlNumberCtrl.text = d['draft_bl_number'].toString();
          if (d['booking_no'] != null && _bookingNoCtrl.text.isEmpty) _bookingNoCtrl.text = d['booking_no'].toString();
          if (d['vessel_name'] != null && _vesselNameCtrl.text.isEmpty) _vesselNameCtrl.text = d['vessel_name'].toString();
          if (d['voyage_number'] != null && _voyageCtrl.text.isEmpty) _voyageCtrl.text = d['voyage_number'].toString();
          if (d['pol'] != null && _polCtrl.text.isEmpty) _polCtrl.text = d['pol'].toString();
          if (d['pod'] != null && _podCtrl.text.isEmpty) _podCtrl.text = d['pod'].toString();
          if (d['freight_terms'] != null && _freightTermsCtrl.text.isEmpty) _freightTermsCtrl.text = d['freight_terms'].toString();
          if (d['total_gross_weight_kg'] != null && _grossWeightCtrl.text.isEmpty) _grossWeightCtrl.text = d['total_gross_weight_kg'].toString();
          if (d['cbm'] != null && _cbmCtrl.text.isEmpty) _cbmCtrl.text = d['cbm'].toString();
          if (d['qty_pkg'] != null && _packagesCountCtrl.text.isEmpty) _packagesCountCtrl.text = d['qty_pkg'].toString();
        }
      });

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.hasBlockingMismatch
                ? context.l10n.draftBlComparisonMismatch(res.openDiscrepanciesCount)
                : context.l10n.draftBlComparisonMatchSuccess),
            backgroundColor: res.hasBlockingMismatch ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.draftBlComparisonError(e.toString())), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _syncExtractedFieldsToControllers(Map<String, dynamic> d) {
    final extractedBl = d['draft_bl_number'] ?? d['bl_number'] ?? d['bl_no'] ?? d['bill_of_lading_no'] ?? d['bill_of_lading_number'] ?? d['b_l_number'] ?? d['bol_number'];
    if (extractedBl != null && extractedBl.toString().trim().isNotEmpty) {
      _draftBlNumberCtrl.text = extractedBl.toString().trim();
    }
    if (d.containsKey('booking_no') && d['booking_no'] != null) _bookingNoCtrl.text = d['booking_no'].toString();
    if (d.containsKey('shipper') && d['shipper'] != null) _shipperCtrl.text = d['shipper'].toString();
    if (d.containsKey('consignee') && d['consignee'] != null) _consigneeCtrl.text = d['consignee'].toString();
    if (d.containsKey('notify_party') && d['notify_party'] != null) _notifyPartyCtrl.text = d['notify_party'].toString();
    if (d.containsKey('shipping_line') && d['shipping_line'] != null) _shippingLineCtrl.text = d['shipping_line'].toString();
    if (d.containsKey('vessel_name') && d['vessel_name'] != null) _vesselNameCtrl.text = d['vessel_name'].toString();
    if (d.containsKey('voyage_number') && d['voyage_number'] != null) _voyageCtrl.text = d['voyage_number'].toString();
    if (d.containsKey('pol') && d['pol'] != null) _polCtrl.text = d['pol'].toString();
    if (d.containsKey('pod') && d['pod'] != null) _podCtrl.text = d['pod'].toString();
    if (d.containsKey('freight_terms') && d['freight_terms'] != null) _freightTermsCtrl.text = d['freight_terms'].toString();
    if (d.containsKey('place_of_delivery') && d['place_of_delivery'] != null) _placeOfDeliveryCtrl.text = d['place_of_delivery'].toString();
    if (d.containsKey('goods_description') && d['goods_description'] != null) _goodsDescCtrl.text = d['goods_description'].toString();
    if (d.containsKey('total_gross_weight_kg') && d['total_gross_weight_kg'] != null) _grossWeightCtrl.text = d['total_gross_weight_kg'].toString();
    if (d.containsKey('total_net_weight_kg') && d['total_net_weight_kg'] != null) _netWeightCtrl.text = d['total_net_weight_kg'].toString();
    if (d.containsKey('cbm') && d['cbm'] != null) _cbmCtrl.text = d['cbm'].toString();
    if (d.containsKey('qty_pkg') && d['qty_pkg'] != null) _packagesCountCtrl.text = d['qty_pkg'].toString();
    if (d.containsKey('container_summary') && d['container_summary'] != null) {
      _containerNoCtrl.text = d['container_summary'].toString();
    }
  }

  void _openSearchAndCloneDraftBlDialog() {
    final allReviews = ref.read(draftBLReviewsProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (ctx) => SearchAndCloneDraftBlDialog(
        reviews: allReviews,
        onSelectReview: _onCloneDraftBlSession,
      ),
    );
  }

  void _onCloneDraftBlSession(DraftBLReviewModel session) {
    final blNumber = (session.draftExtractedData?['draft_bl_number'] ??
            session.draftExtractedData?['bl_number'] ??
            session.systemDataSnapshot?['draft_bl_number'] ??
            session.draftBlNumber)
        .toString();

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: CloneEntityReviewDialog(
            entityType: 'مسودة بوليصة الشحن (Draft B/L Review)',
            sourceCode: session.blReviewCode,
            sourceTitle: '$blNumber — ${session.shippingLine ?? ""}',
            suggestedNewCode: 'DRAFT-BL-2026-',
            copiedFieldsSummary: {
              'الخط الملاحي': session.shippingLine ?? '-',
              'اسم السفينة / الرحلة': '${session.vesselName ?? "-"} / ${session.voyageNumber ?? "-"}',
              'رقم الحجز (Booking)': session.bookingNumber ?? '-',
              'شروط النولون': session.freightTerms ?? 'Prepaid',
              'ميناء الشحن / الوصول': '${session.polName ?? "-"} -> ${session.podName ?? "-"}',
            },
            mandatorilyResetFields: const [
              'رقم مسودة البوليصة: يتم تصفيره إلى كود مسودة مؤقت (DRAFT-BL-2026-)',
              'معرف جلسة المراجعة السابقة: تم فك الارتباط وبدء جلسة جديدة',
              'اعتماد المستورد: يعاد إلى قيد الانتظار (Pending) وتفريغ الملاحظات',
              'اعتماد المخلص الجمركي: يعاد إلى قيد الانتظار (Pending) وتفريغ الملاحظات',
              'لقطة بيانات النظام: يتم تحديثها ومطابقتها مع ملف الشحنة المختار',
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
              setState(() {
                _activeSession = null;
                _activeStep = 0; // Jump to Review Sheet Stage
                _draftBlNumberCtrl.text = newCode.isNotEmpty ? newCode : 'DRAFT-BL-2026-';
                if (session.bookingNumber != null) _bookingNoCtrl.text = session.bookingNumber!;
                if (session.shippingLine != null) _shippingLineCtrl.text = session.shippingLine!;
                if (session.vesselName != null) _vesselNameCtrl.text = session.vesselName!;
                if (session.voyageNumber != null) _voyageCtrl.text = session.voyageNumber!;
                if (session.polName != null) _polCtrl.text = session.polName!;
                if (session.podName != null) _podCtrl.text = session.podName!;
                if (session.freightTerms != null) _freightTermsCtrl.text = session.freightTerms!;
                if (session.placeOfDelivery != null) _placeOfDeliveryCtrl.text = session.placeOfDelivery!;
                _cbmCtrl.text = session.measurementCbm.toString();
                _netWeightCtrl.text = session.netWeightKg.toString();
                _packagesCountCtrl.text = session.packagesCount.toString();
                if (session.containerSummary != null) _containerNoCtrl.text = session.containerSummary!;

                final draftData = session.draftExtractedData ?? {};
                if (draftData.isNotEmpty) {
                  _syncExtractedFieldsToControllers(draftData);
                  _draftBlNumberCtrl.text = newCode.isNotEmpty ? newCode : 'DRAFT-BL-2026-';
                }

                _importerNotesCtrl.clear();
                _brokerNotesCtrl.clear();
              });

              if (_selectedImportFileId != null) {
                await _runComparison(silent: true);
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.cloneDraftBlSuccess),
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

  Future<void> _pickAndExtractFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'xlsx', 'xls', 'txt', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileBytes = FilePickerHelper.getBytes(file);
      if (fileBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.draftBlFileReadError), backgroundColor: Colors.red),
          );
        }
        return;
      }

      setState(() {
        _isUploadingFile = true;
        _uploadedFileName = file.name;
        _uploadedFileSize = file.size;
      });

      final res = await ref.read(draftBLReviewsProvider.notifier).extractDraftBLFromFile(
            fileBytes,
            file.name,
            importFileId: _selectedImportFileId,
          );

      final rawText = res['raw_text'] as String? ?? '';
      final extractedFields = res['extracted_fields'] as Map<String, dynamic>? ?? {};
      final extractionStatus = res['extraction_status'] as String? ?? 'EXTRACTION_COMPLETE';
      final missingCritical = res['missing_critical_fields'] as List? ?? [];
      final safetyWarning = res['safety_warning'] as String?;

      setState(() {
        _rawTextCtrl.text = rawText;
        _extractionStatus = extractionStatus;
        _missingCriticalFields = missingCritical;
        _safetyWarning = safetyWarning;
        _syncExtractedFieldsToControllers(extractedFields);

        if (res['comparison_result'] != null) {
          _comparisonResult = DraftBLComparisonResultModel.fromJson(res['comparison_result']);
        }
      });

      if (_selectedImportFileId != null && res['comparison_result'] == null) {
        await _runComparison(silent: true);
      }

      if (mounted) {
        if (missingCritical.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.draftBlExtractedWithCritical(file.name)),
              backgroundColor: Colors.amber.shade900,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.draftBlExtractedSuccess(file.name)),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.draftBlExtractionError(e.toString())), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingFile = false);
      }
    }
  }

  Future<void> _saveReview({bool isDraft = false}) async {
    if (_comparisonResult == null || _selectedImportFileId == null) {
      if (_selectedImportFileId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.selectImportFileFirst), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (!isDraft && _comparisonResult!.hasBlockingMismatch) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.crimson),
              SizedBox(width: 8),
              Text('تأكيد الاعتماد النهائي للبوليصة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'توجد فروقات حرجة (${_comparisonResult!.openDiscrepanciesCount}) مسجلة في فحص البوليصة.\nهل أنت متأكد من رغبتك في الاعتماد النهائي وتحديث الموافقة الجمركية على الأوراق والانتقال لمرحلة شهادة المنشأ؟',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الاعتماد النهائي'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      if (isDraft) {
        _isSavingDraft = true;
      } else {
        _isCertifying = true;
      }
      _isLoading = true;
    });

    try {
      final payload = {
        'import_file_id': _selectedImportFileId,
        'draft_bl_number': _draftBlNumberCtrl.text.trim().isNotEmpty
            ? _draftBlNumberCtrl.text.trim()
            : (_comparisonResult?.draftData['draft_bl_number']?.toString() ?? 'DRAFT-BL-${DateTime.now().millisecondsSinceEpoch}'),
        'shipping_line': _shippingLineCtrl.text.trim().isNotEmpty ? _shippingLineCtrl.text.trim() : (_comparisonResult?.draftData['shipping_line']?.toString() ?? ''),
        'vessel_name': _vesselNameCtrl.text.trim().isNotEmpty ? _vesselNameCtrl.text.trim() : (_comparisonResult?.draftData['vessel_name']?.toString() ?? ''),
        'voyage_number': _voyageCtrl.text.trim().isNotEmpty ? _voyageCtrl.text.trim() : (_comparisonResult?.draftData['voyage_number']?.toString() ?? ''),
        'booking_no': _bookingNoCtrl.text.trim().isNotEmpty ? _bookingNoCtrl.text.trim() : (_comparisonResult?.draftData['booking_no']?.toString() ?? ''),
        'freight_terms': _freightTermsCtrl.text.trim().isNotEmpty ? _freightTermsCtrl.text.trim() : (_comparisonResult?.draftData['freight_terms']?.toString() ?? 'Prepaid'),
        'place_of_delivery': _placeOfDeliveryCtrl.text.trim().isNotEmpty ? _placeOfDeliveryCtrl.text.trim() : (_comparisonResult?.draftData['place_of_delivery']?.toString() ?? ''),
        'importer_tax_id': _comparisonResult?.systemData['importer_tax_id']?.toString() ?? '',
        'shipper_reg_id': _comparisonResult?.systemData['shipper_reg_id']?.toString() ?? '',
        'measurement_cbm': double.tryParse(_cbmCtrl.text) ?? ((_comparisonResult?.draftData['cbm'] as num?)?.toDouble() ?? 0.0),
        'net_weight_kg': double.tryParse(_netWeightCtrl.text) ?? ((_comparisonResult?.draftData['total_net_weight_kg'] as num?)?.toDouble() ?? 0.0),
        'packages_count': int.tryParse(_packagesCountCtrl.text) ?? ((_comparisonResult?.draftData['qty_pkg'] as num?)?.toInt() ?? 0),
        'container_summary': _containerNoCtrl.text.trim().isNotEmpty ? _containerNoCtrl.text.trim() : (_comparisonResult?.draftData['container_summary']?.toString() ?? ''),
        'stage': _comparisonResult!.stage,
        'system_snapshot_data': _comparisonResult!.systemData,
        'draft_input_data': _comparisonResult!.draftData,
        'comparison_matrix': _comparisonResult!.matrix.map((m) => m.toJson()).toList(),
        'checklist_data': _comparisonResult!.checklist.map((c) => c.toJson()).toList(),
        'revision_report_data': _comparisonResult!.revisionReport.map((r) => r.toJson()).toList(),
        'has_blocking_mismatch': _comparisonResult!.hasBlockingMismatch,
        'open_discrepancies_count': _comparisonResult!.openDiscrepanciesCount,
        'blocking_reasons': _comparisonResult!.blockingReasons,
        'status': isDraft ? 'DRAFT' : 'APPROVED',
        'is_draft': isDraft,
        'correction_request_letter': _comparisonResult!.correctionRequestLetter,
      };

      final created = await ref.read(draftBLReviewsProvider.notifier).saveDraftBLReview(payload);
      ref.invalidate(importFilesProvider);
      ref.invalidate(docsCustomsApprovalProvider);
      ref.invalidate(smartTasksProvider);

      setState(() {
        _activeSession = created;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(isDraft ? Icons.bookmark_added_rounded : Icons.verified_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isDraft
                        ? 'تم حفظ مسودة جلسة مراجعة البوليصة بنجاح (${created.blReviewCode})'
                        : 'تم الاعتماد النهائي لمسودة البوليصة (${created.blReviewCode}) وتحديث الموافقة الجمركية والانتقال لمرحلة شهادة المنشأ بنجاح',
                  ),
                ),
              ],
            ),
            backgroundColor: isDraft ? AppTheme.cobalt : AppTheme.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء حفظ الجلسة: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
          _isCertifying = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateChecklistRow(
    int idx, {
    dynamic draftValue,
    String? status,
    String? correction,
    String? reason,
    String? respParty,
  }) async {
    if (_comparisonResult == null) return;
    setState(() {
      final old = _comparisonResult!.checklist[idx];
      final newDraft = draftValue ?? old.draftValue;

      String newStatus = status ?? old.status;
      if (draftValue != null && status == null) {
        final sysStr = (old.systemValue?.toString() ?? '').trim().toLowerCase();
        final draftStr = (newDraft?.toString() ?? '').trim().toLowerCase();
        if (draftStr.isNotEmpty && sysStr == draftStr) {
          newStatus = 'Correct';
        } else if (draftStr.isNotEmpty && sysStr != draftStr) {
          newStatus = 'Incorrect';
        }
      }

      _comparisonResult!.checklist[idx] = DraftBLChecklistItemModel(
        fieldKey: old.fieldKey,
        fieldLabelAr: old.fieldLabelAr,
        fieldLabelEn: old.fieldLabelEn,
        sourceEntity: old.sourceEntity,
        systemValue: old.systemValue,
        draftValue: newDraft,
        status: newStatus,
        requiredCorrection: correction ?? (newStatus == 'Correct' ? null : old.requiredCorrection),
        reason: reason ?? old.reason,
        // A typed reason replaces the system message: keep the text, drop the code.
        reasonCode: reason != null ? null : old.reasonCode,
        reasonParams: reason != null ? null : old.reasonParams,
        notes: old.notes,
        responsibleParty: respParty ?? old.responsibleParty,
        isLocked: old.isLocked,
        previousStatus: old.previousStatus,
      );
    });

    if (_activeSession != null) {
      try {
        final updated = await ref.read(draftBLReviewsProvider.notifier).updateDraftBLChecklist(
              _activeSession!.blReviewId,
              _comparisonResult!.checklist,
            );
        setState(() {
          _activeSession = updated;
        });
      } catch (_) {}
    }
  }

  Future<void> _submitApproval(String role, String action) async {
    if (_activeSession == null) {
      await _saveReview();
    }
    if (_activeSession == null) return;

    setState(() => _isLoading = true);
    try {
      String approver = role == 'importer' ? _importerApproverCtrl.text.trim() : _brokerApproverCtrl.text.trim();
      String? notes = role == 'importer' ? _importerNotesCtrl.text.trim() : _brokerNotesCtrl.text.trim();

      final updated = await ref.read(draftBLReviewsProvider.notifier).submitDualApproval(
            _activeSession!.blReviewId,
            role,
            action,
            approver,
            notes: notes,
          );

      setState(() {
        _activeSession = updated;
      });

      ref.invalidate(importFilesProvider);
      ref.invalidate(docsCustomsApprovalProvider);
      ref.invalidate(smartTasksProvider);

      if (mounted) {
        if (updated.stage == 'Stage 5: Final') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.draftBlDualApprovalCompleted), backgroundColor: Colors.green),
          );
          setState(() => _activeStep = 4);
        } else if (action == 'Rejected') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.draftBlRevisionRequiredAlert), backgroundColor: Colors.red),
          );
          setState(() => _activeStep = 1);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.draftBlRoleApprovalRegistered(role)), backgroundColor: Colors.blue),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.draftBlApprovalError(e.toString())), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _rawTextCtrl.dispose();
    _draftBlNumberCtrl.dispose();
    _bookingNoCtrl.dispose();
    _shipperCtrl.dispose();
    _consigneeCtrl.dispose();
    _notifyPartyCtrl.dispose();
    _shippingLineCtrl.dispose();
    _vesselNameCtrl.dispose();
    _voyageCtrl.dispose();
    _polCtrl.dispose();
    _podCtrl.dispose();
    _freightTermsCtrl.dispose();
    _placeOfDeliveryCtrl.dispose();
    _goodsDescCtrl.dispose();
    _grossWeightCtrl.dispose();
    _netWeightCtrl.dispose();
    _cbmCtrl.dispose();
    _containerNoCtrl.dispose();
    _sealNoCtrl.dispose();
    _packagesCountCtrl.dispose();
    _importerApproverCtrl.dispose();
    _importerNotesCtrl.dispose();
    _brokerApproverCtrl.dispose();
    _brokerNotesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final allReviews = ref.watch(draftBLReviewsProvider).valueOrNull ?? [];

    final l10n = context.l10n;

    return AdaptiveTabScaffold(
      selectedIndex: _activeStep,
      onTabSelected: (index) => setState(() => _activeStep = index),
      accentColor: AppTheme.cobalt,
      tabs: [
        AdaptiveTabItem(
          icon: Icons.fact_check,
          label: l10n.draftBlStage0ReviewSheet,
          content: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildStage1UnifiedReviewSheetView(importFiles),
          ),
        ),
        AdaptiveTabItem(
          icon: Icons.assignment_late,
          label: l10n.draftBlStage1RevisionReport,
          content: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildStage2RevisionView(importFiles),
          ),
        ),
        AdaptiveTabItem(
          icon: Icons.history,
          label: l10n.draftBlStage2VersionBranching,
          content: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildStage3VersionBranchingView(importFiles),
          ),
        ),
        AdaptiveTabItem(
          icon: Icons.verified_user,
          label: l10n.draftBlStage3DualApproval,
          content: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildStage4DualApprovalView(importFiles),
          ),
        ),
        AdaptiveTabItem(
          icon: Icons.inventory_2,
          label: l10n.draftBlStage4FinalRegistry,
          content: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildStage5FinalRegistryView(allReviews),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // STAGE 1: UNIFIED DOCUMENT REVIEW SHEET (SUMMARY + RAW TEXT + CHECKLIST)
  // ===========================================================================
  Widget _buildStage1UnifiedReviewSheetView(List<dynamic> importFiles) {
    final sys = _comparisonResult?.systemData ?? {};
    final checklist = _comparisonResult?.checklist ?? [];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header & File Selector Card
        Card(
          elevation: 2,
          color: isDark ? AppTheme.darkCardBackground : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, _) {
                    final messenger = ScaffoldMessenger.of(context);
                    final l = context.l10n;

                    final actionWidgets = [
                      OutlinedButton.icon(
                        key: const Key('stage1SearchAndCloneBtn'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.copy_all, size: 16, color: AppTheme.wcagCobalt),
                        label: Text(l.searchAndCloneDraftBlBtn, style: const TextStyle(fontSize: 12)),
                        onPressed: _openSearchAndCloneDraftBlDialog,
                      ),
                      if (_comparisonResult != null) ...[
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await DraftBLExportService.exportDraftBLToPdf(
                                systemData: _comparisonResult!.systemData,
                                draftData: _comparisonResult!.draftData,
                                draftBlNumber: _draftBlNumberCtrl.text.isNotEmpty ? _draftBlNumberCtrl.text : null,
                                bookingNumber: _bookingNoCtrl.text.isNotEmpty ? _bookingNoCtrl.text : null,
                              );
                            } catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(l.draftBlPdfExportError(e.toString())), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 15),
                          label: Text(l.draftBlDownloadPdfButton, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.crimson,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final res = await DraftBLExportService.exportDraftBLToExcel(
                                systemData: _comparisonResult!.systemData,
                                draftData: _comparisonResult!.draftData,
                                draftBlNumber: _draftBlNumberCtrl.text.isNotEmpty ? _draftBlNumberCtrl.text : null,
                                bookingNumber: _bookingNoCtrl.text.isNotEmpty ? _bookingNoCtrl.text : null,
                              );
                              if (mounted && res != null) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(l.excelExportSuccess(res)), backgroundColor: Colors.green),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(l.excelExportError(e.toString())), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.table_chart, color: Colors.white, size: 15),
                          label: Text(context.l10n.draftBlDownloadExcelButton, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _comparisonResult!.hasBlockingMismatch
                                ? (isDark ? const Color(0xFF3B1E1E) : Colors.red.shade50)
                                : (isDark ? const Color(0xFF064E3B) : Colors.green.shade50),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _comparisonResult!.hasBlockingMismatch
                                  ? (isDark ? const Color(0xFFEF4444) : Colors.red)
                                  : (isDark ? const Color(0xFF059669) : Colors.green),
                            ),
                          ),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Icon(
                                _comparisonResult!.hasBlockingMismatch ? Icons.error : Icons.check_circle,
                                color: _comparisonResult!.hasBlockingMismatch
                                    ? (isDark ? const Color(0xFFF87171) : Colors.red)
                                    : (isDark ? const Color(0xFF6EE7B7) : Colors.green),
                                size: 16,
                              ),
                              Text(
                                _comparisonResult!.hasBlockingMismatch
                                    ? context.l10n.draftBlMismatchesFound(_comparisonResult!.openDiscrepanciesCount)
                                    : context.l10n.draftBlPerfectMatchReady,
                                style: TextStyle(
                                  color: _comparisonResult!.hasBlockingMismatch
                                      ? (isDark ? const Color(0xFFFCA5A5) : Colors.red.shade900)
                                      : (isDark ? const Color(0xFF6EE7B7) : Colors.green.shade900),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ];

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          children: [
                            const Icon(Icons.description, color: AppTheme.wcagCobalt, size: 26),
                            Text(
                              context.l10n.draftBlReviewSheetTitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                            ),
                          ],
                        ),
                        ...actionWidgets,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.draftBlReviewSheetSub,
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
                Divider(height: 24, color: isDark ? AppTheme.darkBorder : null),
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final isCompact = constraints.maxWidth < 650;
                    final dropdown = SearchableDropdownField<int>(
                      value: _selectedImportFileId,
                      labelText: context.l10n.draftBlSelectImportFileLabel,
                      searchHintText: context.l10n.searchFileOrShipmentHint,
                      items: importFiles
                          .map((f) => SearchableDropdownItem<int>(
                                value: f.importFileId,
                                label: '${f.primaryNameWithCode} - ${f.companyName} (${f.supplierName})',
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null && v != _selectedImportFileId) {
                          setState(() {
                            _selectedImportFileId = v;
                            _rawTextCtrl.clear();
                            _draftBlNumberCtrl.clear();
                            _bookingNoCtrl.clear();
                            _shipperCtrl.clear();
                            _consigneeCtrl.clear();
                            _notifyPartyCtrl.clear();
                            _shippingLineCtrl.clear();
                            _vesselNameCtrl.clear();
                            _voyageCtrl.clear();
                            _polCtrl.clear();
                            _podCtrl.clear();
                            _freightTermsCtrl.clear();
                            _placeOfDeliveryCtrl.clear();
                            _goodsDescCtrl.clear();
                            _grossWeightCtrl.clear();
                            _netWeightCtrl.clear();
                            _cbmCtrl.clear();
                            _packagesCountCtrl.clear();
                            _containerNoCtrl.clear();
                            _sealNoCtrl.clear();
                            _comparisonResult = null;
                            _activeSession = null;
                          });
                          _runComparison(silent: false);
                        }
                      },
                    );

                    final refreshBtn = ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cobalt,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.sync, color: Colors.white),
                      label: Text(context.l10n.draftBlRefreshAndCompare, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: _isLoading ? null : () => _runComparison(silent: false),
                    );

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          dropdown,
                          const SizedBox(height: 10),
                          refreshBtn,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: dropdown,
                        ),
                        const SizedBox(width: 16),
                        refreshBtn,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Multi-Format Smart Extractor Card (PDF / Word / Excel / Text)
        Card(
          elevation: 2,
          color: isDark ? AppTheme.darkCardBackground : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final isNarrow = constraints.maxWidth < 650;
                    final badges = Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildFormatBadge('PDF', Colors.red),
                        _buildFormatBadge('Word (.docx)', Colors.blue),
                        _buildFormatBadge('Excel (.xlsx)', Colors.green),
                        _buildFormatBadge('Text / OCR', Colors.teal),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.document_scanner, color: AppTheme.cobalt, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.l10n.draftBlSmartExtractorTitle,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : AppTheme.charcoal),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(context.l10n.draftBlSmartExtractorSub, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey)),
                          const SizedBox(height: 8),
                          badges,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        const Icon(Icons.document_scanner, color: AppTheme.cobalt, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.l10n.draftBlSmartExtractorTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : AppTheme.charcoal)),
                              const SizedBox(height: 2),
                              Text(context.l10n.draftBlSmartExtractorSub, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey)),
                            ],
                          ),
                        ),
                        badges,
                      ],
                    );
                  },
                ),
                Divider(height: 24, color: isDark ? AppTheme.darkBorder : null),

                // File Upload Button & Selected File Status
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B365D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isUploadingFile
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.upload_file, size: 20),
                      label: Text(
                        _isUploadingFile ? context.l10n.draftBlExtractingFileProgress : context.l10n.draftBlUploadAndExtractButton,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: _isUploadingFile ? null : _pickAndExtractFile,
                    ),
                    if (_uploadedFileName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50,
                          border: Border.all(color: isDark ? Colors.green.shade700 : Colors.green.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 18),
                            Text(
                              context.l10n.draftBlFileExtractedSuccess(_uploadedFileName!, ((_uploadedFileSize ?? 0) / 1024).toStringAsFixed(1)),
                              style: TextStyle(color: isDark ? Colors.greenAccent : Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18, color: Colors.green),
                              tooltip: context.l10n.draftBlReuploadTooltip,
                              onPressed: _pickAndExtractFile,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                // Extracted B/L Number Quick Display Card
                if (_draftBlNumberCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withOpacity(isDark ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cobalt.withOpacity(0.35)),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          children: [
                            const Icon(Icons.confirmation_number_outlined, color: AppTheme.cobalt, size: 22),
                            Text(
                              context.l10n.draftBlExtractedBlNumberLabel,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : AppTheme.charcoal),
                            ),
                          ],
                        ),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.cobalt.withOpacity(0.4)),
                              ),
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                children: [
                                  Text(
                                    _draftBlNumberCtrl.text,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppTheme.cobaltLight : AppTheme.cobalt, fontFamily: 'monospace'),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: _draftBlNumberCtrl.text));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(context.l10n.draftBlCopiedBlNumberSnackbar(_draftBlNumberCtrl.text))),
                                      );
                                    },
                                    child: Tooltip(
                                      message: context.l10n.draftBlCopyBlNumberTooltip,
                                      child: Icon(Icons.copy, size: 16, color: isDark ? AppTheme.cobaltLight : AppTheme.cobalt),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              icon: Icon(Icons.edit, size: 14, color: isDark ? Colors.grey.shade300 : AppTheme.charcoal),
                              label: Text(context.l10n.edit, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : AppTheme.charcoal)),
                              onPressed: () {
                            showDialog(
                              context: context,
                              builder: (dCtx) {
                                final editCtrl = TextEditingController(text: _draftBlNumberCtrl.text);
                                return AlertDialog(
                                  title: Text(context.l10n.draftBlEditBlNumberTitle),
                                  content: TextField(
                                    controller: editCtrl,
                                    decoration: InputDecoration(labelText: context.l10n.draftBlRegistryColBlNumber, border: const OutlineInputBorder()),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(dCtx), child: Text(context.l10n.cancel)),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                                      onPressed: () {
                                        setState(() {
                                          _draftBlNumberCtrl.text = editCtrl.text.trim();
                                        });
                                        Navigator.pop(dCtx);
                                      },
                                      child: Text(context.l10n.save, style: const TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
                                // Safety Guardrail Warning Banner
                if (_missingCriticalFields.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade700, width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.amber.shade900, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.draftBlSafetyAlertTitle,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _safetyWarning ?? context.l10n.draftBlSafetyAlertSub,
                                style: TextStyle(fontSize: 12, color: Colors.brown.shade900),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: _missingCriticalFields.map((f) {
                                  final label = f is Map ? (f['field_label'] ?? f['field_key']) : f.toString();
                                  return Chip(
                                    label: Text(label.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                    backgroundColor: Colors.amber.shade800,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_uploadedFileName != null && _extractionStatus == 'EXTRACTION_COMPLETE') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade400),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.draftBlSmartExtractionComplete,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Optional Text Paste Area Expander
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8),
                  title: Text(
                    context.l10n.draftBlPasteRawTextTitle,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  children: [
                    TextFormField(
                      controller: _rawTextCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: context.l10n.draftBlPasteRawTextHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        icon: const Icon(Icons.flash_on, size: 16),
                        label: Text(context.l10n.draftBlExtractFromTextButton, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () => _runComparison(silent: false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // SECTION 1: AUTO GENERATED SHIPMENT SUMMARY (REFERENCE VALUES AS VISUAL B/L)
        if (_showReferenceAsVisualBL) ...[
          VisualDraftBLSheet(
            systemData: sys,
            draftData: sys,
            isReferenceOnly: true,
            title: context.l10n.draftBlReferenceVisualSheetTitle,
            subtitle: context.l10n.draftBlReferenceVisualSheetSub,
            onRefresh: () => _runComparison(silent: true),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: TextButton.icon(
                onPressed: () => setState(() => _showReferenceAsVisualBL = false),
                icon: const Icon(Icons.grid_view, size: 16, color: AppTheme.cobalt),
                label: Text(context.l10n.draftBlSwitchToGridView, style: const TextStyle(fontSize: 12, color: AppTheme.cobalt, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ] else ...[
          Card(
            elevation: 2,
            color: isDark ? AppTheme.darkCardBackground : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          const Icon(Icons.hub, color: AppTheme.cobalt, size: 22),
                          Text(
                            context.l10n.draftBlAutoSummaryTitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.charcoal,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.cobalt,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.description, size: 16),
                            label: Text(context.l10n.draftBlSwitchToVisualBl, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => setState(() => _showReferenceAsVisualBL = true),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.cobalt,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.print, size: 16),
                            label: Text(context.l10n.draftBlPrintButton, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => DraftBLExportService.printDraftBL(
                              systemData: sys,
                              draftData: sys,
                              documentTitle: 'SYSTEM REFERENCE BILL OF LADING — NOT NEGOTIABLE',
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.crimson,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.picture_as_pdf, size: 16),
                            label: Text(context.l10n.draftBlDownloadPdfButton, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => DraftBLExportService.exportDraftBLToPdf(
                              systemData: sys,
                              draftData: sys,
                              documentTitle: 'SYSTEM REFERENCE BILL OF LADING — NOT NEGOTIABLE',
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.emerald,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.table_chart, size: 16),
                            label: Text(context.l10n.draftBlDownloadExcelButton, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => DraftBLExportService.exportDraftBLToExcel(
                              systemData: sys,
                              draftData: sys,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.draftBlAutoSummarySub,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const Divider(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildSummaryBox(context.l10n.draftBlSummaryShipper, sys['shipper'] ?? context.l10n.unspecified, Icons.business, Colors.indigo, flex: 2),
                      _buildSummaryBox(context.l10n.draftBlSummaryConsignee, sys['consignee'] ?? context.l10n.unspecified, Icons.account_balance, Colors.blue, flex: 2),
                      _buildSummaryBox(context.l10n.draftBlSummaryNotifyParty, sys['notify_party'] ?? 'SAME AS CONSIGNEE', Icons.notifications_active, Colors.cyan, flex: 2),
                      _buildSummaryBox(context.l10n.draftBlSummaryVesselVoyage, '${sys['vessel_name'] ?? 'N/A'} - ${sys['voyage_number'] ?? 'N/A'}', Icons.directions_boat, Colors.teal),
                      _buildSummaryBox(context.l10n.draftBlSummaryPorts, '${sys['pol'] ?? 'N/A'} ➔ ${sys['pod'] ?? 'N/A'}', Icons.anchor, Colors.purple),
                      _buildSummaryBox(context.l10n.draftBlSummaryFreightTerms, sys['freight_terms'] ?? 'Freight Prepaid', Icons.payment, Colors.orange),
                      _buildSummaryBox(context.l10n.draftBlSummaryBookingNo, sys['booking_no'] ?? 'N/A', Icons.confirmation_number, Colors.brown),
                      _buildSummaryBox(context.l10n.draftBlSummaryAcidNo, sys['acid_number'] ?? 'N/A', Icons.security, Colors.red, isCritical: true),
                      _buildSummaryBox(context.l10n.draftBlSummaryImporterTaxId, sys['importer_tax_id'] ?? 'N/A', Icons.badge, Colors.red, isCritical: true),
                      _buildSummaryBox(context.l10n.draftBlSummaryShipperReg, sys['shipper_reg_id'] ?? 'N/A', Icons.pin, Colors.red, isCritical: true),
                      _buildSummaryBox(context.l10n.draftBlSummaryContainers, sys['container_summary'] ?? 'N/A', Icons.inventory, Colors.teal, flex: 2),
                      _buildSummaryBox(context.l10n.draftBlSummaryGrossWeight, '${sys['total_gross_weight_kg'] ?? 0.0} kg', Icons.scale, Colors.green),
                      _buildSummaryBox(context.l10n.draftBlSummaryNetWeight, '${sys['total_net_weight_kg'] ?? 0.0} kg', Icons.fitness_center, Colors.indigo),
                      _buildSummaryBox(context.l10n.draftBlSummaryCbm, '${sys['cbm'] ?? 0.0} CBM', Icons.view_in_ar, Colors.orange),
                      _buildSummaryBox(context.l10n.draftBlSummaryPackages, '${sys['qty_pkg'] ?? 0} (${sys['goods_description'] ?? 'Goods'})', Icons.category, Colors.deepPurple, flex: 2),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // SECTION 2: REVIEW CHECKLIST TABLE (THE 20-FIELD COMPARISON ENGINE)
        Card(
          elevation: 2,
          color: isDark ? AppTheme.darkCardBackground : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        const Icon(Icons.checklist_rtl, color: AppTheme.cobalt, size: 24),
                        Text(
                          context.l10n.draftBlChecklistSectionTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.charcoal,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('draftBlSaveDraftBtn'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.cobalt,
                            side: const BorderSide(color: AppTheme.cobalt),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: _isSavingDraft
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.bookmark_added_outlined, size: 18),
                          label: const Text('حفظ مسودة مؤقتة', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _isLoading ? null : () => _saveReview(isDraft: true),
                        ),
                        ElevatedButton.icon(
                          key: const Key('draftBlCertifyBtn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: _isCertifying
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.verified_rounded, size: 18),
                          label: const Text('اعتماد نهائي للمستندات', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _isLoading ? null : () => _saveReview(isDraft: false),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.assignment_late, color: Colors.white, size: 18),
                          label: Text(context.l10n.draftBlRevisionReportCarrierButton, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () => setState(() => _activeStep = 1),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.draftBlChecklistSectionSub,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const Divider(height: 20),
                if (checklist.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(context.l10n.draftBlSelectFileToStartChecklist, style: const TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 70,
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                      columns: [
                        DataColumn(label: Text(context.l10n.draftBlChecklistColField, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(context.l10n.draftBlChecklistColSystemValue, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(context.l10n.draftBlChecklistColDraftValue, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(context.l10n.draftBlChecklistColStatus, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(context.l10n.draftBlChecklistColRequiredAction, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(context.l10n.draftBlChecklistColResponsibleParty, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(context.l10n.draftBlChecklistColReasonNotes, style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: checklist.asMap().entries.map((entry) {
                        int idx = entry.key;
                        var itm = entry.value;
                        bool isCorrect = itm.status == 'Correct';
                        bool isNA = itm.status == 'N/A';

                        return DataRow(
                          color: WidgetStateProperty.resolveWith((_) {
                            if (!isCorrect && !isNA) return Colors.red.shade50.withOpacity(0.5);
                            return null;
                          }),
                          cells: [
                            // Field Name
                            DataCell(
                              SizedBox(
                                width: 170,
                                child: CopyableText(
                                  Localizations.localeOf(context).languageCode == 'ar' ? itm.fieldLabelAr : itm.fieldLabelEn,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                            // System Value
                            DataCell(
                              SizedBox(
                                width: 190,
                                child: CopyableText(
                                  itm.systemValue?.toString() ?? 'N/A',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            // Draft Value (Editable in-place)
                            DataCell(
                              SizedBox(
                                width: 220,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        key: ValueKey('draft_${itm.fieldKey}'),
                                        initialValue: itm.draftValue?.toString() ?? '',
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: context.l10n.draftBlEnterDraftValueHint,
                                          hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(6),
                                            borderSide: BorderSide(
                                              color: (itm.draftValue != null && itm.draftValue.toString().isNotEmpty)
                                                  ? (isCorrect ? Colors.green.shade300 : Colors.orange.shade300)
                                                  : Colors.grey.shade300,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isCorrect ? Colors.green.shade900 : Colors.black87,
                                        ),
                                        onChanged: (val) {
                                          _updateChecklistRow(idx, draftValue: val);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.content_copy, size: 14, color: AppTheme.cobalt),
                                      tooltip: context.l10n.draftBlCopySystemValueTooltip,
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      onPressed: () {
                                        _updateChecklistRow(
                                          idx,
                                          draftValue: itm.systemValue,
                                          status: 'Correct',
                                          correction: null,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Status Dropdown
                            DataCell(
                              DropdownButton<String>(
                                value: itm.status,
                                isDense: true,
                                underline: const SizedBox.shrink(),
                                items: [
                                  DropdownMenuItem(value: 'Correct', child: Text('✅ ${context.l10n.draftBlStatusCorrect}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))),
                                  DropdownMenuItem(value: 'Incorrect', child: Text('❌ ${context.l10n.draftBlStatusIncorrect}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))),
                                  DropdownMenuItem(value: 'N/A', child: Text('⚪ ${context.l10n.draftBlStatusNA}', style: const TextStyle(color: Colors.grey, fontSize: 12))),
                                ],
                                onChanged: (v) {
                                  if (v != null) _updateChecklistRow(idx, status: v);
                                },
                              ),
                            ),
                            // Required Action / Correction
                            DataCell(
                              SizedBox(
                                width: 180,
                                child: TextFormField(
                                  initialValue: itm.requiredCorrection ?? '',
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: isCorrect ? context.l10n.draftBlMatchedHint : context.l10n.draftBlEnterCorrectionHint,
                                    hintStyle: TextStyle(fontSize: 11, color: isCorrect ? Colors.green : Colors.grey),
                                    contentPadding: const EdgeInsets.all(6),
                                    border: const OutlineInputBorder(),
                                  ),
                                  style: const TextStyle(fontSize: 11.5),
                                  onChanged: (v) => _updateChecklistRow(idx, correction: v),
                                ),
                              ),
                            ),
                            // Responsible Party
                            DataCell(
                              SizedBox(
                                width: 130,
                                child: DropdownButtonFormField<String>(
                                  value: itm.responsibleParty ?? 'Shipping Provider',
                                  isDense: true,
                                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6), border: OutlineInputBorder()),
                                  items: [
                                    DropdownMenuItem(value: 'Shipping Provider', child: Text(context.l10n.draftBlPartyShippingLine, style: const TextStyle(fontSize: 11.5))),
                                    DropdownMenuItem(value: 'Supplier', child: Text(context.l10n.draftBlPartySupplier, style: const TextStyle(fontSize: 11.5))),
                                    DropdownMenuItem(value: 'Importer', child: Text(context.l10n.draftBlPartyImporter, style: const TextStyle(fontSize: 11.5))),
                                    DropdownMenuItem(value: 'Customs Broker', child: Text(context.l10n.draftBlPartyCustomsBroker, style: const TextStyle(fontSize: 11.5))),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) _updateChecklistRow(idx, respParty: v);
                                  },
                                ),
                              ),
                            ),
                            // Reason & Notes
                            DataCell(
                              SizedBox(
                                width: 160,
                                child: TextFormField(
                                  initialValue: itm.displayReason(context.l10n),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: context.l10n.draftBlEnterReasonHint,
                                    contentPadding: const EdgeInsets.all(6),
                                    border: const OutlineInputBorder(),
                                  ),
                                  style: const TextStyle(fontSize: 11.5),
                                  onChanged: (v) => _updateChecklistRow(idx, reason: v),
                                ),
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
        ),

        // 5. Visual Maritime Draft B/L Sheet (مطابقة لشكل بوليصة الخط الملاحي الرسمية ونافذة)
        if (_comparisonResult != null) ...[
          const SizedBox(height: 16),
          VisualDraftBLSheet(
            systemData: sys,
            draftData: _comparisonResult!.draftData,
            draftBlNumber: _draftBlNumberCtrl.text.isNotEmpty ? _draftBlNumberCtrl.text : null,
            bookingNumber: _bookingNoCtrl.text.isNotEmpty ? _bookingNoCtrl.text : null,
            title: context.l10n.draftBlExtractedVisualSheetTitle,
            subtitle: context.l10n.draftBlExtractedVisualSheetSub,
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryBox(String title, String value, IconData icon, Color color, {int flex = 1, bool isCritical = false}) {
    return Container(
      width: flex == 2 ? 380 : 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCritical ? Colors.red.shade50.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isCritical ? Colors.red : color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            radius: 16,
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11.5, color: isCritical ? Colors.red.shade900 : Colors.grey.shade700, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                CopyableText(
                  value,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isCritical ? Colors.red.shade900 : Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STAGE 2: REVISION REPORT & CARRIER CORRECTION LETTER
  // ===========================================================================
  Widget _buildStage2RevisionView(List<dynamic> importFiles) {
    final checklist = _comparisonResult?.checklist ?? [];
    final incorrectItems = checklist.where((c) => c.status == 'Incorrect').toList();
    final letter = _comparisonResult?.correctionRequestLetter ?? context.l10n.draftBlNoLetterGeneratedYet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top File Selector
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SearchableDropdownField<int>(
                    value: _selectedImportFileId,
                    labelText: context.l10n.draftBlSelectImportFileLabel,
                    searchHintText: context.l10n.searchFileOrCompanyHint,
                    items: importFiles
                        .map((f) => SearchableDropdownItem<int>(
                              value: f.importFileId,
                              label: '${f.primaryNameWithCode} - ${f.companyName}',
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null && v != _selectedImportFileId) {
                        setState(() => _selectedImportFileId = v);
                        _runComparison(silent: false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedImportFileId == null)
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.folder_off, size: 48, color: Colors.orange),
                    const SizedBox(height: 12),
                    Text(context.l10n.draftBlSelectFileToViewRevision, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      label: Text(context.l10n.draftBlBackToSelectFile, style: const TextStyle(color: Colors.white)),
                      onPressed: () => setState(() => _activeStep = 0),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment_late, color: Colors.orange, size: 24),
                          const SizedBox(width: 8),
                          Text(context.l10n.draftBlRevisionReportTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                        icon: const Icon(Icons.history, color: Colors.white, size: 16),
                        label: Text(context.l10n.draftBlProceedToVersionHistory, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () => setState(() => _activeStep = 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(context.l10n.draftBlRevisionReportSub, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const Divider(height: 20),
                  if (incorrectItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 10),
                          Text(context.l10n.draftBlNoAmendmentsNeeded, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  else
                    DataTable(
                      columns: [
                        DataColumn(label: Text(context.l10n.draftBlRevisionColItem)),
                        DataColumn(label: Text(context.l10n.draftBlRevisionColRequiredAction)),
                        DataColumn(label: Text(context.l10n.draftBlRevisionColResponsible)),
                        DataColumn(label: Text(context.l10n.draftBlRevisionColReason)),
                      ],
                      rows: incorrectItems.map((itm) {
                        final label = Localizations.localeOf(context).languageCode == 'ar' ? itm.fieldLabelAr : itm.fieldLabelEn;
                        final corr = itm.requiredCorrection ?? 'Update to match system value (${itm.systemValue})';
                        final resp = itm.responsibleParty == 'Shipping Provider'
                            ? context.l10n.draftBlPartyShippingLine
                            : itm.responsibleParty == 'Supplier'
                                ? context.l10n.draftBlPartySupplier
                                : itm.responsibleParty == 'Importer'
                                    ? context.l10n.draftBlPartyImporter
                                    : context.l10n.draftBlPartyCustomsBroker;
                        final rsn = itm.reason == null
                            ? 'Mismatch with system master record'
                            : itm.displayReason(context.l10n);
                        final rowSummary = [label, corr, resp, rsn].join('\t');

                        return DataRow(cells: [
                      DataCell(CopyableTableCell(
                            value: label,
                            rowSummary: rowSummary,
                            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                          )),
                          DataCell(CopyableTableCell(
                            value: corr,
                            rowSummary: rowSummary,
                            child: Text(corr, style: const TextStyle(color: Colors.red)),
                          )),
                          DataCell(CopyableTableCell(
                            value: resp,
                            rowSummary: rowSummary,
                            child: Text(resp),
                          )),
                          DataCell(CopyableTableCell(
                            value: rsn,
                            rowSummary: rowSummary,
                            child: Text(rsn),
                          )),
                        ]);
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Carrier Request Letter
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.mail, color: AppTheme.cobalt, size: 24),
                          const SizedBox(width: 8),
                          Text(context.l10n.draftBlCarrierRequestLetterTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                        label: Text(context.l10n.draftBlCopyLetterButton, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () => CopyHelper.copy(context, letter),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: SelectableText(
                      letter,
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // STAGE 3: VERSION BRANCHING (v1 / v2 / v3)
  // ===========================================================================
  Widget _buildStage3VersionBranchingView(List<dynamic> importFiles) {
    return Column(
      children: [
        // Top File Selector
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SearchableDropdownField<int>(
                    value: _selectedImportFileId,
                    labelText: context.l10n.draftBlSelectImportFileLabel,
                    searchHintText: context.l10n.searchFileOrCompanyHint,
                    items: importFiles
                        .map((f) => SearchableDropdownItem<int>(
                              value: f.importFileId,
                              label: '${f.primaryNameWithCode} - ${f.companyName}',
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null && v != _selectedImportFileId) {
                        setState(() => _selectedImportFileId = v);
                        _runComparison(silent: false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedImportFileId == null)
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.folder_off, size: 48, color: Colors.orange),
                    const SizedBox(height: 12),
                    Text(context.l10n.draftBlSelectFileToViewVersions, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      label: Text(context.l10n.draftBlBackToSelectFile, style: const TextStyle(color: Colors.white)),
                      onPressed: () => setState(() => _activeStep = 0),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.alt_route, color: AppTheme.cobalt, size: 24),
                          const SizedBox(width: 8),
                          Text(context.l10n.draftBlVersionBranchingTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                        icon: const Icon(Icons.verified_user, color: Colors.white, size: 16),
                        label: Text(context.l10n.draftBlProceedToDualApproval, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () => setState(() => _activeStep = 3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.draftBlVersionBranchingSub,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const Divider(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: AppTheme.cobalt),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.l10n.draftBlActiveVersionBanner(_activeSession?.version ?? 'v1', _activeSession?.stage ?? 'Stage 1: Review', _comparisonResult?.checklist.where((c) => c.isLocked).length ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // STAGE 4: DUAL APPROVAL (IMPORTER + CUSTOMS BROKER)
  // ===========================================================================
  Widget _buildStage4DualApprovalView(List<dynamic> importFiles) {
    final hasBlocking = _comparisonResult?.hasBlockingMismatch ?? false;
    final reasons = _comparisonResult?.blockingReasons ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top File Selector
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SearchableDropdownField<int>(
                    value: _selectedImportFileId,
                    labelText: context.l10n.draftBlSelectImportFileLabel,
                    searchHintText: context.l10n.searchFileOrCompanyHint,
                    items: importFiles
                        .map((f) => SearchableDropdownItem<int>(
                              value: f.importFileId,
                              label: '${f.primaryNameWithCode} - ${f.companyName}',
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null && v != _selectedImportFileId) {
                        setState(() => _selectedImportFileId = v);
                        _runComparison(silent: false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedImportFileId == null)
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.folder_off, size: 48, color: Colors.orange),
                    const SizedBox(height: 12),
                    Text(context.l10n.draftBlSelectFileToCompleteApproval, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      label: Text(context.l10n.draftBlBackToSelectFile, style: const TextStyle(color: Colors.white)),
                      onPressed: () => setState(() => _activeStep = 0),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          if (hasBlocking)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red)),
              child: Row(
                children: [
                  const Icon(Icons.block, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.draftBlApprovalBlockedTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        const SizedBox(height: 4),
                        Text(reasons.join(' | '), style: TextStyle(fontSize: 12, color: Colors.red.shade900)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Importer Card
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, color: AppTheme.cobalt),
                            const SizedBox(width: 8),
                            Text(context.l10n.draftBlImporterApprovalTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text(
                              _activeSession?.importerApprovalStatus == 'Approved' ? context.l10n.approved : context.l10n.pending,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _activeSession?.importerApprovalStatus == 'Approved' ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        TextFormField(
                          controller: _importerApproverCtrl,
                          decoration: InputDecoration(labelText: context.l10n.draftBlImporterApproverNameLabel, border: const OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _importerNotesCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(labelText: context.l10n.draftBlImporterNotesLabel, border: const OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)),
                                icon: const Icon(Icons.check, color: Colors.white),
                                label: Text(context.l10n.draftBlApproveAndAcceptButton, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                onPressed: (hasBlocking || _isLoading) ? null : () => _submitApproval('importer', 'Approved'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 12)),
                              icon: const Icon(Icons.close),
                              label: Text(context.l10n.draftBlRejectDraftButton),
                              onPressed: _isLoading ? null : () => _submitApproval('importer', 'Rejected'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Customs Broker Card
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.gavel, color: Colors.teal),
                            const SizedBox(width: 8),
                            Text(context.l10n.draftBlBrokerApprovalTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text(
                              _activeSession?.brokerApprovalStatus == 'Approved' ? context.l10n.approved : context.l10n.pending,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _activeSession?.brokerApprovalStatus == 'Approved' ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        TextFormField(
                          controller: _brokerApproverCtrl,
                          decoration: InputDecoration(labelText: context.l10n.draftBlBrokerApproverNameLabel, border: const OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _brokerNotesCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(labelText: context.l10n.draftBlBrokerNotesLabel, border: const OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 12)),
                                icon: const Icon(Icons.check, color: Colors.white),
                                label: Text(context.l10n.draftBlBrokerApproveButton, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                onPressed: (hasBlocking || _isLoading) ? null : () => _submitApproval('broker', 'Approved'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 12)),
                              icon: const Icon(Icons.close),
                              label: Text(context.l10n.draftBlRejectDraftButton),
                              onPressed: _isLoading ? null : () => _submitApproval('broker', 'Rejected'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // STAGE 5: FINAL REGISTRY & SESSIONS ARCHIVE
  // ===========================================================================
  Widget _buildStage5FinalRegistryView(List<DraftBLReviewModel> allReviews) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalCount = allReviews.length;
    final certifiedCount = allReviews.where((r) => !r.isDraft).length;
    final draftCount = allReviews.where((r) => r.isDraft).length;

    final filteredReviews = allReviews.where((r) {
      if (_selectedStatusFilter == 'DRAFT' && !r.isDraft) return false;
      if (_selectedStatusFilter == 'CERTIFIED' && r.isDraft) return false;
      if (_filterImportFileId != null && r.importFileId != _filterImportFileId) return false;
      if (_registrySearchQuery.trim().isEmpty) return true;
      final q = _registrySearchQuery.trim().toLowerCase();
      final blNo = (r.draftExtractedData?['draft_bl_number'] ?? r.draftExtractedData?['bl_number'] ?? r.draftBlNumber).toString().toLowerCase();
      final line = (r.shippingLine ?? '').toLowerCase();
      final stage = r.stage.toLowerCase();
      final code = r.blReviewCode.toLowerCase();
      return blNo.contains(q) || line.contains(q) || stage.contains(q) || code.contains(q) || r.blReviewId.toString().contains(q);
    }).toList();

    return Card(
      elevation: 2,
      color: isDark ? AppTheme.darkCardBackground : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (ctx, constraints) {
                final actions = [
                  OutlinedButton.icon(
                    key: const Key('stage5SearchAndCloneBtn'),
                    icon: const Icon(Icons.copy_all, size: 16, color: AppTheme.cobalt),
                    label: Text(
                      context.l10n.searchAndCloneDraftBlBtn,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppTheme.cobaltLight : AppTheme.cobalt,
                      side: BorderSide(color: isDark ? AppTheme.cobaltLight : AppTheme.cobalt),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _openSearchAndCloneDraftBlDialog,
                  ),
                  ElevatedButton.icon(
                    key: const Key('stage5RefreshRegistryBtn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(context.l10n.draftBlRefreshRegistry, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      ref.invalidate(draftBLReviewsProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.draftBlRegistryUpdatedSuccess)),
                      );
                    },
                  ),
                ];

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, color: Colors.green, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'سجل جلسات مراجعة وتدقيق بوالص الشحن (B/L)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.charcoal,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: actions,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              'سجل شامل لجلسات مسودات البوليصة المؤقتة والمعتمدة نهائياً مع تتبع الفروقات والموافقات',
              style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // 1. KPI Cards Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.charcoal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceAround,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _sessionKpiCard(
                    icon: Icons.assignment_turned_in,
                    label: 'إجمالي جلسات البوليصة',
                    value: '$totalCount',
                    color: Colors.cyanAccent,
                  ),
                  _sessionKpiCard(
                    icon: Icons.verified_rounded,
                    label: 'جلسات معتمدة نهائياً',
                    value: '$certifiedCount',
                    color: AppTheme.emerald,
                  ),
                  _sessionKpiCard(
                    icon: Icons.bookmark_added_outlined,
                    label: 'مسودات مؤقتة قيد التعديل',
                    value: '$draftCount',
                    color: AppTheme.orange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Filter & Actions Toolbar
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: Text('الكل ($totalCount)'),
                  selected: _selectedStatusFilter == 'ALL',
                  onSelected: (_) => setState(() => _selectedStatusFilter = 'ALL'),
                  selectedColor: AppTheme.cobalt,
                  labelStyle: TextStyle(
                    color: _selectedStatusFilter == 'ALL' ? Colors.white : (isDark ? Colors.white70 : AppTheme.charcoal),
                    fontWeight: _selectedStatusFilter == 'ALL' ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
                ChoiceChip(
                  label: Text('معتمدة نهائية ($certifiedCount)'),
                  selected: _selectedStatusFilter == 'CERTIFIED',
                  onSelected: (_) => setState(() => _selectedStatusFilter = 'CERTIFIED'),
                  selectedColor: AppTheme.emerald,
                  labelStyle: TextStyle(
                    color: _selectedStatusFilter == 'CERTIFIED' ? Colors.white : (isDark ? Colors.white70 : AppTheme.charcoal),
                    fontWeight: _selectedStatusFilter == 'CERTIFIED' ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
                ChoiceChip(
                  label: Text('مسودات مؤقتة ($draftCount)'),
                  selected: _selectedStatusFilter == 'DRAFT',
                  onSelected: (_) => setState(() => _selectedStatusFilter = 'DRAFT'),
                  selectedColor: AppTheme.orange,
                  labelStyle: TextStyle(
                    color: _selectedStatusFilter == 'DRAFT' ? Colors.white : (isDark ? Colors.white70 : AppTheme.charcoal),
                    fontWeight: _selectedStatusFilter == 'DRAFT' ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
                if (importFiles.isNotEmpty)
                  SizedBox(
                    width: 280,
                    child: SearchableDropdownField<int?>(
                      labelText: 'تصفية حسب ملف الشحنة',
                      value: _filterImportFileId,
                      items: [
                        const SearchableDropdownItem<int?>(value: null, label: 'كافة الشحنات والملفات'),
                        ...importFiles.map((f) => SearchableDropdownItem<int?>(
                              value: f.importFileId,
                              label: '${f.primaryNameWithCode} - ${f.supplierName}',
                            )),
                      ],
                      onChanged: (val) => setState(() => _filterImportFileId = val),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar & Export Buttons
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 768;
                final isAr = Localizations.localeOf(context).languageCode == 'ar';
                final searchBar = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: AppTheme.cobalt, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const Key('draftBlRegistrySearchInput'),
                          decoration: InputDecoration(
                            hintText: context.l10n.draftBlSearchRegistryHint,
                            hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : null),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: TextStyle(color: isDark ? Colors.white : null),
                          onChanged: (val) {
                            setState(() => _registrySearchQuery = val);
                          },
                        ),
                      ),
                      if (_registrySearchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _registrySearchQuery = ''),
                        ),
                    ],
                  ),
                );

                final actionButtons = [
                  OutlinedButton.icon(
                    key: const Key('draftBlRegistryCopyBtn'),
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(isAr ? 'نسخ TSV' : 'Copy TSV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppTheme.wcagCobalt : AppTheme.charcoal,
                      side: BorderSide(color: isDark ? AppTheme.wcagCobalt : AppTheme.charcoal),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onPressed: () => _copyDraftBlRegistryAsTsv(filteredReviews),
                  ),
                  OutlinedButton.icon(
                    key: const Key('draftBlRegistryExcelBtn'),
                    icon: const Icon(Icons.table_chart, size: 16, color: Colors.green),
                    label: Text(isAr ? 'تصدير Excel' : 'Export Excel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onPressed: () => _exportDraftBlRegistryToExcel(filteredReviews),
                  ),
                  OutlinedButton.icon(
                    key: const Key('draftBlRegistryPdfBtn'),
                    icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.red),
                    label: Text(isAr ? 'تصدير PDF' : 'Export PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onPressed: () => _exportDraftBlRegistryToPdf(filteredReviews),
                  ),
                ];

                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchBar,
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: actionButtons),
                      const SizedBox(height: 16),
                    ],
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Expanded(child: searchBar),
                        const SizedBox(width: 10),
                        ...actionButtons.map((btn) => Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: btn,
                        )),
                      ],
                    ),
                  );
                }
              },
            ),

            if (filteredReviews.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        _registrySearchQuery.isNotEmpty ? context.l10n.draftBlNoRegistriesFound : context.l10n.draftBlNoRegistriesYet,
                        style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _registrySearchQuery.isNotEmpty ? context.l10n.draftBlTryDifferentSearch : context.l10n.draftBlExtractNewDraftHint,
                        style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              SelectionArea(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 950),
                    child: DataTable(
                      columnSpacing: 18,
                      headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkSurface : Colors.grey.shade100),
                      columns: [
                        DataColumn(label: Text(context.l10n.draftBlRegistryColActions, style: const TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('نوع الجلسة', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(context.l10n.draftBlRegistryColSessionId, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(context.l10n.draftBlRegistryColBlNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt))),
                        DataColumn(label: Text(context.l10n.draftBlRegistryColShippingLine, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(context.l10n.draftBlRegistryColVesselVoyage, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(context.l10n.draftBlRegistryColStage, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(context.l10n.draftBlRegistryColImporterApproval, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(context.l10n.draftBlRegistryColBrokerApproval, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(context.l10n.draftBlRegistryColStatus, style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: filteredReviews.map((r) {
                        final blNumber = (r.draftExtractedData?['draft_bl_number'] ??
                                r.draftExtractedData?['bl_number'] ??
                                r.systemDataSnapshot?['draft_bl_number'] ??
                                r.draftBlNumber)
                            .toString();

                        final vesselVoyage = '${r.vesselName ?? "-"} / ${r.voyageNumber ?? "-"}';
                        final importerApproval = r.importerApprovalStatus == 'Approved' ? context.l10n.approved : r.importerApprovalStatus;
                        final brokerApproval = r.brokerApprovalStatus == 'Approved' ? context.l10n.approved : r.brokerApprovalStatus;
                        final statusLabel = r.status == 'Final Approved' || r.status == 'Approved' ? context.l10n.approved : r.status;
                        final isDraft = r.isDraft;
                        final rowSummary = [
                          isDraft ? 'مسودة مؤقتة' : 'معتمدة نهائية',
                          '#${r.blReviewId}',
                          blNumber,
                          r.shippingLine ?? '-',
                          vesselVoyage,
                          r.stage,
                          importerApproval,
                          brokerApproval,
                          statusLabel,
                        ].join('\t');

                        return DataRow(cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: context.l10n.cloneDraftBlRecordTooltip,
                                  child: IconButton(
                                    key: Key('cloneDraftBlRowBtn_${r.blReviewId}'),
                                    icon: const Icon(Icons.copy_all, size: 18, color: AppTheme.emerald),
                                    onPressed: () => _onCloneDraftBlSession(r),
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                Tooltip(
                                  message: 'استعادة وتحميل الجلسة في أداة الفحص',
                                  child: IconButton(
                                    icon: const Icon(Icons.play_circle_outline, size: 18, color: AppTheme.cobalt),
                                    onPressed: () => _loadSessionIntoEditor(r),
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                Tooltip(
                                  message: 'عرض تفاصيل ومصفوفة الجلسة',
                                  child: IconButton(
                                    icon: const Icon(Icons.info_outline, size: 18, color: AppTheme.charcoal),
                                    onPressed: () => _showDraftBLSessionDetailsDialog(r),
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                Tooltip(
                                  message: context.l10n.draftBlPrintBlTooltip,
                                  child: IconButton(
                                    icon: Icon(Icons.print, size: 18, color: isDark ? Colors.grey.shade300 : AppTheme.charcoal),
                                    onPressed: () async {
                                      try {
                                        final sysData = r.systemDataSnapshot ?? {};
                                        final draftData = r.draftExtractedData ?? {};
                                        await DraftBLExportService.printDraftBL(
                                          systemData: sysData,
                                          draftData: draftData,
                                          draftBlNumber: blNumber,
                                        );
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(context.l10n.draftBlPrintError(e.toString())), backgroundColor: Colors.red),
                                          );
                                        }
                                      }
                                    },
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                Tooltip(
                                  message: context.l10n.draftBlDownloadPdfTooltip,
                                  child: IconButton(
                                    icon: const Icon(Icons.picture_as_pdf, size: 18, color: AppTheme.crimson),
                                    onPressed: () async {
                                      try {
                                        final sysData = r.systemDataSnapshot ?? {};
                                        final draftData = r.draftExtractedData ?? {};
                                        await DraftBLExportService.exportDraftBLToPdf(
                                          systemData: sysData,
                                          draftData: draftData,
                                          draftBlNumber: blNumber,
                                        );
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(context.l10n.draftBlPdfExportError(e.toString())), backgroundColor: Colors.red),
                                          );
                                        }
                                      }
                                    },
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                if (isDraft)
                                  Tooltip(
                                    message: 'حذف المسودة',
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.crimson),
                                      onPressed: () => _deleteDraftBLSession(r),
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDraft ? AppTheme.orange.withOpacity(0.12) : AppTheme.emerald.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isDraft ? AppTheme.orange : AppTheme.emerald),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(isDraft ? Icons.edit_document : Icons.verified_rounded, size: 13, color: isDraft ? AppTheme.orange : AppTheme.emerald),
                                  const SizedBox(width: 4),
                                  Text(
                                    isDraft ? 'مسودة مؤقتة' : 'معتمدة نهائية',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDraft ? AppTheme.orange : AppTheme.emerald,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(CopyableTableCell(
                            value: '#${r.blReviewId}',
                            rowSummary: rowSummary,
                            child: Text('#${r.blReviewId}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                          )),
                          DataCell(
                            CopyableTableCell(
                              value: blNumber,
                              rowSummary: rowSummary,
                              child: InkWell(
                                onTap: () => CopyHelper.copy(context, blNumber),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cobalt.withOpacity(isDark ? 0.2 : 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.confirmation_number_outlined, size: 14, color: AppTheme.cobalt),
                                      const SizedBox(width: 6),
                                      Text(
                                        blNumber,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppTheme.cobaltLight : AppTheme.cobalt,
                                          fontFamily: 'monospace',
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Tooltip(
                                        message: context.l10n.draftBlCopyBlNumberTooltip,
                                        child: Icon(Icons.copy, size: 12, color: isDark ? AppTheme.cobaltLight : AppTheme.cobalt),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(CopyableTableCell(
                            value: r.shippingLine ?? '-',
                            rowSummary: rowSummary,
                            child: Text(r.shippingLine ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                          )),
                          DataCell(CopyableTableCell(
                            value: vesselVoyage,
                            rowSummary: rowSummary,
                            child: Text(vesselVoyage, style: const TextStyle(fontSize: 11.5)),
                          )),
                          DataCell(CopyableTableCell(
                            value: r.stage,
                            rowSummary: rowSummary,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.blueGrey.shade900 : Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: isDark ? Colors.blueGrey.shade700 : Colors.blueGrey.shade200),
                              ),
                              child: Text(
                                r.stage,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade800,
                                ),
                              ),
                            ),
                          )),
                          DataCell(CopyableTableCell(
                            value: importerApproval,
                            rowSummary: rowSummary,
                            child: Text(
                              importerApproval,
                              style: TextStyle(
                                color: r.importerApprovalStatus == 'Approved' ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )),
                          DataCell(CopyableTableCell(
                            value: brokerApproval,
                            rowSummary: rowSummary,
                            child: Text(
                              brokerApproval,
                              style: TextStyle(
                                color: r.brokerApprovalStatus == 'Approved' ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )),
                          DataCell(CopyableTableCell(
                            value: statusLabel,
                            rowSummary: rowSummary,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: r.status == 'Final Approved' || r.status == 'Approved'
                                    ? (isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50)
                                    : (isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: r.status == 'Final Approved' || r.status == 'Approved'
                                      ? (isDark ? Colors.green.shade600 : Colors.green.shade300)
                                      : (isDark ? Colors.blue.shade600 : Colors.blue.shade300),
                                ),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: r.status == 'Final Approved' || r.status == 'Approved'
                                      ? (isDark ? Colors.greenAccent : Colors.green.shade900)
                                      : (isDark ? Colors.lightBlueAccent : Colors.blue.shade900),
                                ),
                              ),
                            ),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sessionKpiCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  void _loadSessionIntoEditor(DraftBLReviewModel session) {
    setState(() {
      _selectedImportFileId = session.importFileId;
      _activeSession = session;
      _draftBlNumberCtrl.text = session.draftBlNumber;
      _shippingLineCtrl.text = session.shippingLine ?? '';
      _vesselNameCtrl.text = session.vesselName ?? '';
      _voyageCtrl.text = session.voyageNumber ?? '';
      _bookingNoCtrl.text = session.bookingNumber ?? '';
      _polCtrl.text = session.polName ?? '';
      _podCtrl.text = session.podName ?? '';
      _freightTermsCtrl.text = session.freightTerms ?? '';
      _placeOfDeliveryCtrl.text = session.placeOfDelivery ?? '';
      _grossWeightCtrl.text = session.systemDataSnapshot?['total_gross_weight_kg']?.toString() ?? '';
      _netWeightCtrl.text = session.netWeightKg > 0 ? session.netWeightKg.toString() : '';
      _cbmCtrl.text = session.measurementCbm > 0 ? session.measurementCbm.toString() : '';
      _packagesCountCtrl.text = session.packagesCount > 0 ? session.packagesCount.toString() : '';
      _containerNoCtrl.text = session.containerSummary ?? '';
      _activeStep = 0; // jump to Review Sheet
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم استرجاع وتحميل بيانات الجلسة (${session.blReviewCode}) إلى أداة المراجعة بنجاح')),
    );
  }

  Future<void> _deleteDraftBLSession(DraftBLReviewModel session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: AppTheme.crimson),
            SizedBox(width: 8),
            Text('تأكيد حذف مسودة الجلسة'),
          ],
        ),
        content: Text('هل أنت متأكد من حذف مسودة الجلسة (${session.blReviewCode})؟ لن يؤثر ذلك على بيانات الشحنة الأصلية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(draftBLReviewsProvider.notifier).deleteDraftBLReview(session.blReviewId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف مسودة الجلسة بنجاح'), backgroundColor: AppTheme.crimson),
        );
      }
    }
  }

  void _showDraftBLSessionDetailsDialog(DraftBLReviewModel session) {
    final matrix = session.comparisonMatrix;
    final isDraft = session.isDraft;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDraft ? AppTheme.orange : AppTheme.emerald).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isDraft ? Icons.bookmark_added_rounded : Icons.verified_rounded,
                color: isDraft ? AppTheme.orange : AppTheme.emerald,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفاصيل الجلسة: ${session.blReviewCode}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'رقم البوليصة: ${session.draftBlNumber}  |  تاريخ الإنشاء: ${session.createdAt}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (isDraft ? AppTheme.orange : AppTheme.emerald).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDraft ? AppTheme.orange : AppTheme.emerald),
              ),
              child: Text(
                isDraft ? 'مسودة مؤقتة' : 'معتمدة نهائية',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDraft ? AppTheme.orange : AppTheme.emerald,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 850,
          height: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text('مصفوفة الفحص والمقارنة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                if (matrix.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد بنود مصفوفة محفوظة')))
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppTheme.charcoal),
                      headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      columns: const [
                        DataColumn(label: Text('الحقل المعياري')),
                        DataColumn(label: Text('القيمة المسجلة بالسيستم')),
                        DataColumn(label: Text('القيمة بمسودة البوليصة')),
                        DataColumn(label: Text('حالة التطابق')),
                      ],
                      rows: matrix.map((item) {
                        return DataRow(cells: [
                          DataCell(Text(item.fieldLabelAr, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(item.displaySystemValue(context.l10n))),
                          DataCell(Text(item.displayDraftValue(context.l10n))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: item.matchStatus == 'MATCH' ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.matchStatus == 'MATCH' ? 'متطابق' : 'فارق',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: item.matchStatus == 'MATCH' ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _loadSessionIntoEditor(session);
            },
            icon: const Icon(Icons.play_circle_outline, size: 16, color: AppTheme.emerald),
            label: const Text('استعادة وتحميل في أداة المراجعة',
                style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.charcoal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _exportDraftBlRegistryToExcel(List<dynamic> reviews) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final headers = [
      isAr ? 'نوع الجلسة' : 'Session Type',
      context.l10n.draftBlRegistryColSessionId,
      context.l10n.draftBlRegistryColBlNumber,
      context.l10n.draftBlRegistryColShippingLine,
      context.l10n.draftBlRegistryColVesselVoyage,
      context.l10n.draftBlRegistryColStage,
      context.l10n.draftBlRegistryColImporterApproval,
      context.l10n.draftBlRegistryColBrokerApproval,
      context.l10n.draftBlRegistryColStatus,
    ];
    final rows = reviews.map((r) {
      final blNumber = (r.draftExtractedData?['draft_bl_number'] ??
              r.draftExtractedData?['bl_number'] ??
              r.systemDataSnapshot?['draft_bl_number'] ??
              r.draftBlNumber)
          .toString();
      final vesselVoyage = '${r.vesselName ?? "-"} / ${r.voyageNumber ?? "-"}';
      final importerApproval = r.importerApprovalStatus == 'Approved' ? context.l10n.approved : r.importerApprovalStatus;
      final brokerApproval = r.brokerApprovalStatus == 'Approved' ? context.l10n.approved : r.brokerApprovalStatus;
      final statusLabel = r.status == 'Final Approved' || r.status == 'Approved' ? context.l10n.approved : r.status;
      return [
        r.isDraft ? (isAr ? 'مسودة مؤقتة' : 'Draft') : (isAr ? 'معتمدة نهائية' : 'Certified'),
        '#${r.blReviewId}',
        blNumber,
        r.shippingLine ?? '-',
        vesselVoyage,
        r.stage,
        importerApproval,
        brokerApproval,
        statusLabel,
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: isAr ? 'سجل بوالص الشحن المبدئية' : 'Draft B/L Registry',
      importFileNameOrCode: 'Draft_BL_Registry',
    );
  }

  Future<void> _exportDraftBlRegistryToPdf(List<dynamic> reviews) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final headers = [
      isAr ? 'نوع الجلسة' : 'Session Type',
      context.l10n.draftBlRegistryColSessionId,
      context.l10n.draftBlRegistryColBlNumber,
      context.l10n.draftBlRegistryColShippingLine,
      context.l10n.draftBlRegistryColVesselVoyage,
      context.l10n.draftBlRegistryColStage,
      context.l10n.draftBlRegistryColImporterApproval,
      context.l10n.draftBlRegistryColBrokerApproval,
      context.l10n.draftBlRegistryColStatus,
    ];
    final rows = reviews.map((r) {
      final blNumber = (r.draftExtractedData?['draft_bl_number'] ??
              r.draftExtractedData?['bl_number'] ??
              r.systemDataSnapshot?['draft_bl_number'] ??
              r.draftBlNumber)
          .toString();
      final vesselVoyage = '${r.vesselName ?? "-"} / ${r.voyageNumber ?? "-"}';
      final importerApproval = r.importerApprovalStatus == 'Approved' ? context.l10n.approved : r.importerApprovalStatus;
      final brokerApproval = r.brokerApprovalStatus == 'Approved' ? context.l10n.approved : r.brokerApprovalStatus;
      final statusLabel = r.status == 'Final Approved' || r.status == 'Approved' ? context.l10n.approved : r.status;
      return [
        r.isDraft ? (isAr ? 'مسودة مؤقتة' : 'Draft') : (isAr ? 'معتمدة نهائية' : 'Certified'),
        '#${r.blReviewId}',
        blNumber,
        r.shippingLine ?? '-',
        vesselVoyage,
        r.stage,
        importerApproval,
        brokerApproval,
        statusLabel,
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: isAr ? 'سجل بوالص الشحن المبدئية' : 'Draft B/L Registry',
      importFileNameOrCode: 'Draft_BL_Registry',
    );
  }

  void _copyDraftBlRegistryAsTsv(List<dynamic> reviews) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final headers = [
      isAr ? 'نوع الجلسة' : 'Session Type',
      context.l10n.draftBlRegistryColSessionId,
      context.l10n.draftBlRegistryColBlNumber,
      context.l10n.draftBlRegistryColShippingLine,
      context.l10n.draftBlRegistryColVesselVoyage,
      context.l10n.draftBlRegistryColStage,
      context.l10n.draftBlRegistryColImporterApproval,
      context.l10n.draftBlRegistryColBrokerApproval,
      context.l10n.draftBlRegistryColStatus,
    ];
    final rows = reviews.map((r) {
      final blNumber = (r.draftExtractedData?['draft_bl_number'] ??
              r.draftExtractedData?['bl_number'] ??
              r.systemDataSnapshot?['draft_bl_number'] ??
              r.draftBlNumber)
          .toString();
      final vesselVoyage = '${r.vesselName ?? "-"} / ${r.voyageNumber ?? "-"}';
      final importerApproval = r.importerApprovalStatus == 'Approved' ? context.l10n.approved : r.importerApprovalStatus;
      final brokerApproval = r.brokerApprovalStatus == 'Approved' ? context.l10n.approved : r.brokerApprovalStatus;
      final statusLabel = r.status == 'Final Approved' || r.status == 'Approved' ? context.l10n.approved : r.status;
      return [
        r.isDraft ? (isAr ? 'مسودة مؤقتة' : 'Draft') : (isAr ? 'معتمدة نهائية' : 'Certified'),
        '#${r.blReviewId}',
        blNumber,
        r.shippingLine ?? '-',
        vesselVoyage,
        r.stage,
        importerApproval,
        brokerApproval,
        statusLabel,
      ];
    }).toList();

    TableCopyHelper.copyTable(context, headers, rows);
  }
}
