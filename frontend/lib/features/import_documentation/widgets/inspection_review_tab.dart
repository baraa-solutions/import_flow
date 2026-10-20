import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/system_messages/coded_item_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import 'idoc_ui_b.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/import_doc_stepper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/smart_upload_button.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import '../services/inspection_export_service.dart';
import 'extraction_match_status_chip.dart';
import 'visual_draft_inspection_sheet.dart';

class InspectionReviewTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  const InspectionReviewTab({super.key, this.initialImportFileId});

  @override
  ConsumerState<InspectionReviewTab> createState() => _InspectionReviewTabState();
}

class _InspectionReviewTabState extends ConsumerState<InspectionReviewTab> {
  int _activeStep = 0; // 0: Requirements, 1: Smart Input, 2: Discrepancy Matrix, 3: Registry
  int? _selectedImportFileId;

  String _inspType = 'COC (Certificate of Conformity)';
  String _inspAgency = 'SGS';
  final TextEditingController _certNumberCtrl = TextEditingController();
  final TextEditingController _importerCtrl = TextEditingController();
  final TextEditingController _exporterCtrl = TextEditingController();
  final TextEditingController _authorityCtrl = TextEditingController();
  final TextEditingController _invoiceNoCtrl = TextEditingController();
  final TextEditingController _acidCtrl = TextEditingController();
  final TextEditingController _originCountryCtrl = TextEditingController();
  final TextEditingController _specCtrl = TextEditingController();
  final TextEditingController _rawTextCtrl = TextEditingController();
  final TextEditingController _overrideReasonCtrl = TextEditingController();

  bool _isLoading = false;
  Map<String, dynamic>? _comparisonResult;
  String? _pickedFileName;
  Map<String, dynamic>? _activeDraftTemplate;
  String? _activeAcidNumber;
  List<String> _activeStandards = [];

  List<ImportDocStep> _buildSteps(AppLocalizations l10n) => [
    ImportDocStep(label: '1. ${l10n.inspStepRequirements}', icon: Icons.fact_check_outlined),
    ImportDocStep(label: '2. ${l10n.inspStepDraftInput}', icon: Icons.file_upload),
    ImportDocStep(label: '3. ${l10n.inspStepDiscrepancyMatrix}', icon: Icons.rule),
    ImportDocStep(label: '4. ${l10n.inspStepRegistry}', icon: Icons.history),
  ];

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!ref.read(importFilesProvider).isLoading) {
        await ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
      if (!ref.read(inspectionReviewsProvider).isLoading) {
        await ref.read(inspectionReviewsProvider.notifier).fetchInspectionReviews();
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
  void dispose() {
    _certNumberCtrl.dispose();
    _importerCtrl.dispose();
    _exporterCtrl.dispose();
    _authorityCtrl.dispose();
    _invoiceNoCtrl.dispose();
    _acidCtrl.dispose();
    _originCountryCtrl.dispose();
    _specCtrl.dispose();
    _rawTextCtrl.dispose();
    _overrideReasonCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InspectionReviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImportFileId != oldWidget.initialImportFileId && widget.initialImportFileId != null) {
      setState(() {
        _selectedImportFileId = widget.initialImportFileId;
      });
      _loadSnapshot(_selectedImportFileId!);
    }
  }

  void _loadSnapshot(int fileId) {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == fileId).firstOrNull;
    if (file != null) {
      _importerCtrl.text = file.companyName;
      _exporterCtrl.text = file.supplierName;
      _invoiceNoCtrl.text = file.piNumber ?? '';
      if (file.acidNumber != null && file.acidNumber!.isNotEmpty) {
        _acidCtrl.text = file.acidNumber!;
      }
    }
    _fetchAndApplyDraft(fileId);
  }

  Future<void> _fetchAndApplyDraft(int fileId) async {
    try {
      final res = await ref.read(inspectionReviewsProvider.notifier).fetchInspectionDraftTemplate(
            fileId,
            agency: _inspAgency,
            certType: _inspType,
          );
      final template = res['template_data'] as Map<String, dynamic>? ?? {};
      final standards = (res['applicable_standards'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final files = ref.read(importFilesProvider).valueOrNull ?? [];
      final file = files.where((f) => f.importFileId == fileId).firstOrNull;

      if (mounted) {
        setState(() {
          _activeDraftTemplate = template;
          _activeAcidNumber = (file?.acidNumber != null && file!.acidNumber!.isNotEmpty)
              ? file.acidNumber
              : (template['acid_number'] ?? '').toString();
          _activeStandards = standards;

          if (template['coc_number'] != null) _certNumberCtrl.text = template['coc_number'].toString();
          if (template['exporter_name_and_address'] != null) _exporterCtrl.text = template['exporter_name_and_address'].toString();
          if (template['importer_name_and_address'] != null) _importerCtrl.text = template['importer_name_and_address'].toString();
          if (template['acid_number'] != null) _acidCtrl.text = template['acid_number'].toString();
          if (template['country_of_origin'] != null) _originCountryCtrl.text = template['country_of_origin'].toString();
          if (standards.isNotEmpty) _specCtrl.text = standards.join('\n');
        });
      }
    } catch (_) {}
  }

  /// Normalizes a free-text agency name (e.g. from OCR) to a valid Dropdown value.
  String _normalizeInspAgency(String raw) {
    final r = raw.trim().toLowerCase();
    if (r.contains('tuv') || r.contains('tüv') || r.contains('rheinland')) return 'TÜV Rheinland';
    if (r.contains('bureau') || r.contains('veritas') || r.contains('bv')) return 'Bureau Veritas';
    if (r.contains('intertek')) return 'Intertek';
    if (r.contains('cotecna')) return 'Cotecna';
    if (r.contains('sgs')) return 'SGS';
    return 'SGS'; // fallback
  }

  /// Normalizes a free-text cert type to a valid Dropdown value.
  String _normalizeInspType(String raw) {
    final r = raw.trim().toLowerCase();
    if (r.contains('analysis') || r.contains('coa')) return 'COA (Certificate of Analysis)';
    if (r.contains('verification') || r.contains('voc')) return 'VOC (Verification of Conformity)';
    if (r.contains('pre-shipment') || r.contains('psi')) return 'PSI (Pre-Shipment Inspection)';
    return 'COC (Certificate of Conformity)'; // default
  }

  Future<void> _runComparison() async {
    final l10n = context.l10n;
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectFileFirstPrompt), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final draftFields = {
        'inspection_type': _inspType,
        'inspection_agency': _inspAgency,
        'certificate_number': _certNumberCtrl.text.trim(),
        'importer_name': _importerCtrl.text.trim(),
        'exporter_name': _exporterCtrl.text.trim(),
        'acid_number': _acidCtrl.text.trim(),
        'country_of_origin': _originCountryCtrl.text.trim(),
        'regulatory_authority': _authorityCtrl.text.trim(),
        'invoice_number': _invoiceNoCtrl.text.trim(),
        'standard_specification': _specCtrl.text.trim(),
      };

      final res = await ref.read(inspectionReviewsProvider.notifier).compareInspection(
            _selectedImportFileId!,
            _inspType,
            _inspAgency,
            draftFields,
          );

      setState(() {
        _comparisonResult = res;
        _activeStep = 2;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.inspectionComparisonError(ApiErrorText.of(l10n, e))), backgroundColor: AppTheme.crimson),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// ACID used for exports: the file's ACID, else what the user typed. Never invented.
  String get _effectiveAcid {
    final active = (_activeAcidNumber ?? '').trim();
    return active.isNotEmpty ? active : _acidCtrl.text.trim();
  }

  void _showAcidMissing() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.idocBExportBlockedAcid), backgroundColor: AppTheme.crimson),
    );
  }

  /// Shows the "ACID missing" SnackBar and returns true when no ACID is available.
  bool _blockIfAcidMissing() {
    if (_effectiveAcid.isNotEmpty) return false;
    _showAcidMissing();
    return true;
  }

  Future<void> _saveReview() async {
    final l10n = context.l10n;
    if (_comparisonResult == null || _selectedImportFileId == null) return;
    if (_blockIfAcidMissing()) return;
    if (_certNumberCtrl.text.trim().isEmpty || _authorityCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.idocBInspectionFieldsRequired), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    final hasDisc = _comparisonResult!['has_discrepancies'] as bool? ?? false;
    final hasCritical = _comparisonResult!['has_critical_mismatch'] as bool? ?? false;
    final reason = _overrideReasonCtrl.text.trim();

    if ((hasDisc || hasCritical) && reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ ${l10n.overrideReasonMandatoryWarning}'),
          backgroundColor: AppTheme.orange,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final payload = {
        'import_file_id': _selectedImportFileId,
        'inspection_type': _inspType,
        'inspection_agency': _inspAgency,
        'certificate_number': _certNumberCtrl.text.trim(),
        'regulatory_authority': _authorityCtrl.text.trim(),
        'standard_specification': _specCtrl.text.trim(),
        'raw_input_text': _rawTextCtrl.text,
        'raw_text': _rawTextCtrl.text,
        'system_snapshot_data': _comparisonResult!['system_snapshot_data'],
        'draft_input_data': _comparisonResult!['draft_input_data'],
        'comparison_matrix': _comparisonResult!['comparison_matrix'],
        'has_discrepancies': hasDisc,
        'has_critical_mismatch': hasCritical,
        'override_reason': reason,
        'status': hasDisc ? (hasCritical ? 'Correction Requested' : 'Discrepancy_Accepted') : 'Verified',
      };

      await ref.read(inspectionReviewsProvider.notifier).saveInspectionReview(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✔ ${l10n.saveInspectionReviewSuccess}'), backgroundColor: AppTheme.emerald),
        );
        setState(() => _activeStep = 3);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveInspectionReviewError(ApiErrorText.of(l10n, e))), backgroundColor: AppTheme.crimson),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateOfficialDraft() async {
    final l10n = context.l10n;
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.generateDraftSelectFileFirstPrompt), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await ref.read(inspectionReviewsProvider.notifier).fetchInspectionDraftTemplate(
            _selectedImportFileId!,
            agency: _inspAgency,
            certType: _inspType,
          );

      if (!mounted) return;

      final template = res['template_data'] as Map<String, dynamic>? ?? {};
      final standards = (res['applicable_standards'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final files = ref.read(importFilesProvider).valueOrNull ?? [];
      final file = files.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;
      final acidNo = file?.acidNumber ?? '';

      setState(() {
        _activeDraftTemplate = template;
        _activeAcidNumber = acidNo;
        _activeStandards = standards;
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
                  const Icon(Icons.fact_check, color: AppTheme.cobalt),
                  const SizedBox(width: 8),
                  Text(l10n.inspectionVisualPreviewDialogTitle(_inspAgency, _inspType),
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
              child: VisualDraftInspectionSheet(
                templateData: template,
                agency: _inspAgency,
                certType: _inspType,
                acidNumber: acidNo,
                standards: standards,
                onRefresh: () => _fetchAndApplyDraft(_selectedImportFileId!),
              ),
            ),
          ),
          actions: [
            IdocBUi.fit(AppButton(label: l10n.cancelAndClose, onPressed: () => Navigator.pop(ctx), variant: AppButtonVariant.secondary)),
            IdocBUi.fit(AppButton(label: l10n.applyInspectionDraftDataBtn, onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  if (template['coc_number'] != null) _certNumberCtrl.text = template['coc_number'].toString();
                  if (template['regulatory_authority'] != null) _authorityCtrl.text = template['regulatory_authority'].toString();
                  if (template['exporter_name_and_address'] != null) _exporterCtrl.text = template['exporter_name_and_address'].toString();
                  if (template['importer_name_and_address'] != null) _importerCtrl.text = template['importer_name_and_address'].toString();
                  if (standards.isNotEmpty) _specCtrl.text = standards.join('\n');
                  _activeStep = 1;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✔ ${l10n.inspectionDraftDataAppliedSuccess}'), backgroundColor: AppTheme.emerald),
                );
              }, variant: AppButtonVariant.success, icon: Icons.check)),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.generateDraftError(ApiErrorText.of(l10n, e))), backgroundColor: AppTheme.crimson),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _extractFromOcrText() async {
    final l10n = context.l10n;
    final rawText = _rawTextCtrl.text.trim();
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pasteRawTextFirstPrompt), backgroundColor: AppTheme.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await ref.read(inspectionReviewsProvider.notifier).extractCertificate(
            'INSPECTION_VOC',
            rawText,
            importFileId: _selectedImportFileId,
          );

      final extracted = res['extracted_data'] as Map<String, dynamic>? ?? {};
      final isDraft = res['is_draft_detected'] as bool? ?? false;
      final warnings = res['warnings'] as List<dynamic>? ?? [];

      setState(() {
        if (extracted['coc_number'] != null && extracted['coc_number'].toString().isNotEmpty) {
          _certNumberCtrl.text = extracted['coc_number'].toString();
        } else if (extracted['certificate_number'] != null && extracted['certificate_number'].toString().isNotEmpty) {
          _certNumberCtrl.text = extracted['certificate_number'].toString();
        }
        if (extracted['exporter_name'] != null && extracted['exporter_name'].toString().isNotEmpty) {
          _exporterCtrl.text = extracted['exporter_name'].toString();
        }
        if (extracted['importer_name'] != null && extracted['importer_name'].toString().isNotEmpty) {
          _importerCtrl.text = extracted['importer_name'].toString();
        }
        if (extracted['invoice_number'] != null && extracted['invoice_number'].toString().isNotEmpty) {
          _invoiceNoCtrl.text = extracted['invoice_number'].toString();
        } else if (extracted['invoices'] != null && (extracted['invoices'] as List).isNotEmpty) {
          final invList = (extracted['invoices'] as List)
              .map((i) => i is Map ? (i['invoice_number'] ?? '').toString() : i.toString())
              .where((s) => s.isNotEmpty)
              .toList();
          if (invList.isNotEmpty) _invoiceNoCtrl.text = invList.join(', ');
        }
        if (extracted['regulatory_authority'] != null && extracted['regulatory_authority'].toString().isNotEmpty) {
          _authorityCtrl.text = extracted['regulatory_authority'].toString();
        }
        if (extracted['inspection_agency'] != null && extracted['inspection_agency'].toString().isNotEmpty) {
          _inspAgency = _normalizeInspAgency(extracted['inspection_agency'].toString());
        }
        if (extracted['certificate_type'] != null && extracted['certificate_type'].toString().isNotEmpty) {
          _inspType = _normalizeInspType(extracted['certificate_type'].toString());
        } else if (extracted['inspection_type'] != null && extracted['inspection_type'].toString().isNotEmpty) {
          _inspType = _normalizeInspType(extracted['inspection_type'].toString());
        }
        if (extracted['acid_number'] != null && extracted['acid_number'].toString().isNotEmpty) {
          _acidCtrl.text = extracted['acid_number'].toString();
        }
        if (extracted['country_of_origin'] != null && extracted['country_of_origin'].toString().isNotEmpty) {
          _originCountryCtrl.text = extracted['country_of_origin'].toString();
        } else if (extracted['origin_country'] != null && extracted['origin_country'].toString().isNotEmpty) {
          _originCountryCtrl.text = extracted['origin_country'].toString();
        }
        if (extracted['testing_standards'] != null && (extracted['testing_standards'] as List).isNotEmpty) {
          _specCtrl.text = (extracted['testing_standards'] as List).join(' + ');
        } else if (extracted['standards_tested'] != null && (extracted['standards_tested'] as List).isNotEmpty) {
          _specCtrl.text = (extracted['standards_tested'] as List).join(' + ');
        }
      });

      if (mounted) {
        if (warnings.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.inspectionOcrWarningsAlert(warnings.join(', '))),
              backgroundColor: AppTheme.warningForeground,
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (isDraft) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${l10n.inspectionDraft48hWarningAlert}'),
              backgroundColor: AppTheme.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✔ ${l10n.inspectionExtractionSuccess}'), backgroundColor: AppTheme.emerald),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.inspectionComparisonError(ApiErrorText.of(l10n, e))), backgroundColor: AppTheme.crimson),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    return SelectionArea(
      child: Column(
        children: [
          // Unified Stepper Navigation
          ImportDocStepper(
            steps: _buildSteps(l10n),
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
    final l10n = context.l10n;
    final existingReviews = ref.watch(inspectionReviewsProvider).valueOrNull ?? [];
    final existingReview = existingReviews.where((r) => r.importFileId == _selectedImportFileId).firstOrNull;

    return Column(
      children: [
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
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.cobalt, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.existingInspectionReviewBanner(existingReview.inspectionReviewCode, existingReview.status),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal),
                          ),
                        ),
                        IdocBUi.fit(AppButton(label: l10n.inspectionRegistryBtn, onPressed: () => setState(() => _activeStep = 3), size: AppButtonSize.small, icon: Icons.history)),
                      ],
                    ),
                  ),
                ],
                Row(
                  children: [
                    const Icon(Icons.verified, color: AppTheme.cobalt),
                    const SizedBox(width: 10),
                    Text(l10n.inspRequirementsHeader, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SearchableDropdownField<int>(
                        value: _selectedImportFileId,
                        labelText: l10n.selectInspectionFileLabel,
                        searchHintText: l10n.selectInspectionFileHint,
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
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: SearchableDropdownField<String>(
                        value: _inspType,
                        labelText: l10n.inspectionCertTypeLabel,
                        searchHintText: l10n.inspectionCertTypeHint,
                        items: [
                          SearchableDropdownItem(value: 'COC (Certificate of Conformity)', label: l10n.optInspectionCoc),
                          SearchableDropdownItem(value: 'COA (Certificate of Analysis)', label: l10n.optInspectionCoa),
                          SearchableDropdownItem(value: 'VOC (Verification of Conformity)', label: l10n.optInspectionVoc),
                          SearchableDropdownItem(value: 'PSI (Pre-Shipment Inspection)', label: l10n.optInspectionPsi),
                        ],
                        onChanged: (v) {
                          setState(() => _inspType = v ?? 'COC (Certificate of Conformity)');
                          if (_selectedImportFileId != null) {
                            _fetchAndApplyDraft(_selectedImportFileId!);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: SearchableDropdownField<String>(
                        value: _inspAgency,
                        labelText: l10n.inspectionAgencyLabel,
                        searchHintText: l10n.inspectionAgencyHint,
                        items: const [
                          SearchableDropdownItem(value: 'SGS', label: 'SGS International'),
                          SearchableDropdownItem(value: 'TÜV Rheinland', label: 'TÜV Rheinland'),
                          SearchableDropdownItem(value: 'Bureau Veritas', label: 'Bureau Veritas (BV)'),
                          SearchableDropdownItem(value: 'Intertek', label: 'Intertek Testing Services'),
                          SearchableDropdownItem(value: 'Cotecna', label: 'Cotecna Inspection'),
                        ],
                        onChanged: (v) {
                          setState(() => _inspAgency = v ?? 'SGS');
                          if (_selectedImportFileId != null) {
                            _fetchAndApplyDraft(_selectedImportFileId!);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    IdocBUi.fit(AppButton(label: l10n.openInspectionPreviewBtn, onPressed: _generateOfficialDraft, variant: AppButtonVariant.success, icon: Icons.bolt)),
                    const SizedBox(width: 12),
                    IdocBUi.fit(AppButton(label: l10n.nextInspectionInputBtn, onPressed: () => setState(() => _activeStep = 1), icon: Icons.arrow_forward)),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_activeDraftTemplate != null) ...[
          const SizedBox(height: 16),
          VisualDraftInspectionSheet(
            templateData: _activeDraftTemplate!,
            agency: _inspAgency,
            certType: _inspType,
            acidNumber: _activeAcidNumber ?? '',
            standards: _activeStandards,
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
    final l10n = context.l10n;
    return Card(
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
                Text(l10n.inspDraftInputHeader, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IdocBUi.fit(AppButton(label: l10n.runInspectionComparisonBtn, onPressed: (_isLoading || _selectedImportFileId == null) ? null : _runComparison, variant: AppButtonVariant.success, icon: Icons.compare_arrows, isLoading: _isLoading)),
              ],
            ),
            const Divider(height: 24),
            // Mandatory Import File Selector Row
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: SearchableDropdownField<int>(
                    value: _selectedImportFileId,
                    labelText: l10n.linkedInspectionFileLabel,
                    searchHintText: l10n.linkedInspectionFileHint,
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
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: SearchableDropdownField<String>(
                    value: _inspType,
                    labelText: l10n.inspectionCertTypeLabel,
                    searchHintText: l10n.inspectionCertTypeHint,
                    items: [
                      SearchableDropdownItem(value: 'COC (Certificate of Conformity)', label: l10n.optInspectionCoc),
                      SearchableDropdownItem(value: 'COA (Certificate of Analysis)', label: l10n.optInspectionCoa),
                      SearchableDropdownItem(value: 'VOC (Verification of Conformity)', label: l10n.optInspectionVoc),
                      SearchableDropdownItem(value: 'PSI (Pre-Shipment Inspection)', label: l10n.optInspectionPsi),
                    ],
                    onChanged: (v) {
                      setState(() => _inspType = v ?? 'COC (Certificate of Conformity)');
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: SearchableDropdownField<String>(
                    value: _inspAgency,
                    labelText: l10n.inspectionAgencyLabel,
                    searchHintText: l10n.inspectionAgencyHint,
                    items: const [
                      SearchableDropdownItem(value: 'SGS', label: 'SGS International'),
                      SearchableDropdownItem(value: 'TÜV Rheinland', label: 'TÜV Rheinland'),
                      SearchableDropdownItem(value: 'Bureau Veritas', label: 'Bureau Veritas (BV)'),
                      SearchableDropdownItem(value: 'Intertek', label: 'Intertek Testing Services'),
                      SearchableDropdownItem(value: 'Cotecna', label: 'Cotecna Inspection'),
                    ],
                    onChanged: (v) {
                      setState(() => _inspAgency = v ?? 'SGS');
                    },
                  ),
                ),
              ],
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
                        '⚠️ ${l10n.pleaseSelectInspectionFileWarning}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _certNumberCtrl,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) => (v == null || v.trim().isEmpty) ? l10n.idocBFieldRequired : null,
                    decoration: InputDecoration(labelText: l10n.certNumberFieldLabel, border: const OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _authorityCtrl,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) => (v == null || v.trim().isEmpty) ? l10n.idocBFieldRequired : null,
                    decoration: InputDecoration(labelText: l10n.regulatoryAuthorityFieldLabel, border: const OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _invoiceNoCtrl,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(labelText: l10n.inspectedInvoiceNumberFieldLabel, border: const OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _exporterCtrl,
                    decoration: InputDecoration(labelText: l10n.exporterShipperFieldLabel, border: const OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _importerCtrl,
                    decoration: InputDecoration(labelText: l10n.importerApplicantFieldLabel, border: const OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _specCtrl,
                    decoration: InputDecoration(labelText: l10n.standardSpecFieldLabel, border: const OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _acidCtrl,
                    textDirection: TextDirection.ltr,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) => (v == null || v.trim().isEmpty) ? l10n.idocBAcidRequired : null,
                    decoration: InputDecoration(labelText: l10n.acidNumberFieldLabel, border: const OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _originCountryCtrl,
                    decoration: InputDecoration(labelText: l10n.countryOfOriginFieldLabel, border: const OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // File Picker & Smart Upload Row
            Row(
              children: [
                SmartUploadButton(
                  module: SmartUploadModule.inspectionCertificate,
                  label: l10n.smartUploadInspectionBtn,
                  onDataExtracted: (result) {
                    final fields = result.extractedFields;
                    setState(() {
                      _pickedFileName = result.filename;
                      if (fields['certificate_number'] != null && fields['certificate_number'].toString().isNotEmpty) {
                        _certNumberCtrl.text = fields['certificate_number'].toString();
                      }
                      if (fields['importer_name'] != null && fields['importer_name'].toString().isNotEmpty) {
                        _importerCtrl.text = fields['importer_name'].toString();
                      }
                      if (fields['exporter_name'] != null && fields['exporter_name'].toString().isNotEmpty) {
                        _exporterCtrl.text = fields['exporter_name'].toString();
                      }
                      if (fields['acid_number'] != null && fields['acid_number'].toString().isNotEmpty) {
                        _acidCtrl.text = fields['acid_number'].toString();
                      }
                      if (fields['country_of_origin'] != null && fields['country_of_origin'].toString().isNotEmpty) {
                        _originCountryCtrl.text = fields['country_of_origin'].toString();
                      } else if (fields['origin_country'] != null && fields['origin_country'].toString().isNotEmpty) {
                        _originCountryCtrl.text = fields['origin_country'].toString();
                      }
                      if (fields['invoice_number'] != null && fields['invoice_number'].toString().isNotEmpty) {
                        _invoiceNoCtrl.text = fields['invoice_number'].toString();
                      }
                      if (fields['inspection_agency'] != null && fields['inspection_agency'].toString().isNotEmpty) {
                        _inspAgency = _normalizeInspAgency(fields['inspection_agency'].toString());
                      }
                      if (fields['regulatory_authority'] != null && fields['regulatory_authority'].toString().isNotEmpty) {
                        _authorityCtrl.text = fields['regulatory_authority'].toString();
                      } else if (fields['inspector_name'] != null && fields['inspector_name'].toString().isNotEmpty) {
                        _authorityCtrl.text = fields['inspector_name'].toString();
                      }
                      if (fields['standard_specification'] != null && fields['standard_specification'].toString().isNotEmpty) {
                        _specCtrl.text = fields['standard_specification'].toString();
                      } else if (fields['standards'] != null && (fields['standards'] as List).isNotEmpty) {
                        _specCtrl.text = (fields['standards'] as List).join(' + ');
                      } else if (fields['product_description'] != null && fields['product_description'].toString().isNotEmpty) {
                        _specCtrl.text = fields['product_description'].toString();
                      }
                    });
                  },
                ),
                if (_pickedFileName != null) ...
                  [
                    const SizedBox(width: 12),
                    const Icon(Icons.check_circle, color: AppTheme.emerald, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _pickedFileName!,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textStrong),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.rawTextInspectionHeader, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                IdocBUi.fit(AppButton(label: l10n.smartExtractFromTextBtn, onPressed: (_isLoading || _selectedImportFileId == null) ? null : _extractFromOcrText, variant: AppButtonVariant.secondary, icon: Icons.auto_awesome)),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _rawTextCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: l10n.rawTextInspectionHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3(List<dynamic> importFiles) {
    final l10n = context.l10n;
    if (_selectedImportFileId == null) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              const Icon(Icons.folder_off, size: 48, color: AppTheme.orange),
              const SizedBox(height: 12),
              Text('⚠️ ${l10n.mustSelectFileForMatrixWarning}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              IdocBUi.fit(AppButton(label: l10n.returnToSelectFileBtn, onPressed: () => setState(() => _activeStep = 1), icon: Icons.arrow_back)),
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
              Text(l10n.pleaseRunComparisonPrompt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              IdocBUi.fit(AppButton(label: l10n.returnToRunComparisonBtn, onPressed: () => setState(() => _activeStep = 1), icon: Icons.arrow_back)),
            ],
          ),
        ),
      );
    }

    final rawMatrix = _comparisonResult!['comparison_matrix'] as List<dynamic>?;
    final matrix = CodedItemText.localizeRows(rawMatrix, l10n);
    // Exports (CSV / TSV / PDF / clipboard) carry no bidi isolates.
    final exportMatrix = CodedItemText.localizeRows(rawMatrix, l10n, forExport: true);
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(hasCritical ? Icons.error : (hasDisc ? Icons.warning : Icons.check_circle), color: hasCritical ? AppTheme.crimson : (hasDisc ? AppTheme.orange : AppTheme.emerald), size: 24),
                    const SizedBox(width: 10),
                    Text(
                      hasCritical ? l10n.hasCriticalMismatchStatus : (hasDisc ? l10n.hasMinorDiscrepanciesStatus : l10n.inspectionConforms100Status),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    IdocBUi.fit(AppButton(label: l10n.exportTsvBtn, onPressed: () {
                        if (_blockIfAcidMissing()) return;
                        final currentTemplate = _activeDraftTemplate ?? {
                          'coc_number': _certNumberCtrl.text.trim(),
                          'importer_name_and_address': _importerCtrl.text.trim(),
                          'exporter_name_and_address': _exporterCtrl.text.trim(),
                          'acid_number': _acidCtrl.text.trim().isNotEmpty ? _acidCtrl.text.trim() : _effectiveAcid,
                          'country_of_origin': _originCountryCtrl.text.trim(),
                          'regulatory_authority': _authorityCtrl.text.trim(),
                          'invoice_number': _invoiceNoCtrl.text.trim(),
                          'standards': _specCtrl.text.trim().split('\n').where((s) => s.isNotEmpty).toList(),
                        };
                        InspectionExportService.saveInspectionTsvToFile(
                          context: context,
                          templateData: currentTemplate,
                          agency: _inspAgency,
                          certType: _inspType,
                          acidNumber: _effectiveAcid,
                          standards: _activeStandards.isNotEmpty ? _activeStandards : _specCtrl.text.trim().split('\n').where((s) => s.isNotEmpty).toList(),
                          comparisonMatrix: exportMatrix,
                        );
                      }, variant: AppButtonVariant.secondary, icon: Icons.table_chart_outlined)),
                    IdocBUi.fit(AppButton(label: l10n.exportExcelBtn, onPressed: () {
                        if (_blockIfAcidMissing()) return;
                        final currentTemplate = _activeDraftTemplate ?? {
                          'coc_number': _certNumberCtrl.text.trim(),
                          'importer_name_and_address': _importerCtrl.text.trim(),
                          'exporter_name_and_address': _exporterCtrl.text.trim(),
                          'acid_number': _acidCtrl.text.trim().isNotEmpty ? _acidCtrl.text.trim() : _effectiveAcid,
                          'country_of_origin': _originCountryCtrl.text.trim(),
                          'regulatory_authority': _authorityCtrl.text.trim(),
                          'invoice_number': _invoiceNoCtrl.text.trim(),
                          'standards': _specCtrl.text.trim().split('\n').where((s) => s.isNotEmpty).toList(),
                        };
                        InspectionExportService.saveInspectionCsvToFile(
                          context: context,
                          templateData: currentTemplate,
                          agency: _inspAgency,
                          certType: _inspType,
                          acidNumber: _effectiveAcid,
                          standards: _activeStandards.isNotEmpty ? _activeStandards : _specCtrl.text.trim().split('\n').where((s) => s.isNotEmpty).toList(),
                          comparisonMatrix: exportMatrix,
                        );
                      }, variant: AppButtonVariant.secondary, icon: Icons.file_download_outlined)),
                    IdocBUi.fit(AppButton(label: l10n.exportPdfBtn, onPressed: () {
                        if (_blockIfAcidMissing()) return;
                        final currentTemplate = _activeDraftTemplate ?? {
                          'coc_number': _certNumberCtrl.text.trim(),
                          'importer_name_and_address': _importerCtrl.text.trim(),
                          'exporter_name_and_address': _exporterCtrl.text.trim(),
                          'acid_number': _acidCtrl.text.trim().isNotEmpty ? _acidCtrl.text.trim() : _effectiveAcid,
                          'country_of_origin': _originCountryCtrl.text.trim(),
                          'regulatory_authority': _authorityCtrl.text.trim(),
                          'invoice_number': _invoiceNoCtrl.text.trim(),
                          'standards': _specCtrl.text.trim().split('\n').where((s) => s.isNotEmpty).toList(),
                        };
                        InspectionExportService.saveInspectionPdfToFile(
                          context: context,
                          templateData: currentTemplate,
                          agency: _inspAgency,
                          certType: _inspType,
                          acidNumber: _effectiveAcid,
                          standards: _activeStandards.isNotEmpty ? _activeStandards : _specCtrl.text.trim().split('\n').where((s) => s.isNotEmpty).toList(),
                          comparisonMatrix: exportMatrix,
                        );
                      }, variant: AppButtonVariant.secondary, icon: Icons.picture_as_pdf)),
                    IdocBUi.fit(AppButton(label: l10n.copyDossierBtn, onPressed: () {
                        if (_blockIfAcidMissing()) return;
                        final currentTemplate = _activeDraftTemplate ?? {
                          'coc_number': _certNumberCtrl.text.trim(),
                          'importer_name_and_address': _importerCtrl.text.trim(),
                          'exporter_name_and_address': _exporterCtrl.text.trim(),
                          'acid_number': _acidCtrl.text.trim().isNotEmpty ? _acidCtrl.text.trim() : _effectiveAcid,
                          'country_of_origin': _originCountryCtrl.text.trim(),
                          'regulatory_authority': _authorityCtrl.text.trim(),
                          'invoice_number': _invoiceNoCtrl.text.trim(),
                          'standards': _specCtrl.text.trim().split('\n').where((s) => s.isNotEmpty).toList(),
                        };
                        InspectionExportService.copyDossierToClipboard(
                          context,
                          templateData: currentTemplate,
                          agency: _inspAgency,
                          certType: _inspType,
                          acidNumber: _effectiveAcid,
                          standards: _activeStandards.isNotEmpty ? _activeStandards : _specCtrl.text.trim().split('\n').where((s) => s.isNotEmpty).toList(),
                          comparisonMatrix: exportMatrix,
                          overrideReason: _overrideReasonCtrl.text.trim().isNotEmpty ? _overrideReasonCtrl.text.trim() : null,
                        );
                      }, variant: AppButtonVariant.secondary, icon: Icons.copy_all_outlined)),
                    IdocBUi.fit(AppButton(label: l10n.saveToInspectionRegistryBtn, onPressed: _saveReview, icon: Icons.save)),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(l10n.colInspField)),
                  DataColumn(label: Text(l10n.colInspSystemValue)),
                  DataColumn(label: Text(l10n.colInspDraftValue)),
                  DataColumn(label: Text(l10n.colInspMatchStatus)),
                  DataColumn(label: Text(l10n.colInspDetails)),
                ],
                rows: matrix.map((m) {
                  final fieldLabel = m['field_label_ar']?.toString() ?? m['field']?.toString() ?? '';
                  final sysVal = m['system_value']?.toString() ?? '—';
                  final draftVal = m['draft_value']?.toString() ?? '—';
                  final matchStatus = m['match_status']?.toString() ?? '';
                  final details = m['details']?.toString() ?? '';
                  final rowSummary = '$fieldLabel | $sysVal vs $draftVal | $matchStatus | $details';

                  return DataRow(cells: [
                    DataCell(
                      CopyableTableCell(
                        value: fieldLabel,
                        rowSummary: rowSummary,
                        child: Text(fieldLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: sysVal,
                        rowSummary: rowSummary,
                        child: Text(sysVal),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: draftVal,
                        rowSummary: rowSummary,
                        child: Text(draftVal),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: matchStatus,
                        rowSummary: rowSummary,
                        child: ExtractionMatchStatusChip(
                          matchStatus: matchStatus,
                          severity: m['severity'],
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: details,
                        rowSummary: rowSummary,
                        child: Text(details),
                      ),
                    ),
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
                        const Icon(Icons.gavel, color: AppTheme.warningForeground, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.inspOverrideReasonBoxTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.warningForeground),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.inspOverrideReasonBoxDesc,
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _overrideReasonCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: l10n.inspOverrideReasonFieldLabel,
                        hintText: l10n.inspOverrideReasonFieldHint,
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: AppTheme.white,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IdocBUi.fit(AppButton(label: l10n.approveAndSaveWithReasonBtn, onPressed: _saveReview, variant: AppButtonVariant.success, icon: Icons.check_circle)),
                        const SizedBox(width: 12),
                        IdocBUi.fit(AppButton(label: l10n.returnToEditAndContactSupplierBtn, onPressed: () => setState(() => _activeStep = 1), variant: AppButtonVariant.secondary, icon: Icons.edit_note)),
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
    final l10n = context.l10n;
    final reviewsState = ref.watch(inspectionReviewsProvider);

    return reviewsState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text(l10n.saveInspectionReviewError(err.toString()))),
      data: (reviews) {
        return Card(
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
                        const Icon(Icons.history_edu, color: AppTheme.cobalt, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          l10n.inspReviewsRegistryTitle(reviews.length),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IdocBUi.fit(AppButton(label: l10n.startNewInspReviewBtn, onPressed: () => setState(() => _activeStep = 1), icon: Icons.add)),
                  ],
                ),
                const SizedBox(height: 16),
                if (reviews.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: AppTheme.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(l10n.noInspReviewsYet)),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppTheme.charcoal.withValues(alpha: 0.06)),
                      columns: [
                        DataColumn(label: Text(l10n.colInspActions)),
                        DataColumn(label: Text(l10n.colInspSessionCode)),
                        DataColumn(label: Text(l10n.colInspCertType)),
                        DataColumn(label: Text(l10n.colInspAgency)),
                        DataColumn(label: Text(l10n.colInspCertNo)),
                        DataColumn(label: Text(l10n.colInspStatus)),
                        DataColumn(label: Text(l10n.colInspCreatedAt)),
                      ],
                      rows: reviews.map((r) {
                        final rawTxt = r.rawText ?? r.draftInputData?['raw_text'] ?? '';
                        final overrideReason = r.notes ?? r.draftInputData?['override_reason'] ?? '';
                        final createdStr = r.createdAt.length >= 10 ? r.createdAt.substring(0, 10) : r.createdAt;
                        final rowSummary = '${r.inspectionReviewCode} | ${r.inspectionType} | ${r.inspectionAgency} | ${r.certificateNumber} | ${r.status} | $createdStr';

                        return DataRow(cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 0. Copy Row (نسخ بيانات السطر)
                                IconButton(
                                  icon: const Icon(Icons.copy, color: AppTheme.cobalt, size: 18),
                                  tooltip: l10n.copyRow,
                                  onPressed: () {
                                    CopyHelper.copy(context, rowSummary, customMessage: l10n.copiedToClipboardGeneric);
                                  },
                                ),
                                // 1. Edit (تعديل)
                                IconButton(
                                  icon: const Icon(Icons.edit, color: AppTheme.cobalt, size: 18),
                                  tooltip: l10n.editInspSessionTooltip,
                                  onPressed: () {
                                    setState(() {
                                      _selectedImportFileId = r.importFileId;
                                      _inspType = r.inspectionType;
                                      _inspAgency = r.inspectionAgency;
                                      _certNumberCtrl.text = r.certificateNumber;
                                      _rawTextCtrl.text = rawTxt;
                                      _overrideReasonCtrl.text = overrideReason;
                                      if (r.comparisonMatrix.isNotEmpty) {
                                        _comparisonResult = {
                                          'comparison_matrix': r.comparisonMatrix,
                                          'has_discrepancies': r.hasDiscrepancies,
                                          'has_critical_mismatch': r.hasCriticalMismatch,
                                          'system_snapshot_data': r.systemSnapshotData,
                                          'draft_input_data': r.draftInputData,
                                        };
                                      }
                                      _activeStep = 1;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(l10n.loadedInspSessionForEdit(r.inspectionReviewCode))),
                                    );
                                  },
                                ),
                                // 2. View (مشاهدة)
                                IconButton(
                                  icon: const Icon(Icons.visibility, color: AppTheme.charcoal, size: 18),
                                  tooltip: l10n.viewInspDetailsTooltip,
                                  onPressed: () => _showInspectionReviewDetailsDialog(r),
                                ),
                                // 3. Download PDF (تنزيل PDF)
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf, color: AppTheme.crimson, size: 18),
                                  tooltip: l10n.downloadInspPdfTooltip,
                                  onPressed: () async {
                                    final rowFiles = ref.read(importFilesProvider).valueOrNull ?? [];
                                    final rowAcid = (rowFiles.where((f) => f.importFileId == r.importFileId).firstOrNull?.acidNumber ?? '').trim();
                                    if (rowAcid.isEmpty) {
                                      _showAcidMissing();
                                      return;
                                    }
                                    final tData = {
                                      'certificate_number': r.certificateNumber,
                                      'inspection_agency': r.inspectionAgency,
                                      'inspection_type': r.inspectionType,
                                      ...?r.draftInputData,
                                    };
                                    await InspectionExportService.printOrSavePdf(
                                      templateData: tData,
                                      agency: r.inspectionAgency,
                                      certType: r.inspectionType,
                                      acidNumber: rowAcid,
                                      standards: _activeStandards,
                                    );
                                  },
                                ),
                                // 4. Delete (حذف)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 18),
                                  tooltip: l10n.deleteInspSessionTooltip,
                                  onPressed: () => _confirmDeleteInspectionReview(r),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: r.inspectionReviewCode,
                              rowSummary: rowSummary,
                              child: Text(r.inspectionReviewCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: r.inspectionType,
                              rowSummary: rowSummary,
                              child: Text(r.inspectionType),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: r.inspectionAgency,
                              rowSummary: rowSummary,
                              child: Text(r.inspectionAgency),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: r.certificateNumber,
                              rowSummary: rowSummary,
                              child: Text(r.certificateNumber),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: r.status,
                              rowSummary: rowSummary,
                              child: Chip(
                                label: Text(r.status, style: const TextStyle(color: AppTheme.white, fontSize: 11)),
                                backgroundColor: r.status == 'Verified' ? AppTheme.emerald : AppTheme.orange,
                              ),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: createdStr,
                              rowSummary: rowSummary,
                              child: Text(createdStr),
                            ),
                          ),

                        ]);
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showInspectionReviewDetailsDialog(InspectionCertificateReviewModel r) {
    final l10n = context.l10n;
    final overrideReason = r.notes ?? r.draftInputData?['override_reason'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Text(l10n.inspDetailsDialogTitle(r.inspectionReviewCode)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.copy_all, color: AppTheme.cobalt, size: 20),
              tooltip: l10n.copyDossierBtn,
              onPressed: () {
                final summary = '''
${l10n.inspDetailsDialogTitle(r.inspectionReviewCode)}
${l10n.tileInspTypeAndAgency}: ${r.inspectionType} — ${r.inspectionAgency}
${l10n.tileInspCertNoAndStatus}: ${r.certificateNumber} | ${r.status}
${overrideReason.isNotEmpty ? '${l10n.tileInspOverrideReason}: $overrideReason\n' : ''}''';
                CopyHelper.copy(ctx, summary, customMessage: l10n.copiedDossierSuccess);
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 700,
          child: SelectionArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(l10n.tileInspTypeAndAgency),
                    subtitle: Text('${r.inspectionType} — ${r.inspectionAgency}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.copyValue,
                      onPressed: () => CopyHelper.copy(ctx, '${r.inspectionType} — ${r.inspectionAgency}'),
                    ),
                    dense: true,
                  ),
                  ListTile(
                    title: Text(l10n.tileInspCertNoAndStatus),
                    subtitle: Text('${r.certificateNumber} | ${r.status}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.copyValue,
                      onPressed: () => CopyHelper.copy(ctx, '${r.certificateNumber} | ${r.status}'),
                    ),
                    dense: true,
                  ),
                  if (overrideReason.isNotEmpty)
                    ListTile(
                      title: Text(l10n.tileInspOverrideReason),
                      subtitle: Text(overrideReason, style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold)),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        tooltip: l10n.copyValue,
                        onPressed: () => CopyHelper.copy(ctx, overrideReason),
                      ),
                      dense: true,
                    ),
                  if (r.comparisonMatrix.isNotEmpty) ...[
                    const Divider(),
                    Text(l10n.sectionInspDiscrepancyMatrix, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...r.comparisonMatrix.map((m) {
                      final item = m is Map ? CodedItemText.localizeRow(m, l10n) : {};
                      final rowText = '${item['field_label_ar'] ?? item['field']}: [${item['draft_value']}] vs [${item['system_value']}]';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: InkWell(
                          onTap: () => CopyHelper.copy(ctx, rowText),
                          child: Row(
                            children: [
                              Icon(item['match_status'] == 'MATCH' ? Icons.check_circle : Icons.warning,
                                  color: item['match_status'] == 'MATCH' ? AppTheme.emerald : AppTheme.orange, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  rowText,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.copy, size: 14, color: AppTheme.textMuted),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          IdocBUi.fit(AppButton(label: l10n.cancel, onPressed: () => Navigator.of(ctx).pop(), variant: AppButtonVariant.secondary)),
        ],
      ),
    );
  }

  void _confirmDeleteInspectionReview(InspectionCertificateReviewModel r) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppTheme.crimson),
            const SizedBox(width: 8),
            Text(l10n.confirmDeleteInspSessionTitle),
          ],
        ),
        content: Text(l10n.confirmDeleteInspSessionContent(r.inspectionReviewCode, r.certificateNumber)),
        actions: [
          IdocBUi.fit(AppButton(label: l10n.cancel, onPressed: () => Navigator.of(ctx).pop(), variant: AppButtonVariant.secondary)),
          IdocBUi.fit(AppButton(label: l10n.delete, onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(inspectionReviewsProvider.notifier).deleteInspectionReview(r.inspectionReviewId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✔ ${l10n.inspSessionDeletedSuccess}'), backgroundColor: AppTheme.emerald),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.deleteInspSessionError(ApiErrorText.of(l10n, e))), backgroundColor: AppTheme.crimson),
                  );
                }
              }
            }, variant: AppButtonVariant.danger)),
        ],
      ),
    );
  }
}
