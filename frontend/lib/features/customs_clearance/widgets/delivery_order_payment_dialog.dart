import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../providers/customs_clearance_provider.dart';

/// Modal dialog for CS-02: Delivery Order (D/O) Payment & Receipt
/// سداد إذن التسليم الملاحي واستلام D/O
class DeliveryOrderPaymentDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;

  const DeliveryOrderPaymentDialog({
    super.key,
    required this.file,
  });

  static Future<bool?> show(BuildContext context, ImportFileModel file) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeliveryOrderPaymentDialog(file: file),
    );
  }

  @override
  ConsumerState<DeliveryOrderPaymentDialog> createState() =>
      _DeliveryOrderPaymentDialogState();
}

class _DeliveryOrderPaymentDialogState
    extends ConsumerState<DeliveryOrderPaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedShippingAgentId;
  String? _selectedShippingAgentName;
  late TextEditingController _doNumberController;
  late TextEditingController _feesController;
  late TextEditingController _paymentRefController;
  late TextEditingController _fileUrlController;
  late TextEditingController _notesController;

  DateTime _doDate = DateTime.now();
  late DateTime _doExpiryDate;
  int _freeDaysAllowed = 14;
  String _selectedCurrency = 'EGP';
  bool _isSubmitting = false;

  final List<String> _currencies = ['EGP', 'USD', 'EUR'];

  @override
  void initState() {
    super.initState();
    _doExpiryDate = DateTime.now().add(const Duration(days: 14));
    _doNumberController = TextEditingController(
      text: widget.file.deliveryOrderNo ?? '',
    );
    _feesController = TextEditingController(text: '12500');
    _paymentRefController = TextEditingController();
    _fileUrlController = TextEditingController();
    _notesController = TextEditingController();

    if (_doNumberController.text.trim().isEmpty) {
      _generateDONumber();
    }

    if (widget.file.targetFreeDays != null && widget.file.targetFreeDays! > 0) {
      _freeDaysAllowed = widget.file.targetFreeDays!;
      _doExpiryDate = _doDate.add(Duration(days: _freeDaysAllowed));
    }

    Future.microtask(() {
      ref.read(allPartnersProvider.notifier).fetchPartners();
    });
  }

  @override
  void dispose() {
    _doNumberController.dispose();
    _feesController.dispose();
    _paymentRefController.dispose();
    _fileUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _generateDONumber() {
    final year = DateTime.now().year;
    final randNum = 1000 + Random().nextInt(9000);
    String linePrefix = 'LINE';
    if (widget.file.customFileNumber != null && widget.file.customFileNumber!.isNotEmpty) {
      final clean = widget.file.customFileNumber!.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      if (clean.length >= 4) {
        linePrefix = clean.substring(0, 4).toUpperCase();
      }
    }
    setState(() {
      _doNumberController.text = 'DO-$linePrefix-$year-$randNum';
    });
  }

  void _updateFreeDays() {
    final diff = _doExpiryDate.difference(_doDate).inDays;
    setState(() {
      _freeDaysAllowed = diff > 0 ? diff : 0;
    });
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final fees = double.tryParse(_feesController.text.trim());
    if (fees == null || fees < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال قيمة صحيحة لرسوم التوكيل الملاحي'),
          backgroundColor: AppTheme.crimson,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'import_file_id': widget.file.importFileId,
        'delivery_order_number': _doNumberController.text.trim(),
        'delivery_order_date': _doDate.toIso8601String(),
        'delivery_order_expiry': _doExpiryDate.toIso8601String(),
        'free_days_allowed': _freeDaysAllowed,
        'shipping_agent_id': _selectedShippingAgentId,
        'shipping_agent_name': _selectedShippingAgentName,
        'delivery_order_fees': fees,
        'delivery_order_currency': _selectedCurrency,
        'delivery_order_payment_ref': _paymentRefController.text.trim(),
        'delivery_order_paid_at': _doDate.toIso8601String(),
        'delivery_order_file_url': _fileUrlController.text.trim().isEmpty
            ? null
            : _fileUrlController.text.trim(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };

      await ref
          .read(customsClearanceProvider.notifier)
          .recordDeliveryOrderPayment(payload);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تم تسجيل سداد مصاريف التوكيل واستلام إذن التسليم (${_doNumberController.text}) بنجاح!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.emerald,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في حفظ إذن التسليم: $e'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final partnersAsync = ref.watch(allPartnersProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0284C7), // Ocean / Shipping Blue
                borderRadius: BorderRadiusDirectional.only(
                  topStart: Radius.circular(16),
                  topEnd: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.directions_boat_filled_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'سداد إذن التسليم الملاحي واستلام D/O (CS-02)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الشحنة: ${widget.file.importFileCode} — ${widget.file.companyName}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status / Informative Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF0284C7).withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFF0284C7),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'المرحلة السادسة: الإعداد الجمركي (46)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'تسجيل سداد مصاريف التوكيل واستلام إذن التسليم (D/O) يرفع تقدم الشحنة لـ 83% ويُتيح فتح وقيد الإقرار الجمركي 46 ك.م.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Shipment Metadata Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (widget.file.customFileNumber != null && widget.file.customFileNumber!.isNotEmpty)
                            _buildInfoChip(Icons.folder_open_rounded, 'رقم الملف:', widget.file.customFileNumber!),
                          if (widget.file.supplierName.isNotEmpty)
                            _buildInfoChip(Icons.business_rounded, 'المورد:', widget.file.supplierName),
                          if (widget.file.portOfDischarge != null && widget.file.portOfDischarge!.isNotEmpty)
                            _buildInfoChip(Icons.anchor_rounded, 'ميناء الوصول:', widget.file.portOfDischarge!),
                          _buildInfoChip(
                            Icons.timelapse_rounded,
                            'فترة السماح:',
                            '$_freeDaysAllowed يوم',
                            color: _freeDaysAllowed <= 3 ? AppTheme.crimson : AppTheme.emerald,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'بيانات التوكيل الملاحي وإذن التسليم',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 20),

                      // Shipping Line Dropdown
                      partnersAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (err, _) => Text(
                          'خطأ في تحميل الشركاء: $err',
                          style: const TextStyle(color: AppTheme.crimson),
                        ),
                        data: (partners) {
                          final shippingLines = partners.where((p) {
                            final type = p.partnerType.toLowerCase();
                            return type.contains('shipping') ||
                                type.contains('line') ||
                                type.contains('agent') ||
                                type.contains('carrier') ||
                                type.contains('ملاح');
                          }).toList();

                          final availablePartners = shippingLines.isNotEmpty ? shippingLines : partners;

                          final items = availablePartners.map((p) {
                            return SearchableDropdownItem<int>(
                              value: p.providerId ?? 0,
                              label: p.partnerName,
                              subtitle: '${p.partnerType} • ${p.partnerCode}',
                              icon: Icons.directions_boat_filled_rounded,
                            );
                          }).toList();

                          return SearchableDropdownField<int>(
                            key: const Key('shippingAgentDropdown'),
                            value: _selectedShippingAgentId,
                            items: items,
                            labelText: 'التوكيل الملاحي / الخط الناقل *',
                            hintText: 'ابحث واختر التوكيل أو الخط الملاحي...',
                            searchHintText: 'ابحث باسم التوكيل أو الكود أو الخط...',
                            isRequired: true,
                            onChanged: (val) {
                              setState(() {
                                _selectedShippingAgentId = val;
                                final matched = availablePartners.firstWhere(
                                  (p) => p.providerId == val,
                                  orElse: () => availablePartners.first,
                                );
                                _selectedShippingAgentName = matched.partnerName;
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // DO Number with Generator
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('doNumberField'),
                              controller: _doNumberController,
                              decoration: InputDecoration(
                                labelText: 'رقم إذن التسليم الملاحي (D/O Number) *',
                                hintText: 'مثال: DO-MAEU-2026-8819',
                                prefixIcon: const Icon(Icons.confirmation_number_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'يرجى إدخال رقم إذن التسليم الملاحي';
                                }
                                if (val.trim().length < 3) {
                                  return 'رقم إذن التسليم يجب ألا يقل عن 3 أحرف/أرقام';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'توليد رقم إذن تسليم تلقائي',
                            child: ElevatedButton.icon(
                              onPressed: _generateDONumber,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('توليد'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // D/O Fee Amount & Currency
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              key: const Key('doFeesField'),
                              controller: _feesController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              decoration: InputDecoration(
                                labelText: 'مصاريف التوكيل الملاحي (D/O Fees) *',
                                hintText: '12500',
                                prefixIcon: const Icon(Icons.payments_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'يرجى إدخال قيمة مصاريف التوكيل';
                                }
                                final numVal = double.tryParse(val.trim());
                                if (numVal == null || numVal < 0) {
                                  return 'يرجى إدخال مبلغ صحيح';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: _selectedCurrency,
                              decoration: InputDecoration(
                                labelText: 'العملة',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: _currencies
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCurrency = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Payment Receipt No.
                      TextFormField(
                        key: const Key('paymentRefField'),
                        controller: _paymentRefController,
                        decoration: InputDecoration(
                          labelText: 'رقم إيصال أو مرجع سداد مصاريف التوكيل *',
                          hintText: 'مثال: RCPT-TXN-2026-9912 أو رقم التحويل البنكي',
                          prefixIcon: const Icon(Icons.receipt_long_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'يرجى إدخال رقم إيصال أو مرجع السداد';
                          }
                          if (val.trim().length < 2) {
                            return 'مرجع السداد يجب ألا يقل عن حرفين/رقمين';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Dates: Issue Date & Expiry Date
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _doDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _doDate = picked;
                                    _updateFreeDays();
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'تاريخ استلام الإذن *',
                                  prefixIcon: const Icon(Icons.calendar_today_rounded),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(
                                  '${_doDate.year}-${_doDate.month.toString().padLeft(2, '0')}-${_doDate.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _doExpiryDate,
                                  firstDate: _doDate,
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _doExpiryDate = picked;
                                    _updateFreeDays();
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'تاريخ انتهاء الصلاحية *',
                                  prefixIcon: const Icon(Icons.event_busy_rounded),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(
                                  '${_doExpiryDate.year}-${_doExpiryDate.month.toString().padLeft(2, '0')}-${_doExpiryDate.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Document File URL
                      TextFormField(
                        key: const Key('fileUrlField'),
                        controller: _fileUrlController,
                        decoration: InputDecoration(
                          labelText: 'رابط أو مسار صورة إذن التسليم المرفوع (اختياري)',
                          hintText: 'https://storage.sorourlogistics.com/docs/do_scan.pdf',
                          prefixIcon: const Icon(Icons.attach_file_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      TextFormField(
                        key: const Key('notesField'),
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'ملاحظات وتوجيهات الكشف الجمركي (اختياري)',
                          hintText: 'سداد غرامات التأخير إن وجدت، تنسيق النقل الداخلي مع المخلص...',
                          prefixIcon: const Icon(Icons.notes_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Dialog Actions Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadiusDirectional.only(
                  bottomStart: Radius.circular(16),
                  bottomEnd: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    key: const Key('submitDeliveryOrderBtn'),
                    onPressed: _isSubmitting ? null : _submitPayment,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: Text(
                      _isSubmitting ? 'جاري الحفظ والاعتماد...' : 'سداد واعتماد إذن التسليم (CS-02)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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

  Widget _buildInfoChip(IconData icon, String label, String value, {Color? color}) {
    final chipColor = color ?? const Color(0xFF0284C7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: chipColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
