import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/helpers/file_picker_helper.dart';



import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/system_messages/coded_item_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/error_details_dialog.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/services/table_export_service.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/invoice_bl_match_session_model.dart';
import '../providers/docs_customs_approval_provider.dart';
import '../providers/import_documentation_provider.dart';
import 'idoc_feedback.dart';
import 'idoc_ui.dart';
class InvoiceBLMatcherTab extends ConsumerStatefulWidget {
  final int? selectedImportFileId;
  final Function(int)? onImportFileChanged;

  const InvoiceBLMatcherTab({
    super.key,
    this.selectedImportFileId,
    this.onImportFileChanged,
  });

  @override
  ConsumerState<InvoiceBLMatcherTab> createState() => _InvoiceBLMatcherTabState();
}

class _InvoiceBLMatcherTabState extends ConsumerState<InvoiceBLMatcherTab> {
  late final Dio _dio = ref.read(dioProvider);
  late final Dio _uploadDio = ref.read(uploadDioProvider);
  final CancelToken _cancelToken = CancelToken();

  final TextEditingController _invoiceTextCtrl = TextEditingController();
  final TextEditingController _blTextCtrl = TextEditingController();
  final TextEditingController _packingTextCtrl = TextEditingController();

  String? _invoiceFileName;
  String? _blFileName;
  String? _packingFileName;
  Uint8List? _invoiceFileBytes;
  Uint8List? _blFileBytes;
  Uint8List? _packingFileBytes;
  List<PlatformFile> _invoiceFiles = [];
  List<PlatformFile> _blFiles = [];
  List<PlatformFile> _packingFiles = [];
  bool _showPackingList = true;
  bool _isLoading = false;
  bool _isSyncing = false;

  Map<String, dynamic>? _matchResult;
  int? _activeFileId;

  // View Mode & Sessions Registry State
  int _activeViewMode = 0; // 0: Matcher & Analyzer, 1: Sessions Registry
  bool _isSavingDraft = false;
  final TextEditingController _searchSessionsCtrl = TextEditingController();
  String _selectedStatusFilter = 'ALL'; // ALL, DRAFT, CERTIFIED
  int? _filterImportFileId;
  int? _activeSessionId;
  String? _activeSessionCode;

  // Real Sample Data Presets
  static const String sampleShawInvoice = '''
Commercial Invoice
Shaw Europe Limited
Blackaddie Road, Sanquhar, United Kingdom, DG4 6DB
VAT Number 428102677

Order Date 24-06-2026
Order Number 35220
Shipment Number 688990
Purchase Order RSA-ARCE-Found Ever

Bill To:
ARCHI BRANDS FOR CORPET AND FLOOR TRADING
44 Street 18, Maadi Sarayat, Cairo, Egypt
Tax ID 759552827
''';

  static const String sampleMscBL = '''
MEDITERRANEAN SHIPPING COMPANY S.A.
BILL OF LADING No. MEDURE910647
DRAFT - SCAC Code: MEDU

SHIPPER:
SHAW EUROPE LTD
BUILDING E, BLACKADDIE RD SANQUHAR, DG4 6DB. UNITED KINGDOM

CONSIGNEE:
ARCHI Brands for Corpet and Floor Trading
St.81 with st.18 building 44, 3rd floor, SARAYAT EL MAADI, Cairo- Egypt
VAT No: 759-552-827

VESSEL AND VOYAGE NO: MSC GISELLE - NL630A
PORT OF LOADING: FELIXSTOWE, UNITED KINGDOM
PORT OF DISCHARGE: SOX - SOKHNA, EGYPT
PLACE OF DELIVERY: SOKHNA, EGYPT

ACID NUMBER: 7595528271019210013
IMPORTER TAX ID: 759552827
EXPORTER REGISTRATION NUMBER: 428102677

CONTAINER NUMBER: BEAU5851356 / 40HC / SEAL: 177345
PACKAGES: 31 PALLETS (CONTAINING 960 BOXES)
COMMODITY: TUFTED CARPET TILES OF NYLON
HS CODE: 5703299100
Gross Cargo Weight: 20,030.000 kgs.
Total Items: 31 Total: 20,030.000 kgs.
''';

  @override
  void initState() {
    super.initState();
    _activeFileId = widget.selectedImportFileId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!ref.read(importFilesProvider).isLoading) {
        await ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
      final files = ref.read(importFilesProvider).valueOrNull ?? [];
      if (_activeFileId == null && files.isNotEmpty && mounted) {
        setState(() {
          _activeFileId = files.first.importFileId;
        });
      }
      ref.read(invoiceBLMatchSessionsProvider.notifier).fetchSessions(importFileId: _activeFileId);
    });
  }

  @override
  void didUpdateWidget(covariant InvoiceBLMatcherTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedImportFileId != oldWidget.selectedImportFileId) {
      setState(() {
        _activeFileId = widget.selectedImportFileId;
      });
      ref.read(invoiceBLMatchSessionsProvider.notifier).fetchSessions(importFileId: _activeFileId);
    }
  }

  @override
  void dispose() {
    _cancelToken.cancel();
    _invoiceTextCtrl.dispose();
    _blTextCtrl.dispose();
    _packingTextCtrl.dispose();
    _searchSessionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile(String docType) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'tif', 'tiff', 'txt', 'csv', 'doc', 'docx', 'xlsx', 'xls'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final resolvedFiles = FilePickerHelper.resolveFilesWithBytes(result.files);
        final file = resolvedFiles.isNotEmpty ? resolvedFiles.first : result.files.first;
        final count = resolvedFiles.length;
        final ext = (file.name.split('.').last).toLowerCase();
        final isTextFormat = ['txt', 'csv', 'json', 'xml', 'log'].contains(ext);
        final fileBytes = file.bytes ?? FilePickerHelper.getBytes(file);

        if (!mounted) return;
        final l = context.l10n;
        setState(() {
          if (docType == 'invoice') {
            _invoiceFiles = resolvedFiles;
            _invoiceFileName = count == 1 ? file.name : '${file.name} (+$count)';
            _invoiceFileBytes = fileBytes;
            if (isTextFormat && fileBytes != null && count == 1) {
              try {
                _invoiceTextCtrl.text = utf8.decode(fileBytes, allowMalformed: true);
              } catch (_) {
                _invoiceTextCtrl.text = '';
              }
            } else {
              _invoiceTextCtrl.text = l.invoiceBlMatcherInvoiceFilesLoaded(count, resolvedFiles.map((f) => f.name).join(", "));
            }
          } else if (docType == 'packing') {
            _showPackingList = true;
            _packingFiles = resolvedFiles;
            _packingFileName = count == 1 ? file.name : '${file.name} (+$count)';
            _packingFileBytes = fileBytes;
            if (isTextFormat && fileBytes != null && count == 1) {
              try {
                _packingTextCtrl.text = utf8.decode(fileBytes, allowMalformed: true);
              } catch (_) {
                _packingTextCtrl.text = '';
              }
            } else {
              _packingTextCtrl.text = l.invoiceBlMatcherPackingFilesLoaded(count, resolvedFiles.map((f) => f.name).join(", "));
            }
          } else {
            _blFiles = resolvedFiles;
            _blFileName = count == 1 ? file.name : '${file.name} (+$count)';
            _blFileBytes = fileBytes;
            if (isTextFormat && fileBytes != null && count == 1) {
              try {
                _blTextCtrl.text = utf8.decode(fileBytes, allowMalformed: true);
              } catch (_) {
                _blTextCtrl.text = '';
              }
            } else {
              _blTextCtrl.text = l.invoiceBlMatcherBlFilesLoaded(count, resolvedFiles.map((f) => f.name).join(", "));
            }
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.invoiceBlMatcherFilesSelectedSuccess(count, result.files.map((f) => f.name).join(", "))),
              backgroundColor: AppTheme.emerald,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.invoiceBlMatcherFileReadError(e)),
            backgroundColor: AppTheme.crimson,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _loadSampleData() {
    setState(() {
      _invoiceTextCtrl.text = sampleShawInvoice.trim();
      _invoiceFileName = 'ShawContract_Commercial_Invoice.txt';
      _blTextCtrl.text = sampleMscBL.trim();
      _blFileName = 'MSC_Draft_BL_MEDURE910647.txt';
      _invoiceFileBytes = null;
      _blFileBytes = null;
      _invoiceFiles = [];
      _blFiles = [];
      _packingFiles = [];
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.invoiceBlMatcherSampleLoadedSuccess),
          backgroundColor: AppTheme.cobalt,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _runCrossMatching() async {
    final hasInvoiceFile = _invoiceFiles.isNotEmpty || _invoiceFileBytes != null;
    final hasBlFile = _blFiles.isNotEmpty || _blFileBytes != null;
    final hasPackingFile = _packingFiles.isNotEmpty || _packingFileBytes != null;
    final invText = _invoiceTextCtrl.text.trim();
    final blText = _blTextCtrl.text.trim();
    final plText = _packingTextCtrl.text.trim();

    final hasInvContent = hasInvoiceFile || (invText.isNotEmpty && !invText.startsWith('['));
    final hasBlContent = hasBlFile || (blText.isNotEmpty && !blText.startsWith('['));
    final hasPlContent = hasPackingFile || (plText.isNotEmpty && !plText.startsWith('['));

    if (!hasInvContent && !hasBlContent && !hasPlContent) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.invoiceBlMatcherValidationRequired),
            backgroundColor: AppTheme.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Response response;

      if (hasInvoiceFile || hasBlFile || hasPackingFile) {
        final formData = FormData();
        if (_activeFileId != null) {
          formData.fields.add(MapEntry('import_file_id', _activeFileId.toString()));
        }

        if (_invoiceFiles.isNotEmpty) {
          for (final f in _invoiceFiles) {
            final b = f.bytes ?? FilePickerHelper.getBytes(f);
            if (b != null) {
              formData.files.add(MapEntry(
                'invoice_files',
                MultipartFile.fromBytes(b, filename: f.name),
              ));
            }
          }
        } else if (_invoiceFileBytes != null) {
          formData.files.add(MapEntry(
            'invoice_file',
            MultipartFile.fromBytes(_invoiceFileBytes!, filename: _invoiceFileName ?? 'invoice.pdf'),
          ));
        } else if (invText.isNotEmpty && !invText.startsWith('[')) {
          formData.fields.add(MapEntry('invoice_text', invText));
        }

        if (_packingFiles.isNotEmpty) {
          for (final f in _packingFiles) {
            final b = f.bytes ?? FilePickerHelper.getBytes(f);
            if (b != null) {
              formData.files.add(MapEntry(
                'packing_list_files',
                MultipartFile.fromBytes(b, filename: f.name),
              ));
            }
          }
        } else if (_packingFileBytes != null) {
          formData.files.add(MapEntry(
            'packing_list_file',
            MultipartFile.fromBytes(_packingFileBytes!, filename: _packingFileName ?? 'packing_list.pdf'),
          ));
        } else if (plText.isNotEmpty && !plText.startsWith('[')) {
          formData.fields.add(MapEntry('packing_list_text', plText));
        }

        if (_blFiles.isNotEmpty) {
          for (final f in _blFiles) {
            final b = f.bytes ?? FilePickerHelper.getBytes(f);
            if (b != null) {
              formData.files.add(MapEntry(
                'bl_files',
                MultipartFile.fromBytes(b, filename: f.name),
              ));
            }
          }
        } else if (_blFileBytes != null) {
          formData.files.add(MapEntry(
            'bl_file',
            MultipartFile.fromBytes(_blFileBytes!, filename: _blFileName ?? 'bl.pdf'),
          ));
        } else if (blText.isNotEmpty && !blText.startsWith('[')) {
          formData.fields.add(MapEntry('bl_text', blText));
        }

        response = await _uploadDio.post(
          '${ApiConstants.baseUrl}/import-documentation/invoice-bl/extract-files-and-match',
          data: formData,
          cancelToken: _cancelToken,
        );
      } else {
        response = await _dio.post(
          '${ApiConstants.baseUrl}/import-documentation/invoice-bl/extract-and-match',
          data: {
            'import_file_id': _activeFileId,
            'invoice_raw_text': _invoiceTextCtrl.text,
            'bl_raw_text': _blTextCtrl.text,
            'packing_list_raw_text': _packingTextCtrl.text,
          },
          cancelToken: _cancelToken,
        );
      }

      if (response.statusCode == 200) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : jsonDecode(response.data.toString()) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _matchResult = data;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.invoiceBlMatcherMatchCompletedSuccess(data['match_score_percentage'])),
              backgroundColor: data['is_safe_for_certification'] == true ? AppTheme.emerald : AppTheme.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: context.l10n.invoiceBlMatcherMatchErrorTitle, error: e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Asks for the justification required when certifying with discrepancies
  /// (backend returns 400 when `notes` is empty and critical > 0).
  Future<String?> _askCertifyJustification() {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final l = ctx.l10n;
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.orange),
              const SizedBox(width: 8),
              Expanded(child: Text(l.idocAConfirmNotMatchedTitle)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.idocAConfirmNotMatchedBody),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('idocCertifyJustificationField'),
                    controller: ctrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l.idocAJustificationLabel,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l.idocAJustificationRequired : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IdocUi.fit(AppButton(
              label: l.idocAReviewDiffs,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx),
            )),
            IdocUi.fit(AppButton(
              label: l.idocAConfirmFinal,
              variant: AppButtonVariant.danger,
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(ctx, ctrl.text.trim());
              },
            )),
          ],
        );
      },
    ).whenComplete(ctrl.dispose);
  }

  Future<void> _saveSession({required bool isDraft}) async {
    if (_isSavingDraft || _isSyncing) return;
    if (_activeFileId == null) {
      showIdocMessage(context, context.l10n.invoiceBlMatcherSelectFileFirstWarning, color: AppTheme.crimson);
      return;
    }

    String? justification;
    final criticalCount = (_matchResult?['critical_discrepancies_count'] as num?)?.toInt() ?? 0;
    final needsJustification = !isDraft &&
        _matchResult != null &&
        (_matchResult!['is_safe_for_certification'] == false || criticalCount > 0);
    if (needsJustification) {
      justification = await _askCertifyJustification();
      if (justification == null) return;
    }
    if (!mounted) return;

    setState(() {
      if (isDraft) {
        _isSavingDraft = true;
      } else {
        _isSyncing = true;
      }
    });

    try {
      final payload = InvoiceBLMatchSessionModel.toCreateJson(
        importFileId: _activeFileId!,
        isDraft: isDraft,
        matchResult: _matchResult,
        notes: justification,
      );

      final createdSession = await ref.read(invoiceBLMatchSessionsProvider.notifier).createSession(payload);
      ref.invalidate(importFilesProvider);
      ref.invalidate(docsCustomsApprovalProvider);
      ref.invalidate(centralArchiveProvider);
      ref.invalidate(legalComplianceFamilyProvider);

      if (mounted) {
        final l = context.l10n;
        showIdocMessage(
          context,
          isDraft
              ? l.idocADraftSaved(createdSession.sessionCode)
              : l.idocASessionApproved(createdSession.sessionCode),
          color: isDraft ? AppTheme.cobalt : AppTheme.emerald,
        );
      }
    } catch (e) {
      if (mounted) {
        showIdocError(
          context,
          e,
          title: isDraft ? context.l10n.idocADraftSaveFailed : context.l10n.idocAFinalApprovalFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final l = context.l10n;

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Toggle: Matcher vs Sessions Registry
            _buildViewModeToggle(),
            const SizedBox(height: 16),

            if (_activeViewMode == 0) ...[
              // 1. Header & Import File Selector Bar
              _buildHeaderControlBar(importFiles),
              const SizedBox(height: 16),

              // 2. Dual Document Ingestion Section (Invoice vs B/L)
              _buildDualIngestionSection(),
              const SizedBox(height: 16),

              // 3. Action Buttons (Run Match, Load Samples, Reset, Save Draft)
              _buildActionButtonsBar(),
              const SizedBox(height: 20),

              // 4. Comparison Results & Score Matrix
              if (_isLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          l.invoiceBlMatcherAnalyzingProgress,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_matchResult != null) ...[
                _buildMatchSummaryCard(),
                const SizedBox(height: 16),
                _buildComparisonMatrixTable(),
                const SizedBox(height: 16),
                _buildExtractedFieldsCards(),
                if (_matchResult!['correction_letter'] != null &&
                    _matchResult!['correction_letter'].toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildCorrectionLetterCard(),
                ],
                const SizedBox(height: 24),
                _buildSyncActionFooter(),
              ],
            ] else ...[
              // 5. Sessions Registry View
              _buildSessionsRegistryView(importFiles),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderControlBar(List<dynamic> importFiles) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 750;
          final titleWidget = Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: AppTheme.cobalt, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.invoiceBlMatcherTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.invoiceBlMatcherSubtitle,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    if (_activeSessionCode != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          context.l10n.idocAActiveSessionUnderReview(_activeSessionCode),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          final fileDropdown = SearchableDropdownField<int>(
            labelText: l.invoiceBlMatcherLinkImportFile,
            hintText: l.invoiceBlMatcherSelectFileHint,
            value: _activeFileId,
            items: importFiles
                .map(
                  (f) => SearchableDropdownItem<int>(
                    value: f.importFileId,
                    label: '${f.primaryNameWithCode} - ${f.supplierName} (${f.status})',
                  ),
                )
                .toList(),
            onChanged: (val) {
              setState(() {
                _activeFileId = val;
              });
              if (widget.onImportFileChanged != null && val != null) {
                widget.onImportFileChanged!(val);
              }
            },
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleWidget,
                const SizedBox(height: 12),
                fileDropdown,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleWidget),
              const SizedBox(width: 16),
              SizedBox(width: 320, child: fileDropdown),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDualIngestionSection() {
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_showPackingList)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IdocUi.fit(AppButton(
                  label: l.invoiceBlMatcherAddPackingListButton,
                  icon: Icons.post_add,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    setState(() {
                      _showPackingList = true;
                    });
                  },
                )),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isVeryWide = constraints.maxWidth > 1050;
            final isWide = constraints.maxWidth > 750;

            final invoiceBox = _buildDocumentInputBox(
              title: l.invoiceBlMatcherInvoiceBoxTitle,
              icon: Icons.receipt_long,
              color: AppTheme.cobalt,
              controller: _invoiceTextCtrl,
              fileName: _invoiceFileName,
              docType: 'invoice',
              placeholder: l.invoiceBlMatcherInvoicePlaceholder,
            );

            final packingBox = _buildDocumentInputBox(
              title: l.invoiceBlMatcherPackingBoxTitle,
              icon: Icons.inventory_2,
              color: AppTheme.orange,
              controller: _packingTextCtrl,
              fileName: _packingFileName,
              docType: 'packing',
              placeholder: l.invoiceBlMatcherPackingPlaceholder,
              onRemove: () {
                setState(() {
                  _showPackingList = false;
                  _packingFileName = null;
                  _packingFileBytes = null;
                  _packingTextCtrl.clear();
                });
              },
            );

            final blBox = _buildDocumentInputBox(
              title: l.invoiceBlMatcherBlBoxTitle,
              icon: Icons.directions_boat,
              color: AppTheme.emerald,
              controller: _blTextCtrl,
              fileName: _blFileName,
              docType: 'bl',
              placeholder: l.invoiceBlMatcherBlPlaceholder,
            );

            if (_showPackingList) {
              if (isVeryWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: invoiceBox),
                    const SizedBox(width: 14),
                    Expanded(child: packingBox),
                    const SizedBox(width: 14),
                    Expanded(child: blBox),
                  ],
                );
              } else if (isWide) {
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: invoiceBox),
                        const SizedBox(width: 14),
                        Expanded(child: packingBox),
                      ],
                    ),
                    const SizedBox(height: 14),
                    blBox,
                  ],
                );
              } else {
                return Column(
                  children: [
                    invoiceBox,
                    const SizedBox(height: 14),
                    packingBox,
                    const SizedBox(height: 14),
                    blBox,
                  ],
                );
              }
            }

            return Flex(
              direction: isWide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: invoiceBox,
                ),
                SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 16),
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: blBox,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDocumentInputBox({
    required String title,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
    required String? fileName,
    required String docType,
    required String placeholder,
    VoidCallback? onRemove,
  }) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? color.withValues(alpha: 0.5) : color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IdocUi.fit(AppButton(
                label: fileName != null ? l.invoiceBlMatcherChangeFile : l.invoiceBlMatcherUploadFile,
                icon: Icons.upload_file,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => _pickFile(docType),
              )),
              if (onRemove != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.crimson),
                  tooltip: l.invoiceBlMatcherRemovePackingList,
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ],
          ),
          if (fileName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.invoiceBlMatcherUploadedFile(fileName),
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(color: AppTheme.textMutedOf(context), fontSize: 11),
              filled: true,
              fillColor: AppTheme.surfaceAltOf(context),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.borderOf(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.borderOf(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsBar() {
    final l = context.l10n;

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IdocUi.fit(AppButton(
          label: l.invoiceBlMatcherExecuteMatchButton,
          icon: Icons.compare_arrows,
          variant: AppButtonVariant.primary,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _runCrossMatching,
        )),
        if (kDebugMode)
          IdocUi.fit(AppButton(
            label: l.invoiceBlMatcherLoadSampleButton,
            icon: Icons.auto_stories,
            variant: AppButtonVariant.secondary,
            onPressed: _loadSampleData,
          )),
        IdocUi.fit(AppButton(
          label: l.invoiceBlMatcherResetButton,
          icon: Icons.refresh,
          variant: AppButtonVariant.ghost,
          onPressed: () {
            setState(() {
              _invoiceTextCtrl.clear();
              _blTextCtrl.clear();
              _packingTextCtrl.clear();
              _invoiceFileName = null;
              _blFileName = null;
              _packingFileName = null;
              _invoiceFileBytes = null;
              _blFileBytes = null;
              _packingFileBytes = null;
              _showPackingList = false;
              _matchResult = null;
            });
          },
        )),
        IdocUi.fit(AppButton(
          label: context.l10n.idocASaveSessionDraftEmoji,
          icon: Icons.save_as_outlined,
          variant: AppButtonVariant.secondary,
          isLoading: _isSavingDraft,
          onPressed: (_activeFileId == null || _isSavingDraft || _isSyncing)
              ? null
              : () => _saveSession(isDraft: true),
        )),
      ],
    );
  }

  Widget _buildMatchSummaryCard() {
    final l = context.l10n;
    final res = _matchResult ?? {};
    final score = res['match_score_percentage'] ?? 0.0;
    final isSafe = res['is_safe_for_certification'] == true;
    final criticalCount = (res['critical_discrepancies_count'] as num?)?.toInt() ?? 0;
    final warningCount = (res['warning_discrepancies_count'] as num?)?.toInt() ?? 0;

    final color = isSafe ? (warningCount > 0 ? AppTheme.orange : AppTheme.emerald) : AppTheme.crimson;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSafe ? Icons.verified_rounded : Icons.gpp_bad_rounded,
              color: color,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isSafe ? l.invoiceBlMatcherStatusSafeTitle : l.invoiceBlMatcherStatusCriticalTitle,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l.invoiceBlMatcherMatchScore(score),
                        style: const TextStyle(color: AppTheme.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isSafe
                      ? l.invoiceBlMatcherStatusSafeDesc
                      : l.invoiceBlMatcherStatusCriticalDesc(criticalCount),
                  style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryOf(context)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              _buildBadgeCounter(l.invoiceBlMatcherCriticalCount(criticalCount), criticalCount, AppTheme.crimson),
              const SizedBox(height: 6),
              _buildBadgeCounter(l.invoiceBlMatcherWarningCount(warningCount), warningCount, AppTheme.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCounter(String labelText, int count, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0 ? col.withValues(alpha: 0.15) : AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: count > 0 ? col : AppTheme.borderOf(context)),
      ),
      child: Text(
        labelText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: count > 0 ? col : AppTheme.textSecondaryOf(context),
        ),
      ),
    );
  }

  bool _isArabic(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl ||
      (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';

  Widget _buildComparisonMatrixTable() {
    final l = context.l10n;
    final isArabic = _isArabic(context);
    final matrix = ((_matchResult?['comparison_matrix']) as List<dynamic>?) ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAltOf(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 750;
                final titleWidget = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.table_chart_outlined, size: 18, color: AppTheme.textPrimaryOf(context)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l.invoiceBlMatcherMatrixTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );

                final buttonsWidget = Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IdocUi.fit(AppButton(
                      key: const Key('copyComparisonMatrixTsvBtn'),
                      label: context.l10n.idocACopyAsTSV,
                      icon: Icons.copy_all,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: matrix.isEmpty ? null : () => _copyComparisonMatrixTsv(matrix),
                    )),
                    IdocUi.fit(AppButton(
                      key: const Key('exportComparisonMatrixExcelBtn'),
                      label: context.l10n.exportExcel,
                      icon: Icons.table_view,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: matrix.isEmpty ? null : () => _exportComparisonMatrixExcel(matrix),
                    )),
                    IdocUi.fit(AppButton(
                      key: const Key('exportComparisonMatrixPdfBtn'),
                      label: context.l10n.idocAPrintPDF,
                      icon: Icons.picture_as_pdf,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: matrix.isEmpty ? null : () => _exportComparisonMatrixPdf(matrix),
                    )),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget,
                      const SizedBox(height: 8),
                      buttonsWidget,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleWidget),
                    const SizedBox(width: 8),
                    buttonsWidget,
                  ],
                );
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAltOf(context)),
              horizontalMargin: 16,
              columnSpacing: 20,
              columns: [
                DataColumn(label: Text(l.invoiceBlMatcherColCheckItem, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)))),
                DataColumn(label: Text(context.l10n.idocASystemValue, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)))),
                DataColumn(label: Text(l.invoiceBlMatcherColInvoiceValue, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)))),
                DataColumn(label: Text(context.l10n.idocAPackingList, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)))),
                DataColumn(label: Text(l.invoiceBlMatcherColBlValue, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)))),
                DataColumn(label: Text(l.invoiceBlMatcherColMatchStatus, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)))),
                DataColumn(label: Text(l.invoiceBlMatcherColActionRequired, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)))),
                DataColumn(label: Text(context.l10n.idocARowActions, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)))),
              ],
              rows: matrix.map((rawItem) {
                final item = CodedItemText.localizeRow(rawItem as Map, l);
                final status = item['match_status'] ?? 'MATCH';
                final isMatch = status == 'MATCH';
                final isMinor = status == 'MISMATCH_MINOR';
                final isExtFailed = status == 'EXTRACTION_FAILED';

                final Color statusCol;
                final String statusTxt;
                if (isMatch) {
                  statusCol = AppTheme.emerald;
                  statusTxt = l.invoiceBlMatcherStatusMatch;
                } else if (isExtFailed) {
                  statusCol = AppTheme.textSecondaryOf(context);
                  statusTxt = context.l10n.idocAExtractionFailed;
                } else if (isMinor) {
                  statusCol = AppTheme.orange;
                  statusTxt = l.invoiceBlMatcherStatusMinor;
                } else {
                  statusCol = AppTheme.crimson;
                  statusTxt = l.invoiceBlMatcherStatusMismatch;
                }

                final checkItemName = isArabic
                    ? (item['field_name_ar'] ?? item['field_name_en'] ?? '')
                    : (item['field_name_en'] ?? item['field_name_ar'] ?? '');

                final systemVal = '${item['system_value'] ?? '—'}';
                final invoiceVal = '${item['invoice_value'] ?? '—'}';
                final plVal = '${item['packing_list_value'] ?? '—'}';
                final blVal = '${item['bl_value'] ?? '—'}';
                final detailsTxt = '${item['details'] ?? item['action_required'] ?? ''}';
                final List<dynamic> disagreeingSources = item['disagreeing_sources'] as List<dynamic>? ?? [];

                final rowSummary = '$checkItemName\t$systemVal\t$invoiceVal\t$plVal\t$blVal\t$statusTxt\t$detailsTxt';

                return DataRow(
                  cells: [
                    DataCell(
                      CopyableTableCell(
                        value: checkItemName,
                        rowSummary: rowSummary,
                        child: Text(
                          checkItemName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: systemVal,
                        rowSummary: rowSummary,
                        child: Text(
                          systemVal,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context)),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: invoiceVal,
                        rowSummary: rowSummary,
                        child: Text(
                          invoiceVal,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.cobalt),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: plVal,
                        rowSummary: rowSummary,
                        child: Text(
                          plVal,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.wcagCobalt),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: blVal,
                        rowSummary: rowSummary,
                        child: Text(
                          blVal,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.emerald),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: statusTxt,
                        rowSummary: rowSummary,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusCol.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusCol),
                              ),
                              child: Text(
                                statusTxt,
                                style: TextStyle(color: statusCol, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            if (disagreeingSources.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 3,
                                runSpacing: 2,
                                children: disagreeingSources.map((s) {
                                  String label = s.toString();
                                  if (isArabic) {
                                    label = label
                                        .replaceAll('INVOICE vs BL', context.l10n.idocADiffInvoiceBl)
                                        .replaceAll('SYSTEM vs INVOICE', context.l10n.idocADiffSystemInvoice)
                                        .replaceAll('SYSTEM vs BL', context.l10n.idocADiffSystemBl)
                                        .replaceAll('PACKING_LIST vs BL', context.l10n.idocADiffPackingBl)
                                        .replaceAll('INVOICE vs PACKING_LIST', context.l10n.idocADiffInvoicePacking)
                                        .replaceAll('SYSTEM vs PACKING_LIST', context.l10n.idocADiffSystemPacking);
                                  }
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.crimson.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      label,
                                      style: const TextStyle(fontSize: 9.5, color: AppTheme.crimson, fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: detailsTxt,
                        rowSummary: rowSummary,
                        child: Text(
                          detailsTxt,
                          style: TextStyle(fontSize: 11, color: isMatch ? (AppTheme.textPrimaryOf(context)) : statusCol),
                        ),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                        tooltip: context.l10n.idocACopyRowDataAsTSV,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: rowSummary));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.idocARowCopiedTsv(checkItemName)),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedFieldsCards() {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final Map<String, dynamic> inv = _matchResult?['invoice_data'] is Map
        ? Map<String, dynamic>.from(_matchResult!['invoice_data'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> pl = _matchResult?['packing_list_data'] is Map
        ? Map<String, dynamic>.from(_matchResult!['packing_list_data'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> bl = _matchResult?['bl_data'] is Map
        ? Map<String, dynamic>.from(_matchResult!['bl_data'] as Map)
        : <String, dynamic>{};

    final List<Widget> cards = [
      Expanded(
        child: _buildDataSummaryCard(
          title: l.invoiceBlMatcherExtractedInvoiceTitle,
          icon: Icons.receipt_long,
          color: AppTheme.cobalt,
          data: inv,
        ),
      ),
    ];

    if (pl.isNotEmpty || _showPackingList) {
      cards.add(const SizedBox(width: 16));
      cards.add(
        Expanded(
          child: _buildDataSummaryCard(
            title: context.l10n.idocAExtractedPackingList,
            icon: Icons.inventory_2,
            color: AppTheme.wcagCobalt,
            data: pl,
          ),
        ),
      );
    }

    cards.add(const SizedBox(width: 16));
    cards.add(
      Expanded(
        child: _buildDataSummaryCard(
          title: l.invoiceBlMatcherExtractedBlTitle,
          icon: Icons.directions_boat,
          color: AppTheme.emerald,
          data: bl,
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cards,
    );
  }

  String _localizeDataKey(String key, AppLocalizations l, bool isArabic) {
    switch (key) {
      case 'invoice_number':
      case 'invoice_no':
        return l.smartExtractorFieldInvoiceNo;
      case 'invoice_date':
        return l.smartExtractorFieldInvoiceDate;
      case 'acid_number':
      case 'acid':
        return l.smartExtractorFieldAcidNo;
      case 'importer_tax_id':
        return l.smartExtractorFieldImporterTaxId;
      case 'supplier_name':
      case 'supplier':
      case 'shipper':
        return l.smartExtractorFieldSupplier;
      case 'importer_name':
      case 'importer':
      case 'consignee':
        return l.smartExtractorFieldImporter;
      case 'incoterm':
      case 'incoterms':
        return l.smartExtractorFieldIncoterms;
      case 'total_amount':
      case 'total_value':
      case 'invoice_value':
        return l.smartExtractorFieldTotalAmount;
      case 'currency':
        return context.l10n.currency;
      case 'gross_weight_kg':
      case 'total_gross_weight':
        return l.smartExtractorFieldTotalGrossWeight;
      case 'bl_number':
      case 'bl_no':
        return l.smartExtractorFieldBlNo;
      case 'carrier_name':
      case 'carrier':
        return l.smartExtractorFieldCarrier;
      case 'pol':
      case 'port_of_loading':
        return l.smartExtractorFieldPol;
      case 'pod':
      case 'port_of_discharge':
        return l.smartExtractorFieldPod;
      case 'total_cbm':
        return l.smartExtractorFieldTotalCbm;
      case 'total_packages':
      case 'packages_count':
        return l.smartExtractorFieldPackagesCount;
      case 'containers':
        return context.l10n.idocAContainers;
      default:
        return key.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
    }
  }

  Widget _buildDataSummaryCard({
    required String title,
    required IconData icon,
    required Color color,
    required Map<String, dynamic> data,
  }) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? color.withValues(alpha: 0.5) : color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
            ],
          ),
          const Divider(),
          ...data.entries.map((e) {
            if (e.key.startsWith('_') || e.value == null || e.value.toString().isEmpty) {
              return const SizedBox.shrink();
            }
            final displayLabel = _localizeDataKey(e.key, l, isArabic);
            final valStr = '${e.value}';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      '$displayLabel:',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: CopyableText(
                      valStr,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCorrectionLetterCard() {
    final l = context.l10n;
    final letter = (_matchResult?['correction_letter'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.severityBackgroundOf(context, AppSeverity.warning),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.mark_email_unread_outlined, color: AppTheme.orange, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.invoiceBlMatcherCorrectionLetterTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                ),
              ),
              IdocUi.fit(AppButton(
                label: l.invoiceBlMatcherCopyLetterButton,
                icon: Icons.copy,
                variant: AppButtonVariant.warning,
                size: AppButtonSize.small,
                onPressed: () {
                  CopyHelper.copy(
                    context,
                    letter,
                    customMessage: l.invoiceBlMatcherLetterCopiedSuccess,
                  );
                },
              )),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppTheme.severityForegroundOf(context, AppSeverity.warning) : AppTheme.orange),
            ),
            child: SelectableText(
              letter,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncActionFooter() {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1150;
        final infoWidget = Row(
          children: [
            const Icon(Icons.sync_alt, color: AppTheme.cobalt, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.invoiceBlMatcherSyncFooterTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  Text(
                    _activeFileId != null
                        ? l.invoiceBlMatcherSyncFooterDesc
                        : l.invoiceBlMatcherSyncFooterNoFile,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        );

        final actionButtons = Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Export / Copy Match Report Button
            IdocUi.fit(AppButton(
              label: l.invoiceBlMatcherExportReportButton,
              icon: Icons.picture_as_pdf_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: _matchResult == null ? null : _showExportReportDialog,
            )),
            // Save Draft Session Button (حفظ مؤقت)
            IdocUi.fit(AppButton(
              label: context.l10n.idocASaveSessionDraftEmoji,
              icon: Icons.save_as_outlined,
              variant: AppButtonVariant.secondary,
              isLoading: _isSavingDraft,
              onPressed: (_activeFileId == null || _isSavingDraft || _isSyncing)
                  ? null
                  : () => _saveSession(isDraft: true),
            )),
            // Certify & Final Save Button (اعتماد وحفظ نهائي وتحديث الموافقة الجمركية)
            IdocUi.fit(AppButton(
              label: context.l10n.idocAApproveSaveFinalEmoji,
              icon: Icons.verified_rounded,
              variant: AppButtonVariant.success,
              isLoading: _isSyncing,
              onPressed: (_activeFileId == null || _isSavingDraft || _isSyncing)
                  ? null
                  : () => _saveSession(isDraft: false),
            )),
          ],
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderOf(context)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    infoWidget,
                    const SizedBox(height: 14),
                    actionButtons,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: infoWidget),
                    const SizedBox(width: 12),
                    Flexible(child: actionButtons),
                  ],
                ),
        );
      },
    );
  }

  void _showExportReportDialog() {
    if (_matchResult == null) return;
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final score = _matchResult?['match_score_percentage'] ?? 0;
    final status = _matchResult?['overall_status'] ?? 'UNKNOWN';
    final isSafe = _matchResult?['is_safe_for_certification'] == true;
    final criticals = (_matchResult?['critical_discrepancies_count'] as num?)?.toInt() ?? 0;
    final warnings = (_matchResult?['warning_discrepancies_count'] as num?)?.toInt() ?? 0;
    final matrix = _matchResult?['comparison_matrix'] as List<dynamic>? ?? [];
    final correctionLetter = _matchResult?['correction_letter']?.toString() ?? '';

    final reportBuffer = StringBuffer();
    reportBuffer.writeln('===============================================================');
    reportBuffer.writeln('    ${l.invoiceBlMatcherReportDialogTitle}');
    reportBuffer.writeln('===============================================================');
    reportBuffer.writeln(l.invoiceBlMatcherReportMatchRatio(score));
    reportBuffer.writeln('${l.invoiceBlMatcherColMatchStatus} : $status');
    reportBuffer.writeln('${l.invoiceBlMatcherSyncFooterTitle} : ${isSafe ? l.reqBadgeYes : l.reqBadgeNo}');
    reportBuffer.writeln(l.invoiceBlMatcherCriticalCount(criticals));
    reportBuffer.writeln(l.invoiceBlMatcherWarningCount(warnings));
    reportBuffer.writeln('---------------------------------------------------------------');
    reportBuffer.writeln('${l.invoiceBlMatcherColCheckItem}\t${l.invoiceBlMatcherColInvoiceValue}\t${l.invoiceBlMatcherColBlValue}\t${l.invoiceBlMatcherColMatchStatus}\t${l.invoiceBlMatcherColActionRequired}');
    for (final row in matrix) {
      final r = CodedItemText.localizeRow(row as Map, l, forExport: true);
      final checkItem = isArabic ? (r['field_name_ar'] ?? r['field_name_en'] ?? '') : (r['field_name_en'] ?? r['field_name_ar'] ?? '');
      final invVal = r['invoice_value'] ?? '—';
      final blVal = r['bl_value'] ?? '—';
      final matchStat = r['match_status'] == 'MATCH'
          ? l.invoiceBlMatcherStatusMatch
          : (r['match_status'] == 'MISMATCH_MINOR' ? l.invoiceBlMatcherStatusMinor : l.invoiceBlMatcherStatusMismatch);
      final details = r['details'] ?? '';
      reportBuffer.writeln('$checkItem\t$invVal\t$blVal\t$matchStat\t$details');
    }
    if (correctionLetter.isNotEmpty) {
      reportBuffer.writeln('---------------------------------------------------------------');
      reportBuffer.writeln('${l.invoiceBlMatcherCorrectionLetterTitle}:');
      reportBuffer.writeln(correctionLetter);
    }
    reportBuffer.writeln('===============================================================');

    final reportText = reportBuffer.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.cobalt),
            const SizedBox(width: 10),
            Text(l.invoiceBlMatcherReportDialogTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 700,
          height: 480,
          child: SelectionArea(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l.invoiceBlMatcherReportMatchRatio(score)}  |  ${isSafe ? l.invoiceBlMatcherReportSafeStatus : l.invoiceBlMatcherReportUnsafeStatus}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSafe ? AppTheme.emerald : AppTheme.crimson,
                      ),
                    ),
                    IdocUi.fit(AppButton(
                      label: l.invoiceBlMatcherCopyReportButton,
                      icon: Icons.copy,
                      variant: AppButtonVariant.ghost,
                      onPressed: () {
                        CopyHelper.copy(
                          context,
                          reportText,
                          customMessage: l.invoiceBlMatcherReportCopiedSuccess,
                        );
                      },
                    )),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
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
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IdocUi.fit(AppButton(
            label: l.invoiceBlMatcherCloseButton,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx),
          )),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW MODE TOGGLE & SESSIONS REGISTRY
  // ==========================================

  Widget _buildViewModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.borderOf(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const Key('matcherTabToggleBtn'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _activeViewMode = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeViewMode == 0
                      ? (AppTheme.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _activeViewMode == 0
                      ? [BoxShadow(color: AppTheme.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.compare_arrows, size: 18, color: _activeViewMode == 0 ? AppTheme.cobalt : AppTheme.textSecondaryOf(context)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.l10n.invoiceBlMatchTabInspect,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _activeViewMode == 0 ? AppTheme.cobalt : (AppTheme.textSecondaryOf(context)),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              key: const Key('sessionsTabToggleBtn'),
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() => _activeViewMode = 1);
                ref.read(invoiceBLMatchSessionsProvider.notifier).fetchSessions(importFileId: _activeFileId);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeViewMode == 1
                      ? (AppTheme.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _activeViewMode == 1
                      ? [BoxShadow(color: AppTheme.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_edu_rounded, size: 18, color: _activeViewMode == 1 ? AppTheme.cobalt : AppTheme.textSecondaryOf(context)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.l10n.invoiceBlMatchTabHistory,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _activeViewMode == 1 ? AppTheme.cobalt : AppTheme.textSecondaryOf(context),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        final sessions = ref.watch(invoiceBLMatchSessionsProvider).valueOrNull ?? [];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _activeViewMode == 1 ? AppTheme.cobalt : AppTheme.textMutedOf(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${sessions.length}',
                            style: const TextStyle(color: AppTheme.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsRegistryView(List<dynamic> importFiles) {
    final sessionsAsync = ref.watch(invoiceBLMatchSessionsProvider);

    return sessionsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsetsDirectional.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              context.l10n.idocALoadingMatchingSessionsRegistry,
              style: IdocUi.sectionTitle(context),
            ),
          ],
        ),
      ),
      error: (e, st) => IdocStateView.error(
        message: context.l10n.idocAFailedToLoadTheSessionsRegistry(e),
        actionLabel: context.l10n.retry,
        onAction: () => ref.read(invoiceBLMatchSessionsProvider.notifier).fetchSessions(importFileId: _activeFileId),
      ),
      data: (sessions) {
        var filtered = sessions.where((s) {
          if (_selectedStatusFilter == 'DRAFT' && !s.isDraft) return false;
          if (_selectedStatusFilter == 'CERTIFIED' && s.isDraft) return false;
          if (_filterImportFileId != null && s.importFileId != _filterImportFileId) return false;

          final query = _searchSessionsCtrl.text.trim().toLowerCase();
          if (query.isNotEmpty) {
            final codeMatch = s.sessionCode.toLowerCase().contains(query);
            final titleMatch = (s.sessionTitle ?? '').toLowerCase().contains(query);
            final notesMatch = (s.sessionNotes ?? '').toLowerCase().contains(query);
            final fileMatch = (s.importFileCode ?? '').toLowerCase().contains(query);
            if (!codeMatch && !titleMatch && !notesMatch && !fileMatch) return false;
          }
          return true;
        }).toList();

        final totalCount = sessions.length;
        final certifiedCount = sessions.where((s) => !s.isDraft).length;
        final draftCount = sessions.where((s) => s.isDraft).length;
        final avgScore = sessions.isEmpty
            ? 0.0
            : (sessions.map((s) => s.matchScore).reduce((a, b) => a + b) / sessions.length);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. KPI / Summary Stats Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IdocUi.metrics([
                    MetricCardData(
                      title: context.l10n.idocATotalSessions,
                      shortTitle: context.l10n.idocATotalSessions,
                      value: '$totalCount',
                      icon: Icons.all_inbox_rounded,
                      color: AppTheme.cobalt,
                    ),
                    MetricCardData(
                      title: context.l10n.idocAApprovedSessions,
                      shortTitle: context.l10n.idocAApprovedSessions,
                      value: '$certifiedCount',
                      icon: Icons.verified_rounded,
                      color: AppTheme.emerald,
                    ),
                    MetricCardData(
                      title: context.l10n.idocATemporaryDrafts,
                      shortTitle: context.l10n.idocATemporaryDrafts,
                      value: '$draftCount',
                      icon: Icons.bookmark_added_rounded,
                      color: AppTheme.orange,
                    ),
                    MetricCardData(
                      title: context.l10n.idocAAverageMatch,
                      shortTitle: context.l10n.idocAAverageMatch,
                      value: '${avgScore.toStringAsFixed(1)}%',
                      icon: Icons.percent_rounded,
                      color: AppTheme.wcagEmerald,
                    ),
                  ]),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: IdocUi.fit(AppButton(
                    label: context.l10n.idocANewInspectionSession,
                    icon: Icons.add_rounded,
                    variant: AppButtonVariant.primary,
                    onPressed: () {
                      setState(() {
                        _activeViewMode = 0;
                        _activeSessionId = null;
                        _activeSessionCode = null;
                      });
                    },
                  )),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. Search & Filter Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderOf(context)),
                boxShadow: [
                  BoxShadow(color: AppTheme.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 650;
                  final searchField = TextField(
                    controller: _searchSessionsCtrl,
                    decoration: InputDecoration(
                      hintText: context.l10n.idocASearchBySessionCodeImportFile,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchSessionsCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _searchSessionsCtrl.clear()),
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (_) => setState(() {}),
                  );

                  final filterDropdown = SearchableDropdownField<int?>(
                    labelText: context.l10n.idocAFilterByImportFile,
                    hintText: context.l10n.idocAAllImportFiles,
                    value: _filterImportFileId,
                    items: [
                      SearchableDropdownItem<int?>(value: null, label: context.l10n.idocAAllImportFiles),
                      ...importFiles.map(
                        (f) => SearchableDropdownItem<int?>(
                          value: f.importFileId,
                          label: '${f.primaryNameWithCode} - ${f.supplierName}',
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _filterImportFileId = val);
                    },
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isNarrow) ...[
                        searchField,
                        const SizedBox(height: 10),
                        filterDropdown,
                      ] else ...[
                        Row(
                          children: [
                            Expanded(child: searchField),
                            const SizedBox(width: 12),
                            SizedBox(width: 260, child: filterDropdown),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildStatusFilterChip('ALL', context.l10n.idocAAllCount(totalCount)),
                              _buildStatusFilterChip('CERTIFIED', context.l10n.idocAApprovedCount(certifiedCount)),
                              _buildStatusFilterChip('DRAFT', context.l10n.idocATemporaryDraftsCount3(draftCount)),
                            ],
                          ),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy_all, color: AppTheme.cobalt),
                                tooltip: context.l10n.idocACopyTableTSV,
                                onPressed: filtered.isEmpty ? null : () => _copySessionsTable(filtered),
                              ),
                              IconButton(
                                icon: const Icon(Icons.table_view_outlined, color: AppTheme.emerald),
                                tooltip: context.l10n.idocAExportExcel,
                                onPressed: filtered.isEmpty ? null : () => _exportSessionsToExcel(filtered),
                              ),
                              IconButton(
                                icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson),
                                tooltip: context.l10n.idocAPrintPDFReport,
                                onPressed: filtered.isEmpty ? null : () => _exportSessionsToPdf(filtered),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded, color: AppTheme.charcoal),
                                tooltip: context.l10n.refresh,
                                onPressed: () => ref.read(invoiceBLMatchSessionsProvider.notifier).fetchSessions(importFileId: _activeFileId),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 3. Sessions Registry Table
            if (filtered.isEmpty)
              Container(
                decoration: AppTheme.cardDecorationOf(context),
                child: IdocStateView.empty(
                  message: context.l10n.idocANoMatchingSessionsFoundForThe,
                  icon: Icons.inventory_2_outlined,
                  actionLabel: context.l10n.invoiceBlMatchNewSessionBtn,
                  onAction: () => setState(() => _activeViewMode = 0),
                ),
              )
            else
              _buildSessionsTable(filtered),
          ],
        );
      },
    );
  }

  Widget _buildStatusFilterChip(String value, String label) {
    final isSelected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedStatusFilter = value),
      selectedColor: AppTheme.cobalt,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.white : AppTheme.charcoal,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildSessionsTable(List<InvoiceBLMatchSessionModel> sessions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderOf(context)),
        boxShadow: [
          BoxShadow(color: AppTheme.black.withValues(alpha: 0.04), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppTheme.charcoal),
            headingTextStyle: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 12),
            dataRowMinHeight: 52,
            dataRowMaxHeight: 64,
            horizontalMargin: 16,
            columnSpacing: 20,
            columns: [
              DataColumn(label: Text(context.l10n.idocASessionCode)),
              DataColumn(label: Text(context.l10n.idocAImportFile)),
              DataColumn(label: Text(context.l10n.idocASessionTitleAndNotes)),
              DataColumn(label: Text(context.l10n.status)),
              DataColumn(label: Text(context.l10n.idocAMatchScore)),
              DataColumn(label: Text(context.l10n.idocADiscrepancies)),
              DataColumn(label: Text(context.l10n.idocASessionDate)),
              DataColumn(label: Text(context.l10n.actions)),
            ],
            rows: sessions.map((session) {
              final isDraft = session.isDraft;
              return DataRow(
                color: WidgetStateProperty.resolveWith((states) {
                  if (session.sessionId == _activeSessionId) {
                    return AppTheme.cobalt.withValues(alpha: 0.08);
                  }
                  return null;
                }),
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(session.sessionCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 14, color: AppTheme.cobalt),
                          tooltip: context.l10n.idocACopyCode,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: session.sessionCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.l10n.idocASessionCodeCopiedToTheClipboard), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      session.importFileCode ?? 'IMP-${session.importFileId}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.charcoal),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            session.sessionTitle ?? context.l10n.idocADefaultSessionTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (session.sessionNotes != null && session.sessionNotes!.isNotEmpty)
                            Text(
                              session.sessionNotes!,
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    IdocStatusChip(
                      label: isDraft ? context.l10n.idocADraft : context.l10n.idocACertified,
                      severity: isDraft ? AppSeverity.warning : AppSeverity.success,
                      icon: isDraft ? Icons.edit_document : Icons.check_circle,
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 50,
                          child: LinearProgressIndicator(
                            value: session.matchScore / 100.0,
                            backgroundColor: AppTheme.borderOf(context),
                            color: session.matchScore >= 90
                                ? AppTheme.emerald
                                : (session.matchScore >= 70 ? AppTheme.orange : AppTheme.crimson),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${session.matchScore.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: session.matchScore >= 90
                                ? AppTheme.emerald
                                : (session.matchScore >= 70 ? AppTheme.orange : AppTheme.crimson),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: session.discrepancyCount > 0 ? AppTheme.crimson.withValues(alpha: 0.1) : AppTheme.emerald.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        session.discrepancyCount > 0 ? context.l10n.idocADiscrepancyCount(session.discrepancyCount) : context.l10n.idocAFullyMatched,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: session.discrepancyCount > 0 ? AppTheme.crimson : AppTheme.emerald,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      session.createdAt.contains('T') ? session.createdAt.split('T').first : session.createdAt,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: Key('cloneSessionBtn_${session.sessionId}'),
                          icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                          tooltip: context.l10n.idocACloneSessionAsANewDraft,
                          onPressed: () => _cloneSession(session),
                        ),
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18, color: AppTheme.cobalt),
                          tooltip: context.l10n.idocAViewSessionDetailsAndMatrix,
                          onPressed: () => _showSessionDetailsDialog(session),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_circle_outline, size: 18, color: AppTheme.emerald),
                          tooltip: context.l10n.idocARestoreAndLoadTheSessionIn,
                          onPressed: () => _loadSessionIntoMatcher(session),
                        ),
                        if (isDraft)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.crimson),
                            tooltip: context.l10n.idocADeleteDraft,
                            onPressed: () => _deleteSession(session),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showSessionDetailsDialog(InvoiceBLMatchSessionModel session) {
    final matrix = session.comparisonMatrix ?? [];
    final invData = session.invoiceData ?? {};
    final blData = session.blData ?? {};
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
                    context.l10n.idocASessionDetailsTitle(session.sessionCode),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                  ),
                  SizedBox(height: 2),
                  Text(
                    context.l10n.idocAImportFileCreated((session.importFileCode ?? "IMP-${session.importFileId}"), session.createdAt),
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            IdocStatusChip(
              label: isDraft ? context.l10n.idocADraft : context.l10n.idocACertified,
              severity: isDraft ? AppSeverity.warning : AppSeverity.success,
              icon: isDraft ? Icons.edit_document : Icons.check_circle,
            ),
          ],
        ),
        content: SizedBox(
          width: 900,
          height: 520,
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                TabBar(
                  labelColor: AppTheme.cobalt,
                  unselectedLabelColor: AppTheme.textMutedOf(context),
                  indicatorColor: AppTheme.cobalt,
                  tabs: [
                    Tab(icon: Icon(Icons.compare_arrows, size: 16), text: context.l10n.idocAMatchingAndVerificationMatrix),
                    Tab(icon: Icon(Icons.data_object, size: 16), text: context.l10n.idocAExtractedDataInvoiceBL),
                    Tab(icon: Icon(Icons.notes, size: 16), text: ctx.l10n.idocASessionNotesTab),
                  ],
                ),
                SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Comparison Matrix Table
                      matrix.isEmpty
                          ? Center(child: Text(context.l10n.idocANoSavedMatchingMatrixForThis))
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppTheme.borderOf(context)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(AppTheme.charcoal),
                                      headingTextStyle: TextStyle(
                                          color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      columns: [
                                        DataColumn(label: Text(context.l10n.idocAStandardItem)),
                                        DataColumn(label: Text(context.l10n.idocASystemData)),
                                        DataColumn(label: Text(context.l10n.idocAInvoiceData)),
                                        DataColumn(label: Text(context.l10n.idocAPackingListAlt)),
                                        DataColumn(label: Text(context.l10n.idocABLData)),
                                        DataColumn(label: Text(context.l10n.idocAMatchStatus)),
                                        DataColumn(label: Text(context.l10n.idocADetailsAndSourcesOfDisagreement)),
                                      ],
                                      rows: matrix.map((item) {
                                        final row = item is Map ? CodedItemText.localizeRow(item, context.l10n) : {};
                                        final status = row['match_status']?.toString() ?? 'UNKNOWN';
                                        final isMatch = status == 'MATCH';
                                        final isExtFailed = status == 'EXTRACTION_FAILED';
                                        final isMinor = status == 'MISMATCH_MINOR';

                                        Color statusCol;
                                        String statusTxt;
                                        if (isMatch) {
                                          statusCol = AppTheme.emerald;
                                          statusTxt = context.l10n.idocAMatched;
                                        } else if (isExtFailed) {
                                          statusCol = AppTheme.textSecondaryOf(context);
                                          statusTxt = context.l10n.idocAExtractionFailed3;
                                        } else if (isMinor) {
                                          statusCol = AppTheme.orange;
                                          statusTxt = context.l10n.idocAMinorVariance;
                                        } else {
                                          statusCol = AppTheme.crimson;
                                          statusTxt = context.l10n.idocAMaterialVariance;
                                        }

                                        final disagreeingSources = (row['disagreeing_sources'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

                                        return DataRow(
                                          cells: [
                                            DataCell(Text(
                                              row['field_name_ar'] ?? row['field_name_en'] ?? '—',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                            )),
                                            DataCell(Text(row['system_value']?.toString() ?? '—',
                                                style: const TextStyle(fontSize: 11))),
                                            DataCell(Text(row['invoice_value']?.toString() ?? '—',
                                                style: const TextStyle(fontSize: 11, color: AppTheme.cobalt))),
                                            DataCell(Text(row['packing_list_value']?.toString() ?? '—',
                                                style: const TextStyle(fontSize: 11, color: AppTheme.wcagCobalt))),
                                            DataCell(Text(row['bl_value']?.toString() ?? '—',
                                                style: const TextStyle(fontSize: 11, color: AppTheme.emerald))),
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: statusCol.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  statusTxt,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: statusCol,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(row['details']?.toString() ?? '—',
                                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                                if (disagreeingSources.isNotEmpty)
                                                  Text(
                                                    context.l10n.idocADisagreementBetween((disagreeingSources.join(", "))),
                                                    style: const TextStyle(fontSize: 9.5, color: AppTheme.crimson, fontWeight: FontWeight.bold),
                                                  ),
                                              ],
                                            )),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      // Tab 2: Extracted Data
                      SingleChildScrollView(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceAltOf(context),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.borderOf(context)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.receipt_long, size: 16, color: AppTheme.cobalt),
                                        SizedBox(width: 6),
                                        Text(context.l10n.idocACommercialInvoiceExtracts,
                                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                      ],
                                    ),
                                    const Divider(),
                                    SelectableText(
                                      const JsonEncoder.withIndent('  ').convert(invData),
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceAltOf(context),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.borderOf(context)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.directions_boat, size: 16, color: AppTheme.emerald),
                                        SizedBox(width: 6),
                                        Text(context.l10n.idocABillOfLadingExtracts,
                                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                                      ],
                                    ),
                                    const Divider(),
                                    SelectableText(
                                      const JsonEncoder.withIndent('  ').convert(blData),
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tab 3: Raw Texts & Notes
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (session.sessionNotes != null && session.sessionNotes!.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.cloudWhite,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.borderOf(context)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(context.l10n.idocASessionNotes, style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(session.sessionNotes!),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
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
          IconButton(
            icon: const Icon(Icons.copy_all, color: AppTheme.cobalt),
            tooltip: context.l10n.idocACopySessionMatrixTSV,
            onPressed: matrix.isEmpty ? null : () => _copyComparisonMatrixTsv(matrix),
          ),
          IdocUi.fit(AppButton(
            key: const Key('dialogCloneSessionBtn'),
            label: context.l10n.idocACloneAsANewDraft,
            icon: Icons.copy_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.pop(ctx);
              _cloneSession(session);
            },
          )),
          IdocUi.fit(AppButton(
            label: context.l10n.idocARestoreAndLoadInTheInspection,
            icon: Icons.play_circle_outline,
            variant: AppButtonVariant.ghost,
            onPressed: () {
              Navigator.pop(ctx);
              _loadSessionIntoMatcher(session);
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

  void _loadSessionIntoMatcher(InvoiceBLMatchSessionModel session) {
    setState(() {
      _activeFileId = session.importFileId;
      // Raw texts / file names are not stored by the backend (Q1): only the
      // extracted data and the comparison matrix are restored.
      _showPackingList = session.packingListData != null;
      _activeSessionId = session.sessionId;
      _activeSessionCode = session.sessionCode;

      if (session.comparisonMatrix != null && session.comparisonMatrix!.isNotEmpty) {
        _matchResult = {
          'import_file_id': session.importFileId,
          'match_score_percentage': session.matchScore,
          'is_safe_for_certification': session.isSafeForCertification,
          'critical_discrepancies_count': session.criticalDiscrepanciesCount,
          'warning_discrepancies_count': session.warningDiscrepanciesCount,
          'comparison_matrix': session.comparisonMatrix,
          'invoice_data': session.invoiceData,
          'bl_data': session.blData,
          'packing_list_data': session.packingListData,
          'overall_status': session.isDraft ? 'DRAFT_SAVED' : 'CERTIFIED_SAVED',
        };
      }
      _activeViewMode = 0; // Switch to Matcher view
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.idocASessionRestoredInspection(session.sessionCode)),
        backgroundColor: AppTheme.cobalt,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _cloneSession(InvoiceBLMatchSessionModel session) {
    setState(() {
      _activeFileId = session.importFileId;
      // Raw texts / file names are not stored by the backend (Q1): only the
      // extracted data and the comparison matrix are restored.
      _showPackingList = session.packingListData != null;
      _activeSessionId = null; // Cleared to create a new editable draft
      _activeSessionCode = null;

      if (session.comparisonMatrix != null && session.comparisonMatrix!.isNotEmpty) {
        _matchResult = {
          'import_file_id': session.importFileId,
          'match_score_percentage': session.matchScore,
          'is_safe_for_certification': session.isSafeForCertification,
          'critical_discrepancies_count': session.criticalDiscrepanciesCount,
          'warning_discrepancies_count': session.warningDiscrepanciesCount,
          'comparison_matrix': List<Map<String, dynamic>>.from(
            session.comparisonMatrix!.map((e) => Map<String, dynamic>.from(e)),
          ),
          'invoice_data': session.invoiceData != null
              ? Map<String, dynamic>.from(session.invoiceData!)
              : <String, dynamic>{},
          'bl_data': session.blData != null
              ? Map<String, dynamic>.from(session.blData!)
              : <String, dynamic>{},
          'packing_list_data': session.packingListData != null
              ? Map<String, dynamic>.from(session.packingListData!)
              : <String, dynamic>{},
          'overall_status': 'DRAFT_SAVED',
        };
      }
      _activeViewMode = 0; // Switch to Matcher view
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.idocASessionDataClonedAsDraft(session.sessionCode)),
        backgroundColor: AppTheme.cobalt,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteSession(InvoiceBLMatchSessionModel session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.idocAConfirmDraftDeletion),
        content: Text(context.l10n.idocAAreYouSureYouWantTo(session.sessionCode)),
        actions: [
          IdocUi.fit(AppButton(
            label: context.l10n.cancel,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx, false),
          )),
          IdocUi.fit(AppButton(
            label: context.l10n.delete,
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.pop(ctx, true),
          )),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(invoiceBLMatchSessionsProvider.notifier).deleteSession(session.sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.idocADraftDeletedSuccessfully), backgroundColor: AppTheme.emerald),
        );
      }
    } catch (e) {
      if (mounted) {
        showIdocError(context, e, title: context.l10n.idocADeleteSessionFailed);
      }
    }
  }

  void _copySessionsTable(List<InvoiceBLMatchSessionModel> sessions) {
    final headers = [
      context.l10n.idocASessionCode,
      context.l10n.idocAImportFile,
      context.l10n.idocATitle,
      context.l10n.status,
      context.l10n.idocAMatchScore,
      context.l10n.idocADiscrepancies,
      context.l10n.idocACreatedAt,
      context.l10n.idocABy,
    ];
    final rows = sessions.map((s) => [
      s.sessionCode,
      s.importFileCode ?? 'IMP-${s.importFileId}',
      s.sessionTitle ?? s.sessionNotes ?? '—',
      s.isDraft ? context.l10n.idocADraft : context.l10n.idocACertified,
      '${s.matchScore.toStringAsFixed(1)}%',
      s.discrepancyCount.toString(),
      s.createdAt,
      s.createdBy ?? '—',
    ]).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: context.l10n.idocAMatchingSessionsTableCopiedToThe,
    );
  }

  Future<void> _exportSessionsToExcel(List<InvoiceBLMatchSessionModel> sessions) async {
    final headers = [
      context.l10n.idocASessionCode,
      context.l10n.idocAImportFile,
      context.l10n.idocATitle,
      context.l10n.status,
      context.l10n.idocAMatchScore,
      context.l10n.idocADiscrepancies,
      context.l10n.idocACreatedAt,
      context.l10n.idocABy,
    ];
    final rows = sessions.map((s) => [
      s.sessionCode,
      s.importFileCode ?? 'IMP-${s.importFileId}',
      s.sessionTitle ?? s.sessionNotes ?? '—',
      s.isDraft ? context.l10n.idocADraft : context.l10n.idocACertified,
      '${s.matchScore.toStringAsFixed(1)}%',
      s.discrepancyCount.toString(),
      s.createdAt,
      s.createdBy ?? '—',
    ]).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'Invoice BL Match Sessions',
      importFileNameOrCode: _activeFileId != null ? 'IMP-$_activeFileId' : 'All-Files',
    );
  }

  Future<void> _exportSessionsToPdf(List<InvoiceBLMatchSessionModel> sessions) async {
    final headers = [
      context.l10n.idocASessionCode,
      context.l10n.idocAImportFile,
      context.l10n.idocATitle,
      context.l10n.status,
      context.l10n.idocAMatchScore,
      context.l10n.idocADiscrepancies,
      context.l10n.idocACreatedAt,
    ];
    final rows = sessions.map((s) => [
      s.sessionCode,
      s.importFileCode ?? 'IMP-${s.importFileId}',
      s.sessionTitle ?? s.sessionNotes ?? '—',
      s.isDraft ? context.l10n.idocADraft : context.l10n.idocACertified,
      '${s.matchScore.toStringAsFixed(1)}%',
      s.discrepancyCount.toString(),
      s.createdAt,
    ]).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocAInvoiceAndBLMatchingSessions,
      importFileNameOrCode: _activeFileId != null ? 'IMP-$_activeFileId' : 'All-Files',
      headerContext: TableExportHeaderContext(
        title: context.l10n.idocACommercialInvoiceAndBillOfLading,
        subtitle: context.l10n.idocAFooterMatchingBrand,
      ),
    );
  }

  void _copyComparisonMatrixTsv(List<dynamic> matrix) {
    final isArabic = _isArabic(context);
    final headers = [
      context.l10n.idocACheckItem,
      context.l10n.idocAInvoiceValue,
      context.l10n.idocABLValue,
      context.l10n.idocAMatchStatus,
      context.l10n.idocADetailsAndAction,
    ];
    final rows = CodedItemText.localizeRows(matrix, context.l10n, forExport: true).map((item) {
      final checkItemName = isArabic
          ? (item['field_name_ar'] ?? item['field_name_en'] ?? '')
          : (item['field_name_en'] ?? item['field_name_ar'] ?? '');
      final invoiceVal = '${item['invoice_value'] ?? '—'}';
      final blVal = '${item['bl_value'] ?? '—'}';
      final status = item['match_status'] ?? 'MATCH';
      final statusTxt = status == 'MATCH'
          ? context.l10n.idocAMatched
          : (status == 'MISMATCH_MINOR' ? context.l10n.idocAMinorVariance : context.l10n.idocANotMatched);
      final detailsTxt = '${item['details'] ?? ''}';
      return [checkItemName, invoiceVal, blVal, statusTxt, detailsTxt];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: context.l10n.idocAMatchingMatrixCopiedToTheClipboard,
    );
  }

  Future<void> _exportComparisonMatrixExcel(List<dynamic> matrix) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final headers = [
      context.l10n.idocACheckItem,
      context.l10n.idocAInvoiceValue,
      context.l10n.idocABLValue,
      context.l10n.idocAMatchStatus,
      context.l10n.idocADetailsAndRequiredAction,
    ];
    final rows = CodedItemText.localizeRows(matrix, context.l10n, forExport: true).map((item) {
      final checkItemName = isArabic
          ? (item['field_name_ar'] ?? item['field_name_en'] ?? '')
          : (item['field_name_en'] ?? item['field_name_ar'] ?? '');
      final invoiceVal = '${item['invoice_value'] ?? '—'}';
      final blVal = '${item['bl_value'] ?? '—'}';
      final status = item['match_status'] ?? 'MATCH';
      final statusTxt = status == 'MATCH'
          ? context.l10n.idocAMatched
          : (status == 'MISMATCH_MINOR' ? context.l10n.idocAMinorVariance : context.l10n.idocANotMatched);
      final detailsTxt = '${item['details'] ?? ''}';
      return [checkItemName, invoiceVal, blVal, statusTxt, detailsTxt];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'Invoice BL Comparison Matrix',
      importFileNameOrCode: _activeFileId != null ? 'IMP-$_activeFileId' : 'All-Files',
    );
  }

  Future<void> _exportComparisonMatrixPdf(List<dynamic> matrix) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final headers = [
      context.l10n.idocACheckItem,
      context.l10n.idocAInvoiceValue,
      context.l10n.idocABLValue,
      context.l10n.idocAMatchStatus,
      context.l10n.idocADetailsAndRequiredAction,
    ];
    final rows = CodedItemText.localizeRows(matrix, context.l10n, forExport: true).map((item) {
      final checkItemName = isArabic
          ? (item['field_name_ar'] ?? item['field_name_en'] ?? '')
          : (item['field_name_en'] ?? item['field_name_ar'] ?? '');
      final invoiceVal = '${item['invoice_value'] ?? '—'}';
      final blVal = '${item['bl_value'] ?? '—'}';
      final status = item['match_status'] ?? 'MATCH';
      final statusTxt = status == 'MATCH'
          ? context.l10n.idocAMatched
          : (status == 'MISMATCH_MINOR' ? context.l10n.idocAMinorVariance : context.l10n.idocANotMatched);
      final detailsTxt = '${item['details'] ?? ''}';
      return [checkItemName, invoiceVal, blVal, statusTxt, detailsTxt];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocACommercialInvoiceAndBillOfLadingAlt,
      importFileNameOrCode: _activeFileId != null ? 'IMP-$_activeFileId' : 'All-Files',
      headerContext: TableExportHeaderContext(
        title: context.l10n.idocACommercialInvoiceAndBillOfLadingAlt,
        subtitle: context.l10n.idocAFooterInspectionBrand,
      ),
    );
  }
}
