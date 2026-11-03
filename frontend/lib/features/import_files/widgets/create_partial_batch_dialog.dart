import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/import_file_model.dart';
import '../providers/import_files_provider.dart';

class CreatePartialBatchDialog extends ConsumerStatefulWidget {
  final ImportFileModel parentFile;

  const CreatePartialBatchDialog({
    super.key,
    required this.parentFile,
  });

  @override
  ConsumerState<CreatePartialBatchDialog> createState() => _CreatePartialBatchDialogState();
}

class _CreatePartialBatchDialogState extends ConsumerState<CreatePartialBatchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _customNumController = TextEditingController();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();

  late String _shipmentMode;
  String _startingStep = 'STEP_01';
  DateTime? _requiredEta;
  bool _isSubmitting = false;

  final List<Map<String, String>> _availableSteps = [
    {'code': 'STEP_01', 'label': 'المرحلة 1: استلام أمر الشراء والتخطيط (STEP_01)'},
    {'code': 'STEP_04', 'label': 'المرحلة 2: الموافقات المالية وموازنة الشحن (STEP_04)'},
    {'code': 'STEP_05', 'label': 'المرحلة 2: استخراج وإدارة رقم ACID (STEP_05)'},
    {'code': 'STEP_06', 'label': 'المرحلة 3: حجز الشحن الدولي مع الخط الملاحي (STEP_06)'},
    {'code': 'STEP_08', 'label': 'المرحلة 3: مراجعة واعتماد مسودة البوليصة والمستندات (STEP_08)'},
  ];

  @override
  void initState() {
    super.initState();
    _shipmentMode = widget.parentFile.shipmentMode;
    _notesController.text = 'دفعة شحن مجزأة من الملف الأساسي: ${widget.parentFile.importFileCode}';
  }

  @override
  void dispose() {
    _codeController.dispose();
    _customNumController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final payload = <String, dynamic>{
        if (_codeController.text.trim().isNotEmpty)
          'target_import_file_code': _codeController.text.trim(),
        if (_customNumController.text.trim().isNotEmpty)
          'target_custom_file_number': _customNumController.text.trim(),
        'shipment_mode': _shipmentMode,
        'initial_starting_step': _startingStep,
        if (_costController.text.trim().isNotEmpty)
          'estimated_cost': double.tryParse(_costController.text.trim()) ?? 0.0,
        if (_requiredEta != null)
          'required_eta': _requiredEta!.toIso8601String().substring(0, 10),
        'notes': _notesController.text.trim(),
      };

      final created = await ref
          .read(importFilesProvider.notifier)
          .createPartialBatch(widget.parentFile.importFileId, payload);

      if (mounted) {
        Navigator.of(context).pop(created);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            'تم إنشاء ملف الدفعة الجزئية بنجاح: ${created?.importFileCode ?? ""}',
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            'فشل إنشاء الدفعة الجزئية: $e',
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parent = widget.parentFile;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.call_split_rounded, color: Colors.amber.shade800, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إنشاء دفعة شحن جزئية مستقلة',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'تفريغ جزء من أمر الشراء في ملف استيرادي مستقل بدورة حياة كاملة (DEV-OPS-04)',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Parent File Context Banner
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.link_rounded, size: 18, color: AppTheme.cobalt),
                                  const SizedBox(width: 8),
                                  Text(
                                    'الملف الأساسي المرتبط: ${parent.importFileCode}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  if (parent.poNumber != null) ...[
                                    const SizedBox(width: 12),
                                    Text(
                                      '| أمر الشراء: ${parent.poNumber}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 16,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'الشركة: ${parent.companyName}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'المورد: ${parent.supplierName}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (parent.portOfLoading != null)
                                    Text(
                                      'الشحن: ${parent.portOfLoading} → ${parent.portOfDischarge}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Form Inputs
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _codeController,
                                decoration: InputDecoration(
                                  labelText: 'كود الملف الجديد (تلقائي إذا تُرك فارغاً)',
                                  hintText: '${parent.importFileCode}-P2',
                                  prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _customNumController,
                                decoration: InputDecoration(
                                  labelText: 'رقم الملف الجمركي المخصص (اختياري)',
                                  prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            // Shipment Mode
                            Expanded(
                              child: SearchableDropdownField<String>(
                                value: _shipmentMode,
                                labelText: 'طريقة الشحن للدفعة',
                                decoration: InputDecoration(
                                  labelText: 'طريقة الشحن للدفعة',
                                  prefixIcon: const Icon(Icons.local_shipping_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                                items: const [
                                  SearchableDropdownItem<String>(value: 'Sea FCL', label: 'Sea FCL (حاوية كاملة)'),
                                  SearchableDropdownItem<String>(value: 'Sea LCL', label: 'Sea LCL (شحنة مجزأة)'),
                                  SearchableDropdownItem<String>(value: 'Air', label: 'Air (شحن جوي)'),
                                  SearchableDropdownItem<String>(value: 'Land', label: 'Land (شحن بري)'),
                                  SearchableDropdownItem<String>(value: 'Courier', label: 'Courier (بريد سريع)'),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _shipmentMode = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Estimated Cost
                            Expanded(
                              child: TextFormField(
                                controller: _costController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'التكلفة التقديرية للدفعة (${parent.estimatedCostCurrency})',
                                  prefixIcon: const Icon(Icons.attach_money_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Starting Lifecycle Step
                        SearchableDropdownField<String>(
                          value: _startingStep,
                          labelText: 'نقطة انطلاق دورة الحياة للدفعة',
                          decoration: InputDecoration(
                            labelText: 'نقطة انطلاق دورة الحياة للدفعة',
                            prefixIcon: const Icon(Icons.flag_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                          items: _availableSteps.map((s) {
                            return SearchableDropdownItem<String>(value: s['code']!, label: s['label']!);
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _startingStep = val);
                          },
                        ),
                        const SizedBox(height: 14),

                        // Operational Notes
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'ملاحظات تشغيلية على الدفعة',
                            prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('إلغاء'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.add_task_rounded, size: 18),
                      label: Text(_isSubmitting ? 'جاري الإنشاء...' : 'إنشاء الدفعة المستقلة'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
