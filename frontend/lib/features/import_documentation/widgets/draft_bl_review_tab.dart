import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/helpers/file_picker_helper.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_tab_scaffold.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/metric_card.dart';
import 'idoc_feedback.dart';
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
import 'idoc_ui.dart';

class DraftBLReviewTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  DraftBLReviewTab({super.key, this.initialImportFileId});

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
  final TextEditingController _freightTermsCtrl = TextEditingController();
  final TextEditingController _placeOfDeliveryCtrl = TextEditingController();
  final TextEditingController _goodsDescCtrl = TextEditingController();
  final TextEditingController _grossWeightCtrl = TextEditingController();
  final TextEditingController _netWeightCtrl = TextEditingController();
  final TextEditingController _cbmCtrl = TextEditingController();
  final TextEditingController _containerNoCtrl = TextEditingController();
  final TextEditingController _sealNoCtrl = TextEditingController();
  final TextEditingController _packagesCountCtrl = TextEditingController();

  // Dual Approval Controllers
  final TextEditingController _importerApproverCtrl = TextEditingController();
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
    _importerApproverCtrl.text = _brokerApproverCtrl.text;
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
          SnackBar(content: Text(context.l10n.selectImportFileFirst), backgroundColor: AppTheme.crimson),
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
            backgroundColor: res.hasBlockingMismatch ? AppTheme.orange : AppTheme.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.draftBlComparisonError(ApiErrorText.of(context.l10n, e))), backgroundColor: AppTheme.crimson),
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
            entityType: context.l10n.idocADraftBillOfLadingDraftB,
            sourceCode: session.blReviewCode,
            sourceTitle: '$blNumber — ${session.shippingLine ?? ""}',
            suggestedNewCode: 'DRAFT-BL-2026-',
            copiedFieldsSummary: {
              context.l10n.idocAShippingLine: session.shippingLine ?? '-',
              context.l10n.idocAVesselVoyage: '${session.vesselName ?? "-"} / ${session.voyageNumber ?? "-"}',
              context.l10n.idocABookingNumber: session.bookingNumber ?? '-',
              context.l10n.idocAFreightTerms: session.freightTerms ?? 'Prepaid',
              context.l10n.idocAPortOfLoadingArrival: '${session.polName ?? "-"} -> ${session.podName ?? "-"}',
            },
            mandatorilyResetFields: [
              context.l10n.idocACloneNoteBlNumber,
              context.l10n.idocACloneNoteReviewId,
              context.l10n.idocACloneNoteImporter,
              context.l10n.idocACloneNoteBroker,
              context.l10n.idocACloneNoteSnapshot,
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
            SnackBar(content: Text(context.l10n.draftBlFileReadError), backgroundColor: AppTheme.crimson),
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
              backgroundColor: AppTheme.severityForegroundOf(context, AppSeverity.warning),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.draftBlExtractedSuccess(file.name)),
              backgroundColor: AppTheme.emerald,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.draftBlExtractionError(ApiErrorText.of(context.l10n, e))), backgroundColor: AppTheme.crimson),
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
          SnackBar(content: Text(context.l10n.selectImportFileFirst), backgroundColor: AppTheme.crimson),
        );
      }
      return;
    }

    if (!isDraft && _comparisonResult!.hasBlockingMismatch) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final l = ctx.l10n;
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.idocADraftBlConfirmTitle,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: Text(
              l.idocADraftBlConfirmBody(_comparisonResult!.openDiscrepanciesCount),
              style: const TextStyle(fontSize: 13),
            ),
            actions: [
              IdocUi.fit(AppButton(
                label: l.cancel,
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.pop(ctx, false),
              )),
              IdocUi.fit(AppButton(
                label: l.idocADraftBlConfirmAction,
                variant: AppButtonVariant.danger,
                onPressed: () => Navigator.pop(ctx, true),
              )),
            ],
          );
        },
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
        'system_snapshot_data': _comparisonResult!.systemData,
        'draft_input_data': _comparisonResult!.draftData,
        'comparison_matrix': _comparisonResult!.matrix.map((m) => m.toJson()).toList(),
        'checklist_data': _comparisonResult!.checklist.map((c) => c.toJson()).toList(),
        'revision_report_data': _comparisonResult!.revisionReport.map((r) => r.toJson()).toList(),
        'has_blocking_mismatch': _comparisonResult!.hasBlockingMismatch,
        'open_discrepancies_count': _comparisonResult!.openDiscrepanciesCount,
        'blocking_reasons': _comparisonResult!.blockingReasons,
        'blocking_reasons_coded': _comparisonResult!.blockingReasonsCoded,
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
        final l = context.l10n;
        showIdocMessage(
          context,
          isDraft ? l.idocADraftBlSaved(created.blReviewCode) : l.idocADraftBlSavedForApproval(created.blReviewCode),
          color: isDraft ? AppTheme.cobalt : AppTheme.emerald,
        );
      }
    } catch (e) {
      if (mounted) {
        showIdocError(context, e, title: context.l10n.idocADraftBlSaveFailed);
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

    _scheduleChecklistSync();
  }

  // --- Checklist persistence -------------------------------------------------
  // Edits stay local while a row is incomplete; one PUT is sent after the user
  // pauses typing (never per keystroke), PUTs are serialized, and a stale
  // response never overwrites a newer one. A failed PUT keeps the local edit
  // (so the text fields stay consistent) and is retried on the next edit.
  Timer? _checklistDebounce;
  bool _checklistSyncing = false;
  bool _checklistSyncQueued = false;

  /// The server rejects an Incorrect row that has no correction and no reason.
  bool _isChecklistRowComplete(DraftBLChecklistItemModel i) {
    if (i.status != 'Incorrect') return true;
    final hasCorrection = (i.requiredCorrection ?? '').trim().isNotEmpty;
    final hasReason = (i.reason ?? '').trim().isNotEmpty || (i.reasonCode ?? '').isNotEmpty;
    return hasCorrection && hasReason;
  }

  void _scheduleChecklistSync() {
    if (_activeSession == null) return;
    _checklistDebounce?.cancel();
    _checklistDebounce = Timer(const Duration(milliseconds: 600), _syncChecklist);
  }

  Future<void> _syncChecklist() async {
    if (!mounted || _activeSession == null || _comparisonResult == null) return;
    if (_checklistSyncing) {
      _checklistSyncQueued = true;
      return;
    }
    final items = _comparisonResult!.checklist;
    if (!items.every(_isChecklistRowComplete)) return; // wait until the row is complete
    _checklistSyncing = true;
    try {
      final updated = await ref.read(draftBLReviewsProvider.notifier).updateDraftBLChecklist(
            _activeSession!.blReviewId,
            List<DraftBLChecklistItemModel>.of(items),
            reviewerName: idocCurrentUserName(ref),
          );
      if (!mounted) return;
      // Only the session metadata is taken from the response; the local rows
      // (possibly edited since the request was sent) are never replaced.
      setState(() => _activeSession = updated);
    } catch (e) {
      if (mounted) showIdocError(context, e, title: context.l10n.idocAChecklistSaveFailed);
    } finally {
      _checklistSyncing = false;
      if (mounted && _checklistSyncQueued) {
        _checklistSyncQueued = false;
        _scheduleChecklistSync();
      }
    }
  }

  Set<String> _currentUserNames() {
    final u = ref.read(authProvider).user;
    return {u?.fullName ?? '', u?.username ?? ''};
  }

  /// Single-step approval: completes the one missing role (`POST /approve`).
  Future<void> _approveSingleStep() async {
    final session = _activeSession;
    if (session == null) return;
    setState(() => _isLoading = true);
    try {
      final updated = await ref.read(draftBLReviewsProvider.notifier).approveDraftBL(
            session.blReviewId,
            approvedBy: idocCurrentUserName(ref),
          );
      if (!mounted) return;
      setState(() => _activeSession = updated);
      if (updated.stage == 'Stage 5: Final') {
        showIdocMessage(context, context.l10n.draftBlDualApprovalCompleted);
        setState(() => _activeStep = 4);
      }
    } catch (e) {
      if (mounted) showIdocError(context, e, title: context.l10n.draftBlApprovalError(''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            SnackBar(content: Text(context.l10n.draftBlDualApprovalCompleted), backgroundColor: AppTheme.emerald),
          );
          setState(() => _activeStep = 4);
        } else if (action == 'Rejected') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.draftBlRevisionRequiredAlert), backgroundColor: AppTheme.crimson),
          );
          setState(() => _activeStep = 1);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.draftBlRoleApprovalRegistered(role)), backgroundColor: AppTheme.cobalt),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.draftBlApprovalError(ApiErrorText.of(context.l10n, e))), backgroundColor: AppTheme.crimson),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _checklistDebounce?.cancel();
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
                  builder: (context, _) {
                    final messenger = ScaffoldMessenger.of(context);
                    final l = context.l10n;

                    final actionWidgets = [
                      IdocUi.fit(AppButton(
                        key: const Key('stage1SearchAndCloneBtn'),
                        label: l.searchAndCloneDraftBlBtn,
                        icon: Icons.copy_all,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        onPressed: _openSearchAndCloneDraftBlDialog,
                      )),
                      if (_comparisonResult != null) ...[
                        IdocUi.fit(AppButton(
                          label: l.draftBlDownloadPdfButton,
                          icon: Icons.picture_as_pdf,
                          variant: AppButtonVariant.danger,
                          size: AppButtonSize.small,
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
                                  SnackBar(content: Text(l.draftBlPdfExportError(ApiErrorText.of(context.l10n, e))), backgroundColor: AppTheme.crimson),
                                );
                              }
                            }
                          },
                        )),
                        IdocUi.fit(AppButton(
                          label: context.l10n.draftBlDownloadExcelButton,
                          icon: Icons.table_chart,
                          variant: AppButtonVariant.success,
                          size: AppButtonSize.small,
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
                                  SnackBar(content: Text(l.excelExportSuccess(res)), backgroundColor: AppTheme.emerald),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(l.excelExportError(ApiErrorText.of(context.l10n, e))), backgroundColor: AppTheme.crimson),
                                );
                              }
                            }
                          },
                        )),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _comparisonResult!.hasBlockingMismatch
                                ? (AppTheme.severityBackgroundOf(context, AppSeverity.danger))
                                : (AppTheme.severityBackgroundOf(context, AppSeverity.success)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _comparisonResult!.hasBlockingMismatch
                                  ? (AppTheme.crimson)
                                  : (AppTheme.emerald),
                            ),
                          ),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Icon(
                                _comparisonResult!.hasBlockingMismatch ? Icons.error : Icons.check_circle,
                                color: _comparisonResult!.hasBlockingMismatch
                                    ? (AppTheme.crimson)
                                    : (AppTheme.emerald),
                                size: 16,
                              ),
                              Text(
                                _comparisonResult!.hasBlockingMismatch
                                    ? context.l10n.draftBlMismatchesFound(_comparisonResult!.openDiscrepanciesCount)
                                    : context.l10n.draftBlPerfectMatchReady,
                                style: TextStyle(
                                  color: _comparisonResult!.hasBlockingMismatch
                                      ? (AppTheme.severityForegroundOf(context, AppSeverity.danger))
                                      : (AppTheme.severityForegroundOf(context, AppSeverity.success)),
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
                                color: AppTheme.textPrimaryOf(context),
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
                    color: AppTheme.textSecondaryOf(context),
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

                    final refreshBtn = IdocUi.fit(AppButton(
                      label: context.l10n.draftBlRefreshAndCompare,
                      icon: Icons.sync,
                      variant: AppButtonVariant.primary,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : () => _runComparison(silent: false),
                    ));

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
          color: AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.transparent),
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
                        _buildFormatBadge('PDF', AppTheme.crimson),
                        _buildFormatBadge('Word (.docx)', AppTheme.cobalt),
                        _buildFormatBadge('Excel (.xlsx)', AppTheme.emerald),
                        _buildFormatBadge('Text / OCR', AppTheme.emerald),
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
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryOf(context)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(context.l10n.draftBlSmartExtractorSub, style: TextStyle(fontSize: 12, color: AppTheme.textMutedOf(context))),
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
                              Text(context.l10n.draftBlSmartExtractorTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
                              const SizedBox(height: 2),
                              Text(context.l10n.draftBlSmartExtractorSub, style: TextStyle(fontSize: 12, color: AppTheme.textMutedOf(context))),
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
                    IdocUi.fit(AppButton(
                      label: _isUploadingFile ? context.l10n.draftBlExtractingFileProgress : context.l10n.draftBlUploadAndExtractButton,
                      icon: Icons.upload_file,
                      variant: AppButtonVariant.primary,
                      isLoading: _isUploadingFile,
                      onPressed: _isUploadingFile ? null : _pickAndExtractFile,
                    )),
                    if (_uploadedFileName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.severityForegroundOf(context, AppSeverity.success).withValues(alpha: 0.3) : AppTheme.severityBackgroundOf(context, AppSeverity.success),
                          border: Border.all(color: isDark ? AppTheme.severityForegroundOf(context, AppSeverity.success) : AppTheme.emeraldBorder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            const Icon(Icons.check_circle, color: AppTheme.emerald, size: 18),
                            Text(
                              context.l10n.draftBlFileExtractedSuccess(_uploadedFileName!, ((_uploadedFileSize ?? 0) / 1024).toStringAsFixed(1)),
                              style: TextStyle(color: isDark ? AppTheme.emerald : AppTheme.severityForegroundOf(context, AppSeverity.success), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18, color: AppTheme.emerald),
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
                      color: AppTheme.cobalt.withValues(alpha: isDark ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.35)),
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
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryOf(context)),
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
                                color: AppTheme.surfaceOf(context),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.4)),
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
                            IdocUi.fit(AppButton(
                              label: context.l10n.edit,
                              icon: Icons.edit,
                              variant: AppButtonVariant.ghost,
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
                                    AppButton(
                                      label: context.l10n.cancel,
                                      variant: AppButtonVariant.ghost,
                                      onPressed: () => Navigator.pop(dCtx),
                                    ),
                                    AppButton(
                                      label: context.l10n.save,
                                      variant: AppButtonVariant.primary,
                                      onPressed: () {
                                        setState(() {
                                          _draftBlNumberCtrl.text = editCtrl.text.trim();
                                        });
                                        Navigator.pop(dCtx);
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                            )),
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
                      color: AppTheme.severityBackgroundOf(context, AppSeverity.warning),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.severityForegroundOf(context, AppSeverity.warning), width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, color: AppTheme.severityForegroundOf(context, AppSeverity.warning), size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.draftBlSafetyAlertTitle,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.severityForegroundOf(context, AppSeverity.warning)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _safetyWarning ?? context.l10n.draftBlSafetyAlertSub,
                                style: TextStyle(fontSize: 12, color: AppTheme.charcoal),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: _missingCriticalFields.map((f) {
                                  final label = f is Map ? (f['field_label'] ?? f['field_key']) : f.toString();
                                  return Chip(
                                    label: Text(label.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.white)),
                                    backgroundColor: AppTheme.severityForegroundOf(context, AppSeverity.warning),
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
                      color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.emeraldBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: AppTheme.emerald, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.draftBlSmartExtractionComplete,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald),
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
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
                      child: IdocUi.fit(AppButton(
                        label: context.l10n.draftBlExtractFromTextButton,
                        icon: Icons.flash_on,
                        variant: AppButtonVariant.success,
                        onPressed: () => _runComparison(silent: false),
                      )),
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
              child: IdocUi.fit(AppButton(
                label: context.l10n.draftBlSwitchToGridView,
                icon: Icons.grid_view,
                variant: AppButtonVariant.ghost,
                onPressed: () => setState(() => _showReferenceAsVisualBL = false),
              )),
            ),
          ),
        ] else ...[
          Card(
            elevation: 2,
            color: AppTheme.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.transparent),
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
                              color: AppTheme.textPrimaryOf(context),
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          IdocUi.fit(AppButton(
                            label: context.l10n.draftBlSwitchToVisualBl,
                            icon: Icons.description,
                            variant: AppButtonVariant.primary,
                            size: AppButtonSize.small,
                            onPressed: () => setState(() => _showReferenceAsVisualBL = true),
                          )),
                          IdocUi.fit(AppButton(
                            label: context.l10n.draftBlPrintButton,
                            icon: Icons.print,
                            variant: AppButtonVariant.primary,
                            size: AppButtonSize.small,
                            onPressed: () => DraftBLExportService.printDraftBL(
                              systemData: sys,
                              draftData: sys,
                              documentTitle: 'SYSTEM REFERENCE BILL OF LADING — NOT NEGOTIABLE',
                            ),
                          )),
                          IdocUi.fit(AppButton(
                            label: context.l10n.draftBlDownloadPdfButton,
                            icon: Icons.picture_as_pdf,
                            variant: AppButtonVariant.danger,
                            size: AppButtonSize.small,
                            onPressed: () => DraftBLExportService.exportDraftBLToPdf(
                              systemData: sys,
                              draftData: sys,
                              documentTitle: 'SYSTEM REFERENCE BILL OF LADING — NOT NEGOTIABLE',
                            ),
                          )),
                          IdocUi.fit(AppButton(
                            label: context.l10n.draftBlDownloadExcelButton,
                            icon: Icons.table_chart,
                            variant: AppButtonVariant.success,
                            size: AppButtonSize.small,
                            onPressed: () => DraftBLExportService.exportDraftBLToExcel(
                              systemData: sys,
                              draftData: sys,
                            ),
                          )),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.draftBlAutoSummarySub,
                    style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 12),
                  ),
                  const Divider(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildSummaryBox(context.l10n.draftBlSummaryShipper, sys['shipper'] ?? context.l10n.unspecified, Icons.business, AppTheme.wcagCobalt, flex: 2),
                      _buildSummaryBox(context.l10n.draftBlSummaryConsignee, sys['consignee'] ?? context.l10n.unspecified, Icons.account_balance, AppTheme.cobalt, flex: 2),
                      _buildSummaryBox(context.l10n.draftBlSummaryNotifyParty, sys['notify_party'] ?? 'SAME AS CONSIGNEE', Icons.notifications_active, AppTheme.cobalt, flex: 2),
                      _buildSummaryBox(context.l10n.draftBlSummaryVesselVoyage, '${sys['vessel_name'] ?? 'N/A'} - ${sys['voyage_number'] ?? 'N/A'}', Icons.directions_boat, AppTheme.emerald),
                      _buildSummaryBox(context.l10n.draftBlSummaryPorts, '${sys['pol'] ?? 'N/A'} ➔ ${sys['pod'] ?? 'N/A'}', Icons.anchor, AppTheme.wcagCobalt),
                      _buildSummaryBox(context.l10n.draftBlSummaryFreightTerms, sys['freight_terms'] ?? 'Freight Prepaid', Icons.payment, AppTheme.orange),
                      _buildSummaryBox(context.l10n.draftBlSummaryBookingNo, sys['booking_no'] ?? 'N/A', Icons.confirmation_number, AppTheme.charcoal),
                      _buildSummaryBox(context.l10n.draftBlSummaryAcidNo, sys['acid_number'] ?? 'N/A', Icons.security, AppTheme.crimson, isCritical: true),
                      _buildSummaryBox(context.l10n.draftBlSummaryImporterTaxId, sys['importer_tax_id'] ?? 'N/A', Icons.badge, AppTheme.crimson, isCritical: true),
                      _buildSummaryBox(context.l10n.draftBlSummaryShipperReg, sys['shipper_reg_id'] ?? 'N/A', Icons.pin, AppTheme.crimson, isCritical: true),
                      _buildSummaryBox(context.l10n.draftBlSummaryContainers, sys['container_summary'] ?? 'N/A', Icons.inventory, AppTheme.emerald, flex: 2),
                      _buildSummaryBox(context.l10n.draftBlSummaryGrossWeight, '${sys['total_gross_weight_kg'] ?? 0.0} kg', Icons.scale, AppTheme.emerald),
                      _buildSummaryBox(context.l10n.draftBlSummaryNetWeight, '${sys['total_net_weight_kg'] ?? 0.0} kg', Icons.fitness_center, AppTheme.wcagCobalt),
                      _buildSummaryBox(context.l10n.draftBlSummaryCbm, '${sys['cbm'] ?? 0.0} CBM', Icons.view_in_ar, AppTheme.orange),
                      _buildSummaryBox(context.l10n.draftBlSummaryPackages, '${sys['qty_pkg'] ?? 0} (${sys['goods_description'] ?? 'Goods'})', Icons.category, AppTheme.wcagCobalt, flex: 2),
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
          color: AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.transparent),
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
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        IdocUi.fit(AppButton(
                          key: const Key('draftBlSaveDraftBtn'),
                          label: context.l10n.idocASaveTempDraft,
                          icon: Icons.bookmark_added_outlined,
                          variant: AppButtonVariant.secondary,
                          isLoading: _isSavingDraft,
                          onPressed: _isLoading ? null : () => _saveReview(isDraft: true),
                        )),
                        IdocUi.fit(AppButton(
                          key: const Key('draftBlCertifyBtn'),
                          label: context.l10n.idocAFinalApprovalOfDocuments,
                          icon: Icons.verified_rounded,
                          variant: AppButtonVariant.success,
                          isLoading: _isCertifying,
                          onPressed: _isLoading ? null : () => _saveReview(isDraft: false),
                        )),
                        IdocUi.fit(AppButton(
                          label: context.l10n.draftBlRevisionReportCarrierButton,
                          icon: Icons.assignment_late,
                          variant: AppButtonVariant.primary,
                          onPressed: () => setState(() => _activeStep = 1),
                        )),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.draftBlChecklistSectionSub,
                  style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 12),
                ),
                const Divider(height: 20),
                if (checklist.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(context.l10n.draftBlSelectFileToStartChecklist, style: const TextStyle(color: AppTheme.textMuted)),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 70,
                      headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAltOf(context)),
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
                            if (!isCorrect && !isNA) return AppTheme.severityBackgroundOf(context, AppSeverity.danger).withValues(alpha: 0.5);
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
                                          hintStyle: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(6),
                                            borderSide: BorderSide(
                                              color: (itm.draftValue != null && itm.draftValue.toString().isNotEmpty)
                                                  ? (isCorrect ? AppTheme.emeraldBorder : AppTheme.orange)
                                                  : AppTheme.borderOf(context),
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: AppTheme.surfaceOf(context),
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isCorrect ? AppTheme.severityForegroundOf(context, AppSeverity.success) : AppTheme.textPrimaryOf(context),
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
                                  DropdownMenuItem(value: 'Correct', child: Text('✅ ${context.l10n.draftBlStatusCorrect}', style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 12))),
                                  DropdownMenuItem(value: 'Incorrect', child: Text('❌ ${context.l10n.draftBlStatusIncorrect}', style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 12))),
                                  DropdownMenuItem(value: 'N/A', child: Text('⚪ ${context.l10n.draftBlStatusNA}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
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
                                    hintStyle: TextStyle(fontSize: 11, color: isCorrect ? AppTheme.emerald : AppTheme.textMutedOf(context)),
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
                                child: SearchableDropdownField<String>(
                                  value: itm.responsibleParty ?? 'Shipping Provider',
                                  labelText: context.l10n.draftBlPartyShippingLine,
                                  items: [
                                    SearchableDropdownItem(value: 'Shipping Provider', label: context.l10n.draftBlPartyShippingLine),
                                    SearchableDropdownItem(value: 'Supplier', label: context.l10n.draftBlPartySupplier),
                                    SearchableDropdownItem(value: 'Importer', label: context.l10n.draftBlPartyImporter),
                                    SearchableDropdownItem(value: 'Customs Broker', label: context.l10n.draftBlPartyCustomsBroker),
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
        color: isCritical ? AppTheme.severityBackgroundOf(context, AppSeverity.danger).withValues(alpha: 0.5) : AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isCritical ? AppTheme.crimson : color.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            radius: 16,
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11.5, color: isCritical ? AppTheme.severityForegroundOf(context, AppSeverity.danger) : AppTheme.textSecondaryOf(context), fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                CopyableText(
                  value,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isCritical ? AppTheme.severityForegroundOf(context, AppSeverity.danger) : AppTheme.textPrimaryOf(context)),
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
                    const Icon(Icons.folder_off, size: 48, color: AppTheme.orange),
                    const SizedBox(height: 12),
                    Text(context.l10n.draftBlSelectFileToViewRevision, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    IdocUi.fit(AppButton(
                      label: context.l10n.draftBlBackToSelectFile,
                      icon: Icons.arrow_back,
                      variant: AppButtonVariant.primary,
                      onPressed: () => setState(() => _activeStep = 0),
                    )),
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
                          const Icon(Icons.assignment_late, color: AppTheme.orange, size: 24),
                          const SizedBox(width: 8),
                          Text(context.l10n.draftBlRevisionReportTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IdocUi.fit(AppButton(
                        label: context.l10n.draftBlProceedToVersionHistory,
                        icon: Icons.history,
                        variant: AppButtonVariant.primary,
                        onPressed: () => setState(() => _activeStep = 2),
                      )),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(context.l10n.draftBlRevisionReportSub, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  const Divider(height: 20),
                  if (incorrectItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppTheme.severityBackgroundOf(context, AppSeverity.success), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.emerald)),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppTheme.emerald),
                          const SizedBox(width: 10),
                          Text(context.l10n.draftBlNoAmendmentsNeeded, style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold)),
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
                            child: Text(corr, style: const TextStyle(color: AppTheme.crimson)),
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
                      IdocUi.fit(AppButton(
                        label: context.l10n.draftBlCopyLetterButton,
                        icon: Icons.copy,
                        variant: AppButtonVariant.success,
                        onPressed: () => CopyHelper.copy(context, letter),
                      )),
                    ],
                  ),
                  const Divider(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.surfaceAltOf(context), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.borderOf(context))),
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
                    const Icon(Icons.folder_off, size: 48, color: AppTheme.orange),
                    const SizedBox(height: 12),
                    Text(context.l10n.draftBlSelectFileToViewVersions, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    IdocUi.fit(AppButton(
                      label: context.l10n.draftBlBackToSelectFile,
                      icon: Icons.arrow_back,
                      variant: AppButtonVariant.primary,
                      onPressed: () => setState(() => _activeStep = 0),
                    )),
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
                      IdocUi.fit(AppButton(
                        label: context.l10n.draftBlProceedToDualApproval,
                        icon: Icons.verified_user,
                        variant: AppButtonVariant.primary,
                        onPressed: () => setState(() => _activeStep = 3),
                      )),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.draftBlVersionBranchingSub,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const Divider(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.severityBackgroundOf(context, AppSeverity.info), borderRadius: BorderRadius.circular(8)),
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
    final singleRole = draftBlSingleStepRole(_activeSession, currentUserNames: _currentUserNames());
    final reasons = _comparisonResult == null
        ? <String>[]
        : displayBlockingReasons(context.l10n, _comparisonResult!.blockingReasons, _comparisonResult!.blockingReasonsCoded);

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
                    const Icon(Icons.folder_off, size: 48, color: AppTheme.orange),
                    const SizedBox(height: 12),
                    Text(context.l10n.draftBlSelectFileToCompleteApproval, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    IdocUi.fit(AppButton(
                      label: context.l10n.draftBlBackToSelectFile,
                      icon: Icons.arrow_back,
                      variant: AppButtonVariant.primary,
                      onPressed: () => setState(() => _activeStep = 0),
                    )),
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
              decoration: BoxDecoration(color: AppTheme.severityBackgroundOf(context, AppSeverity.danger), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.crimson)),
              child: Row(
                children: [
                  const Icon(Icons.block, color: AppTheme.crimson, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.draftBlApprovalBlockedTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson)),
                        const SizedBox(height: 4),
                        Text(reasons.join(' | '), style: TextStyle(fontSize: 12, color: AppTheme.severityForegroundOf(context, AppSeverity.danger))),
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
                                color: _activeSession?.importerApprovalStatus == 'Approved' ? AppTheme.emerald : AppTheme.orange,
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
                            if (singleRole == null || singleRole == 'importer')
                            Expanded(
                              child: IdocUi.fit(AppButton(
                                key: const Key('draftBlImporterApproveBtn'),
                                label: context.l10n.draftBlApproveAndAcceptButton,
                                icon: Icons.check,
                                variant: AppButtonVariant.success,
                                onPressed: (hasBlocking || _isLoading)
                                    ? null
                                    : (singleRole == 'importer' ? _approveSingleStep : () => _submitApproval('importer', 'Approved')),
                              )),
                            ),
                            const SizedBox(width: 8),
                            IdocUi.fit(AppButton(
                              label: context.l10n.draftBlRejectDraftButton,
                              icon: Icons.close,
                              variant: AppButtonVariant.danger,
                              onPressed: _isLoading ? null : () => _submitApproval('importer', 'Rejected'),
                            )),
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
                            const Icon(Icons.gavel, color: AppTheme.emerald),
                            const SizedBox(width: 8),
                            Text(context.l10n.draftBlBrokerApprovalTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text(
                              _activeSession?.brokerApprovalStatus == 'Approved' ? context.l10n.approved : context.l10n.pending,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _activeSession?.brokerApprovalStatus == 'Approved' ? AppTheme.emerald : AppTheme.orange,
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
                            if (singleRole == null || singleRole == 'customs_broker')
                            Expanded(
                              child: IdocUi.fit(AppButton(
                                key: const Key('draftBlBrokerApproveBtn'),
                                label: context.l10n.draftBlBrokerApproveButton,
                                icon: Icons.check,
                                variant: AppButtonVariant.success,
                                onPressed: (hasBlocking || _isLoading)
                                    ? null
                                    : (singleRole == 'customs_broker' ? _approveSingleStep : () => _submitApproval('customs_broker', 'Approved')),
                              )),
                            ),
                            const SizedBox(width: 8),
                            IdocUi.fit(AppButton(
                              label: context.l10n.draftBlRejectDraftButton,
                              icon: Icons.close,
                              variant: AppButtonVariant.danger,
                              onPressed: _isLoading ? null : () => _submitApproval('customs_broker', 'Rejected'),
                            )),
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
      color: AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.transparent),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (ctx, constraints) {
                final actions = [
                  IdocUi.fit(AppButton(
                    key: const Key('stage5SearchAndCloneBtn'),
                    label: context.l10n.searchAndCloneDraftBlBtn,
                    icon: Icons.copy_all,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: _openSearchAndCloneDraftBlDialog,
                  )),
                  IdocUi.fit(AppButton(
                    key: const Key('stage5RefreshRegistryBtn'),
                    label: context.l10n.draftBlRefreshRegistry,
                    icon: Icons.refresh,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    onPressed: () {
                      ref.invalidate(draftBLReviewsProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.draftBlRegistryUpdatedSuccess)),
                      );
                    },
                  )),
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
                        const Icon(Icons.verified, color: AppTheme.emerald, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.idocABillOfLadingBLReview,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryOf(context),
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
              context.l10n.idocAComprehensiveRegistryOfTemporaryAndFinally,
              style: TextStyle(color: AppTheme.textMutedOf(context), fontSize: 13),
            ),
            const SizedBox(height: 16),

            // 1. KPI Cards Banner
            IdocUi.metrics([
              MetricCardData(
                title: context.l10n.idocATotalBLSessions,
                shortTitle: context.l10n.idocATotalBLSessions,
                value: '$totalCount',
                icon: Icons.assignment_turned_in,
                color: AppTheme.cobalt,
              ),
              MetricCardData(
                title: context.l10n.idocAFinallyApprovedSessions,
                shortTitle: context.l10n.idocAFinallyApprovedSessions,
                value: '$certifiedCount',
                icon: Icons.verified_rounded,
                color: AppTheme.emerald,
              ),
              MetricCardData(
                title: context.l10n.idocATemporaryDraftsBeingEdited,
                shortTitle: context.l10n.idocATemporaryDraftsBeingEdited,
                value: '$draftCount',
                icon: Icons.bookmark_added_outlined,
                color: AppTheme.orange,
              ),
            ]),
            const SizedBox(height: 16),

            // 2. Filter & Actions Toolbar
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: Text(context.l10n.idocAAllCount(totalCount)),
                  selected: _selectedStatusFilter == 'ALL',
                  onSelected: (_) => setState(() => _selectedStatusFilter = 'ALL'),
                  selectedColor: AppTheme.cobalt,
                  labelStyle: TextStyle(
                    color: _selectedStatusFilter == 'ALL' ? AppTheme.white : (AppTheme.textPrimaryOf(context)),
                    fontWeight: _selectedStatusFilter == 'ALL' ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
                ChoiceChip(
                  label: Text(context.l10n.idocAFinalApprovedCount(certifiedCount)),
                  selected: _selectedStatusFilter == 'CERTIFIED',
                  onSelected: (_) => setState(() => _selectedStatusFilter = 'CERTIFIED'),
                  selectedColor: AppTheme.emerald,
                  labelStyle: TextStyle(
                    color: _selectedStatusFilter == 'CERTIFIED' ? AppTheme.white : (AppTheme.textPrimaryOf(context)),
                    fontWeight: _selectedStatusFilter == 'CERTIFIED' ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
                ChoiceChip(
                  label: Text(context.l10n.idocATemporaryDraftsCount(draftCount)),
                  selected: _selectedStatusFilter == 'DRAFT',
                  onSelected: (_) => setState(() => _selectedStatusFilter = 'DRAFT'),
                  selectedColor: AppTheme.orange,
                  labelStyle: TextStyle(
                    color: _selectedStatusFilter == 'DRAFT' ? AppTheme.white : (AppTheme.textPrimaryOf(context)),
                    fontWeight: _selectedStatusFilter == 'DRAFT' ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
                if (importFiles.isNotEmpty)
                  SizedBox(
                    width: 280,
                    child: SearchableDropdownField<int?>(
                      labelText: context.l10n.idocAFilterByImportFile,
                      value: _filterImportFileId,
                      items: [
                        SearchableDropdownItem<int?>(value: null, label: context.l10n.idocAAllShipmentsAndFiles),
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
                final searchBar = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAltOf(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderOf(context)),
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
                            hintStyle: TextStyle(color: isDark ? AppTheme.textMutedOf(context) : null),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: TextStyle(color: isDark ? AppTheme.white : null),
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
                  IdocUi.fit(AppButton(
                    key: const Key('draftBlRegistryCopyBtn'),
                    label: context.l10n.idocACopyTSV,
                    icon: Icons.copy,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _copyDraftBlRegistryAsTsv(filteredReviews),
                  )),
                  IdocUi.fit(AppButton(
                    key: const Key('draftBlRegistryExcelBtn'),
                    label: context.l10n.exportExcel,
                    icon: Icons.table_chart,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _exportDraftBlRegistryToExcel(filteredReviews),
                  )),
                  IdocUi.fit(AppButton(
                    key: const Key('draftBlRegistryPdfBtn'),
                    label: context.l10n.exportPdf,
                    icon: Icons.picture_as_pdf,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _exportDraftBlRegistryToPdf(filteredReviews),
                  )),
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
                      Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.textMutedOf(context)),
                      const SizedBox(height: 10),
                      Text(
                        _registrySearchQuery.isNotEmpty ? context.l10n.draftBlNoRegistriesFound : context.l10n.draftBlNoRegistriesYet,
                        style: TextStyle(color: AppTheme.textMutedOf(context), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _registrySearchQuery.isNotEmpty ? context.l10n.draftBlTryDifferentSearch : context.l10n.draftBlExtractNewDraftHint,
                        style: TextStyle(color: isDark ? AppTheme.textMutedOf(context) : AppTheme.textSecondaryOf(context), fontSize: 12),
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
                      headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAltOf(context)),
                      columns: [
                        DataColumn(label: Text(context.l10n.draftBlRegistryColActions, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(context.l10n.idocASessionType, style: TextStyle(fontWeight: FontWeight.bold))),
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
                          isDraft ? context.l10n.idocADraft : context.l10n.idocACertified,
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
                                  message: context.l10n.idocARestoreAndLoadTheSessionInAlt,
                                  child: IconButton(
                                    icon: const Icon(Icons.play_circle_outline, size: 18, color: AppTheme.cobalt),
                                    onPressed: () => _loadSessionIntoEditor(r),
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                Tooltip(
                                  message: context.l10n.idocAViewSessionDetailsAndMatrix,
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
                                    icon: Icon(Icons.print, size: 18, color: AppTheme.textPrimaryOf(context)),
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
                                            SnackBar(content: Text(context.l10n.draftBlPrintError(ApiErrorText.of(context.l10n, e))), backgroundColor: AppTheme.crimson),
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
                                            SnackBar(content: Text(context.l10n.draftBlPdfExportError(ApiErrorText.of(context.l10n, e))), backgroundColor: AppTheme.crimson),
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
                                    message: context.l10n.idocADeleteDraft,
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
                            IdocStatusChip(
                              label: isDraft ? context.l10n.idocADraft : context.l10n.idocACertified,
                              severity: isDraft ? AppSeverity.warning : AppSeverity.success,
                              icon: isDraft ? Icons.edit_document : Icons.verified_rounded,
                            ),
                          ),
                          DataCell(CopyableTableCell(
                            value: '#${r.blReviewId}',
                            rowSummary: rowSummary,
                            child: Text('#${r.blReviewId}', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
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
                                    color: AppTheme.cobalt.withValues(alpha: isDark ? 0.2 : 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
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
                                color: isDark ? AppTheme.textPrimaryOf(context) : AppTheme.surfaceAltOf(context),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.borderOf(context)),
                              ),
                              child: Text(
                                r.stage,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryOf(context),
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
                                color: r.importerApprovalStatus == 'Approved' ? AppTheme.emerald : AppTheme.orange,
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
                                color: r.brokerApprovalStatus == 'Approved' ? AppTheme.emerald : AppTheme.orange,
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
                                    ? (isDark ? AppTheme.severityForegroundOf(context, AppSeverity.success).withValues(alpha: 0.3) : AppTheme.severityBackgroundOf(context, AppSeverity.success))
                                    : (isDark ? AppTheme.severityForegroundOf(context, AppSeverity.info).withValues(alpha: 0.3) : AppTheme.severityBackgroundOf(context, AppSeverity.info)),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: r.status == 'Final Approved' || r.status == 'Approved'
                                      ? (isDark ? AppTheme.severityForegroundOf(context, AppSeverity.success) : AppTheme.emeraldBorder)
                                      : (isDark ? AppTheme.severityForegroundOf(context, AppSeverity.info) : AppTheme.cobaltBorder),
                                ),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: r.status == 'Final Approved' || r.status == 'Approved'
                                      ? (isDark ? AppTheme.emerald : AppTheme.severityForegroundOf(context, AppSeverity.success))
                                      : (isDark ? AppTheme.cobalt : AppTheme.severityForegroundOf(context, AppSeverity.info)),
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
      SnackBar(content: Text(context.l10n.idocASessionRestoredReview(session.blReviewCode))),
    );
  }

  Future<void> _deleteDraftBLSession(DraftBLReviewModel session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: AppTheme.crimson),
            SizedBox(width: 8),
            Text(context.l10n.idocAConfirmDraftSessionDeletion),
          ],
        ),
        content: Text(context.l10n.idocAAreYouSureYouWantToAlt(session.blReviewCode)),
        actions: [
          IdocUi.fit(AppButton(
            label: context.l10n.cancel,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx, false),
          )),
          IdocUi.fit(AppButton(
            label: context.l10n.idocAConfirmDeletion,
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.pop(ctx, true),
          )),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(draftBLReviewsProvider.notifier).deleteDraftBLReview(session.blReviewId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.idocADraftSessionDeletedSuccessfully), backgroundColor: AppTheme.crimson),
          );
        }
      } catch (e) {
        // e.g. 409 when the review is FINAL.
        if (mounted) showIdocError(context, e);
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
                color: (isDraft ? AppTheme.orange : AppTheme.emerald).withValues(alpha: 0.12),
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
                    context.l10n.idocASessionDetailsTitle(session.blReviewCode),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.idocABlNumberCreated(session.draftBlNumber, session.createdAt),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (isDraft ? AppTheme.orange : AppTheme.emerald).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDraft ? AppTheme.orange : AppTheme.emerald),
              ),
              child: Text(
                isDraft ? context.l10n.idocADraft : context.l10n.idocACertified,
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
                SizedBox(height: 8),
                Text(context.l10n.idocAReviewAndComparisonMatrix, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(height: 8),
                if (matrix.isEmpty)
                  Center(child: Padding(padding: EdgeInsets.all(20), child: Text(context.l10n.idocANoSavedMatrixItems)))
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppTheme.charcoal),
                      headingTextStyle: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 12),
                      columns: [
                        DataColumn(label: Text(context.l10n.idocAStandardField)),
                        DataColumn(label: Text(context.l10n.idocAValueRecordedInTheSystem)),
                        DataColumn(label: Text(context.l10n.idocAValueInTheDraftBL)),
                        DataColumn(label: Text(context.l10n.idocAMatchStatus)),
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
                                color: item.matchStatus == 'MATCH' ? AppTheme.emerald.withValues(alpha: 0.12) : AppTheme.crimson.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.matchStatus == 'MATCH' ? context.l10n.idocAMatched : context.l10n.idocAVariance,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: item.matchStatus == 'MATCH' ? AppTheme.emerald : AppTheme.crimson,
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
          IdocUi.fit(AppButton(
            label: context.l10n.idocARestoreAndLoadInTheReview,
            icon: Icons.play_circle_outline,
            variant: AppButtonVariant.ghost,
            onPressed: () {
              Navigator.pop(ctx);
              _loadSessionIntoEditor(session);
            },
          )),
          IdocUi.fit(AppButton(
            label: context.l10n.close,
            variant: AppButtonVariant.primary,
            onPressed: () => Navigator.pop(ctx),
          )),
        ],
      ),
    );
  }

  Widget _buildFormatBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _exportDraftBlRegistryToExcel(List<dynamic> reviews) async {
    final headers = [
      context.l10n.idocASessionTypeAlt,
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
        r.isDraft ? (context.l10n.idocADraft) : (context.l10n.idocACertified),
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
      stageName: context.l10n.idocADraftBLRegistry,
      importFileNameOrCode: 'Draft_BL_Registry',
    );
  }

  Future<void> _exportDraftBlRegistryToPdf(List<dynamic> reviews) async {
    final headers = [
      context.l10n.idocASessionTypeAlt,
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
        r.isDraft ? (context.l10n.idocADraft) : (context.l10n.idocACertified),
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
      stageName: context.l10n.idocADraftBLRegistry,
      importFileNameOrCode: 'Draft_BL_Registry',
    );
  }

  void _copyDraftBlRegistryAsTsv(List<dynamic> reviews) {
    final headers = [
      context.l10n.idocASessionTypeAlt,
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
        r.isDraft ? (context.l10n.idocADraft) : (context.l10n.idocACertified),
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
