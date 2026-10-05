import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/demurrage_model.dart';
import '../providers/demurrage_provider.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/localization/app_localizations.dart';

/// TR-05: تسجيل وتوثيق إرجاع الحاويات الفارغة للخط الملاحي (EIR)
/// يوقف عدادات الغرامات بالكامل وينقل الشحنة للمرحلة التاسعة (تكلفة الوصول والتسوية الختامية)
class EmptyContainerReturnDialog extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final String? initialContainerNumber;
  final String? initialEirNumber;
  final String? initialDepotName;

  const EmptyContainerReturnDialog({
    super.key,
    this.initialImportFileId,
    this.initialContainerNumber,
    this.initialEirNumber,
    this.initialDepotName,
  });

  static Future<EmptyContainerReturnResponseModel?> show(
    BuildContext context, {
    int? initialImportFileId,
    String? initialContainerNumber,
    String? initialEirNumber,
    String? initialDepotName,
  }) {
    return showDialog<EmptyContainerReturnResponseModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EmptyContainerReturnDialog(
        initialImportFileId: initialImportFileId,
        initialContainerNumber: initialContainerNumber,
        initialEirNumber: initialEirNumber,
        initialDepotName: initialDepotName,
      ),
    );
  }

  @override
  ConsumerState<EmptyContainerReturnDialog> createState() =>
      _EmptyContainerReturnDialogState();
}

class _EmptyContainerReturnDialogState
    extends ConsumerState<EmptyContainerReturnDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedImportFileId;
  late final TextEditingController _eirNumberCtrl;
  late final TextEditingController _depotNameCtrl;
  final _driverNameCtrl = TextEditingController();
  final _truckPlateNoCtrl = TextEditingController();
  final _damageNotesCtrl = TextEditingController();
  final _damageFeeCtrl = TextEditingController(text: '0.0');
  final _notesCtrl = TextEditingController();

  DateTime _emptyReturnDate = DateTime.now();
  String _containerCondition = 'SOUND_CLEAN';
  bool _isSubmitting = false;

  /// Depot codes (DomainEnumType.depot); labels follow the UI language.
  final List<String> _popularDepots = DomainEnums.codesOf(DomainEnumType.depot);

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;

    final randomId = 1000 + Random().nextInt(9000);
    final autoEir = widget.initialEirNumber ??
        'EIR-${DateTime.now().year}-$randomId';
    _eirNumberCtrl = TextEditingController(text: autoEir);

    _depotNameCtrl = TextEditingController(
      text: DomainEnums.initialCode(DomainEnumType.depot, widget.initialDepotName, widget.initialDepotName ?? _popularDepots.first),
    );
  }

  @override
  void dispose() {
    _eirNumberCtrl.dispose();
    _depotNameCtrl.dispose();
    _driverNameCtrl.dispose();
    _truckPlateNoCtrl.dispose();
    _damageNotesCtrl.dispose();
    _damageFeeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _regenerateEirNumber() {
    final randomId = 1000 + Random().nextInt(9000);
    setState(() {
      _eirNumberCtrl.text = 'EIR-${DateTime.now().year}-$randomId';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار ملف الشحنة المراد إرجاع حاوياتها'),
          backgroundColor: AppTheme.flatCrimson,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final submitModel = EmptyContainerReturnSubmitModel(
        importFileId: _selectedImportFileId!,
        eirNumber: _eirNumberCtrl.text.trim(),
        emptyReturnDate:
            _emptyReturnDate.toIso8601String().split('T').first,
        depotName: _depotNameCtrl.text.trim(),
        returnedContainers: widget.initialContainerNumber != null
            ? [widget.initialContainerNumber!]
            : null,
        containerCondition: _containerCondition,
        damageNotes: _containerCondition != 'SOUND_CLEAN'
            ? _damageNotesCtrl.text.trim()
            : null,
        damageFeeEstimated: _containerCondition != 'SOUND_CLEAN'
            ? double.tryParse(_damageFeeCtrl.text.trim()) ?? 0.0
            : 0.0,
        driverName: _driverNameCtrl.text.trim().isNotEmpty
            ? _driverNameCtrl.text.trim()
            : null,
        truckPlateNo: _truckPlateNoCtrl.text.trim().isNotEmpty
            ? _truckPlateNoCtrl.text.trim()
            : null,
        notes: _notesCtrl.text.trim().isNotEmpty
            ? _notesCtrl.text.trim()
            : null,
      );

      final res = await ref
          .read(demurrageProvider.notifier)
          .recordEmptyContainerReturn(submitModel);

      if (mounted && res != null) {
        Navigator.of(context).pop(res);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(res.messageAr)),
              ],
            ),
            backgroundColor: AppTheme.flatEmerald,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تسجيل إرجاع الحاوية: ${e.toString()}'),
            backgroundColor: AppTheme.flatCrimson,
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
    final filesAsync = ref.watch(importFilesProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 850),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFileSelector(filesAsync),
                      const SizedBox(height: 16),
                      _buildRadarNoticeBanner(),
                      const SizedBox(height: 20),
                      _buildEirAndDateRow(),
                      const SizedBox(height: 16),
                      _buildDepotSelector(),
                      const SizedBox(height: 20),
                      _buildContainerConditionSection(),
                      const SizedBox(height: 16),
                      _buildDriverAndTruckRow(),
                      const SizedBox(height: 16),
                      _buildNotesField(),
                    ],
                  ),
                ),
              ),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        color: AppTheme.flatCharcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.assignment_turned_in_rounded,
              color: AppTheme.flatEmerald,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تأكيد إرجاع الحاويات الفارغة للخط (EIR) — (TR-05)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إصدار إيصال استلام الحاوية وإيقاف عدادات غرامات التأخير ونقل الملف للمرحلة الختامية',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            tooltip: 'إغلاق',
          ),
        ],
      ),
    );
  }

  Widget _buildFileSelector(AsyncValue<List<dynamic>> filesAsync) {
    return filesAsync.when(
      data: (files) {
        if (files.isEmpty) {
          return const Text('لا توجد ملفات استيراد مسجلة');
        }

        final selectedFile = files
            .cast<dynamic>()
            .firstWhere(
              (f) => f.importFileId == _selectedImportFileId,
              orElse: () => null,
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_shared_outlined,
                    size: 18, color: AppTheme.flatCobalt),
                const SizedBox(width: 8),
                const Text(
                  'ملف الاستيراد المستهدف',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.flatCharcoal,
                  ),
                ),
                const Spacer(),
                if (widget.initialContainerNumber != null)
                  Chip(
                    avatar: const Icon(Icons.inventory_2_outlined,
                        size: 14, color: Colors.white),
                    label: Text(
                      'الحاوية: ${widget.initialContainerNumber}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: AppTheme.flatCharcoal,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SearchableDropdownField<int>(
              key: const Key('emptyReturnImportFileDropdown'),
              items: files
                  .map((f) => SearchableDropdownItem<int>(
                        value: f.importFileId,
                        label: '${f.primaryNameWithCode} — ${f.companyName}',
                      ))
                  .toList(),
              value: _selectedImportFileId,
              hintText: 'اختر ملف الاستيراد لتسليم حاوياته...',
              onChanged: (val) {
                setState(() => _selectedImportFileId = val);
              },
            ),
            if (selectedFile != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cloudWhite.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSmallDetail(
                        'المستورد',
                        selectedFile.companyName ?? '-',
                      ),
                    ),
                    Expanded(
                      child: _buildSmallDetail(
                        'المورد',
                        selectedFile.supplierName ?? '-',
                      ),
                    ),
                    Expanded(
                      child: _buildSmallDetail(
                        'حالة النقل الداخلي',
                        selectedFile.inlandTransportStatus ?? '-',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('خطأ في جلب الملفات: $e'),
    );
  }

  Widget _buildSmallDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.flatCharcoal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildRadarNoticeBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F9F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.flatEmerald.withOpacity(0.35)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined,
              color: AppTheme.flatEmerald, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أثر تسليم الحاوية الفارغة على رادار الغرامات ودورة الحياة:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.flatEmerald,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '1. إيقاف احتساب عداد غرامات التأخير (Detention) فورياً.\n'
                  '2. تحويل حالة الحاوية في رادار الغرامات إلى "RETURNED_SAFE" (تم الإرجاع بسلام).\n'
                  '3. ترقية نسبة إنجاز الشحنة إلى 98% ونقل الملف رسمياً للمرحلة التاسعة: تكلفة الوصول والتسوية الختامية (CLO-01).',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.flatCharcoal,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEirAndDateRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'رقم إيصال استلام الحاوية (EIR) *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _regenerateEirNumber,
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('توليد جديد',
                        style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('eirNumberField'),
                controller: _eirNumberCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. EIR-2026-88001',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 3) {
                    return 'يرجى إدخال رقم إيصال EIR صحيح (3 أحرف على الأقل)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'تاريخ الإرجاع الفعلي *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _emptyReturnDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _emptyReturnDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 18, color: AppTheme.flatCobalt),
                      const SizedBox(width: 10),
                      Text(
                        _emptyReturnDate
                            .toIso8601String()
                            .split('T')
                            .first,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDepotSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'مستودع وساحة إرجاع الحاوية (Carrier Depot / Terminal)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 6),
        SearchableDropdownField<String>(
          key: const Key('depotNameDropdown'),
          items: _popularDepots
              .map((d) => SearchableDropdownItem<String>(
                    value: d,
                    label: DomainEnums.label(context.l10n, DomainEnumType.depot, d),
                  ))
              .toList(),
          value: _popularDepots.contains(_depotNameCtrl.text)
              ? _depotNameCtrl.text
              : null,
          hintText: 'اختر ساحة ومستودع الخط الملاحي...',
          onChanged: (val) {
            if (val != null) {
              setState(() => _depotNameCtrl.text = val);
            }
          },
        ),
      ],
    );
  }

  Widget _buildContainerConditionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'حالة سلامة الحاوية عند التسليم الفعلي',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.flatCharcoal,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildConditionCard(
                'SOUND_CLEAN',
                'سليمة ونظيفة (Sound & Clean)',
                'خالية من أي تلفيات أو أضرار',
                Icons.check_circle_outline,
                AppTheme.flatEmerald,
              ),
              const SizedBox(width: 12),
              _buildConditionCard(
                'MINOR_DAMAGE',
                'تلفيات بسيطة (Minor Damage)',
                'خدوش أو انحناءات طفيفة',
                Icons.warning_amber_rounded,
                AppTheme.flatOrange,
              ),
              const SizedBox(width: 12),
              _buildConditionCard(
                'REPAIR_REQUIRED',
                'تتطلب إصلاح (Repair Required)',
                'تلفيات بالأرضية أو الباب',
                Icons.build_outlined,
                AppTheme.flatCrimson,
              ),
            ],
          ),
          if (_containerCondition != 'SOUND_CLEAN') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _damageNotesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات وتفاصيل التلفيات بالمعاينة',
                      hintText: 'e.g. انحناء بسيط بالقائم الأيمن والباب',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _damageFeeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'غرامة الإصلاح (USD)',
                      prefixIcon: Icon(Icons.attach_money, size: 18),
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConditionCard(
    String code,
    String title,
    String subtitle,
    IconData icon,
    Color activeColor,
  ) {
    final isSelected = _containerCondition == code;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _containerCondition = code),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? activeColor : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      size: 18,
                      color: isSelected ? activeColor : Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? activeColor
                            : AppTheme.flatCharcoal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverAndTruckRow() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _driverNameCtrl,
            decoration: const InputDecoration(
              labelText: 'اسم سائق شاحنة الإرجاع (اختياري)',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: TextFormField(
            controller: _truckPlateNoCtrl,
            decoration: const InputDecoration(
              labelText: 'رقم لوحة الشاحنة (اختياري)',
              prefixIcon: Icon(Icons.local_shipping_outlined),
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesCtrl,
      maxLines: 2,
      decoration: const InputDecoration(
        labelText: 'ملاحظات إضافية على تسليم الحاوية الفارغة',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            key: const Key('submitEmptyContainerReturnBtn'),
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.flatEmerald,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_rounded, size: 18),
            label: Text(
              _isSubmitting
                  ? 'جاري إثبات التسليم...'
                  : 'تأكيد الإرجاع واستلام إيصال EIR',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
