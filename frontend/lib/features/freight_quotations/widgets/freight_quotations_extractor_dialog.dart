import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/extraction_progress_dialog.dart';
import '../../../core/widgets/universal_entity_extractor_dialog.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';

/// Data class representing an extracted freight quotation option.
class ExtractedQuotationOption {
  final int optionId;
  String carrierName;
  String? forwarderName;
  String? vesselName;
  String? voyageNumber;
  String containerType;
  double oceanFreight;
  double? localCharges;
  double? exwCharges;
  double totalEstimatedCost;
  String currency;
  String? incoterm;
  String? originPort;
  String? destinationPort;
  int? transitDays;
  bool isDirect;
  int? freeTimeDays;
  String? etdDate;
  String? etaDate;
  String? notes;
  bool isSelected;

  ExtractedQuotationOption({
    required this.optionId,
    required this.carrierName,
    this.forwarderName,
    this.vesselName,
    this.voyageNumber,
    required this.containerType,
    required this.oceanFreight,
    this.localCharges,
    this.exwCharges,
    required this.totalEstimatedCost,
    this.currency = 'USD',
    this.incoterm,
    this.originPort,
    this.destinationPort,
    this.transitDays,
    this.isDirect = true,
    this.freeTimeDays,
    this.etdDate,
    this.etaDate,
    this.notes,
    this.isSelected = true,
  });

  factory ExtractedQuotationOption.fromMap(Map<String, dynamic> map, int id) {
    final ocean = (map['ocean_freight'] as num?)?.toDouble() ??
        (map['freight_rate'] as num?)?.toDouble() ??
        0.0;
    final local = (map['local_charges'] as num?)?.toDouble();
    final exw = (map['exw_charges'] as num?)?.toDouble();
    final total = (map['total_estimated_cost'] as num?)?.toDouble() ?? (ocean + (local ?? 0.0));

    return ExtractedQuotationOption(
      optionId: id,
      carrierName: (map['carrier_name'] ?? 'Shipping Line').toString(),
      forwarderName: map['forwarder_name']?.toString(),
      vesselName: map['vessel_name']?.toString(),
      voyageNumber: map['voyage_number']?.toString(),
      containerType: (map['container_type'] ?? '40HQ').toString(),
      oceanFreight: ocean,
      localCharges: local,
      exwCharges: exw,
      totalEstimatedCost: total,
      currency: (map['currency'] ?? 'USD').toString(),
      incoterm: map['incoterm']?.toString(),
      originPort: map['origin_port']?.toString(),
      destinationPort: map['destination_port']?.toString(),
      transitDays: map['transit_days'] as int?,
      isDirect: map['is_direct'] as bool? ?? true,
      freeTimeDays: (map['free_time_days'] ?? map['free_days_demurrage']) as int?,
      etdDate: map['etd_date']?.toString(),
      etaDate: map['eta_date']?.toString(),
      notes: map['notes']?.toString(),
      isSelected: true,
    );
  }
}

/// Advanced Freight Quotations Extractor Dialog supporting Text & OCR Scans,
/// Party Verification (Forwarder & Carrier in DB), and Manual Custom Fields.
class FreightQuotationsExtractorDialog extends ConsumerStatefulWidget {
  final void Function(List<ExtractedQuotationOption> selectedOptions) onAddQuotations;

  const FreightQuotationsExtractorDialog({
    super.key,
    required this.onAddQuotations,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(List<ExtractedQuotationOption> selectedOptions) onAddQuotations,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FreightQuotationsExtractorDialog(
        onAddQuotations: onAddQuotations,
      ),
    );
  }

  @override
  ConsumerState<FreightQuotationsExtractorDialog> createState() => _FreightQuotationsExtractorDialogState();
}

class _FreightQuotationsExtractorDialogState extends ConsumerState<FreightQuotationsExtractorDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();

  bool _isExtracting = false;
  String? _error;

  // Selected file for OCR upload
  PlatformFile? _pickedFile;

  // Extracted Results
  List<ExtractedQuotationOption> _options = [];
  Map<String, dynamic>? _primaryMetadata;
  Map<String, String> _customFields = {};
  double _confidenceScore = 1.0;

  static const String _sampleQuoteText = '''
vertexexpress
POL ：NINGBO
POD：DEKHEILA
OF：USD6760/20GP
FREE TIME EXTEND : USD200/ctnr
OF：USD7735/40HQ
FREE TIME EXTEND : USD200/ctnr)
ETD：30-Aug
CARRIER：WHL
TT : 35 DAYS direct
FREE TIME：14 days
Other (21days+USD200/ctnr)
''';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _loadSampleText() {
    setState(() {
      _textController.text = _sampleQuoteText.trim();
      _error = null;
    });
  }

  Future<void> _extractFromText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'يرجى إدخال أو لصق نص عرض السعر أولاً');
      return;
    }

    setState(() {
      _isExtracting = true;
      _error = null;
      _options = [];
      _primaryMetadata = null;
      _customFields = {};
    });

    final progressCtrl = ExtractionProgressController();
    progressCtrl.update(
      percent: 0.20,
      status: 'جاري فحص وتحليل نصوص عروض الشحن والنولون...',
      stepLabel: 'المرحلة 1 من 4: تحليل النص الذكي',
      currentStep: 1,
    );

    ExtractionProgressDialog.show(
      context: context,
      title: 'استخراج وتدقيق عروض أسعار الشحن من النص',
      fileName: 'النص المنسوخ (${text.length} حرف)',
      controller: progressCtrl,
    );

    progressCtrl.startAutoAdvance(targetPercent: 0.90, duration: const Duration(seconds: 2));

    try {
      final dio = ref.read(uploadDioProvider);
      final response = await dio.post(
        '${ApiConstants.baseUrl}/smart-upload/parse-text/freight-quotation',
        data: FormData.fromMap({
          'raw_text': text,
          'save_session': false,
        }),
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      progressCtrl.complete();
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      _processExtractedResponse(response.data);
    } on DioException catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _error = 'خطأ في الاتصال بالخادم: ${e.message}');
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _error = 'حدث خطأ أثناء الاستخراج: $e');
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'xlsx', 'xls', 'docx', 'doc', 'txt'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedFile = result.files.first;
        _error = null;
      });
    }
  }

  Future<void> _extractFromFileOcr() async {
    if (_pickedFile == null || _pickedFile!.bytes == null) {
      setState(() => _error = 'يرجى اختيار ملف أو صورة عرض السعر أولاً');
      return;
    }

    final file = _pickedFile!;
    final fileSizeFormatted = file.size > 1024 * 1024
        ? '${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB'
        : '${(file.size / 1024).toStringAsFixed(1)} KB';

    setState(() {
      _isExtracting = true;
      _error = null;
      _options = [];
      _primaryMetadata = null;
      _customFields = {};
    });

    final progressCtrl = ExtractionProgressController();
    progressCtrl.update(
      percent: 0.15,
      status: 'جاري رفع الملف وتهيئة الماسح الضوئي...',
      stepLabel: 'المرحلة 1 من 4: رفع الملف',
      currentStep: 1,
    );

    ExtractionProgressDialog.show(
      context: context,
      title: 'استخراج عروض أسعار الشحن بالماسح الضوئي',
      fileName: file.name,
      fileSize: fileSizeFormatted,
      controller: progressCtrl,
    );

    try {
      final dio = ref.read(uploadDioProvider);
      final multipartFile = MultipartFile.fromBytes(file.bytes!, filename: file.name);
      final formData = FormData.fromMap({
        'file': multipartFile,
        'module_name': 'freight-quotation',
        'save_session': false,
      });

      final response = await dio.post(
        '${ApiConstants.baseUrl}/smart-upload/upload',
        data: formData,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final uploadRatio = sent / total;
            final p = 0.15 + (uploadRatio * 0.35);
            progressCtrl.update(
              percent: p,
              status: 'جاري رفع الملف (${(uploadRatio * 100).round()}%)...',
              stepLabel: 'المرحلة 2 من 4: رفع الملف',
              currentStep: 2,
            );
            if (uploadRatio >= 0.99) {
              progressCtrl.startAutoAdvance(targetPercent: 0.92, duration: const Duration(seconds: 5));
            }
          }
        },
      );

      progressCtrl.complete();
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      _processExtractedResponse(response.data);
    } on DioException catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _error = 'خطأ في معالجة الملف بالماسح الضوئي: ${e.message}');
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _error = 'حدث خطأ أثناء معالجة المستند: $e');
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  void _processExtractedResponse(dynamic data) {
    if (data == null) return;
    final extracted = (data['extracted_fields'] as Map<String, dynamic>?) ?? {};
    final rawRateOptions = (extracted['rate_options'] as List<dynamic>?) ?? [];
    final score = (data['confidence_score'] as num?)?.toDouble() ?? 1.0;

    final List<ExtractedQuotationOption> parsedList = [];

    if (rawRateOptions.isNotEmpty) {
      for (int i = 0; i < rawRateOptions.length; i++) {
        final optMap = rawRateOptions[i] as Map<String, dynamic>;
        parsedList.add(ExtractedQuotationOption.fromMap(optMap, i + 1));
      }
    } else if (extracted['freight_rate'] != null || extracted['ocean_freight'] != null) {
      parsedList.add(ExtractedQuotationOption.fromMap(extracted, 1));
    }

    final Map<String, String> cFields = {};
    final additionalExpenses = (extracted['additional_expenses'] as List<dynamic>?) ?? [];
    for (final item in additionalExpenses) {
      if (item is Map<String, dynamic>) {
        final lbl = (item['label'] ?? item['raw_label'] ?? 'مصروف إضافي').toString();
        final val = (item['formatted_value'] ?? 'USD ${item['amount']}').toString();
        cFields[lbl] = val;
      }
    }

    if (extracted['cancel_fee'] != null) {
      final isArabic = Directionality.of(context) == TextDirection.rtl;
      final cancelLabel = isArabic ? 'رسوم الإلغاء' : 'Cancellation Fee';
      cFields[cancelLabel] = 'USD ${extracted['cancel_fee']}';
    }

    setState(() {
      _confidenceScore = score;
      _primaryMetadata = extracted;
      _options = parsedList;
      _customFields = cFields;
      if (parsedList.isEmpty) {
        _error = 'لم يتم العثور على أية عروض أسعار صالحة في النص أو المستند المدخل. يرجى التحقق من الصيغة.';
      }
    });
  }


  void _addSelectedAndClose() {
    final selected = _options.where((o) => o.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          'يرجى تحديد عرض سعر واحد على الأقل للإضافة.',
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    // Attach custom fields / additional expenses to selected options notes if not already there
    if (_customFields.isNotEmpty) {
      final customSummary = _customFields.entries.map((e) => '${e.key}: ${e.value}').join(' | ');
      for (final opt in selected) {
        if (opt.notes == null || opt.notes!.isEmpty) {
          opt.notes = customSummary;
        } else if (!opt.notes!.contains(customSummary)) {
          opt.notes = '${opt.notes!} | $customSummary';
        }
      }
    }

    widget.onAddQuotations(selected);
    Navigator.of(context).pop();
  }

  // ─── Manual Custom Field Modal ─────────────────────────────────────────────

  void _showAddCustomFieldModal() {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    String selectedPreset = 'free_time_extend';
    final keyCtrl = TextEditingController(text: isArabic ? 'تمديد فترة السماح' : 'Free Time Extension');
    final valCtrl = TextEditingController();

    final presets = isArabic
        ? {
            'free_time_extend': '⏳ تمديد فترة السماح (بالدولار لكل حاوية)',
            'thc_charge': '🏗️ رسوم المناولة وتداول الحاويات',
            'doc_fee': '📄 رسوم بوليصة ومستندات',
            'isps_fee': '🛡️ رسوم أمن الميناء',
            'seal_fee': '🔒 رسوم الرصاصة الجمركية',
            'vgm_fee': '⚖️ رسوم وزن الحاوية',
            'chassis_fee': '🚛 رسوم الشاسيه',
            'forwarder_name': '🏢 وكيل الشحن أو الناقل',
            'carrier_name': '🚢 الخط الملاحي',
            'origin_port': '⚓ ميناء الشحن أو القيام',
            'destination_port': '⚓ ميناء الوصول أو التفريغ',
            'vessel_name': '🚢 اسم الباخرة',
            'voyage_number': '🔢 رقم الرحلة',
            'etd_date': '📅 تاريخ الإبحار',
            'eta_date': '📅 تاريخ الوصول',
            'transit_days': '⏱ مدة الإبحار (أيام)',
            'free_time_days': '⏳ فترة السماح (أيام)',
            'rate_20gp': '💵 نولون الحاوية 20',
            'rate_40hq': '💵 نولون الحاوية 40',
            'local_charges': '💰 مصاريف ورسوم محلية بالدولار',
            'exw_charges': '🏭 رسوم المصنع والنقل الداخلي بالدولار',
            'notes': '📝 ملاحظات وشروط إضافية',
            'custom': '➕ بيان أو مصروف مخصص آخر',
          }
        : {
            'free_time_extend': '⏳ Free Time Extension (USD/cntr)',
            'thc_charge': '🏗️ Terminal Handling Charges (THC)',
            'doc_fee': '📄 Documentation Fee',
            'isps_fee': '🛡️ Port Security Fee (ISPS)',
            'seal_fee': '🔒 Container Seal Fee',
            'vgm_fee': '⚖️ Verified Gross Mass Fee (VGM)',
            'chassis_fee': '🚛 Chassis Fee',
            'forwarder_name': '🏢 Freight Forwarder',
            'carrier_name': '🚢 Shipping Line / Carrier',
            'origin_port': '⚓ Port of Loading (POL)',
            'destination_port': '⚓ Port of Discharge (POD)',
            'vessel_name': '🚢 Vessel Name',
            'voyage_number': '🔢 Voyage Number',
            'etd_date': '📅 Departure Date (ETD - YYYY-MM-DD)',
            'eta_date': '📅 Arrival Date (ETA - YYYY-MM-DD)',
            'transit_days': '⏱ Transit Time (Days)',
            'free_time_days': '⏳ Free Time (Days)',
            'rate_20gp': '💵 Rate USD / 20GP',
            'rate_40hq': '💵 Rate USD / 40HQ',
            'local_charges': '💰 Local Charges (USD)',
            'exw_charges': '🏭 EXW / Inland Charges (USD)',
            'notes': '📝 Special Notes & Terms',
            'custom': '➕ Other Custom Expense / Field',
          };

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.add_box_rounded, color: AppTheme.emerald),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'إضافة بيان أو مصروف إضافي يدوياً' : 'Add Custom Field / Expense',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic
                      ? 'اختر نوع المصروف أو البيان أو أدخل بياناً مخصصاً لعروض الأسعار:'
                      : 'Select expense/field type or enter custom details:',
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedPreset,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'نوع البيان أو المصروف المطلوب إضافته' : 'Expense / Field Type',
                    isDense: true,
                  ),
                  items: presets.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12.5))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setModalState(() {
                        selectedPreset = v;
                        if (v != 'custom') {
                          keyCtrl.text = presets[v]!.replaceAll(RegExp(r'^[^\w\s\u0600-\u06FF]+'), '').trim();
                        } else {
                          keyCtrl.clear();
                        }
                      });
                    }
                  },
                ),
                if (selectedPreset == 'custom') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: keyCtrl,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'اسم المصروف أو البيان الجديد *' : 'New Expense / Field Name *',
                      hintText: isArabic ? 'مثلاً: غرامة إضافية أو تأخير' : 'e.g. Demurrage Tier 2 or Surcharge',
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: valCtrl,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'القيمة أو التفاصيل *' : 'Value / Details *',
                    hintText: isArabic ? 'مثلاً: 200 دولار لكل حاوية أو 21 يوماً' : 'e.g. USD 200/cntr or 21 days',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
              icon: const Icon(Icons.check, size: 16),
              label: Text(isArabic ? 'إضافة للبيانات' : 'Add to Data'),
              onPressed: () {
                final k = keyCtrl.text.trim();
                final v = valCtrl.text.trim();
                if (k.isNotEmpty && v.isNotEmpty) {
                  setState(() {
                    _customFields[k] = v;
                  });
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCustomFieldModal(String key, String currentValue) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final valCtrl = TextEditingController(text: currentValue);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppTheme.cobalt),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isArabic ? 'تعديل: $key' : 'Edit: $key',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: valCtrl,
            decoration: InputDecoration(
              labelText: isArabic ? 'القيمة المعدلة' : 'Updated Value',
              isDense: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, foregroundColor: Colors.white),
            icon: const Icon(Icons.save, size: 16),
            label: Text(isArabic ? 'حفظ التعديل' : 'Save Changes'),
            onPressed: () {
              final v = valCtrl.text.trim();
              if (v.isNotEmpty) {
                setState(() => _customFields[key] = v);
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final selectedCount = _options.where((o) => o.isSelected).length;
    final hasResults = _options.isNotEmpty;

    // Watch partners and ports for live database verification
    final partnersAsync = ref.watch(allPartnersProvider);
    final portsAsync = ref.watch(transportLocationsProvider);

    final partners = partnersAsync.value ?? [];
    final portsList = portsAsync.value ?? [];

    final int confidencePercent = (_confidenceScore * 100).round();
    final bool hasUnmappedWarning = _primaryMetadata?['unmapped_expenses_warning'] != null || _customFields.isNotEmpty;

    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: Container(
          width: 880,
          constraints: const BoxConstraints(maxHeight: 840),
          child: Column(
            children: [
              // ─── Header Matching Smart Invoice Review UI ─────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic
                                ? 'نتائج الاستخراج — استخراج كامل'
                                : 'Extraction Results — Full Extraction',
                            style: const TextStyle(
                              color: AppTheme.emerald,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isArabic
                                ? 'عروض أسعار الشحن والنولون · معدل الثقة: $confidencePercent%'
                                : 'Freight Quotations · Confidence: $confidencePercent%',
                            style: TextStyle(fontSize: 12, color: AppTheme.charcoal.withValues(alpha: 0.65)),
                          ),
                        ],
                      ),
                    ),
                    // Confidence Progress Indicator Badge
                    SizedBox(
                      width: 90,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$confidencePercent%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 13)),
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _confidenceScore,
                              color: AppTheme.emerald,
                              backgroundColor: AppTheme.emerald.withValues(alpha: 0.2),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Tab Bar
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.cobalt,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.cobalt,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.text_snippet_outlined, size: 18),
                    text: isArabic ? '📝 لصق نص أو بريد إلكتروني' : '📝 Paste Text / Email',
                  ),
                  Tab(
                    icon: const Icon(Icons.document_scanner_outlined, size: 18),
                    text: isArabic ? '📁 رفع ملف أو مستند أو صورة' : '📁 Upload File / Document (OCR)',
                  ),
                ],
              ),

              // Body Area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tab Content (Input)
                      SizedBox(
                        height: 220,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTextInputTab(),
                            _buildFileOcrTab(),
                          ],
                        ),
                      ),

                      // Error Box
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.crimson.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppTheme.crimson, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Results Section
                      if (hasResults) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 10),

                        // ── Top Header with Add Manual Field Button (Like Invoices) ────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isArabic
                                  ? 'الحقول المستخرجة (${_calculateTotalFieldsCount()})'
                                  : 'Extracted Fields (${_calculateTotalFieldsCount()})',
                              style: const TextStyle(
                                color: AppTheme.charcoal,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.emerald,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: Text(
                                isArabic ? '➕ إضافة بيان يدوي' : '➕ Add Manual Field',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onPressed: _showAddCustomFieldModal,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── Entity Verification Panel (Like Invoices) ────────────
                        _buildPartiesVerificationPanel(partners, portsList),
                        const SizedBox(height: 12),

                        // ── ⚠️ Unmapped / Special Expenses Warning Alert ─────────
                        if (hasUnmappedWarning) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.shade400, width: 1.2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _primaryMetadata?['unmapped_expenses_warning']?.toString() ??
                                            (isArabic
                                                ? '⚠️ تنبيه: تم اكتشاف مصروفات إضافية في العرض غير مكودة قياسياً في النولون — يرجى مراجعتها وتوجيهها لتضمينها في دراسة الشحن لعدم فقدان أي تكلفة.'
                                                : '⚠️ Warning: Additional unmapped expenses detected in quotation — please review to include in freight cost analysis.'),
                                        style: TextStyle(
                                          color: Colors.amber.shade900,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isArabic
                                      ? '💡 تم استخراج هذه البنود وتثبيتها أدناه (★) مع إمكانية تعديلها أو حذفها، وسيتم تضمينها تلقائياً في ملاحظات وتكاليف الشحنة.'
                                      : '💡 These items have been extracted below (★) with edit/delete support, and will be included in shipment notes and costs.',
                                  style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900.withValues(alpha: 0.85)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // ── Standard & Custom Extracted Fields List (Like Invoices) ────
                        _buildExtractedFieldsList(),
                        const SizedBox(height: 12),

                        // ── Green Options Container & Cards (Exact User Design) ──
                        _buildExtractedOptionsGreenContainer(),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const Spacer(),
                    if (hasResults)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cobalt,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: selectedCount > 0 ? _addSelectedAndClose : null,
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: Text(
                          isArabic
                              ? '➕ تعبئة وإضافة العروض المحددة ($selectedCount)'
                              : '➕ Add Selected Quotes ($selectedCount)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Verification Panel ────────────────────────────────────────────────────

  Widget _buildPartiesVerificationPanel(List partners, List portsList) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final rawForwarder = _primaryMetadata?['forwarder_name']?.toString() ??
        _options.firstOrNull?.forwarderName ??
        '';
    final rawCarrier = _primaryMetadata?['carrier_name']?.toString() ??
        _options.firstOrNull?.carrierName ??
        '';
    final rawPol = _primaryMetadata?['origin_port']?.toString() ??
        _options.firstOrNull?.originPort ??
        '';
    final rawPod = _primaryMetadata?['destination_port']?.toString() ??
        _options.firstOrNull?.destinationPort ??
        '';

    // Verify Forwarder in partners
    final matchedForwarder = rawForwarder.isNotEmpty
        ? partners.where((p) {
            final pName = (p.partnerName as String).toLowerCase();
            final rf = rawForwarder.toLowerCase();
            return pName.contains(rf) || rf.contains(pName);
          }).firstOrNull
        : null;

    // Verify Carrier in partners
    final matchedCarrier = rawCarrier.isNotEmpty
        ? partners.where((p) {
            final pName = (p.partnerName as String).toLowerCase();
            final rc = rawCarrier.toLowerCase();
            final scac = (p.scacCode ?? '').toString().toLowerCase();
            return pName.contains(rc) || rc.contains(pName) || (scac.isNotEmpty && rc.contains(scac));
          }).firstOrNull
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.charcoal.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.charcoal.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, size: 16, color: AppTheme.charcoal),
              const SizedBox(width: 6),
              Text(
                isArabic
                    ? 'التحقق من أطراف الشحن والموانئ في قاعدة البيانات'
                    : 'Verify Shipping Parties & Ports in Database',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Forwarder Verification Row
          if (rawForwarder.isNotEmpty) ...[
            _buildPartyRow(
              icon: Icons.business_rounded,
              title: isArabic ? 'وكيل الشحن أو الناقل' : 'Freight Forwarder / Carrier',
              name: rawForwarder,
              isVerified: matchedForwarder != null,
              code: matchedForwarder?.partnerCode ?? (matchedForwarder != null ? 'PRV-${matchedForwarder.providerId}' : null),
              onRegister: () => UniversalEntityExtractorDialog.show(
                context,
                initialTarget: EntityTarget.partner,
                onSaved: () => ref.invalidate(allPartnersProvider),
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Shipping Line Verification Row
          if (rawCarrier.isNotEmpty) ...[
            _buildPartyRow(
              icon: Icons.directions_boat_rounded,
              title: isArabic ? 'الخط الملاحي' : 'Shipping Line',
              name: rawCarrier,
              isVerified: matchedCarrier != null,
              code: matchedCarrier?.partnerCode ?? (matchedCarrier != null ? 'PRV-${matchedCarrier.providerId}' : null),
              onRegister: () => UniversalEntityExtractorDialog.show(
                context,
                initialTarget: EntityTarget.partner,
                onSaved: () => ref.invalidate(allPartnersProvider),
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Ports Row
          Row(
            children: [
              if (rawPol.isNotEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flight_takeoff, size: 14, color: AppTheme.cobalt),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isArabic ? 'ميناء الشحن: $rawPol' : 'POL: $rawPol',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (rawPol.isNotEmpty && rawPod.isNotEmpty) const SizedBox(width: 8),
              if (rawPod.isNotEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flight_land, size: 14, color: AppTheme.emerald),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isArabic ? 'ميناء الوصول: $rawPod' : 'POD: $rawPod',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPartyRow({
    required IconData icon,
    required String title,
    required String name,
    required bool isVerified,
    String? code,
    required VoidCallback onRegister,
  }) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isVerified ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isVerified ? const Color(0xFF86EFAC) : const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isVerified ? AppTheme.emerald : AppTheme.crimson),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (isVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 12, color: AppTheme.emerald),
                  const SizedBox(width: 4),
                  Text(
                    code != null
                        ? (isArabic ? 'مسجل ($code)' : 'Verified ($code)')
                        : (isArabic ? 'مسجل في النظام' : 'Verified in System'),
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.crimson.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cancel_rounded, size: 12, color: AppTheme.crimson),
                  const SizedBox(width: 4),
                  Text(
                    isArabic ? 'غير مسجل' : 'Unconfirmed',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.crimson),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cobalt,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.add, size: 14),
              label: Text(
                isArabic ? 'سجّل +' : 'Register +',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: onRegister,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextInputTab() {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isArabic
                    ? 'الصق نص الإيميل أو عرض السعر الوارد من شركة الشحن:'
                    : 'Paste email text or quotation received from shipping line:',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _loadSampleText,
              icon: const Icon(Icons.content_paste_go, size: 14, color: AppTheme.cobalt),
              label: Text(
                isArabic ? '📋 تحميل نص تجريبي' : '📋 Load Sample Text',
                style: const TextStyle(fontSize: 11, color: AppTheme.cobalt),
              ),
            ),
            if (_textController.text.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() {
                  _textController.clear();
                  _options = [];
                  _primaryMetadata = null;
                  _error = null;
                }),
                icon: const Icon(Icons.clear_all, size: 14, color: Colors.grey),
                label: Text(
                  isArabic ? 'مسح' : 'Clear',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: TextField(
            controller: _textController,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: isArabic
                  ? 'الصق نص عرض السعر أو البريد هنا...\nمثال:\nمسار الرحلة: شنغهاي إلى الدخيلة\nالنولون البحري: 6700 دولار لكل حاوية 40 قدم\nمدة الإبحار: 29 يوماً | فترة السماح: 21 يوماً\nالمصاريف المحلية: 880 دولار لكل حاوية'
                  : 'Paste quotation text or email here...\nExample:\nRoute: Shanghai - El Dekheila\nOcean Freight: USD 6700 per 40HQ container\nTransit: 29 days direct | Free time: 21 days\nLocal charges: USD 880 per container',
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.cobalt,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isExtracting ? null : _extractFromText,
          icon: _isExtracting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.search, color: Colors.white),
          label: Text(
            _isExtracting
                ? (isArabic ? 'جاري التحليل والاستخراج...' : 'Analyzing & extracting...')
                : (isArabic ? '🔍 استخراج عروض الأسعار من النص' : '🔍 Extract Quotations from Text'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildFileOcrTab() {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _pickedFile != null ? AppTheme.cobalt : Colors.grey.shade300, width: 1.5),
              ),
              child: Center(
                child: _pickedFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 42, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            isArabic
                                ? 'اضغط هنا لاختيار ملف عرض السعر أو اسحب وأفلت الملف'
                                : 'Click to select quotation file or drag & drop',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isArabic
                                ? 'يدعم ملفات المستندات والصور والجداول الإلكترونية'
                                : 'Supports PDF, images (PNG, JPG, WEBP), Word documents, and Excel',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_getFileIcon(_pickedFile!.name), size: 36, color: AppTheme.cobalt),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _pickedFile!.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          OutlinedButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.refresh, size: 14),
                            label: Text(
                              isArabic ? 'تغيير الملف' : 'Change File',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.cobalt,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: (_isExtracting || _pickedFile == null) ? null : _extractFromFileOcr,
          icon: _isExtracting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.document_scanner, color: Colors.white),
          label: Text(
            _isExtracting
                ? (isArabic ? 'جاري الفحص بالماسح الضوئي...' : 'Scanning document (OCR)...')
                : (isArabic ? '🚀 قراءة واستخراج بالماسح الضوئي' : '🚀 Scan & Extract Document (OCR)'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  IconData _getFileIcon(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
      return Icons.image;
    }
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) return Icons.table_chart;
    return Icons.insert_drive_file;
  }

  Widget _buildExtractedOptionsGreenContainer() {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final pol = _primaryMetadata?['origin_port']?.toString() ?? _options.firstOrNull?.originPort;
    final pod = _primaryMetadata?['destination_port']?.toString() ?? _options.firstOrNull?.destinationPort;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Header Row ────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic
                      ? 'تم استخراج ${_options.length} من عروض الأسعار بنجاح! راجع العروض أدناه ثم أضفها لدراسة المفاضلة:'
                      : 'Successfully extracted ${_options.length} quotation(s)! Review below and add to benchmark study:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_all_rounded, color: AppTheme.cobalt, size: 20),
                tooltip: isArabic ? 'نسخ كافة العروض بتنسيق جدول بيانات' : 'Copy All Quotes (TSV / Excel)',
                onPressed: () => _copyAllQuotes(context, isArabic),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 1,
                ),
                icon: const Icon(Icons.add_task, size: 15, color: Colors.white),
                label: Text(
                  isArabic
                      ? 'إضافة كافة العروض (${_options.length}) 🚀 +'
                      : 'Add All Quotes (${_options.length}) 🚀 +',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                ),
                onPressed: () {
                  for (final opt in _options) {
                    opt.isSelected = true;
                  }
                  _addSelectedAndClose();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Ports Chips Row ───────────────────────────────────────────────
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              if (pol != null && pol.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black87, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flight_takeoff, size: 15, color: AppTheme.cobalt),
                      const SizedBox(width: 6),
                      Text(
                        isArabic ? 'ميناء الشحن: $pol' : 'POL: $pol',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                      ),
                    ],
                  ),
                ),
              if (pod != null && pod.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black87, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flight_land, size: 15, color: AppTheme.emerald),
                      const SizedBox(width: 6),
                      Text(
                        isArabic ? 'ميناء الوصول: $pod' : 'POD: $pod',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Quotation Cards Grid / Wrap ──────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 580;
              final cardWidth = isWide ? (constraints.maxWidth - 12) / 2 : double.infinity;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _options.map((opt) {
                  return SizedBox(
                    width: cardWidth,
                    child: _buildQuotationCardMatched(opt),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationCardMatched(ExtractedQuotationOption opt) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & Direct/Transit Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${opt.carrierName} (${opt.containerType})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.cobalt,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 15, color: AppTheme.cobalt),
                    tooltip: isArabic ? 'نسخ بيانات هذا العرض' : 'Copy Quote Details',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _copySingleQuote(context, opt, isArabic),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: opt.isDirect ? const Color(0xFFF0FDF4) : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: opt.isDirect ? const Color(0xFF86EFAC) : Colors.orange.shade200,
                      ),
                    ),
                    child: Text(
                      opt.isDirect
                          ? (isArabic ? 'مباشر' : 'Direct')
                          : (isArabic ? 'ترانزيت' : 'Transit'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: opt.isDirect ? Colors.green.shade800 : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 8, thickness: 1),
          const SizedBox(height: 6),

          // Price Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic
                    ? 'نولون: \$${opt.oceanFreight.toStringAsFixed(0)}'
                    : 'Freight: \$${opt.oceanFreight.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              if (opt.localCharges != null && opt.localCharges! > 0)
                Text(
                  isArabic
                      ? 'محلي: \$${opt.localCharges!.toStringAsFixed(0)}'
                      : 'Local: \$${opt.localCharges!.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              Text(
                isArabic
                    ? 'الإجمالي: \$${opt.totalEstimatedCost.toStringAsFixed(0)}'
                    : 'Total: \$${opt.totalEstimatedCost.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Transit & Demurrage Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic
                    ? '⏱️ ترانزيت: ${opt.transitDays ?? "-"} يوم'
                    : '⏱️ Transit: ${opt.transitDays ?? "-"} days',
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
              Text(
                isArabic
                    ? '⏳ سماح: ${opt.freeTimeDays ?? 14} يوم'
                    : '⏳ Free Time: ${opt.freeTimeDays ?? 14} days',
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ],
          ),

          // Extra Notes / Unmapped Expenses Pill (if any)
          if (opt.notes != null && opt.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                '★ ${opt.notes!}',
                style: const TextStyle(fontSize: 10.5, color: AppTheme.cobalt, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Full-width Add Button (Outlined Blue Button with + icon)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.cobalt,
                side: const BorderSide(color: AppTheme.cobalt, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                isArabic ? '+ إضافة هذا العرض للسيناريو' : '+ Add This Quote to Scenario',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                widget.onAddQuotations([opt]);
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _copyAllQuotes(BuildContext context, bool isArabic) {
    if (_options.isEmpty) return;
    final headers = isArabic
        ? ['الخط الملاحي', 'نوع الحاوية', 'النولون', 'المصاريف المحلية', 'الإجمالي', 'العملة', 'الترانزيت (أيام)', 'فترة السماح (أيام)', 'مباشر أو ترانزيت', 'ميناء الشحن', 'ميناء الوصول', 'ملاحظات']
        : ['Carrier', 'Container Type', 'Ocean Freight', 'Local Charges', 'Total', 'Currency', 'Transit Days', 'Free Time Days', 'Direct/Transit', 'POL', 'POD', 'Notes'];

    final pol = _primaryMetadata?['origin_port']?.toString() ?? _options.firstOrNull?.originPort ?? '';
    final pod = _primaryMetadata?['destination_port']?.toString() ?? _options.firstOrNull?.destinationPort ?? '';

    final rows = _options.map((opt) => [
      opt.carrierName,
      opt.containerType,
      opt.oceanFreight.toStringAsFixed(2),
      (opt.localCharges ?? 0).toStringAsFixed(2),
      opt.totalEstimatedCost.toStringAsFixed(2),
      opt.currency,
      opt.transitDays?.toString() ?? '',
      opt.freeTimeDays?.toString() ?? '',
      opt.isDirect ? (isArabic ? 'مباشر' : 'Direct') : (isArabic ? 'ترانزيت' : 'Transit'),
      opt.originPort ?? pol,
      opt.destinationPort ?? pod,
      opt.notes ?? '',
    ].join('\t')).join('\n');

    final tsv = '${headers.join('\t')}\n$rows';
    CopyHelper.copy(
      context,
      tsv,
      customMessage: isArabic
          ? 'تم نسخ جميع عروض الأسعار بصيغة جدول بنجاح!'
          : 'All quotations copied to clipboard (TSV / Excel) successfully!',
    );
  }

  void _copySingleQuote(BuildContext context, ExtractedQuotationOption opt, bool isArabic) {
    final pol = opt.originPort ?? _primaryMetadata?['origin_port']?.toString() ?? '';
    final pod = opt.destinationPort ?? _primaryMetadata?['destination_port']?.toString() ?? '';
    final text = isArabic
        ? '${opt.carrierName} | حاوية: ${opt.containerType} | نولون: \$${opt.oceanFreight.toStringAsFixed(0)} | إجمالي: \$${opt.totalEstimatedCost.toStringAsFixed(0)} | ترانزيت: ${opt.transitDays ?? "-"} يوم | سماح: ${opt.freeTimeDays ?? 14} يوم | من: $pol | إلى: $pod'
        : '${opt.carrierName} | Container: ${opt.containerType} | Freight: \$${opt.oceanFreight.toStringAsFixed(0)} | Total: \$${opt.totalEstimatedCost.toStringAsFixed(0)} | Transit: ${opt.transitDays ?? "-"}d | Free Time: ${opt.freeTimeDays ?? 14}d | POL: $pol | POD: $pod';
    CopyHelper.copy(
      context,
      text,
      customMessage: isArabic ? 'تم نسخ بيانات العرض بنجاح!' : 'Quote details copied successfully!',
    );
  }

  int _calculateTotalFieldsCount() {
    int count = 0;
    if (_primaryMetadata != null) {
      if (_primaryMetadata!['origin_port'] != null) count++;
      if (_primaryMetadata!['destination_port'] != null) count++;
      if (_primaryMetadata!['carrier_name'] != null) count++;
      if (_primaryMetadata!['forwarder_name'] != null) count++;
      if (_primaryMetadata!['etd_date'] != null) count++;
      if (_primaryMetadata!['transit_days'] != null) count++;
      if (_primaryMetadata!['free_days_demurrage'] != null) count++;
    }
    count += _options.length;
    count += _customFields.length;
    return count;
  }

  Widget _buildExtractedFieldsList() {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final pol = _primaryMetadata?['origin_port']?.toString() ?? _options.firstOrNull?.originPort;
    final pod = _primaryMetadata?['destination_port']?.toString() ?? _options.firstOrNull?.destinationPort;
    final carrier = _primaryMetadata?['carrier_name']?.toString() ?? _options.firstOrNull?.carrierName;
    final fwd = _primaryMetadata?['forwarder_name']?.toString() ?? _options.firstOrNull?.forwarderName;
    final etd = _primaryMetadata?['etd_date']?.toString() ?? _options.firstOrNull?.etdDate;
    final transit = _primaryMetadata?['transit_days']?.toString() ?? _options.firstOrNull?.transitDays?.toString();
    final freeTime = _primaryMetadata?['free_days_demurrage']?.toString() ?? _options.firstOrNull?.freeTimeDays?.toString();

    return Column(
      children: [
        // Standard Fields
        if (pol != null && pol.isNotEmpty)
          _buildFieldRow(label: isArabic ? 'ميناء الشحن' : 'Port of Loading (POL)', value: pol, isCustom: false),
        if (pod != null && pod.isNotEmpty)
          _buildFieldRow(label: isArabic ? 'ميناء الوصول' : 'Port of Discharge (POD)', value: pod, isCustom: false),
        if (carrier != null && carrier.isNotEmpty)
          _buildFieldRow(label: isArabic ? 'الخط الملاحي' : 'Shipping Line / Carrier', value: carrier, isCustom: false),
        if (fwd != null && fwd.isNotEmpty)
          _buildFieldRow(label: isArabic ? 'وكيل الشحن أو الناقل' : 'Freight Forwarder', value: fwd, isCustom: false),
        if (etd != null && etd.isNotEmpty)
          _buildFieldRow(label: isArabic ? 'تاريخ الإبحار' : 'Departure Date (ETD)', value: etd, isCustom: false),
        if (transit != null && transit.isNotEmpty)
          _buildFieldRow(
            label: isArabic ? 'مدة الإبحار' : 'Transit Time',
            value: isArabic ? '$transit يوم مباشر' : '$transit days direct',
            isCustom: false,
          ),
        if (freeTime != null && freeTime.isNotEmpty)
          _buildFieldRow(
            label: isArabic ? 'فترة السماح' : 'Free Time',
            value: isArabic ? '$freeTime يوم' : '$freeTime days',
            isCustom: false,
          ),

        // Custom & Unmapped Starred Fields
        ..._customFields.entries.map(
          (e) => _buildFieldRow(
            label: '★ ${e.key}',
            value: e.value,
            isCustom: true,
            onEdit: () => _showEditCustomFieldModal(e.key, e.value),
            onDelete: () => setState(() => _customFields.remove(e.key)),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldRow({
    required String label,
    required String value,
    required bool isCustom,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isCustom ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCustom ? const Color(0xFF93C5FD) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCustom ? FontWeight.bold : FontWeight.w600,
                color: isCustom ? AppTheme.cobalt : AppTheme.charcoal,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 15, color: Colors.grey),
            tooltip: isArabic ? 'نسخ القيمة' : 'Copy value',
            onPressed: () => CopyHelper.copy(context, value),
          ),
          if (isCustom) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.cobalt),
              tooltip: isArabic ? 'تعديل هذا البند' : 'Edit item',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.crimson),
              tooltip: isArabic ? 'حذف هذا البند' : 'Delete item',
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}
