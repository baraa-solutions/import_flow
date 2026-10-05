import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/localization/app_localizations.dart';

/// Modal dialog for CL-04: Final Customs Release Order
/// صدور إذن الإفراج الجمركي الأخضر وبدء إجراءات النقل للمخازن
class CustomsFinalReleaseDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;
  final CustomsClearanceModel? clearanceRecord;

  const CustomsFinalReleaseDialog({
    super.key,
    required this.file,
    this.clearanceRecord,
  });

  static Future<bool?> show(
    BuildContext context,
    ImportFileModel file, {
    CustomsClearanceModel? clearanceRecord,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomsFinalReleaseDialog(
        file: file,
        clearanceRecord: clearanceRecord,
      ),
    );
  }

  @override
  ConsumerState<CustomsFinalReleaseDialog> createState() =>
      _CustomsFinalReleaseDialogState();
}

class _CustomsFinalReleaseDialogState
    extends ConsumerState<CustomsFinalReleaseDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _releasePermitNoController;
  late TextEditingController _releaseOfficerController;
  late TextEditingController _gatePassNoController;
  late TextEditingController _demurrageFeesController;
  late TextEditingController _documentUrlController;
  late TextEditingController _transportInstructionsController;
  late TextEditingController _notesController;

  /// Release type code (DomainEnumType.releaseType); the label follows the UI language.
  String _releaseType = 'FINAL_GREEN';
  DateTime _releaseDate = DateTime.now();
  DateTime? _portGateOutDate = DateTime.now();
  bool _dispatchAuthorized = true;
  bool _isSubmitting = false;

  final List<String> _releaseTypes = DomainEnums.codesOf(DomainEnumType.releaseType);

  @override
  void initState() {
    super.initState();
    final rec = widget.clearanceRecord;
    final file = widget.file;

    // Prefill release permit number
    String initialPermit = rec?.releasePermitNo ?? file.customsReleasePermitNo ?? '';
    if (initialPermit.isEmpty) {
      initialPermit = 'REL-${DateTime.now().year}-${file.importFileId.toString().padLeft(4, '0')}';
    }
    _releasePermitNoController = TextEditingController(text: initialPermit);

    // Prefill officer name
    _releaseOfficerController = TextEditingController(
      text: rec?.releaseOfficerName ?? file.customsReleaseOfficer ?? '',
    );

    // Prefill gate pass number
    String initialGatePass = rec?.gatePassNumber ?? file.customsGatePassNo ?? '';
    if (initialGatePass.isEmpty) {
      initialGatePass = 'GP-${DateTime.now().year}-${file.importFileId.toString().padLeft(4, '0')}';
    }
    _gatePassNoController = TextEditingController(text: initialGatePass);

    // Prefill demurrage fees
    double demurrage = rec?.demurrageStorageFees ?? 0.0;
    _demurrageFeesController = TextEditingController(
      text: demurrage > 0 ? demurrage.toStringAsFixed(2) : '0.00',
    );

    // Prefill release type
    // Legacy rows hold the old ar/en label; map it to its code.
    _releaseType = DomainEnums.legacyToCode(DomainEnumType.releaseType, rec?.releaseType) ??
        DomainEnums.legacyToCode(DomainEnumType.releaseType, file.customsReleaseType) ??
        _releaseType;

    _documentUrlController = TextEditingController(
      text: rec?.releaseDocumentUrl ?? '',
    );

    _transportInstructionsController = TextEditingController(
      text: rec?.transportInstructions ??
          'Direct delivery to company warehouses - verify customs seal integrity before opening the container',
    );

    _notesController = TextEditingController(
      text: rec?.notes ?? '',
    );

    _dispatchAuthorized = rec?.dispatchAuthorized ?? true;
  }

  @override
  void dispose() {
    _releasePermitNoController.dispose();
    _releaseOfficerController.dispose();
    _gatePassNoController.dispose();
    _demurrageFeesController.dispose();
    _documentUrlController.dispose();
    _transportInstructionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _generatePermitNumber() {
    final year = DateTime.now().year;
    final id = widget.file.importFileId.toString().padLeft(4, '0');
    final rand = DateTime.now().millisecond.toString().padLeft(3, '0');
    setState(() {
      _releasePermitNoController.text = 'REL-$year-$id-$rand';
    });
  }

  void _generateGatePassNumber() {
    final year = DateTime.now().year;
    final id = widget.file.importFileId.toString().padLeft(4, '0');
    final rand = DateTime.now().millisecond.toString().padLeft(3, '0');
    setState(() {
      _gatePassNoController.text = 'GP-$year-$id-$rand';
    });
  }

  Future<void> _pickReleaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _releaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ar', 'EG'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.emerald,
              onPrimary: Colors.white,
              onSurface: AppTheme.charcoal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _releaseDate = picked);
    }
  }

  Future<void> _pickGateOutDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _portGateOutDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ar', 'EG'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.emerald,
              onPrimary: Colors.white,
              onSurface: AppTheme.charcoal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _portGateOutDate = picked);
    }
  }

  Future<void> _submitFinalRelease() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final demurrage = double.tryParse(_demurrageFeesController.text.trim()) ?? 0.0;
      final payload = {
        'import_file_id': widget.file.importFileId,
        'clearance_id': widget.clearanceRecord?.customsClearanceId,
        'release_permit_no': _releasePermitNoController.text.trim(),
        'release_date': _releaseDate.toIso8601String(),
        'release_officer_name': _releaseOfficerController.text.trim().isNotEmpty
            ? _releaseOfficerController.text.trim()
            : null,
        'release_type': _releaseType,
        'release_document_url': _documentUrlController.text.trim().isNotEmpty
            ? _documentUrlController.text.trim()
            : null,
        'gate_pass_number': _gatePassNoController.text.trim().isNotEmpty
            ? _gatePassNoController.text.trim()
            : null,
        'port_gate_out_date': _portGateOutDate?.toIso8601String(),
        'demurrage_storage_fees': demurrage,
        'dispatch_authorized': _dispatchAuthorized,
        'transport_instructions': _transportInstructionsController.text.trim().isNotEmpty
            ? _transportInstructionsController.text.trim()
            : null,
        'notes': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      };

      await ref
          .read(customsClearanceProvider.notifier)
          .issueFinalRelease(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم صدور إذن الإفراج الجمركي الأخضر برقم (${_releasePermitNoController.text.trim()}) وتفويض النقل بنجاح! تم تنشيط مهام النقل للمخازن (TR-01 & TR-02).',
                    overflow: TextOverflow.ellipsis,
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
            content: Text('حدث خطأ أثناء إصدار إذن الإفراج: $e'),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 920 ? 880.0 : screenWidth * 0.95;
    final rec = widget.clearanceRecord;
    final file = widget.file;

    final decl46 = rec?.declaration46No ?? file.form46No ?? '-';
    final sadadNo = rec?.sadadNumber ?? file.customsDutySadadNo ?? '-';
    final paidAmount = (rec != null && rec.dutyPaidAmount > 0)
        ? rec.dutyPaidAmount
        : (file.customsDutyPaidAmount > 0)
            ? file.customsDutyPaidAmount
            : ((rec != null && rec.actualDutyTotal > 0) ? rec.actualDutyTotal : 0.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: AppTheme.emerald,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.verified_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'صدور إذن الإفراج الجمركي الأخضر وبدء النقل (CL-04)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ملف: ${file.primaryNameWithCode} | شهادة 46: $decl46',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Summary Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.emerald.withOpacity(0.25),
                          ),
                        ),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            _buildInfoChip(
                              icon: Icons.receipt_long,
                              label: 'رقم الإقرار (شهادة 46)',
                              value: decl46,
                            ),
                            _buildInfoChip(
                              icon: Icons.payment,
                              label: 'رقم سداد الرسوم',
                              value: sadadNo,
                            ),
                            _buildInfoChip(
                              icon: Icons.price_check,
                              label: 'الرسوم المسددة',
                              value: '${paidAmount.toStringAsFixed(2)} ج.م',
                              isHighlight: true,
                            ),
                            _buildInfoChip(
                              icon: Icons.anchor,
                              label: 'ميناء الوصول',
                              value: file.portOfDischarge ?? 'ميناء الدخيلة',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section Title: إذن الإفراج
                      _buildSectionHeader(
                        icon: Icons.fact_check,
                        title: 'بيانات إذن الإفراج الجمركي الأخضر (MTS Release Permit)',
                      ),
                      const SizedBox(height: 12),

                      // Permit Number & Release Date
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('releasePermitNoField'),
                              controller: _releasePermitNoController,
                              decoration: InputDecoration(
                                labelText: 'رقم إذن الإفراج الأخضر *',
                                hintText: 'مثال: REL-2026-0004',
                                prefixIcon: const Icon(Icons.confirmation_number_outlined),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.auto_awesome, color: AppTheme.emerald),
                                  tooltip: 'توليد رقم إذن تلقائي',
                                  onPressed: _generatePermitNumber,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'رقم إذن الإفراج إلزامي';
                                }
                                if (val.trim().length < 3) {
                                  return 'الرقم قصير جداً';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: _pickReleaseDate,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'تاريخ صدور الإفراج *',
                                  prefixIcon: const Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  '${_releaseDate.year}-${_releaseDate.month.toString().padLeft(2, '0')}-${_releaseDate.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Officer Name & Release Type
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('releaseOfficerField'),
                              controller: _releaseOfficerController,
                              decoration: InputDecoration(
                                labelText: 'اسم مأمور الجمرك / المفرج',
                                hintText: 'اسم المفتش أو مأمور الإفراج',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _releaseType,
                              decoration: InputDecoration(
                                labelText: 'نوع الإفراج الجمركي',
                                prefixIcon: const Icon(Icons.category_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: _releaseTypes.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    DomainEnums.label(context.l10n, DomainEnumType.releaseType, type),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _releaseType = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Section Title: تصريح بوابة الميناء والنقل
                      _buildSectionHeader(
                        icon: Icons.local_shipping,
                        title: 'تصريح خروج البوابة وإجراءات النقل الداخلي (Port Gate-Out & Transport)',
                      ),
                      const SizedBox(height: 12),

                      // Gate Pass Number & Gate Out Date
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('gatePassNoField'),
                              controller: _gatePassNoController,
                              decoration: InputDecoration(
                                labelText: 'رقم تصريح الخروج من بوابة الميناء (Gate Pass)',
                                hintText: 'مثال: GP-2026-0004',
                                prefixIcon: const Icon(Icons.vpn_key_outlined),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.auto_awesome, color: AppTheme.emerald),
                                  tooltip: 'توليد رقم تصريح تلقائي',
                                  onPressed: _generateGatePassNumber,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: _pickGateOutDate,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'تاريخ الخروج من الميناء',
                                  prefixIcon: const Icon(Icons.departure_board),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  _portGateOutDate != null
                                      ? '${_portGateOutDate!.year}-${_portGateOutDate!.month.toString().padLeft(2, '0')}-${_portGateOutDate!.day.toString().padLeft(2, '0')}'
                                      : 'غير محدد',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Demurrage Storage Fees & Document URL
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('demurrageFeesField'),
                              controller: _demurrageFeesController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'رسوم الأرضيات وغرامات التأخير إن وجدت (ج.م)',
                                hintText: '0.00',
                                prefixIcon: const Icon(Icons.attach_money),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (val) {
                                if (val != null && val.trim().isNotEmpty) {
                                  final numVal = double.tryParse(val.trim());
                                  if (numVal == null || numVal < 0) {
                                    return 'أدخل مبلغاً صحيحاً';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              key: const Key('documentUrlField'),
                              controller: _documentUrlController,
                              decoration: InputDecoration(
                                labelText: 'رابط ملف إذن الإفراج (PDF / صورة)',
                                hintText: 'https://...',
                                prefixIcon: const Icon(Icons.link),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Dispatch Authorization Switch
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _dispatchAuthorized
                              ? AppTheme.emerald.withOpacity(0.08)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _dispatchAuthorized
                                ? AppTheme.emerald.withOpacity(0.4)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _dispatchAuthorized ? Icons.check_circle : Icons.pause_circle_outline,
                              color: _dispatchAuthorized ? AppTheme.emerald : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'تصريح مغادرة ونقل الشحنة (Dispatch Authorization)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'تأكيد جاهزية الحاوية للشحن الداخلي وبدء توجيه أسطول النقل للمستودعات',
                                    style: TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _dispatchAuthorized,
                              activeColor: AppTheme.emerald,
                              onChanged: (val) => setState(() => _dispatchAuthorized = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Transport Instructions
                      TextFormField(
                        key: const Key('transportInstructionsField'),
                        controller: _transportInstructionsController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'تعليمات النقل والتوجيه لمخازن الشركة',
                          hintText: 'تحديد موقع التعتيق، تعليمات السلامة الجمركية، وجهة التسليم...',
                          prefixIcon: const Icon(Icons.navigation_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      TextFormField(
                        key: const Key('notesField'),
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'ملاحظات وتوجيهات إضافية',
                          hintText: 'أية توجيهات للمخلص الجمركي أو إدارة العمليات...',
                          prefixIcon: const Icon(Icons.notes_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('إلغاء'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: ElevatedButton.icon(
                      key: const Key('customsFinalReleaseSubmitBtn'),
                      onPressed: _isSubmitting ? null : _submitFinalRelease,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified, color: Colors.white),
                      label: Text(
                        _isSubmitting
                            ? 'جاري إصدار الإفراج...'
                            : 'إصدار إذن الإفراج النهائي وتفويض النقل',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.emerald),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.charcoal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: isHighlight ? AppTheme.emerald : Colors.black54,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isHighlight ? AppTheme.emerald : AppTheme.charcoal,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
