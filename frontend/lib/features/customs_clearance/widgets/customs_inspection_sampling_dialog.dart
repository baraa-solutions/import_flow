import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/models/import_file_model.dart';
import '../providers/customs_clearance_provider.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/localization/app_localizations.dart';

/// Modal dialog for CL-01: Customs Inspection & Samples GOEIC Report
/// تسجيل الكشف والمعاينة وسحب العينات ومطابقة الرقابة على الصادرات والواردات
class CustomsInspectionSamplingDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;

  const CustomsInspectionSamplingDialog({
    super.key,
    required this.file,
  });

  static Future<bool?> show(BuildContext context, ImportFileModel file) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomsInspectionSamplingDialog(file: file),
    );
  }

  @override
  ConsumerState<CustomsInspectionSamplingDialog> createState() =>
      _CustomsInspectionSamplingDialogState();
}

class _CustomsInspectionSamplingDialogState
    extends ConsumerState<CustomsInspectionSamplingDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _inspectorController;
  late TextEditingController _samplingRecordController;
  late TextEditingController _goeicCertController;
  late TextEditingController _labFeesController;
  late TextEditingController _inspectionNotesController;

  DateTime _inspectionDate = DateTime.now();
  DateTime _samplingDate = DateTime.now();

  String _selectedInspectionType = 'Physical & Sampling';
  String _selectedYard = 'ALEXANDRIA_BERTH_42';
  String _selectedResult = 'Conforming';
  bool _isSampleDrawn = true;
  String _selectedSampleTestStatus = 'Samples Under Testing';

  final Set<String> _selectedSampledBodies = {'GOEIC'};

  bool _isSubmitting = false;

  final List<String> _inspectionYards = DomainEnums.codesOf(DomainEnumType.inspectionYard);

  final List<Map<String, String>> _inspectionTypes = [
    {
      'id': 'Physical & Sampling',
      'label': 'كشف فعلي وسحب عينات',
      'desc': 'فتح الطرود، المعاينة البصرية، وسحب عينات معملية للجهات الرقابية',
    },
    {
      'id': '100% Full Inspection',
      'label': 'تفريغ وكشف كلي 100%',
      'desc': 'تفريغ كامل الحاوية/الشحنة ومطابقة كل طرد وقطعة',
    },
    {
      'id': 'Random Sample Check',
      'label': 'كشف عشوائي للطرود',
      'desc': 'معاينة عينات عشوائية بنسبة محددة من إجمالي الطرود',
    },
    {
      'id': 'X-Ray Scan & Inspection',
      'label': 'فحص بالأشعة X-Ray',
      'desc': 'مرور عبر أجهزة الكشف بالأشعة مع فحص ظاهري للحاوية',
    },
    {
      'id': 'Document Review Only',
      'label': 'مطابقة مستندية',
      'desc': 'فحص ومطابقة الأختام ومراجعة بوالص الشحن والفواتير',
    },
  ];

  final List<Map<String, dynamic>> _inspectionResults = [
    {
      'id': 'Conforming',
      'label': 'مطابقة تامة (Conforming)',
      'desc': 'الأصناف مطابقة للمستندات والوزن والمواصفات القياسية',
      'color': const Color(0xFF16A34A),
      'icon': Icons.check_circle_rounded,
    },
    {
      'id': 'Shortage',
      'label': 'وجود عجز (Shortage)',
      'desc': 'كميات أو طرود أقل من المصرح بها بالفاتورة',
      'color': const Color(0xFFD97706),
      'icon': Icons.remove_circle_outline_rounded,
    },
    {
      'id': 'Surplus',
      'label': 'وجود زيادة (Surplus)',
      'desc': 'كميات أو أصناف إضافية غير مدرجة بالفاتورة',
      'color': const Color(0xFF2563EB),
      'icon': Icons.add_circle_outline_rounded,
    },
    {
      'id': 'Discrepancy',
      'label': 'اختلاف في البند/المنشأ (Discrepancy)',
      'desc': 'تباين في المنشأ أو مواصفات الصنف عن الإقرار 46',
      'color': const Color(0xFFDC2626),
      'icon': Icons.warning_amber_rounded,
    },
  ];

  final List<String> _regulatoryAgencyOptions = const [
    'GOEIC',
    'NFSA',
    'CHEMISTRY_DEPT',
    'ATOMIC_ENERGY',
    'AGRICULTURAL_QUARANTINE',
    'VETERINARY_QUARANTINE',
    'NTRA',
    'WEIGHTS_MEASURES',
    'EDA',
  ];

  @override
  void initState() {
    super.initState();
    _inspectorController = TextEditingController(
      text: 'Joint Customs Inspection Committee',
    );
    _samplingRecordController = TextEditingController(
      text: _generateSamplingRecordNo(),
    );
    _goeicCertController = TextEditingController();
    _labFeesController = TextEditingController(text: '0');
    _inspectionNotesController = TextEditingController();
  }

  @override
  void dispose() {
    _inspectorController.dispose();
    _samplingRecordController.dispose();
    _goeicCertController.dispose();
    _labFeesController.dispose();
    _inspectionNotesController.dispose();
    super.dispose();
  }

  String _generateSamplingRecordNo() {
    final year = DateTime.now().year;
    final rand = Random().nextInt(9000) + 1000;
    return 'SMP-$year-ALX-$rand';
  }

  Future<void> _pickDate({required bool isSampling}) async {
    final initialDate = isSampling ? _samplingDate : _inspectionDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ar', 'EG'),
    );
    if (picked != null) {
      setState(() {
        if (isSampling) {
          _samplingDate = picked;
        } else {
          _inspectionDate = picked;
        }
      });
    }
  }

  Future<void> _submitInspectionSampling() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final labFees = double.tryParse(_labFeesController.text.trim()) ?? 0.0;

      final payload = {
        'import_file_id': widget.file.importFileId,
        'inspection_date': _inspectionDate.toIso8601String(),
        'inspection_type': _selectedInspectionType,
        'inspection_yard': _selectedYard,
        'inspector_name': _inspectorController.text.trim().isNotEmpty
            ? _inspectorController.text.trim()
            : null,
        'inspection_result': _selectedResult,
        'is_sample_drawn': _isSampleDrawn,
        'sampling_date': _isSampleDrawn ? _samplingDate.toIso8601String() : null,
        'sampling_record_no': _isSampleDrawn && _samplingRecordController.text.trim().isNotEmpty
            ? _samplingRecordController.text.trim()
            : null,
        'sample_test_status': _selectedSampleTestStatus,
        'sampled_regulatory_bodies': _isSampleDrawn ? _selectedSampledBodies.toList() : [],
        'goeic_certificate_no': _goeicCertController.text.trim().isNotEmpty
            ? _goeicCertController.text.trim()
            : null,
        'lab_service_fees': labFees,
        'inspection_notes': _inspectionNotesController.text.trim().isNotEmpty
            ? _inspectionNotesController.text.trim()
            : null,
      };

      await ref
          .read(customsClearanceProvider.notifier)
          .recordInspectionSampling(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم تسجيل الكشف والمعاينة وسحب العينات بنجاح! نتيجة الفحص ($_selectedResult). تم الانتقال للمرحلة التالية: احتساب الرسوم والضرائب الجمركية النهائية (CL-02).',
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.emerald,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تسجيل الكشف وسحب العينات: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 860,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          children: [
            // 1. Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: AppTheme.charcoal,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.biotech_rounded,
                      color: AppTheme.cobalt,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تسجيل الكشف والمعاينة وسحب العينات ومطابقة الرقابة (CL-01)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'المرحلة السابعة: التخليص والإفراج الجمركي | ملف الشحنة: ${file.importFileCode} (${file.companyName})',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'إغلاق النافذة',
                  ),
                ],
              ),
            ),

            // 2. Dialog Body (Form & Key Details)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Context Cards Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoBadge(
                              title: 'رقم الإقرار الجمركي 46',
                              value: file.form46No ?? 'مسجل بنموذج 46',
                              icon: Icons.assignment_turned_in_rounded,
                              accentColor: AppTheme.cobalt,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoBadge(
                              title: 'المسار الجمركي المحدد',
                              value: 'المسار الأحمر (Red Channel)',
                              icon: Icons.security_rounded,
                              accentColor: const Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoBadge(
                              title: 'تاريخ القيد الجمركي',
                              value: file.form46Date != null && file.form46Date!.length >= 10
                                  ? file.form46Date!.substring(0, 10)
                                  : DateTime.now().toIso8601String().substring(0, 10),
                              icon: Icons.calendar_today_rounded,
                              accentColor: AppTheme.charcoal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECTION 1: بيانات الكشف والمعاينة الميدانية
                      _buildSectionTitle(
                        title: 'أولاً: بيانات الكشف والمعاينة الميدانية بالميناء',
                        icon: Icons.fact_check_rounded,
                      ),
                      const SizedBox(height: 12),

                      // Row: Inspection Yard & Inspection Date
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: SearchableDropdownField<String>(
                              key: const Key('inspectionYardDropdown'),
                              labelText: 'ساحة / رصيف المعاينة والكشف بالميناء *',
                              hintText: 'اختر ساحة الفحص...',
                              items: _inspectionYards
                                  .map(
                                    (yard) => SearchableDropdownItem<String>(
                                      value: yard,
                                      label: DomainEnums.label(context.l10n, DomainEnumType.inspectionYard, yard),
                                    ),
                                  )
                                  .toList(),
                              value: _selectedYard,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.warehouse_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedYard = val);
                                }
                              },
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'يرجى تحديد ساحة المعاينة';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: () => _pickDate(isSampling: false),
                              borderRadius: BorderRadius.circular(8),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'تاريخ المعاينة الفنية *',
                                  prefixIcon: const Icon(Icons.calendar_month_rounded),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(
                                  _inspectionDate.toIso8601String().substring(0, 10),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Inspection Type Selector
                      const Text(
                        'نوع وطريقة الكشف والمعاينة:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _inspectionTypes.map((type) {
                          final isSelected = _selectedInspectionType == type['id'];
                          return ChoiceChip(
                            label: Text(type['label']!),
                            selected: isSelected,
                            selectedColor: AppTheme.cobalt.withOpacity(0.15),
                            avatar: isSelected
                                ? const Icon(Icons.check, size: 16, color: AppTheme.cobalt)
                                : null,
                            labelStyle: TextStyle(
                              color: isSelected ? AppTheme.cobalt : AppTheme.charcoal,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedInspectionType = type['id']!);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Inspector Name Field
                      TextFormField(
                        controller: _inspectorController,
                        decoration: InputDecoration(
                          labelText: 'اسم المفتش / رئيس لجنة الفحص الجمركي المشترك',
                          hintText: 'مثال: م. إبراهيم خليل - رئيس لجنة الفحص المشترك',
                          prefixIcon: const Icon(Icons.badge_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Inspection Result Choice Cards
                      const Text(
                        'نتيجة الكشف والمعاينة الميدانية *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: _inspectionResults.map((result) {
                          final isSelected = _selectedResult == result['id'];
                          final Color color = result['color'] as Color;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                onTap: () => setState(() => _selectedResult = result['id'] as String),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
                                    border: Border.all(
                                      color: isSelected ? color : Colors.grey.shade300,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            result['icon'] as IconData,
                                            size: 18,
                                            color: isSelected ? color : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              result['label'] as String,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? color : AppTheme.charcoal,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        result['desc'] as String,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: Colors.grey.shade700,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // SECTION 2: سحب العينات ومطابقة الرقابة على الصادرات والواردات (GOEIC)
                      _buildSectionTitle(
                        title: 'ثانياً: سحب العينات والرقابة على الصادرات والواردات (GOEIC)',
                        icon: Icons.science_rounded,
                      ),
                      const SizedBox(height: 8),

                      // Toggle: Was sample drawn?
                      SwitchListTile(
                        value: _isSampleDrawn,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'تم سحب عينات للفحص والتحليل المعملي للجهات الرقابية',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        subtitle: Text(
                          _isSampleDrawn
                              ? 'سيتم تدوين رقم محضر سحب العينات وتحديد جهات الفحص المعملي ومتابعة تقرير GOEIC'
                              : 'لم يتم سحب عينات (اكتفاء بالمعاينة الظاهرية ومطابقة المستندات)',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                        ),
                        activeColor: AppTheme.emerald,
                        onChanged: (val) {
                          setState(() {
                            _isSampleDrawn = val;
                            if (val && _samplingRecordController.text.trim().isEmpty) {
                              _samplingRecordController.text = _generateSamplingRecordNo();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      if (_isSampleDrawn) ...[
                        // Row: Sampling record & Sampling date
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _samplingRecordController,
                                decoration: InputDecoration(
                                  labelText: 'رقم محضر سحب العينات الرسمي *',
                                  hintText: 'مثال: SMP-2026-ALX-1082',
                                  prefixIcon: const Icon(Icons.numbers_rounded),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.refresh_rounded, size: 20),
                                    tooltip: 'توليد رقم محضر جديد',
                                    onPressed: () {
                                      setState(() {
                                        _samplingRecordController.text = _generateSamplingRecordNo();
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: (val) {
                                  if (_isSampleDrawn && (val == null || val.trim().length < 3)) {
                                    return 'رقم محضر سحب العينات مطلوب (3 أحرف على الأقل)';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: InkWell(
                                onTap: () => _pickDate(isSampling: true),
                                borderRadius: BorderRadius.circular(8),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'تاريخ سحب العينات *',
                                    prefixIcon: const Icon(Icons.event_note_rounded),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text(
                                    _samplingDate.toIso8601String().substring(0, 10),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Sampled Regulatory Bodies Chips
                        const Text(
                          'الجهات الرقابية الساحبة للعينات والفاحصة معملياً:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _regulatoryAgencyOptions.map((agency) {
                            final isSelected = _selectedSampledBodies.contains(agency);
                            return FilterChip(
                              label: Text(DomainEnums.label(context.l10n, DomainEnumType.regulatoryBody, agency), style: const TextStyle(fontSize: 12)),
                              selected: isSelected,
                              selectedColor: AppTheme.cobalt.withOpacity(0.15),
                              checkmarkColor: AppTheme.cobalt,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedSampledBodies.add(agency);
                                  } else {
                                    _selectedSampledBodies.remove(agency);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Row: GOEIC Certificate No & Lab Fees
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _goeicCertController,
                                decoration: InputDecoration(
                                  labelText: 'رقم شهادة الفحص / إشعار المعاينة (GOEIC Ref)',
                                  hintText: 'مثال: GOEIC-2026-INSP-9922',
                                  prefixIcon: const Icon(Icons.verified_rounded),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _labFeesController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'رسوم ومصاريف التحليل المعملي',
                                  suffixText: 'EGP',
                                  prefixIcon: const Icon(Icons.payments_rounded),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Sample Test Status
                        const Text(
                          'حالة فحص العينات المعملية:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildSampleStatusChip('Samples Under Testing', 'عينات تحت الفحص المعملي', Icons.hourglass_top_rounded, AppTheme.orange),
                            _buildSampleStatusChip('Approved', 'مطابقة ومعتمدة رقابياً', Icons.check_circle_rounded, AppTheme.emerald),
                            _buildSampleStatusChip('Rejected', 'غير مطابقة (مرفوضة)', Icons.cancel_rounded, AppTheme.crimson),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // SECTION 3: ملاحظات وتوصيات لجنة المعاينة
                      _buildSectionTitle(
                        title: 'ثالثاً: ملاحظات وتوصيات لجنة المعاينة والفحص',
                        icon: Icons.notes_rounded,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _inspectionNotesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'ملاحظات الكشف والمعاينة والتثمين',
                          hintText: 'أدخل أي ملاحظات فنية حول حالة الطرود، سلامة الأختام الملاحية، توصيات لجنة الكشف، أو متطلبات الفحص المعملي...',
                          prefixIcon: const Icon(Icons.edit_note_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Dialog Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'اعتماد الكشف والمعاينة سيرفع نسبة تقدم الملف إلى 88% ويولد مهمة احتساب الرسوم (CL-02).',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitInspectionSampling,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _isSubmitting ? 'جاري الحفظ والاعتماد...' : 'حفظ واعتماد الكشف وسحب العينات (CL-01)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.cobalt),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.charcoal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBadge({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleStatusChip(String code, String label, IconData icon, Color color) {
    final isSelected = _selectedSampleTestStatus == code;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? color : Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11.5, color: isSelected ? color : AppTheme.charcoal)),
        ],
      ),
      selected: isSelected,
      selectedColor: color.withOpacity(0.15),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedSampleTestStatus = code);
        }
      },
    );
  }
}
