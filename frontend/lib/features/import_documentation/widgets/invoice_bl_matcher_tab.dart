import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/helpers/file_picker_helper.dart';



import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/error_details_dialog.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/services/table_export_service.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/invoice_bl_match_session_model.dart';
import '../providers/docs_customs_approval_provider.dart';
import '../providers/import_documentation_provider.dart';
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

  Future<void> _saveSession({required bool isDraft}) async {
    if (_activeFileId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.invoiceBlMatcherSelectFileFirstWarning),
            backgroundColor: AppTheme.crimson,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!isDraft && _matchResult != null && _matchResult!['is_safe_for_certification'] == false) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.orange),
              SizedBox(width: 8),
              Text('تنبيه: عدم اكتمال شروط المطابقة'),
            ],
          ),
          content: const Text(
            'تحتوي نتائج الفحص على فروقات حَرِجة أو تحذيرات غير مطابقة. هل تود بالتأكيد الاعتماد النهائي وتحديث الموافقة الجمركية على الأوراق؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('مراجعة الفروقات'),
            ),
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
        _isSyncing = true;
      }
    });

    try {
      final payload = {
        'import_file_id': _activeFileId,
        'session_title': isDraft ? 'مسودة فحص مطابقة الفاتورة والبوليصة' : 'اعتماد نهائي لمطابقة الفاتورة والبوليصة',
        'is_draft': isDraft,
        'invoice_raw_text': _invoiceTextCtrl.text.isNotEmpty ? _invoiceTextCtrl.text : null,
        'bl_raw_text': _blTextCtrl.text.isNotEmpty ? _blTextCtrl.text : null,
        'packing_list_raw_text': _packingTextCtrl.text.isNotEmpty ? _packingTextCtrl.text : null,
        'invoice_file_name': _invoiceFileName,
        'bl_file_name': _blFileName,
        'packing_file_name': _packingFileName,
        'match_score': (_matchResult?['match_score_percentage'] as num?)?.toDouble() ?? 0.0,
        'is_safe_for_certification': _matchResult?['is_safe_for_certification'] ?? false,
        'has_critical_discrepancies': ((_matchResult?['critical_discrepancies_count'] as num?)?.toInt() ?? 0) > 0,
        'discrepancy_count': (((_matchResult?['critical_discrepancies_count'] as num?)?.toInt() ?? 0) +
                              ((_matchResult?['warning_discrepancies_count'] as num?)?.toInt() ?? 0)),
        'comparison_matrix': _matchResult?['comparison_matrix'],
        'invoice_extracted_data': _matchResult?['invoice_data'],
        'bl_extracted_data': _matchResult?['bl_data'],
        'packing_extracted_data': _matchResult?['packing_list_data'],
        'session_notes': isDraft ? 'حفظ مؤقت لمتابعة التدقيق لاحقاً' : 'تم الاعتماد النهائي وتحديث الموافقة الجمركية',
        'created_by': 'system',
      };

      final createdSession = await ref.read(invoiceBLMatchSessionsProvider.notifier).createSession(payload);
      ref.invalidate(importFilesProvider);
      ref.invalidate(docsCustomsApprovalProvider);

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
                        ? 'تم حفظ مسودة الجلسة بنجاح (${createdSession.sessionCode}) في سجل الجلسات'
                        : 'تم اعتماد الجلسة (${createdSession.sessionCode}) وتحديث الموافقة الجمركية على الأوراق والانتقال لمرحلة شهادة المنشأ بنجاح',
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
        showErrorDetailsDialog(
          context,
          title: isDraft ? 'فشل حفظ المسودة المؤقتة' : 'فشل الاعتماد النهائي للجلسة',
          error: e,
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
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                  color: AppTheme.cobalt.withOpacity(0.1),
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
                        color: isDark ? Colors.white : AppTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.invoiceBlMatcherSubtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (_activeSessionCode != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.cobalt.withOpacity(0.4)),
                        ),
                        child: Text(
                          'جلسة نشطة قيد الفحص: $_activeSessionCode',
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
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showPackingList = true;
                    });
                  },
                  icon: const Icon(Icons.post_add, size: 18, color: AppTheme.orange),
                  label: Text(
                    l.invoiceBlMatcherAddPackingListButton,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.orange),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.orange),
                    backgroundColor: AppTheme.orange.withOpacity(0.04),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
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
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? color.withOpacity(0.5) : color.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.04),
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
              OutlinedButton.icon(
                onPressed: () => _pickFile(docType),
                icon: const Icon(Icons.upload_file, size: 16),
                label: Text(fileName != null ? l.invoiceBlMatcherChangeFile : l.invoiceBlMatcherUploadFile),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
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
                color: color.withOpacity(0.08),
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
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
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
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _runCrossMatching,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.compare_arrows, size: 20),
          label: Text(
            l.invoiceBlMatcherExecuteMatchButton,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.cobalt,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            elevation: 2,
          ),
        ),
        OutlinedButton.icon(
          onPressed: _loadSampleData,
          icon: const Icon(Icons.auto_stories, size: 18, color: AppTheme.charcoal),
          label: Text(
            l.invoiceBlMatcherLoadSampleButton,
            style: const TextStyle(color: AppTheme.charcoal, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.grey),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        TextButton.icon(
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
          icon: const Icon(Icons.refresh, size: 18, color: Colors.grey),
          label: Text(l.invoiceBlMatcherResetButton, style: const TextStyle(color: Colors.grey)),
        ),
        OutlinedButton.icon(
          onPressed: (_activeFileId == null || _isSavingDraft || _isSyncing)
              ? null
              : () => _saveSession(isDraft: true),
          icon: _isSavingDraft
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(color: AppTheme.cobalt, strokeWidth: 2),
                )
              : const Icon(Icons.save_as_outlined, size: 16, color: AppTheme.cobalt),
          label: const Text(
            '💾 حفظ مؤقت للجلسة',
            style: TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.cobalt),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
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
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
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
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isSafe
                      ? l.invoiceBlMatcherStatusSafeDesc
                      : l.invoiceBlMatcherStatusCriticalDesc(criticalCount),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
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
        color: count > 0 ? col.withOpacity(0.15) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: count > 0 ? col : Colors.grey.shade300),
      ),
      child: Text(
        labelText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: count > 0 ? col : Colors.grey.shade600,
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
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 750;
                final titleWidget = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.table_chart_outlined, size: 18, color: isDark ? Colors.white70 : AppTheme.charcoal),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l.invoiceBlMatcherMatrixTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.white : AppTheme.charcoal,
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
                    OutlinedButton.icon(
                      key: const Key('copyComparisonMatrixTsvBtn'),
                      onPressed: matrix.isEmpty ? null : () => _copyComparisonMatrixTsv(matrix),
                      icon: const Icon(Icons.copy_all, size: 14, color: AppTheme.cobalt),
                      label: const Text('نسخ كـ TSV', style: TextStyle(fontSize: 11, color: AppTheme.cobalt)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('exportComparisonMatrixExcelBtn'),
                      onPressed: matrix.isEmpty ? null : () => _exportComparisonMatrixExcel(matrix),
                      icon: const Icon(Icons.table_view, size: 14, color: AppTheme.emerald),
                      label: const Text('تصدير إكسل', style: TextStyle(fontSize: 11, color: AppTheme.emerald)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('exportComparisonMatrixPdfBtn'),
                      onPressed: matrix.isEmpty ? null : () => _exportComparisonMatrixPdf(matrix),
                      icon: const Icon(Icons.picture_as_pdf, size: 14, color: AppTheme.crimson),
                      label: const Text('طباعة PDF', style: TextStyle(fontSize: 11, color: AppTheme.crimson)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
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
              headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : Colors.grey.shade50),
              horizontalMargin: 16,
              columnSpacing: 20,
              columns: [
                DataColumn(label: Text(l.invoiceBlMatcherColCheckItem, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.charcoal))),
                DataColumn(label: Text(isArabic ? 'بيانات النظام' : 'System Value', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.charcoal))),
                DataColumn(label: Text(l.invoiceBlMatcherColInvoiceValue, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.charcoal))),
                DataColumn(label: Text(isArabic ? 'كشف التعبئة' : 'Packing List', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.charcoal))),
                DataColumn(label: Text(l.invoiceBlMatcherColBlValue, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.charcoal))),
                DataColumn(label: Text(l.invoiceBlMatcherColMatchStatus, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.charcoal))),
                DataColumn(label: Text(l.invoiceBlMatcherColActionRequired, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.charcoal))),
                DataColumn(label: Text('إجراءات السطر', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.charcoal))),
              ],
              rows: matrix.map((item) {
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
                  statusCol = Colors.blueGrey;
                  statusTxt = isArabic ? 'تعذر القراءة' : 'Extraction Failed';
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
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : AppTheme.charcoal),
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
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.deepPurple),
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
                                color: statusCol.withOpacity(0.12),
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
                                        .replaceAll('INVOICE vs BL', 'فاتورة ≠ بوليصة')
                                        .replaceAll('SYSTEM vs INVOICE', 'سستم ≠ فاتورة')
                                        .replaceAll('SYSTEM vs BL', 'سستم ≠ بوليصة')
                                        .replaceAll('PACKING_LIST vs BL', 'تعبئة ≠ بوليصة')
                                        .replaceAll('INVOICE vs PACKING_LIST', 'فاتورة ≠ تعبئة')
                                        .replaceAll('SYSTEM vs PACKING_LIST', 'سستم ≠ تعبئة');
                                  }
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.08),
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
                          style: TextStyle(fontSize: 11, color: isMatch ? (isDark ? Colors.grey.shade300 : Colors.grey.shade800) : statusCol),
                        ),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                        tooltip: 'نسخ بيانات السطر كـ TSV',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: rowSummary));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم نسخ بيانات البند ($checkItemName) كـ TSV'),
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
            title: isArabic ? 'كشف التعبئة المستخرج' : 'Extracted Packing List',
            icon: Icons.inventory_2,
            color: Colors.deepPurple,
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
        return isArabic ? 'العملة' : 'Currency';
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
        return isArabic ? 'الحاويات' : 'Containers';
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
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? color.withOpacity(0.5) : color.withOpacity(0.3)),
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
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
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
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade400),
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
              ElevatedButton.icon(
                onPressed: () {
                  CopyHelper.copy(
                    context,
                    letter,
                    customMessage: l.invoiceBlMatcherLetterCopiedSuccess,
                  );
                },
                icon: const Icon(Icons.copy, size: 14),
                label: Text(l.invoiceBlMatcherCopyLetterButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.amber.shade700 : Colors.amber.shade200),
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
                      color: isDark ? Colors.white : AppTheme.charcoal,
                    ),
                  ),
                  Text(
                    _activeFileId != null
                        ? l.invoiceBlMatcherSyncFooterDesc
                        : l.invoiceBlMatcherSyncFooterNoFile,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
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
            OutlinedButton.icon(
              onPressed: _matchResult == null ? null : _showExportReportDialog,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: Text(l.invoiceBlMatcherExportReportButton, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white70 : AppTheme.charcoal,
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            // Save Draft Session Button (حفظ مؤقت)
            OutlinedButton.icon(
              onPressed: (_activeFileId == null || _isSavingDraft || _isSyncing)
                  ? null
                  : () => _saveSession(isDraft: true),
              icon: _isSavingDraft
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: AppTheme.cobalt, strokeWidth: 2),
                    )
                  : const Icon(Icons.save_as_outlined, size: 16),
              label: const Text(
                '💾 حفظ مؤقت للجلسة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.cobalt,
                side: const BorderSide(color: AppTheme.cobalt, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            // Certify & Final Save Button (اعتماد وحفظ نهائي وتحديث الموافقة الجمركية)
            ElevatedButton.icon(
              onPressed: (_activeFileId == null || _isSavingDraft || _isSyncing)
                  ? null
                  : () => _saveSession(isDraft: false),
              icon: _isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_rounded, size: 18),
              label: const Text(
                '✅ اعتماد وحفظ نهائي وتحديث الموافقة الجمركية',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                elevation: 2,
              ),
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
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
      final r = row as Map<String, dynamic>;
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
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: Text(l.invoiceBlMatcherCopyReportButton),
                      onPressed: () {
                        CopyHelper.copy(
                          context,
                          reportText,
                          customMessage: l.invoiceBlMatcherReportCopiedSuccess,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.invoiceBlMatcherCloseButton)),
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
        color: Colors.grey.shade200,
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
                      ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _activeViewMode == 0
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.compare_arrows, size: 18, color: _activeViewMode == 0 ? AppTheme.cobalt : Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.l10n.invoiceBlMatchTabInspect,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _activeViewMode == 0 ? AppTheme.cobalt : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade300 : Colors.grey.shade700),
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
                      ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _activeViewMode == 1
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_edu_rounded, size: 18, color: _activeViewMode == 1 ? AppTheme.cobalt : Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.l10n.invoiceBlMatchTabHistory,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _activeViewMode == 1 ? AppTheme.cobalt : Colors.grey.shade700,
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
                            color: _activeViewMode == 1 ? AppTheme.cobalt : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${sessions.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري تحميل سجل جلسات المطابقة...', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: AppTheme.crimson, size: 48),
              const SizedBox(height: 12),
              Text('حدث خطأ أثناء تحميل سجل الجلسات: $e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                onPressed: () => ref.read(invoiceBLMatchSessionsProvider.notifier).fetchSessions(importFileId: _activeFileId),
              ),
            ],
          ),
        ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.charcoal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _sessionKpiCard(
                      icon: Icons.all_inbox_rounded,
                      label: 'إجمالي الجلسات',
                      value: '$totalCount جلسة',
                      color: AppTheme.cobalt,
                    ),
                    const SizedBox(width: 14),
                    _sessionKpiCard(
                      icon: Icons.verified_rounded,
                      label: 'الجلسات المعتمدة',
                      value: '$certifiedCount جلسة',
                      color: AppTheme.emerald,
                    ),
                    const SizedBox(width: 14),
                    _sessionKpiCard(
                      icon: Icons.bookmark_added_rounded,
                      label: 'المسودات المؤقتة',
                      value: '$draftCount مسودة',
                      color: AppTheme.orange,
                    ),
                    const SizedBox(width: 14),
                    _sessionKpiCard(
                      icon: Icons.percent_rounded,
                      label: 'متوسط التطابق',
                      value: '${avgScore.toStringAsFixed(1)}%',
                      color: const Color(0xFF16A085),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cobalt,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('جلسة فحص جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {
                          _activeViewMode = 0;
                          _activeSessionId = null;
                          _activeSessionCode = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Search & Filter Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 650;
                  final searchField = TextField(
                    controller: _searchSessionsCtrl,
                    decoration: InputDecoration(
                      hintText: 'بحث بكود الجلسة، ملف الشحنة، أو الملاحظات...',
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
                    labelText: 'تصفية حسب ملف الشحنة',
                    hintText: 'جميع ملفات الشحن',
                    value: _filterImportFileId,
                    items: [
                      const SearchableDropdownItem<int?>(value: null, label: 'جميع ملفات الشحن'),
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
                              _buildStatusFilterChip('ALL', 'الكل ($totalCount)'),
                              _buildStatusFilterChip('CERTIFIED', 'معتمدة ($certifiedCount)'),
                              _buildStatusFilterChip('DRAFT', 'مسودة مؤقتة ($draftCount)'),
                            ],
                          ),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy_all, color: AppTheme.cobalt),
                                tooltip: 'نسخ الجدول (TSV)',
                                onPressed: filtered.isEmpty ? null : () => _copySessionsTable(filtered),
                              ),
                              IconButton(
                                icon: const Icon(Icons.table_view_outlined, color: AppTheme.emerald),
                                tooltip: 'تصدير إكسيل (Excel)',
                                onPressed: filtered.isEmpty ? null : () => _exportSessionsToExcel(filtered),
                              ),
                              IconButton(
                                icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson),
                                tooltip: 'طباعة تقرير PDF',
                                onPressed: filtered.isEmpty ? null : () => _exportSessionsToPdf(filtered),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded, color: AppTheme.charcoal),
                                tooltip: 'تحديث البيانات',
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
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'لا توجد جلسات مطابقة مسجلة مطابقة لمعايير البحث',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, foregroundColor: Colors.white),
                        icon: const Icon(Icons.add),
                        label: Text(context.l10n.invoiceBlMatchNewSessionBtn),
                        onPressed: () => setState(() => _activeViewMode = 0),
                      ),
                    ],
                  ),
                ),
              )
            else
              _buildSessionsTable(filtered),
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

  Widget _buildStatusFilterChip(String value, String label) {
    final isSelected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedStatusFilter = value),
      selectedColor: AppTheme.cobalt,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.charcoal,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildSessionsTable(List<InvoiceBLMatchSessionModel> sessions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : AppTheme.charcoal),
            headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            dataRowMinHeight: 52,
            dataRowMaxHeight: 64,
            horizontalMargin: 16,
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('كود الجلسة')),
              DataColumn(label: Text('ملف الشحنة')),
              DataColumn(label: Text('عنوان وملاحظات الجلسة')),
              DataColumn(label: Text('الحالة')),
              DataColumn(label: Text('نسبة التطابق')),
              DataColumn(label: Text('الفروقات')),
              DataColumn(label: Text('تاريخ الجلسة')),
              DataColumn(label: Text('الإجراءات')),
            ],
            rows: sessions.map((session) {
              final isDraft = session.isDraft;
              return DataRow(
                color: WidgetStateProperty.resolveWith((states) {
                  if (session.sessionId == _activeSessionId) {
                    return AppTheme.cobalt.withOpacity(0.08);
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
                          tooltip: 'نسخ الكود',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: session.sessionCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم نسخ كود الجلسة إلى الحافظة'), duration: Duration(seconds: 1)),
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
                            session.sessionTitle ?? 'جلسة فحص مطابقة',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (session.sessionNotes != null && session.sessionNotes!.isNotEmpty)
                            Text(
                              session.sessionNotes!,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDraft ? AppTheme.orange.withOpacity(0.12) : AppTheme.emerald.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDraft ? AppTheme.orange : AppTheme.emerald),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isDraft ? Icons.edit_document : Icons.check_circle, size: 13, color: isDraft ? AppTheme.orange : AppTheme.emerald),
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
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 50,
                          child: LinearProgressIndicator(
                            value: session.matchScore / 100.0,
                            backgroundColor: Colors.grey.shade200,
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
                        color: session.discrepancyCount > 0 ? AppTheme.crimson.withOpacity(0.1) : AppTheme.emerald.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        session.discrepancyCount > 0 ? '${session.discrepancyCount} فارق' : 'متطابق بالكامل',
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
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: Key('cloneSessionBtn_${session.sessionId}'),
                          icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                          tooltip: 'استنساخ الجلسة كمسودة جديدة',
                          onPressed: () => _cloneSession(session),
                        ),
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18, color: AppTheme.cobalt),
                          tooltip: 'عرض تفاصيل ومصفوفة الجلسة',
                          onPressed: () => _showSessionDetailsDialog(session),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_circle_outline, size: 18, color: AppTheme.emerald),
                          tooltip: 'استعادة وتحميل الجلسة لشاشة الفحص',
                          onPressed: () => _loadSessionIntoMatcher(session),
                        ),
                        if (isDraft)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.crimson),
                            tooltip: 'حذف المسودة',
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
    final invData = session.invoiceExtractedData ?? {};
    final blData = session.blExtractedData ?? {};
    final isDraft = session.isDraft;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                    'تفاصيل الجلسة: ${session.sessionCode}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ملف الشحنة: ${session.importFileCode ?? "IMP-${session.importFileId}"}  |  تاريخ الإنشاء: ${session.createdAt}',
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
          width: 900,
          height: 520,
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  labelColor: AppTheme.cobalt,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.cobalt,
                  tabs: [
                    Tab(icon: Icon(Icons.compare_arrows, size: 16), text: 'مصفوفة المطابقة والتحقق'),
                    Tab(icon: Icon(Icons.data_object, size: 16), text: 'البيانات المستخرجة (فاتورة / بوليصة)'),
                    Tab(icon: Icon(Icons.notes, size: 16), text: 'النصوص الأصلية والملاحظات'),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Comparison Matrix Table
                      matrix.isEmpty
                          ? const Center(child: Text('لا توجد مصفوفة مطابقة محفوظة لهذه الجلسة'))
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(AppTheme.charcoal),
                                      headingTextStyle: const TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      columns: const [
                                        DataColumn(label: Text('البند المعياري')),
                                        DataColumn(label: Text('بيانات النظام')),
                                        DataColumn(label: Text('بيانات الفاتورة')),
                                        DataColumn(label: Text('كشف التعبئة')),
                                        DataColumn(label: Text('بيانات البوليصة')),
                                        DataColumn(label: Text('حالة التطابق')),
                                        DataColumn(label: Text('التفاصيل ومصادر الاختلاف')),
                                      ],
                                      rows: matrix.map((item) {
                                        final row = item is Map<String, dynamic> ? item : {};
                                        final status = row['match_status']?.toString() ?? 'UNKNOWN';
                                        final isMatch = status == 'MATCH';
                                        final isExtFailed = status == 'EXTRACTION_FAILED';
                                        final isMinor = status == 'MISMATCH_MINOR';

                                        Color statusCol;
                                        String statusTxt;
                                        if (isMatch) {
                                          statusCol = AppTheme.emerald;
                                          statusTxt = 'متطابق';
                                        } else if (isExtFailed) {
                                          statusCol = Colors.blueGrey;
                                          statusTxt = 'تعذر القراءة';
                                        } else if (isMinor) {
                                          statusCol = AppTheme.orange;
                                          statusTxt = 'فارق طفيف';
                                        } else {
                                          statusCol = AppTheme.crimson;
                                          statusTxt = 'فارق جوهري';
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
                                                style: const TextStyle(fontSize: 11, color: Colors.deepPurple))),
                                            DataCell(Text(row['bl_value']?.toString() ?? '—',
                                                style: const TextStyle(fontSize: 11, color: AppTheme.emerald))),
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: statusCol.withOpacity(0.12),
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
                                                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                                if (disagreeingSources.isNotEmpty)
                                                  Text(
                                                    'اختلاف بين: ${disagreeingSources.join(", ")}',
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
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.receipt_long, size: 16, color: AppTheme.cobalt),
                                        SizedBox(width: 6),
                                        Text('مستخرجات الفاتورة التجارية',
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
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.directions_boat, size: 16, color: AppTheme.emerald),
                                        SizedBox(width: 6),
                                        Text('مستخرجات بوليصة الشحن',
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
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('ملاحظات الجلسة:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(session.sessionNotes!),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            const Text('نص الفاتورة المدخل:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: SelectableText(
                                session.invoiceRawText ?? '—',
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('نص بوليصة الشحن المدخل:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: SelectableText(
                                session.blRawText ?? '—',
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                              ),
                            ),
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
            tooltip: 'نسخ مصفوفة الجلسة (TSV)',
            onPressed: matrix.isEmpty ? null : () => _copyComparisonMatrixTsv(matrix),
          ),
          OutlinedButton.icon(
            key: const Key('dialogCloneSessionBtn'),
            onPressed: () {
              Navigator.pop(ctx);
              _cloneSession(session);
            },
            icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
            label: const Text('استنساخ كمسودة جديدة',
                style: TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold)),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _loadSessionIntoMatcher(session);
            },
            icon: const Icon(Icons.play_circle_outline, size: 16, color: AppTheme.emerald),
            label: const Text('استعادة وتحميل في شاشة الفحص',
                style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : AppTheme.charcoal,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _loadSessionIntoMatcher(InvoiceBLMatchSessionModel session) {
    setState(() {
      _activeFileId = session.importFileId;
      _invoiceTextCtrl.text = session.invoiceRawText ?? '';
      _blTextCtrl.text = session.blRawText ?? '';
      _packingTextCtrl.text = session.packingListRawText ?? '';
      _invoiceFileName = session.invoiceFileName;
      _blFileName = session.blFileName;
      _packingFileName = session.packingFileName;
      _showPackingList = session.packingListRawText != null || session.packingFileName != null;
      _activeSessionId = session.sessionId;
      _activeSessionCode = session.sessionCode;

      if (session.comparisonMatrix != null && session.comparisonMatrix!.isNotEmpty) {
        _matchResult = {
          'import_file_id': session.importFileId,
          'match_score_percentage': session.matchScore,
          'is_safe_for_certification': session.isSafeForCertification,
          'critical_discrepancies_count': session.hasCriticalDiscrepancies ? 1 : 0,
          'warning_discrepancies_count': session.discrepancyCount,
          'comparison_matrix': session.comparisonMatrix,
          'invoice_data': session.invoiceExtractedData,
          'bl_data': session.blExtractedData,
          'packing_list_data': session.packingExtractedData,
          'overall_status': session.isDraft ? 'DRAFT_SAVED' : 'CERTIFIED_SAVED',
        };
      }
      _activeViewMode = 0; // Switch to Matcher view
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم استرجاع وتحميل بيانات الجلسة ${session.sessionCode} إلى شاشة الفحص بنجاح'),
        backgroundColor: AppTheme.cobalt,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _cloneSession(InvoiceBLMatchSessionModel session) {
    setState(() {
      _activeFileId = session.importFileId;
      _invoiceTextCtrl.text = session.invoiceRawText ?? '';
      _blTextCtrl.text = session.blRawText ?? '';
      _packingTextCtrl.text = session.packingListRawText ?? '';
      _invoiceFileName = session.invoiceFileName;
      _blFileName = session.blFileName;
      _packingFileName = session.packingFileName;
      _showPackingList = session.packingListRawText != null || session.packingFileName != null;
      _activeSessionId = null; // Cleared to create a new editable draft
      _activeSessionCode = null;

      if (session.comparisonMatrix != null && session.comparisonMatrix!.isNotEmpty) {
        _matchResult = {
          'import_file_id': session.importFileId,
          'match_score_percentage': session.matchScore,
          'is_safe_for_certification': session.isSafeForCertification,
          'critical_discrepancies_count': session.hasCriticalDiscrepancies ? 1 : 0,
          'warning_discrepancies_count': session.discrepancyCount,
          'comparison_matrix': List<Map<String, dynamic>>.from(
            session.comparisonMatrix!.map((e) => Map<String, dynamic>.from(e)),
          ),
          'invoice_data': session.invoiceExtractedData != null
              ? Map<String, dynamic>.from(session.invoiceExtractedData!)
              : <String, dynamic>{},
          'bl_data': session.blExtractedData != null
              ? Map<String, dynamic>.from(session.blExtractedData!)
              : <String, dynamic>{},
          'packing_list_data': session.packingExtractedData != null
              ? Map<String, dynamic>.from(session.packingExtractedData!)
              : <String, dynamic>{},
          'overall_status': 'DRAFT_SAVED',
        };
      }
      _activeViewMode = 0; // Switch to Matcher view
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم استنساخ بيانات الجلسة (${session.sessionCode}) كمسودة جديدة في شاشة الفحص'),
        backgroundColor: AppTheme.cobalt,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteSession(InvoiceBLMatchSessionModel session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف المسودة'),
        content: Text('هل أنت متأكد من رغبتك في حذف مسودة الجلسة (${session.sessionCode})؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(invoiceBLMatchSessionsProvider.notifier).deleteSession(session.sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المسودة بنجاح'), backgroundColor: AppTheme.emerald),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: 'خطأ في حذف الجلسة', error: e);
      }
    }
  }

  void _copySessionsTable(List<InvoiceBLMatchSessionModel> sessions) {
    final headers = [
      'كود الجلسة',
      'ملف الاستيراد',
      'العنوان',
      'الحالة',
      'نسبة التطابق',
      'الفروقات',
      'تاريخ الإنشاء',
      'بواسطة',
    ];
    final rows = sessions.map((s) => [
      s.sessionCode,
      s.importFileCode ?? 'IMP-${s.importFileId}',
      s.sessionTitle ?? s.sessionNotes ?? '—',
      s.isDraft ? 'مسودة مؤقتة' : 'معتمدة ونهائية',
      '${s.matchScore.toStringAsFixed(1)}%',
      s.discrepancyCount.toString(),
      s.createdAt,
      s.createdBy,
    ]).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: 'تم نسخ جدول جلسات المطابقة كـ TSV إلى الحافظة بنجاح',
    );
  }

  Future<void> _exportSessionsToExcel(List<InvoiceBLMatchSessionModel> sessions) async {
    final headers = [
      'كود الجلسة',
      'ملف الاستيراد',
      'العنوان',
      'الحالة',
      'نسبة التطابق',
      'الفروقات',
      'تاريخ الإنشاء',
      'بواسطة',
    ];
    final rows = sessions.map((s) => [
      s.sessionCode,
      s.importFileCode ?? 'IMP-${s.importFileId}',
      s.sessionTitle ?? s.sessionNotes ?? '—',
      s.isDraft ? 'مسودة مؤقتة' : 'معتمدة ونهائية',
      '${s.matchScore.toStringAsFixed(1)}%',
      s.discrepancyCount.toString(),
      s.createdAt,
      s.createdBy,
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
      'كود الجلسة',
      'ملف الاستيراد',
      'العنوان',
      'الحالة',
      'نسبة التطابق',
      'الفروقات',
      'تاريخ الإنشاء',
    ];
    final rows = sessions.map((s) => [
      s.sessionCode,
      s.importFileCode ?? 'IMP-${s.importFileId}',
      s.sessionTitle ?? s.sessionNotes ?? '—',
      s.isDraft ? 'مسودة مؤقتة' : 'معتمدة ونهائية',
      '${s.matchScore.toStringAsFixed(1)}%',
      s.discrepancyCount.toString(),
      s.createdAt,
    ]).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'سجل جلسات مطابقة الفاتورة والبوليصة',
      importFileNameOrCode: _activeFileId != null ? 'IMP-$_activeFileId' : 'All-Files',
      headerContext: const TableExportHeaderContext(
        title: 'سجل جلسات مطابقة الفاتورة التجارية وبوليصة الشحن',
        subtitle: 'Sorour Logistics ERP — إدارة الوثائق والمطابقة المستندية الجمركية',
      ),
    );
  }

  void _copyComparisonMatrixTsv(List<dynamic> matrix) {
    final isArabic = _isArabic(context);
    final headers = [
      'بند الفحص / Check Item',
      'القيمة بالفاتورة / Invoice Value',
      'القيمة بالبوليصة / B/L Value',
      'حالة التطابق / Match Status',
      'التفاصيل والإجراء / Action & Details',
    ];
    final rows = matrix.map((item) {
      final checkItemName = isArabic
          ? (item['field_name_ar'] ?? item['field_name_en'] ?? '')
          : (item['field_name_en'] ?? item['field_name_ar'] ?? '');
      final invoiceVal = '${item['invoice_value'] ?? '—'}';
      final blVal = '${item['bl_value'] ?? '—'}';
      final status = item['match_status'] ?? 'MATCH';
      final statusTxt = status == 'MATCH'
          ? 'متطابق'
          : (status == 'MISMATCH_MINOR' ? 'فارق طفيف' : 'غير متطابق');
      final detailsTxt = '${item['details'] ?? ''}';
      return [checkItemName, invoiceVal, blVal, statusTxt, detailsTxt];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: 'تم نسخ مصفوفة المطابقة كـ TSV إلى الحافظة بنجاح',
    );
  }

  Future<void> _exportComparisonMatrixExcel(List<dynamic> matrix) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final headers = [
      'بند الفحص',
      'القيمة بالفاتورة',
      'القيمة بالبوليصة',
      'حالة التطابق',
      'التفاصيل والإجراء المطلوب',
    ];
    final rows = matrix.map((item) {
      final checkItemName = isArabic
          ? (item['field_name_ar'] ?? item['field_name_en'] ?? '')
          : (item['field_name_en'] ?? item['field_name_ar'] ?? '');
      final invoiceVal = '${item['invoice_value'] ?? '—'}';
      final blVal = '${item['bl_value'] ?? '—'}';
      final status = item['match_status'] ?? 'MATCH';
      final statusTxt = status == 'MATCH'
          ? 'متطابق'
          : (status == 'MISMATCH_MINOR' ? 'فارق طفيف' : 'غير متطابق');
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
      'بند الفحص',
      'القيمة بالفاتورة',
      'القيمة بالبوليصة',
      'حالة التطابق',
      'التفاصيل والإجراء المطلوب',
    ];
    final rows = matrix.map((item) {
      final checkItemName = isArabic
          ? (item['field_name_ar'] ?? item['field_name_en'] ?? '')
          : (item['field_name_en'] ?? item['field_name_ar'] ?? '');
      final invoiceVal = '${item['invoice_value'] ?? '—'}';
      final blVal = '${item['bl_value'] ?? '—'}';
      final status = item['match_status'] ?? 'MATCH';
      final statusTxt = status == 'MATCH'
          ? 'متطابق'
          : (status == 'MISMATCH_MINOR' ? 'فارق طفيف' : 'غير متطابق');
      final detailsTxt = '${item['details'] ?? ''}';
      return [checkItemName, invoiceVal, blVal, statusTxt, detailsTxt];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'مصفوفة مطابقة الفاتورة التجارية وبوليصة الشحن',
      importFileNameOrCode: _activeFileId != null ? 'IMP-$_activeFileId' : 'All-Files',
      headerContext: const TableExportHeaderContext(
        title: 'مصفوفة مطابقة الفاتورة التجارية وبوليصة الشحن',
        subtitle: 'Sorour Logistics ERP — نظام فحص ومطابقة الوثائق الجمركية',
      ),
    );
  }
}
