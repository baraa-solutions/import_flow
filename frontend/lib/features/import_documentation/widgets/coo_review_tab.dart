import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/system_messages/coded_item_text.dart';
import '../../../core/localization/app_localizations_ar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import 'idoc_ui_b.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/import_doc_stepper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/smart_upload_button.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import '../providers/docs_customs_approval_provider.dart';
import '../services/coo_export_service.dart';
import 'search_and_clone_coo_dialog.dart';
import 'visual_draft_coo_sheet.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/services/table_export_service.dart';

class COOReviewTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  const COOReviewTab({super.key, this.initialImportFileId});

  @override
  ConsumerState<COOReviewTab> createState() => COOReviewTabState();
}

class COOReviewTabState extends ConsumerState<COOReviewTab> {
  void openSearchAndCloneDialog([List<CertificateOfOriginReviewModel>? reviews]) {
    _openSearchAndCloneCooDialog(reviews);
  }
  int _activeStep = 0; // 0: Requirements, 1: Smart Input, 2: Discrepancy Matrix, 3: Registry
  int? _selectedImportFileId;

  String _selectedStatusFilter = 'ALL';
  int? _filterImportFileId;
  bool _isSavingDraft = false;
  bool _isCertifying = false;

  String _certType = 'EUR.1';
  final TextEditingController _certNumberCtrl = TextEditingController();
  final TextEditingController _exporterCtrl = TextEditingController();
  final TextEditingController _exporterRegIdCtrl = TextEditingController();
  final TextEditingController _importerCtrl = TextEditingController();
  final TextEditingController _originCountryCtrl = TextEditingController();
  final TextEditingController _destCountryCtrl = TextEditingController();
  final TextEditingController _invoiceNoCtrl = TextEditingController();
  final TextEditingController _rawTextCtrl = TextEditingController();
  final TextEditingController _overrideReasonCtrl = TextEditingController();
  final TextEditingController _registrySearchCtrl = TextEditingController();

  bool _isLoading = false;
  Map<String, dynamic>? _comparisonResult;
  String? _pickedFileName;
  Map<String, dynamic>? _activeDraftTemplate;
  String? _activeAcidNumber;
  String? _activeExemptionNotes;
  String? _recommendationAlert;
  bool _isManualChoiceRequired = false;
  List<String> _allowedCertTypes = [];

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!ref.read(importFilesProvider).isLoading) {
        await ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
      if (!ref.read(cooReviewsProvider).isLoading) {
        await ref.read(cooReviewsProvider.notifier).fetchCOOReviews();
      }
      final files = ref.read(importFilesProvider).valueOrNull ?? [];
      if (_selectedImportFileId == null && files.isNotEmpty) {
        if (mounted) {
          setState(() {
            _selectedImportFileId = files.first.importFileId;
          });
        }
      }
      if (_selectedImportFileId != null) {
        _loadSnapshot(_selectedImportFileId!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant COOReviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImportFileId != oldWidget.initialImportFileId && widget.initialImportFileId != null) {
      setState(() {
        _selectedImportFileId = widget.initialImportFileId;
      });
      _loadSnapshot(_selectedImportFileId!);
    }
  }

  @override
  void dispose() {
    _certNumberCtrl.dispose();
    _exporterCtrl.dispose();
    _exporterRegIdCtrl.dispose();
    _importerCtrl.dispose();
    _originCountryCtrl.dispose();
    _destCountryCtrl.dispose();
    _invoiceNoCtrl.dispose();
    _rawTextCtrl.dispose();
    _overrideReasonCtrl.dispose();
    _registrySearchCtrl.dispose();
    super.dispose();
  }

  void _openSearchAndCloneCooDialog([List<CertificateOfOriginReviewModel>? reviews]) {
    final list = reviews ?? ref.read(cooReviewsProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (ctx) => SearchAndCloneCooDialog(
        reviews: list,
        onSelectReview: (r) => _cloneCOOReview(r),
      ),
    );
  }

  void _cloneCOOReview(CertificateOfOriginReviewModel session) {
    final expName = session.draftInputData?['exporter_name'] ??
        session.draftInputData?['box_1_exporter'] ??
        session.systemSnapshotData?['supplier_name'] ??
        '—';
    final impName = session.draftInputData?['importer_name'] ??
        session.draftInputData?['box_2_consignee'] ??
        session.systemSnapshotData?['company_name'] ??
        '—';
    final originCountry = session.draftInputData?['country_of_origin'] ??
        session.draftInputData?['box_3_country_of_origin'] ??
        '—';
    final destCountry = session.draftInputData?['destination_country'] ??
        session.draftInputData?['box_4_country_of_destination'] ??
        '—';
    final invNo = session.draftInputData?['invoice_number'] ??
        session.draftInputData?['box_10_invoice_number_and_date'] ??
        '—';
    final rawTxt = session.rawText ?? session.draftInputData?['raw_text'] ?? '';

    final suggestedCode = session.certificateType.contains('EUR')
        ? 'DRAFT-EUR1-2026-'
        : 'DRAFT-COO-2026-';

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: CloneEntityReviewDialog(
            entityType: context.l10n.idocBCooCloneEntity,
            sourceCode: session.cooReviewCode,
            sourceTitle: '${session.certificateType} - ${session.certificateNumber}',
            suggestedNewCode: suggestedCode,
            copiedFieldsSummary: {
              context.l10n.idocBCooCloneFieldType: session.certificateType,
              context.l10n.idocBCooCloneFieldExporter: expName,
              context.l10n.idocBCooCloneFieldImporter: impName,
              context.l10n.idocBCooCloneFieldOrigin: originCountry,
              context.l10n.idocBCooCloneFieldDestination: destCountry,
              context.l10n.idocBCooCloneFieldInvoice: invNo,
            },
            mandatorilyResetFields: [
              context.l10n.idocBCooCloneReset1,
              context.l10n.idocBCooCloneReset2,
              context.l10n.idocBCooCloneReset3,
              context.l10n.idocBCooCloneReset4,
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
                _activeDraftTemplate = null;
                _comparisonResult = null;
                _selectedImportFileId = session.importFileId ?? _selectedImportFileId;
                _certType = session.certificateType;
                _certNumberCtrl.text = newCode.isNotEmpty ? newCode : suggestedCode;
                _exporterCtrl.text = expName != '—' ? expName : '';
                _importerCtrl.text = impName != '—' ? impName : '';
                _originCountryCtrl.text = originCountry != '—' ? originCountry : 'Germany';
                _destCountryCtrl.text = destCountry != '—' ? destCountry : 'Egypt';
                _invoiceNoCtrl.text = invNo != '—' ? invNo : '';
                _rawTextCtrl.text = rawTxt;
                _overrideReasonCtrl.clear();
                _activeStep = 1; // Jump to Step 1 (Smart Input) for immediate review & comparison
              });
              if (_selectedImportFileId != null) {
                _loadSnapshot(_selectedImportFileId!);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.cloneCooSuccess),
                  backgroundColor: AppTheme.emerald,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _getFieldLabel(String fieldKey, String? labelAr, AppLocalizations l10n) {
    switch (fieldKey) {
      case 'exporter_name':
        return l10n.cooExporterNameLabel.replaceAll('*', '').trim();
      case 'exporter_reg_id':
        return l10n.cooExporterRegIdLabel;
      case 'importer_name':
        return l10n.cooImporterNameLabel.replaceAll('*', '').trim();
      case 'country_of_origin':
        return l10n.cooOriginCountryLabel;
      case 'destination_country':
        return l10n.cooDestinationCountryLabel;
      case 'invoice_number':
        return l10n.cooInvoiceNumberLabel;
      case 'certificate_type':
        return l10n.cooCertTypeLabel;
      case 'certificate_number':
        return l10n.cooDraftCertNumberLabel;
      default:
        return (l10n is AppLocalizationsAr && labelAr != null && labelAr.isNotEmpty) ? labelAr : fieldKey;
    }
  }

  String _localizeAlert(BuildContext context, String? alert) {
    if (alert == null || alert.isEmpty) return '';
    if (context.l10n.isArabic) return alert;
    if (alert.contains('الصين') || alert.contains('China')) {
      return context.l10n.cooChinaRecommendationAlert;
    }
    if (alert.contains('الاتحاد الأوروبي') || alert.contains('EUR.1') || alert.contains('EU')) {
      return context.l10n.cooEuRecommendationAlert;
    }
    if (alert.contains('أغادير') || alert.contains('Agadir')) {
      return context.l10n.cooAgadirGaftaRecommendationAlert;
    }
    return alert;
  }

  String _localizeExemption(BuildContext context, String? notes) {
    if (notes == null || notes.isEmpty) return '';
    if (context.l10n.isArabic) return notes;
    if (notes.contains('China') || notes.contains('الصين')) {
      return context.l10n.cooChinaGeneralExemptionNote;
    }
    return notes;
  }

  void _loadSnapshot(int fileId) {
    final files = ref.read(importFilesProvider).value ?? [];
    final file = files.where((f) => f.importFileId == fileId).firstOrNull;
    if (file != null) {
      _importerCtrl.text = file.companyName;
      _exporterCtrl.text = file.supplierName;
      _invoiceNoCtrl.text = file.piNumber ?? 'INV-FINAL-${file.importFileCode}';
    }
    _fetchAndApplyDraft(fileId);
  }

  Future<void> _fetchAndApplyDraft(int fileId, {String? overrideCertType}) async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(cooReviewsProvider.notifier).fetchCooDraftTemplate(
            fileId,
            certType: overrideCertType,
          );
      final template = res['template_data'] as Map<String, dynamic>? ?? {};
      final files = ref.read(importFilesProvider).value ?? [];
      final file = files.where((f) => f.importFileId == fileId).firstOrNull;
      final recType = res['recommended_certificate_type']?.toString();
      final retCertType = (res['certificate_type'] ?? template['certificate_type'] ?? recType)?.toString();
      final allowed = (res['allowed_certificate_types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final alertMsg = res['recommendation_alert']?.toString();
      final manualReq = res['is_manual_choice_required'] == true;

      if (mounted) {
        setState(() {
          if (overrideCertType != null) {
            _certType = overrideCertType;
          } else if (retCertType != null && retCertType.isNotEmpty) {
            _certType = retCertType;
          } else if (recType != null && recType.isNotEmpty) {
            _certType = recType;
          }
          _recommendationAlert = alertMsg;
          _isManualChoiceRequired = manualReq;
          _allowedCertTypes = allowed;
          _activeDraftTemplate = template;
          _activeAcidNumber = (file?.acidNumber != null && file!.acidNumber!.isNotEmpty)
              ? file.acidNumber
              : '';
          _activeExemptionNotes = res['exemption_notes']?.toString();

          if (template['certificate_number'] != null) _certNumberCtrl.text = template['certificate_number'].toString();
          if (template['country_of_origin'] != null) _originCountryCtrl.text = template['country_of_origin'].toString();
          if (template['box_1_exporter'] != null) _exporterCtrl.text = template['box_1_exporter'].toString();
          if (template['box_2_consignee'] != null) _importerCtrl.text = template['box_2_consignee'].toString();
        });
      }
    } catch (e) {
      debugPrint('Error fetching COO template: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateOfficialDraft() async {
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cooSelectFileFirstForComparison), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await ref.read(cooReviewsProvider.notifier).fetchCooDraftTemplate(
            _selectedImportFileId!,
            certType: _certType,
          );

      if (!mounted) return;

      final preview = res['preview_markdown']?.toString() ?? '';
      final template = res['template_data'] as Map<String, dynamic>? ?? {};
      final exemption = res['exemption_notes']?.toString() ?? '';
      final files = ref.read(importFilesProvider).value ?? [];
      final file = files.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;
      final acidNo = file?.acidNumber ?? '';

      setState(() {
        _activeDraftTemplate = template;
        _activeAcidNumber = acidNo;
        _activeExemptionNotes = exemption;
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified, color: AppTheme.cobalt),
                  const SizedBox(width: 8),
                  Text(context.l10n.cooVisualPreviewTitle(res['certificate_type'] ?? _certType),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textMuted),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          content: SizedBox(
            width: 860,
            child: SingleChildScrollView(
              child: VisualDraftCOOSheet(
                templateData: template,
                certificateType: res['certificate_type'] ?? _certType,
                acidNumber: acidNo,
                exemptionNotes: exemption,
                onRefresh: () => _fetchAndApplyDraft(_selectedImportFileId!),
              ),
            ),
          ),
          actions: [
            IdocBUi.fit(AppButton(label: context.l10n.cancel, onPressed: () => Navigator.pop(ctx), variant: AppButtonVariant.secondary)),
            IdocBUi.fit(AppButton(label: context.l10n.cooAutoFillFieldsButton, onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  if (template['certificate_number'] != null) _certNumberCtrl.text = template['certificate_number'].toString();
                  if (template['country_of_origin'] != null) _originCountryCtrl.text = template['country_of_origin'].toString();
                  if (template['destination_country'] != null) _destCountryCtrl.text = template['destination_country'].toString();
                  if (template['box_1_exporter'] != null) _exporterCtrl.text = template['box_1_exporter'].toString();
                  if (template['box_2_consignee'] != null) _importerCtrl.text = template['box_2_consignee'].toString();
                  _rawTextCtrl.text = preview;
                  _activeStep = 1;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.cooDraftFilledSuccess), backgroundColor: AppTheme.emerald),
                );
              }, variant: AppButtonVariant.success, icon: Icons.check)),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.cooGenerateDraftError(ApiErrorText.of(context.l10n, e))), backgroundColor: AppTheme.crimson),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _extractFromOcrText() async {
    final rawText = _rawTextCtrl.text.trim();
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cooPasteTextOrUploadWarning), backgroundColor: AppTheme.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final docTypeKey = _certType.contains('China') ? 'CHINA_COO' : (_certType.contains('EUR') ? 'EUR1' : 'STANDARD_COO');
      final res = await ref.read(cooReviewsProvider.notifier).extractCertificate(
            docTypeKey,
            rawText,
            importFileId: _selectedImportFileId,
          );

      final extracted = res['extracted_data'] as Map<String, dynamic>? ?? {};
      final warnings = res['warnings'] as List<dynamic>? ?? [];

      setState(() {
        _certNumberCtrl.text = extracted['certificate_number']?.toString() ?? '';
        _originCountryCtrl.text = extracted['country_of_origin']?.toString() ?? extracted['origin_country']?.toString() ?? '';
        _destCountryCtrl.text = extracted['destination_country']?.toString() ?? 'Egypt';
        _exporterCtrl.text = extracted['exporter_name']?.toString() ?? '';
        _exporterRegIdCtrl.text = extracted['exporter_reg_id']?.toString() ?? '';
        _importerCtrl.text = extracted['importer_name']?.toString() ?? extracted['consignee_name']?.toString() ?? '';
        _invoiceNoCtrl.text = extracted['invoice_number']?.toString() ?? '';
      });

      if (mounted) {
        if (warnings.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(warnings.join('\n')), backgroundColor: AppTheme.orange, duration: const Duration(seconds: 4)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.cooAiExtractSuccess), backgroundColor: AppTheme.emerald),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.cooExtractError(ApiErrorText.of(context.l10n, e))), backgroundColor: AppTheme.crimson),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runComparison() async {
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cooSelectFileFirstForComparison), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final draftFields = {
        'certificate_type': _certType,
        'certificate_number': _certNumberCtrl.text.trim(),
        'exporter_name': _exporterCtrl.text.trim(),
        'exporter_reg_id': _exporterRegIdCtrl.text.trim(),
        'importer_name': _importerCtrl.text.trim(),
        'country_of_origin': _originCountryCtrl.text.trim(),
        'destination_country': _destCountryCtrl.text.trim(),
        'invoice_number': _invoiceNoCtrl.text.trim(),
      };

      final res = await ref.read(cooReviewsProvider.notifier).compareCOO(
            _selectedImportFileId!,
            _certType,
            draftFields,
          );

      setState(() {
        _comparisonResult = res;
        _activeStep = 2;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.cooComparisonError(ApiErrorText.of(context.l10n, e))), backgroundColor: AppTheme.crimson),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveReview({bool isDraft = false}) async {
    if (_comparisonResult == null || _selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.cooSelectFileFirstForComparison),
          backgroundColor: AppTheme.orange,
        ),
      );
      return;
    }

    final hasDisc = _comparisonResult!['has_discrepancies'] as bool? ?? false;
    final hasCritical = _comparisonResult!['has_critical_mismatch'] as bool? ?? false;
    final reason = _overrideReasonCtrl.text.trim();

    if (!isDraft && (hasDisc || hasCritical) && reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.cooMustProvideJustificationSnackbar),
          backgroundColor: AppTheme.orange,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      if (isDraft) {
        _isSavingDraft = true;
      } else {
        _isCertifying = true;
      }
    });

    try {
      final snap = _comparisonResult!['system_snapshot_data'] as Map<String, dynamic>? ?? {};
      final draft = _comparisonResult!['draft_input_data'] as Map<String, dynamic>? ?? {};

      final expName = _exporterCtrl.text.trim().isNotEmpty
          ? _exporterCtrl.text.trim()
          : (draft['exporter_name'] ?? snap['exporter_name'] ?? 'Exporter');
      final impName = _importerCtrl.text.trim().isNotEmpty
          ? _importerCtrl.text.trim()
          : (draft['importer_name'] ?? snap['importer_name'] ?? 'Importer');
      final originCountry = _originCountryCtrl.text.trim().isNotEmpty
          ? _originCountryCtrl.text.trim()
          : (draft['country_of_origin'] ?? snap['country_of_origin'] ?? 'China');
      final destCountry = _destCountryCtrl.text.trim().isNotEmpty
          ? _destCountryCtrl.text.trim()
          : 'Egypt';

      final statusValue = isDraft
          ? 'Draft Generated'
          : (hasDisc ? (hasCritical ? 'Correction Requested' : 'Discrepancy_Accepted') : 'Approved');

      final payload = {
        'import_file_id': _selectedImportFileId,
        'certificate_type': _certType,
        'certificate_number': _certNumberCtrl.text.trim().isNotEmpty ? _certNumberCtrl.text.trim() : 'DRAFT-COO',
        'exporter_name': expName,
        'importer_name': impName,
        'country_of_origin': originCountry,
        'destination_country': destCountry,
        'invoice_number': _invoiceNoCtrl.text.trim(),
        'raw_input_text': _rawTextCtrl.text,
        'raw_text': _rawTextCtrl.text,
        'system_snapshot_data': _comparisonResult!['system_snapshot_data'],
        'draft_input_data': _comparisonResult!['draft_input_data'],
        'comparison_matrix': _comparisonResult!['comparison_matrix'],
        'has_discrepancies': hasDisc,
        'has_critical_mismatch': hasCritical,
        'override_reason': reason,
        'is_draft': isDraft,
        'status': statusValue,
      };

      await ref.read(cooReviewsProvider.notifier).saveCOOReview(payload);
      ref.invalidate(importFilesProvider);
      ref.invalidate(docsCustomsApprovalProvider);
      await ref.read(cooReviewsProvider.notifier).fetchCOOReviews();

      if (mounted) {
        final msg = isDraft
            ? '${context.l10n.idocBCooSavedDraft} 💾'
            : '${context.l10n.idocBCooCertified} ✅';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: isDraft ? AppTheme.cobalt : AppTheme.emerald,
          ),
        );
        setState(() => _activeStep = 3);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.cooSaveError(ApiErrorText.of(context.l10n, e))), backgroundColor: AppTheme.crimson),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSavingDraft = false;
          _isCertifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    if (_selectedImportFileId == null && importFiles.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedImportFileId == null && importFiles.isNotEmpty) {
          final firstId = importFiles.first.importFileId;
          setState(() {
            _selectedImportFileId = firstId;
          });
          _loadSnapshot(firstId);
        }
      });
    }

    final steps = [
      ImportDocStep(label: context.l10n.cooStage1Requirements, icon: Icons.description),
      ImportDocStep(label: context.l10n.cooStage2DraftInput, icon: Icons.file_upload),
      ImportDocStep(label: context.l10n.cooStage3DiscrepancyMatrix, icon: Icons.fact_check),
      ImportDocStep(label: context.l10n.cooStage4Registry, icon: Icons.history_edu),
    ];

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
          final reviews = ref.read(cooReviewsProvider).valueOrNull ?? [];
          _openSearchAndCloneCooDialog(reviews);
        },
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            // Unified Stepper Navigation
            ImportDocStepper(
              steps: steps,
              currentStep: _activeStep,
              onStepTapped: (i) => setState(() => _activeStep = i),
            ),
            const Divider(height: 1),

            // Body Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStep(importFiles),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep(List<dynamic> importFiles) {
    switch (_activeStep) {
      case 0:
        return _buildStep1(importFiles);
      case 1:
        return _buildStep2(importFiles);
      case 2:
        return _buildStep3(importFiles);
      case 3:
        return _buildStep4(importFiles);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1(List<dynamic> importFiles) {
    final existingReviews = ref.watch(cooReviewsProvider).valueOrNull ?? [];
    final existingReview = existingReviews.where((r) => r.importFileId == _selectedImportFileId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dedicated COO Decision Engine Header Card
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.charcoal, AppTheme.charcoal.withValues(alpha: 0.92)],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: AppTheme.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.cobalt.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.auto_awesome, color: AppTheme.darkHyperlink, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.cooDecisionEngineTitle,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.l10n.cooDecisionEngineSub,
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.cloudWhite),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedImportFileId != null)
                    IdocBUi.fit(AppButton(label: context.l10n.cooRecheckAgreementButton, onPressed: () => _fetchAndApplyDraft(_selectedImportFileId!), icon: Icons.refresh)),
                ],
              ),
              if (_selectedImportFileId != null) ...[
                const Divider(color: AppTheme.darkBorderLight, height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_originCountryCtrl.text.isNotEmpty || _activeDraftTemplate?['country_of_origin'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBorder,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.darkBorderLight),
                        ),
                        child: CopyableText(
                          context.l10n.cooInvoiceOriginBadge(_activeDraftTemplate?['country_of_origin'] ?? _originCountryCtrl.text),
                          style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isManualChoiceRequired ? AppTheme.orange.withValues(alpha: 0.2) : AppTheme.emerald.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _isManualChoiceRequired ? AppTheme.orange : AppTheme.emerald),
                      ),
                      child: CopyableText(
                        _isManualChoiceRequired ? context.l10n.cooManualChoiceRequiredBadge : context.l10n.cooApprovedCertBadge(_certType),
                        style: TextStyle(
                          color: _isManualChoiceRequired ? AppTheme.orange : AppTheme.emerald,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (_activeExemptionNotes != null && _activeExemptionNotes!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.darkHyperlink.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.savings_outlined, color: AppTheme.darkHyperlink, size: 14),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _localizeExemption(context, _activeExemptionNotes),
                                style: const TextStyle(color: AppTheme.darkHyperlink, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Recommendation & Status Card
        if (_recommendationAlert != null && _recommendationAlert!.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isManualChoiceRequired ? AppTheme.warningBackground : AppTheme.infoBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isManualChoiceRequired ? AppTheme.orange : AppTheme.cobaltBorder,
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _isManualChoiceRequired ? Icons.warning_amber_rounded : Icons.info_outline,
                  color: _isManualChoiceRequired ? AppTheme.warningForeground : AppTheme.cobalt,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _localizeAlert(context, _recommendationAlert),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: _isManualChoiceRequired ? AppTheme.warningForeground : AppTheme.charcoal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Certificate Type Selector Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (existingReview != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.infoBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cobaltBorder, width: 1.2),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline, color: AppTheme.cobalt, size: 20),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  context.l10n.cooExistingReviewBanner(existingReview.cooReviewCode, existingReview.status),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IdocBUi.fit(AppButton(label: context.l10n.cooReviewRegistryButton, onPressed: () => setState(() => _activeStep = 3), size: AppButtonSize.small, icon: Icons.history)),
                      ],
                    ),
                  ),
                ],
                Row(
                  children: [
                    const Icon(Icons.flag, color: AppTheme.cobalt),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(context.l10n.cooGenerateDraftHeader, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const Divider(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 768;
                    final dropdownFile = SearchableDropdownField<int>(
                      value: _selectedImportFileId,
                      labelText: context.l10n.cooSelectImportFileLabel,
                      searchHintText: context.l10n.cooSearchFileHint,
                      items: importFiles
                          .map((f) => SearchableDropdownItem<int>(
                                value: f.importFileId,
                                label: '${f.primaryNameWithCode} - ${f.companyName}',
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedImportFileId = v);
                          _loadSnapshot(v);
                        }
                      },
                    );

                    final dropdownType = SearchableDropdownField<String>(
                      value: _certType,
                      labelText: context.l10n.cooCertTypeLabel,
                      searchHintText: context.l10n.cooSelectCertTypeHint,
                      items: [
                        SearchableDropdownItem(value: 'EUR.1', label: context.l10n.cooCertTypeEur1),
                        SearchableDropdownItem(value: 'China Certificate of Origin (CCPIT)', label: context.l10n.cooCertTypeChina),
                        SearchableDropdownItem(value: 'Standard COO', label: context.l10n.cooCertTypeStandard),
                        SearchableDropdownItem(value: 'Form A / GSP', label: context.l10n.cooCertTypeFormA),
                        SearchableDropdownItem(value: 'Agadir Agreement', label: context.l10n.cooCertTypeAgadir),
                        SearchableDropdownItem(value: 'GAFTA', label: context.l10n.cooCertTypeGafta),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _certType = v);
                          if (_selectedImportFileId != null) {
                            _fetchAndApplyDraft(_selectedImportFileId!, overrideCertType: v);
                          }
                        }
                      },
                    );

                    final actionButtons = Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        IdocBUi.fit(AppButton(label: context.l10n.cooOpenVisualPreviewButton, onPressed: _generateOfficialDraft, variant: AppButtonVariant.success, icon: Icons.bolt)),
                        IdocBUi.fit(AppButton(label: context.l10n.cooNextDraftInputButton, onPressed: () => setState(() => _activeStep = 1), icon: Icons.arrow_forward)),
                      ],
                    );

                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          dropdownFile,
                          const SizedBox(height: 14),
                          dropdownType,
                          const SizedBox(height: 16),
                          actionButtons,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(flex: 3, child: dropdownFile),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: dropdownType),
                        const SizedBox(width: 16),
                        actionButtons,
                      ],
                    );
                  },
                ),
                if (_recommendationAlert != null && _recommendationAlert!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isManualChoiceRequired ? AppTheme.warningBackground : AppTheme.successBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _isManualChoiceRequired ? AppTheme.orange : AppTheme.emeraldBorder, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_isManualChoiceRequired ? Icons.warning_amber_rounded : Icons.verified, color: _isManualChoiceRequired ? AppTheme.warningForeground : AppTheme.successForeground),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CopyableText(
                                _localizeAlert(context, _recommendationAlert),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _isManualChoiceRequired ? AppTheme.warningForeground : AppTheme.successForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isManualChoiceRequired && _allowedCertTypes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _allowedCertTypes.map((type) {
                              final isSelected = _certType == type;
                              final typeLabel = type == 'Agadir Agreement'
                                  ? context.l10n.cooCertTypeAgadir
                                  : (type == 'GAFTA'
                                      ? context.l10n.cooCertTypeGafta
                                      : (type == 'EUR.1'
                                          ? context.l10n.cooCertTypeEur1
                                          : (type.contains('China')
                                              ? context.l10n.cooCertTypeChina
                                              : type)));
                              return ChoiceChip(
                                label: Text(
                                  typeLabel,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? AppTheme.white : AppTheme.textPrimary,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppTheme.cobalt,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() => _certType = type);
                                    if (_selectedImportFileId != null) {
                                      _fetchAndApplyDraft(_selectedImportFileId!, overrideCertType: type);
                                    }
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_activeDraftTemplate != null) ...[
          const SizedBox(height: 16),
          VisualDraftCOOSheet(
            templateData: _activeDraftTemplate!,
            certificateType: _certType,
            acidNumber: _activeAcidNumber ?? '',
            exemptionNotes: _localizeExemption(context, _activeExemptionNotes),
            onRefresh: () {
              if (_selectedImportFileId != null) {
                _fetchAndApplyDraft(_selectedImportFileId!);
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildStep2(List<dynamic> importFiles) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(context.l10n.cooDraftInputTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    IdocBUi.fit(AppButton(key: const Key('cooSaveDraftInputBtn'), label: context.l10n.cooSaveDraftSessionBtn, onPressed: (_isLoading || _selectedImportFileId == null)
                          ? null
                          : () async {
                              if (_comparisonResult == null) {
                                await _runComparison();
                              }
                              if (_comparisonResult != null) {
                                await _saveReview(isDraft: true);
                              }
                            }, variant: AppButtonVariant.secondary, icon: Icons.bookmark_added_outlined, isLoading: _isSavingDraft)),
                    IdocBUi.fit(AppButton(label: context.l10n.cooRunComparisonButton, onPressed: (_isLoading || _selectedImportFileId == null) ? null : _runComparison, variant: AppButtonVariant.success, icon: Icons.compare_arrows, isLoading: _isLoading)),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            // Mandatory Import File Selector
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 768;
                final fileField = SearchableDropdownField<int>(
                  value: _selectedImportFileId,
                  labelText: context.l10n.cooLinkedImportFileLabel,
                  searchHintText: context.l10n.cooSearchFileHint,
                  items: importFiles
                      .map((f) => SearchableDropdownItem<int>(
                            value: f.importFileId,
                            label: '${f.primaryNameWithCode} - ${f.companyName}',
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedImportFileId = v);
                      _loadSnapshot(v);
                    }
                  },
                );

                final certTypeField = SearchableDropdownField<String>(
                  value: _certType,
                  labelText: context.l10n.cooCertTypeLabel,
                  searchHintText: context.l10n.cooSelectCertTypeHint,
                  items: [
                    SearchableDropdownItem(value: 'EUR.1', label: context.l10n.cooCertTypeEur1),
                    SearchableDropdownItem(value: 'China Certificate of Origin (CCPIT)', label: context.l10n.cooCertTypeChina),
                    SearchableDropdownItem(value: 'Standard COO', label: context.l10n.cooCertTypeStandard),
                    SearchableDropdownItem(value: 'Form A / GSP', label: context.l10n.cooCertTypeFormA),
                    SearchableDropdownItem(value: 'Agadir Agreement', label: context.l10n.cooCertTypeAgadir),
                    SearchableDropdownItem(value: 'GAFTA', label: context.l10n.cooCertTypeGafta),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _certType = v);
                    }
                  },
                );

                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      fileField,
                      const SizedBox(height: 12),
                      certTypeField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 4, child: fileField),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: certTypeField),
                  ],
                );
              },
            ),
            if (_selectedImportFileId == null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.dangerBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.crimsonBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.cooSelectFileWarning,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 768;
                final certNum = TextFormField(
                  controller: _certNumberCtrl,
                  decoration: InputDecoration(labelText: context.l10n.cooDraftCertNumberLabel, border: const OutlineInputBorder()),
                );
                final originCountry = TextFormField(
                  controller: _originCountryCtrl,
                  decoration: InputDecoration(labelText: context.l10n.cooOriginCountryLabel, border: const OutlineInputBorder()),
                );
                final destCountry = TextFormField(
                  controller: _destCountryCtrl,
                  decoration: InputDecoration(labelText: context.l10n.cooDestinationCountryLabel, border: const OutlineInputBorder()),
                );

                if (isMobile) {
                  return Column(
                    children: [
                      certNum,
                      const SizedBox(height: 12),
                      originCountry,
                      const SizedBox(height: 12),
                      destCountry,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: certNum),
                    const SizedBox(width: 12),
                    Expanded(child: originCountry),
                    const SizedBox(width: 12),
                    Expanded(child: destCountry),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 768;
                final expField = TextFormField(
                  controller: _exporterCtrl,
                  decoration: InputDecoration(labelText: context.l10n.cooExporterNameLabel, border: const OutlineInputBorder()),
                );
                final regIdField = TextFormField(
                  controller: _exporterRegIdCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.cooExporterRegIdLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  ),
                );
                final impField = TextFormField(
                  controller: _importerCtrl,
                  decoration: InputDecoration(labelText: context.l10n.cooImporterNameLabel, border: const OutlineInputBorder()),
                );
                final invField = TextFormField(
                  controller: _invoiceNoCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: context.l10n.cooInvoiceNumberLabel, border: const OutlineInputBorder()),
                );

                if (isMobile) {
                  return Column(
                    children: [
                      expField,
                      const SizedBox(height: 12),
                      regIdField,
                      const SizedBox(height: 12),
                      impField,
                      const SizedBox(height: 12),
                      invField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 3, child: expField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: regIdField),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: impField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: invField),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            // File Picker & Smart Upload Row
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SmartUploadButton(
                  module: SmartUploadModule.cooCertificate,
                  label: context.l10n.cooSmartUploadButtonLabel,
                  onDataExtracted: (result) {
                    final fields = result.extractedFields;
                    setState(() {
                      _pickedFileName = result.filename;
                      if (fields['certificate_number'] != null && fields['certificate_number'].toString().isNotEmpty) {
                        _certNumberCtrl.text = fields['certificate_number'].toString();
                      }
                      if (fields['origin_country'] != null && fields['origin_country'].toString().isNotEmpty) {
                        _originCountryCtrl.text = fields['origin_country'].toString();
                      }
                      if (fields['exporter_name'] != null && fields['exporter_name'].toString().isNotEmpty) {
                        _exporterCtrl.text = fields['exporter_name'].toString();
                      }
                      if (fields['exporter_reg_id'] != null && fields['exporter_reg_id'].toString().isNotEmpty) {
                        _exporterRegIdCtrl.text = fields['exporter_reg_id'].toString();
                      }
                      if (fields['consignee_name'] != null && fields['consignee_name'].toString().isNotEmpty) {
                        _importerCtrl.text = fields['consignee_name'].toString();
                      }
                      if (fields['importer_name'] != null && fields['importer_name'].toString().isNotEmpty) {
                        _importerCtrl.text = fields['importer_name'].toString();
                      }
                      if (fields['invoice_number'] != null && fields['invoice_number'].toString().isNotEmpty) {
                        _invoiceNoCtrl.text = fields['invoice_number'].toString();
                      }
                    });
                  },
                ),
                if (_pickedFileName != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: AppTheme.emerald, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _pickedFileName!,
                        style: TextStyle(fontSize: 12, color: AppTheme.textStrong),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(context.l10n.cooRawTextSectionTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                IdocBUi.fit(AppButton(label: context.l10n.cooSmartExtractFromTextButton, onPressed: (_isLoading || _selectedImportFileId == null) ? null : _extractFromOcrText, variant: AppButtonVariant.secondary, icon: Icons.auto_awesome)),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _rawTextCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: context.l10n.cooRawTextHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3(List<dynamic> importFiles) {
    if (_selectedImportFileId == null) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              const Icon(Icons.folder_off, size: 48, color: AppTheme.orange),
              const SizedBox(height: 12),
              Text(context.l10n.cooSelectFileToViewMatrix, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              IdocBUi.fit(AppButton(label: context.l10n.cooBackToSelectFile, onPressed: () => setState(() => _activeStep = 1), icon: Icons.arrow_back)),
            ],
          ),
        ),
      );
    }

    if (_comparisonResult == null) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              const Icon(Icons.compare_arrows, size: 48, color: AppTheme.cobalt),
              const SizedBox(height: 12),
              Text(context.l10n.cooRunComparisonPreviousStep, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              IdocBUi.fit(AppButton(label: context.l10n.cooBackToRunComparison, onPressed: () => setState(() => _activeStep = 1), icon: Icons.arrow_back)),
            ],
          ),
        ),
      );
    }

    final matrix = CodedItemText.localizeRows(
        _comparisonResult!['comparison_matrix'] as List<dynamic>?, context.l10n);
    final hasCritical = _comparisonResult!['has_critical_mismatch'] as bool? ?? false;
    final hasDisc = _comparisonResult!['has_discrepancies'] as bool? ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(hasCritical ? Icons.error : (hasDisc ? Icons.warning : Icons.check_circle), color: hasCritical ? AppTheme.crimson : (hasDisc ? AppTheme.orange : AppTheme.emerald), size: 24),
                    const SizedBox(width: 10),
                    Text(
                      hasCritical ? context.l10n.cooCriticalMismatchAlert : (hasDisc ? context.l10n.cooMinorDiscrepancyAlert : context.l10n.cooPerfectMatchSuccess),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    IdocBUi.fit(AppButton(label: context.l10n.cooExportPdfButton, onPressed: () {
                        if (_selectedImportFileId != null && _activeDraftTemplate != null) {
                          if (showCooExportBlockedIfAny(context, CooExportService.missingExportField(_activeDraftTemplate!, _activeAcidNumber))) return;
                          CooExportService.printOrSavePdf(
                            templateData: _activeDraftTemplate!,
                            certificateType: _certType,
                            acidNumber: _activeAcidNumber ?? '',
                            exemptionNotes: _activeExemptionNotes,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.l10n.cooExportingPdfReportSnackbar)),
                          );
                        }
                      }, variant: AppButtonVariant.secondary, icon: Icons.picture_as_pdf)),
                    const SizedBox(width: 8),
                    IdocBUi.fit(AppButton(label: context.l10n.cooExportExcelButton, onPressed: () {
                        if (_activeDraftTemplate != null) {
                          if (showCooExportBlockedIfAny(context, CooExportService.missingExportField(_activeDraftTemplate!, _activeAcidNumber))) return;
                          final csv = CooExportService.exportCOOCsv(
                            templateData: _activeDraftTemplate!,
                            certificateType: _certType,
                            acidNumber: _activeAcidNumber ?? '',
                          );
                          CopyHelper.copy(context, csv, customMessage: context.l10n.cooExcelCopiedSnackbar);
                        }
                      }, variant: AppButtonVariant.secondary, icon: Icons.table_chart)),
                    const SizedBox(width: 8),
                    IdocBUi.fit(AppButton(key: const Key('cooSaveDraftBtn'), label: context.l10n.idocBCooSaveDraftBtn, onPressed: _isLoading ? null : () => _saveReview(isDraft: true), variant: AppButtonVariant.secondary, icon: Icons.bookmark_added_outlined, isLoading: _isSavingDraft)),
                    const SizedBox(width: 8),
                    IdocBUi.fit(AppButton(key: const Key('cooCertifyBtn'), label: context.l10n.idocBCooCertifyBtn, onPressed: _isLoading ? null : () => _saveReview(isDraft: false), variant: AppButtonVariant.success, icon: Icons.verified_rounded, isLoading: _isCertifying)),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(context.l10n.cooMatrixColField)),
                  DataColumn(label: Text(context.l10n.cooMatrixColSystemValue)),
                  DataColumn(label: Text(context.l10n.cooMatrixColDraftValue)),
                  DataColumn(label: Text(context.l10n.cooMatrixColStatus)),
                  DataColumn(label: Text(context.l10n.cooMatrixColDetails)),
                ],
                rows: matrix.map((m) {
                  final fieldKey = m['field']?.toString() ?? '';
                  final fieldLabel = _getFieldLabel(fieldKey, m['field_label_ar']?.toString(), context.l10n);
                  final sysVal = m['system_value']?.toString() ?? '—';
                  final draftVal = m['draft_value']?.toString() ?? '—';
                  final matchStatus = m['match_status']?.toString() ?? '';
                  final details = m['details']?.toString() ?? '';
                  final rowSummary = '$fieldLabel\t$sysVal\t$draftVal\t$matchStatus\t$details';

                  return DataRow(cells: [
                    DataCell(CopyableTableCell(
                      value: fieldLabel,
                      rowSummary: rowSummary,
                      child: Text(fieldLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                    )),
                    DataCell(CopyableTableCell(
                      value: sysVal,
                      rowSummary: rowSummary,
                      child: Text(sysVal),
                    )),
                    DataCell(CopyableTableCell(
                      value: draftVal,
                      rowSummary: rowSummary,
                      child: Text(draftVal),
                    )),
                    DataCell(CopyableTableCell(
                      value: matchStatus,
                      rowSummary: rowSummary,
                      child: Chip(
                        label: Text(
                          matchStatus == 'EXTRACTION_FAILED'
                              ? context.l10n.idocBNotExtracted
                              : (matchStatus == 'MATCH' ? context.l10n.idocBMatched : matchStatus),
                          style: const TextStyle(fontSize: 11, color: AppTheme.white),
                        ),
                        backgroundColor: matchStatus == 'EXTRACTION_FAILED'
                            ? AppTheme.charcoal
                            : (m['severity'] == 'BLOCKING'
                                ? AppTheme.crimson
                                : (m['severity'] == 'WARNING' ? AppTheme.orange : AppTheme.emerald)),
                      ),
                    )),
                    DataCell(CopyableTableCell(
                      value: details,
                      rowSummary: rowSummary,
                      child: Text(details),
                    )),
                  ]);
                }).toList(),
              ),
            ),
            if (hasDisc || hasCritical) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.warningBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.orange, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.gavel, color: AppTheme.warningForeground, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.cooOverrideReasonTitle,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.warningForeground),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.cooOverrideReasonSub,
                      style: TextStyle(fontSize: 11.5, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _overrideReasonCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.l10n.cooOverrideReasonLabel,
                        hintText: context.l10n.cooOverrideReasonHint,
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: AppTheme.white,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        IdocBUi.fit(AppButton(key: const Key('cooSaveWithJustificationBtn'), label: context.l10n.cooSaveWithJustificationButton, onPressed: (_isLoading || _overrideReasonCtrl.text.trim().isEmpty) ? null : () => _saveReview(isDraft: false), variant: AppButtonVariant.success, icon: Icons.check_circle, isLoading: _isCertifying)),
                        IdocBUi.fit(AppButton(key: const Key('cooSaveDraftJustificationBtn'), label: context.l10n.idocBCooSaveDraftAsBtn, onPressed: _isLoading ? null : () => _saveReview(isDraft: true), variant: AppButtonVariant.secondary, icon: Icons.bookmark_added_outlined, isLoading: _isSavingDraft)),
                        IdocBUi.fit(AppButton(label: context.l10n.cooReturnToEditAndNotifySupplierButton, onPressed: () => setState(() => _activeStep = 1), variant: AppButtonVariant.secondary, icon: Icons.edit_note)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStep4(List<dynamic> importFiles) {
    final cooReviews = ref.watch(cooReviewsProvider);

    return cooReviews.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(ApiErrorText.of(context.l10n, e)),
      data: (reviews) {
        final totalSessions = reviews.length;
        final certifiedSessions = reviews.where((r) => !r.isDraft).length;
        final draftSessions = reviews.where((r) => r.isDraft).length;

        final query = _registrySearchCtrl.text.trim().toLowerCase();
        final filteredReviews = reviews.where((r) {
          if (_selectedStatusFilter == 'CERTIFIED' && r.isDraft) return false;
          if (_selectedStatusFilter == 'DRAFT' && !r.isDraft) return false;
          if (_filterImportFileId != null && r.importFileId != _filterImportFileId) return false;
          if (query.isNotEmpty) {
            final certNum = r.certificateNumber.toLowerCase();
            final code = r.cooReviewCode.toLowerCase();
            final type = r.certificateType.toLowerCase();
            final status = r.status.toLowerCase();
            final expName = (r.draftInputData?['exporter_name'] ??
                    r.draftInputData?['box_1_exporter'] ??
                    r.systemSnapshotData?['supplier_name'] ??
                    '')
                .toString()
                .toLowerCase();
            final impName = (r.draftInputData?['importer_name'] ??
                    r.draftInputData?['box_2_consignee'] ??
                    r.systemSnapshotData?['company_name'] ??
                    '')
                .toString()
                .toLowerCase();
            return certNum.contains(query) ||
                code.contains(query) ||
                type.contains(query) ||
                status.contains(query) ||
                expName.contains(query) ||
                impName.contains(query);
          }
          return true;
        }).toList();

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // KPI & Metrics Header Banner
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.charcoal, AppTheme.charcoal.withValues(alpha: 0.92)],
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: AppTheme.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.history_edu, color: AppTheme.darkHyperlink, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.cooRegistryTitle,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.l10n.idocBCooRegistrySubtitle,
                                style: TextStyle(fontSize: 11.5, color: AppTheme.cloudWhite),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _sessionKpiCard(
                            icon: Icons.list_alt,
                            label: context.l10n.idocBCooKpiTotal,
                            value: '$totalSessions',
                            color: AppTheme.white,
                          ),
                          _sessionKpiCard(
                            icon: Icons.verified,
                            label: context.l10n.idocBCooKpiCertified,
                            value: '$certifiedSessions',
                            color: AppTheme.emerald,
                          ),
                          _sessionKpiCard(
                            icon: Icons.bookmark_added,
                            label: context.l10n.idocBCooKpiDrafts,
                            value: '$draftSessions',
                            color: AppTheme.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(context.l10n.idocBCooFilterStatus, style: TextStyle(color: AppTheme.cloudWhite, fontSize: 12, fontWeight: FontWeight.bold)),
                      ChoiceChip(
                        label: Text(context.l10n.idocBCooFilterAll(totalSessions), style: TextStyle(fontSize: 11, color: _selectedStatusFilter == 'ALL' ? AppTheme.white : AppTheme.textPrimary)),
                        selected: _selectedStatusFilter == 'ALL',
                        selectedColor: AppTheme.cobalt,
                        onSelected: (v) => setState(() => _selectedStatusFilter = 'ALL'),
                      ),
                      ChoiceChip(
                        label: Text(context.l10n.idocBCooFilterCertified(certifiedSessions), style: TextStyle(fontSize: 11, color: _selectedStatusFilter == 'CERTIFIED' ? AppTheme.white : AppTheme.textPrimary)),
                        selected: _selectedStatusFilter == 'CERTIFIED',
                        selectedColor: AppTheme.emerald,
                        onSelected: (v) => setState(() => _selectedStatusFilter = 'CERTIFIED'),
                      ),
                      ChoiceChip(
                        label: Text(context.l10n.idocBCooFilterDrafts(draftSessions), style: TextStyle(fontSize: 11, color: _selectedStatusFilter == 'DRAFT' ? AppTheme.white : AppTheme.textPrimary)),
                        selected: _selectedStatusFilter == 'DRAFT',
                        selectedColor: AppTheme.orange,
                        onSelected: (v) => setState(() => _selectedStatusFilter = 'DRAFT'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 768;
                        final searchBar = TextField(
                          key: const Key('cooRegistrySearchField'),
                          controller: _registrySearchCtrl,
                          decoration: InputDecoration(
                            hintText: context.l10n.cooRegistrySearchHint,
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _registrySearchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => setState(() => _registrySearchCtrl.clear()),
                                  )
                                : null,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (_) => setState(() {}),
                        );

                        final fileFilter = SizedBox(
                          width: isMobile ? double.infinity : 280,
                          child: SearchableDropdownField<int?>(
                            value: _filterImportFileId,
                            labelText: context.l10n.idocBFilterByFile,
                            searchHintText: context.l10n.idocBSearchFileHint,
                            items: [
                              SearchableDropdownItem<int?>(value: null, label: context.l10n.idocBAllFiles),
                              ...importFiles.map((f) => SearchableDropdownItem<int?>(
                                    value: f.importFileId,
                                    label: '${f.primaryNameWithCode} - ${f.companyName}',
                                  )),
                            ],
                            onChanged: (val) => setState(() => _filterImportFileId = val),
                          ),
                        );

                        final actionButtons = [
                          IdocBUi.fit(AppButton(key: const Key('searchAndCloneCooBtn'), label: context.l10n.searchAndCloneCooBtn, onPressed: () => _openSearchAndCloneCooDialog(reviews), variant: AppButtonVariant.secondary, icon: Icons.copy_all)),
                          IdocBUi.fit(AppButton(key: const Key('cooRegistryCopyBtn'), label: context.l10n.idocBCopyTable, onPressed: () => _copyCooRegistryAsTsv(filteredReviews), variant: AppButtonVariant.secondary, icon: Icons.copy)),
                          IdocBUi.fit(AppButton(key: const Key('cooRegistryExcelBtn'), label: context.l10n.idocBExportExcel, onPressed: () => _exportCooRegistryToExcel(filteredReviews), variant: AppButtonVariant.secondary, icon: Icons.table_chart)),
                          IdocBUi.fit(AppButton(key: const Key('cooRegistryPdfBtn'), label: context.l10n.idocBExportPdf, onPressed: () => _exportCooRegistryToPdf(filteredReviews), variant: AppButtonVariant.secondary, icon: Icons.picture_as_pdf)),
                          IdocBUi.fit(AppButton(label: context.l10n.cooReviewNewDraftButton, onPressed: () => setState(() => _activeStep = 0), icon: Icons.add)),
                        ];

                        if (isMobile) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              searchBar,
                              const SizedBox(height: 10),
                              fileFilter,
                              const SizedBox(height: 10),
                              Wrap(spacing: 8, runSpacing: 8, children: actionButtons),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: searchBar),
                                const SizedBox(width: 12),
                                fileFilter,
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Wrap(spacing: 8, runSpacing: 8, children: actionButtons),
                            ),
                          ],
                        );
                      },
                    ),
                    const Divider(height: 20),
                    if (filteredReviews.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Text(
                            reviews.isEmpty ? context.l10n.cooNoReviewsYet : context.l10n.noCooReviewsFound,
                          ),
                        ),
                      )
                    else
                      SelectionArea(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt),
                            columns: [
                              DataColumn(label: Text(context.l10n.cooRegistryColActions)),
                              DataColumn(label: Text(context.l10n.idocBSessionTypeCol, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(context.l10n.cooRegistryColCode)),
                              DataColumn(label: Text(context.l10n.cooRegistryColType)),
                              DataColumn(label: Text(context.l10n.cooRegistryColNumber)),
                              DataColumn(label: Text(context.l10n.cooRegistryColExporter)),
                              DataColumn(label: Text(context.l10n.cooRegistryColStatus)),
                              DataColumn(label: Text(context.l10n.cooRegistryColDate)),
                            ],
                            rows: filteredReviews.map((r) {
                              final expName = r.draftInputData?['exporter_name'] ?? r.draftInputData?['box_1_exporter'] ?? '—';
                              final isDraft = r.isDraft;
                              final dateStr = r.createdAt.length >= 10 ? r.createdAt.substring(0, 10) : r.createdAt;
                              final rowSummary = '${isDraft ? context.l10n.idocBSessionDraft : context.l10n.idocBSessionCertified}\t${r.cooReviewCode}\t${r.certificateType}\t${r.certificateNumber}\t$expName\t${r.status}\t$dateStr';

                              return DataRow(cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 0. Clone (استنساخ)
                                      IconButton(
                                        key: Key('cloneCooRowBtn_${r.cooReviewId}'),
                                        icon: const Icon(Icons.copy_all, color: AppTheme.wcagCobalt, size: 18),
                                        tooltip: context.l10n.cloneCooRecordTooltip,
                                        onPressed: () => _cloneCOOReview(r),
                                      ),
                                      // 1. Load into Stepper / Edit (استعادة وتحميل)
                                      IconButton(
                                        icon: const Icon(Icons.play_circle_outline, color: AppTheme.cobalt, size: 18),
                                        tooltip: context.l10n.idocBCooRestoreTooltip,
                                        onPressed: () => _loadSessionIntoEditor(r),
                                      ),
                                      // 2. View Details (مشاهدة)
                                      IconButton(
                                        icon: const Icon(Icons.visibility, color: AppTheme.charcoal, size: 18),
                                        tooltip: context.l10n.cooViewDetailsTooltip,
                                        onPressed: () => _showCOOReviewDetailsDialog(r),
                                      ),
                                      // 3. Download PDF (تنزيل PDF)
                                      IconButton(
                                        icon: const Icon(Icons.picture_as_pdf, color: AppTheme.crimson, size: 18),
                                        tooltip: context.l10n.cooDownloadPdfTooltip,
                                        onPressed: () async {
                                          final tData = {
                                            'certificate_number': r.certificateNumber,
                                            'box_1_exporter': expName,
                                            'box_2_consignee': r.draftInputData?['importer_name'] ?? r.draftInputData?['box_2_consignee'] ?? '—',
                                            'country_of_origin': r.draftInputData?['country_of_origin'] ?? '—',
                                            'box_4_country_of_destination': r.draftInputData?['destination_country'] ?? r.draftInputData?['box_4_country_of_destination'] ?? '—',
                                            'box_10_invoice_number_and_date': r.draftInputData?['invoice_number'] ?? r.draftInputData?['box_10_invoice_number_and_date'] ?? '—',
                                          };
                                          final rowFiles = ref.read(importFilesProvider).valueOrNull ?? [];
                                          final rowAcid = rowFiles.where((f) => f.importFileId == r.importFileId).firstOrNull?.acidNumber ?? '';
                                          if (showCooExportBlockedIfAny(context, CooExportService.missingExportField(tData, rowAcid))) return;
                                          await CooExportService.printOrSavePdf(
                                            templateData: tData,
                                            certificateType: r.certificateType,
                                            acidNumber: rowAcid,
                                          );
                                        },
                                      ),
                                      // 4. Delete Draft (حذف المسودة)
                                      if (isDraft)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 18),
                                          tooltip: context.l10n.idocBCooDeleteDraftTooltip,
                                          onPressed: () => _deleteCOODraftSession(r),
                                        ),
                                    ],
                                  ),
                                ),
                                // Session Type Badge
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDraft ? AppTheme.orange.withValues(alpha: 0.12) : AppTheme.emerald.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isDraft ? AppTheme.orange : AppTheme.emerald),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(isDraft ? Icons.edit_document : Icons.verified_rounded, size: 13, color: isDraft ? AppTheme.orange : AppTheme.emerald),
                                        const SizedBox(width: 4),
                                        Text(
                                          isDraft ? context.l10n.idocBSessionDraft : context.l10n.idocBSessionCertified,
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
                                  value: r.cooReviewCode,
                                  rowSummary: rowSummary,
                                  child: Text(r.cooReviewCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                )),
                                DataCell(CopyableTableCell(
                                  value: r.certificateType,
                                  rowSummary: rowSummary,
                                  child: Text(r.certificateType),
                                )),
                                DataCell(CopyableTableCell(
                                  value: r.certificateNumber,
                                  rowSummary: rowSummary,
                                  child: Text(r.certificateNumber),
                                )),
                                DataCell(CopyableTableCell(
                                  value: expName,
                                  rowSummary: rowSummary,
                                  child: Text(expName),
                                )),
                                DataCell(CopyableTableCell(
                                  value: r.status,
                                  rowSummary: rowSummary,
                                  child: Chip(
                                    label: Text(r.status, style: const TextStyle(color: AppTheme.white, fontSize: 11)),
                                    backgroundColor: r.status == 'Verified' || r.status == 'Approved'
                                        ? AppTheme.emerald
                                        : (isDraft ? AppTheme.orange : AppTheme.cobalt),
                                  ),
                                )),
                                DataCell(CopyableTableCell(
                                  value: dateStr,
                                  rowSummary: rowSummary,
                                  child: Text(dateStr),
                                )),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
        color: AppTheme.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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
              Text(label, style: const TextStyle(color: AppTheme.cloudWhite, fontSize: 11)),
              Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  void _loadSessionIntoEditor(CertificateOfOriginReviewModel session) {
    final expName = session.draftInputData?['exporter_name'] ??
        session.draftInputData?['box_1_exporter'] ??
        session.systemSnapshotData?['supplier_name'] ??
        '';
    final impName = session.draftInputData?['importer_name'] ??
        session.draftInputData?['box_2_consignee'] ??
        session.systemSnapshotData?['company_name'] ??
        '';
    final originCountry = session.draftInputData?['country_of_origin'] ??
        session.draftInputData?['box_3_country_of_origin'] ??
        'Germany';
    final destCountry = session.draftInputData?['destination_country'] ??
        session.draftInputData?['box_4_country_of_destination'] ??
        'Egypt';
    final invNo = session.draftInputData?['invoice_number'] ??
        session.draftInputData?['box_10_invoice_number_and_date'] ??
        '';
    final rawTxt = session.rawText ?? session.draftInputData?['raw_text'] ?? '';
    final overrideReason = session.notes ?? session.draftInputData?['override_reason'] ?? '';

    setState(() {
      _selectedImportFileId = session.importFileId ?? _selectedImportFileId;
      _certType = session.certificateType;
      _certNumberCtrl.text = session.certificateNumber;
      _exporterCtrl.text = expName;
      _importerCtrl.text = impName;
      _originCountryCtrl.text = originCountry;
      _destCountryCtrl.text = destCountry;
      _invoiceNoCtrl.text = invNo;
      _rawTextCtrl.text = rawTxt;
      _overrideReasonCtrl.text = overrideReason;
      if (session.comparisonMatrix.isNotEmpty) {
        _comparisonResult = {
          'comparison_matrix': session.comparisonMatrix,
          'has_discrepancies': session.hasDiscrepancies,
          'has_critical_mismatch': session.hasCriticalMismatch,
          'system_snapshot_data': session.systemSnapshotData,
          'draft_input_data': session.draftInputData,
        };
      }
      _activeStep = 1; // Jump to editor/smart input
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.idocBCooRestored(session.cooReviewCode))),
    );
  }

  Future<void> _deleteCOODraftSession(CertificateOfOriginReviewModel session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: AppTheme.crimson),
            const SizedBox(width: 8),
            Expanded(child: Text(context.l10n.idocBCooDeleteTitle)),
          ],
        ),
        content: Text(context.l10n.idocBCooDeleteConfirm(session.cooReviewCode)),
        actions: [
          IdocBUi.fit(AppButton(label: context.l10n.cancel, onPressed: () => Navigator.pop(ctx, false), variant: AppButtonVariant.secondary)),
          IdocBUi.fit(AppButton(label: context.l10n.idocBConfirmDelete, onPressed: () => Navigator.pop(ctx, true), variant: AppButtonVariant.danger)),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(cooReviewsProvider.notifier).deleteCOOReview(session.cooReviewId);
      ref.invalidate(importFilesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.idocBCooDeleted), backgroundColor: AppTheme.crimson),
        );
      }
    }
  }

  void _showCOOReviewDetailsDialog(CertificateOfOriginReviewModel r) {
    final expName = r.draftInputData?['exporter_name'] ?? r.draftInputData?['box_1_exporter'] ?? '—';
    final impName = r.draftInputData?['importer_name'] ?? r.draftInputData?['box_2_consignee'] ?? '—';
    final originCountry = r.draftInputData?['country_of_origin'] ?? '—';
    final destCountry = r.draftInputData?['destination_country'] ?? r.draftInputData?['box_4_country_of_destination'] ?? '—';
    final overrideReason = r.notes ?? r.draftInputData?['override_reason'] ?? '';
    final isDraft = r.isDraft;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
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
                    context.l10n.cooDetailsDialogTitle(r.cooReviewCode),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.idocBCooCertLine(r.certificateNumber, r.createdAt),
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
                isDraft ? context.l10n.idocBSessionDraft : context.l10n.idocBSessionCertified,
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
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(context.l10n.cooDetailsCertTypeAndNumber),
                  subtitle: CopyableText('${r.certificateType} — #${r.certificateNumber}'),
                  dense: true,
                ),
                ListTile(
                  title: Text(context.l10n.cooDetailsExporterAndImporter),
                  subtitle: CopyableText('${context.l10n.cooDetailsExporterLabel}: $expName\n${context.l10n.cooDetailsImporterLabel}: $impName'),
                  dense: true,
                ),
                ListTile(
                  title: Text(context.l10n.cooDetailsOriginAndDestination),
                  subtitle: CopyableText('$originCountry ➔ $destCountry'),
                  dense: true,
                ),
                if (overrideReason.isNotEmpty)
                  ListTile(
                    title: Text(context.l10n.cooDetailsOverrideReason),
                    subtitle: CopyableText(overrideReason, style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold)),
                    dense: true,
                  ),
                if (r.comparisonMatrix.isNotEmpty) ...[
                  const Divider(),
                  Text(context.l10n.cooDetailsMatrixTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...r.comparisonMatrix.map((m) {
                    final item = m is Map ? CodedItemText.localizeRow(m, context.l10n) : {};
                    final fieldKey = item['field']?.toString() ?? '';
                    final fieldLabel = _getFieldLabel(fieldKey, item['field_label_ar']?.toString(), context.l10n);
                    final dText = '$fieldLabel: [${item['draft_value']}] vs [${item['system_value']}]';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(item['match_status'] == 'MATCH' ? Icons.check_circle : Icons.warning,
                              color: item['match_status'] == 'MATCH' ? AppTheme.emerald : AppTheme.orange, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: CopyableText(
                              dText,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        actions: [
          IdocBUi.fit(AppButton(label: context.l10n.idocBCooRestoreBtn, onPressed: () {
              Navigator.of(ctx).pop();
              _loadSessionIntoEditor(r);
            }, variant: AppButtonVariant.secondary, icon: Icons.play_circle_outline)),
          IdocBUi.fit(AppButton(label: context.l10n.close, onPressed: () => Navigator.of(ctx).pop())),
        ],
      ),
    );
  }

  Future<void> _exportCooRegistryToExcel(List<CertificateOfOriginReviewModel> reviews) async {
    final headers = [
      context.l10n.idocBSessionTypeCol,
      context.l10n.cooRegistryColCode,
      context.l10n.cooRegistryColType,
      context.l10n.cooRegistryColNumber,
      context.l10n.cooRegistryColExporter,
      context.l10n.cooRegistryColStatus,
      context.l10n.cooRegistryColDate,
    ];
    final rows = reviews.map((r) {
      final expName = r.draftInputData?['exporter_name'] ?? r.draftInputData?['box_1_exporter'] ?? '—';
      final isDraft = r.isDraft;
      final dateStr = r.createdAt.length >= 10 ? r.createdAt.substring(0, 10) : r.createdAt;
      return [
        isDraft ? context.l10n.idocBSessionDraftShort : context.l10n.idocBSessionCertifiedShort,
        r.cooReviewCode,
        r.certificateType,
        r.certificateNumber,
        expName,
        r.status,
        dateStr,
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocBCooRegistryStage,
      importFileNameOrCode: 'Draft_COO_Registry',
    );
  }

  Future<void> _exportCooRegistryToPdf(List<CertificateOfOriginReviewModel> reviews) async {
    final headers = [
      context.l10n.idocBSessionTypeCol,
      context.l10n.cooRegistryColCode,
      context.l10n.cooRegistryColType,
      context.l10n.cooRegistryColNumber,
      context.l10n.cooRegistryColExporter,
      context.l10n.cooRegistryColStatus,
      context.l10n.cooRegistryColDate,
    ];
    final rows = reviews.map((r) {
      final expName = r.draftInputData?['exporter_name'] ?? r.draftInputData?['box_1_exporter'] ?? '—';
      final isDraft = r.isDraft;
      final dateStr = r.createdAt.length >= 10 ? r.createdAt.substring(0, 10) : r.createdAt;
      return [
        isDraft ? context.l10n.idocBSessionDraftShort : context.l10n.idocBSessionCertifiedShort,
        r.cooReviewCode,
        r.certificateType,
        r.certificateNumber,
        expName,
        r.status,
        dateStr,
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocBCooRegistryStage,
      importFileNameOrCode: 'Draft_COO_Registry',
    );
  }

  void _copyCooRegistryAsTsv(List<CertificateOfOriginReviewModel> reviews) {
    final headers = [
      context.l10n.idocBSessionTypeCol,
      context.l10n.cooRegistryColCode,
      context.l10n.cooRegistryColType,
      context.l10n.cooRegistryColNumber,
      context.l10n.cooRegistryColExporter,
      context.l10n.cooRegistryColStatus,
      context.l10n.cooRegistryColDate,
    ];
    final rows = reviews.map((r) {
      final expName = r.draftInputData?['exporter_name'] ?? r.draftInputData?['box_1_exporter'] ?? '—';
      final isDraft = r.isDraft;
      final dateStr = r.createdAt.length >= 10 ? r.createdAt.substring(0, 10) : r.createdAt;
      return [
        isDraft ? context.l10n.idocBSessionDraftShort : context.l10n.idocBSessionCertifiedShort,
        r.cooReviewCode,
        r.certificateType,
        r.certificateNumber,
        expName,
        r.status,
        dateStr,
      ];
    }).toList();

    TableCopyHelper.copyTable(context, headers, rows);
  }
}
