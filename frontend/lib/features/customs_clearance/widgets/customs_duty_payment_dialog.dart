import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/localization/app_localizations.dart';

/// Modal dialog for CL-03: Customs Duty Payment Receipt
/// تسجيل سداد الرسوم الجمركية عبر سداد / E-Finance وإيصال السداد البنكي
class CustomsDutyPaymentDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;
  final CustomsClearanceModel? clearanceRecord;

  const CustomsDutyPaymentDialog({
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
      builder: (context) => CustomsDutyPaymentDialog(
        file: file,
        clearanceRecord: clearanceRecord,
      ),
    );
  }

  @override
  ConsumerState<CustomsDutyPaymentDialog> createState() =>
      _CustomsDutyPaymentDialogState();
}

class _CustomsDutyPaymentDialogState
    extends ConsumerState<CustomsDutyPaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _sadadNumberController;
  late TextEditingController _receiptNumberController;
  late TextEditingController _dutyPaidAmountController;
  late TextEditingController _receiptFileUrlController;
  late TextEditingController _notesController;

  // Codes (DomainEnumType.paymentMethod / dutyBank); labels follow the UI language.
  String _paymentMethod = 'SADAD_EFINANCE';
  String _bankName = 'NBE';
  DateTime _paymentDate = DateTime.now();
  bool _isSubmitting = false;

  // Codes first; a stored value that is not a known code/legacy label stays selectable.
  List<String> get _paymentMethods => [
        ...DomainEnums.codesOf(DomainEnumType.paymentMethod),
        if (!DomainEnums.isCode(DomainEnumType.paymentMethod, _paymentMethod)) _paymentMethod,
      ];

  List<String> get _bankNames => [
        ...DomainEnums.codesOf(DomainEnumType.dutyBank),
        if (!DomainEnums.isCode(DomainEnumType.dutyBank, _bankName)) _bankName,
      ];

  @override
  void initState() {
    super.initState();
    final rec = widget.clearanceRecord;
    final file = widget.file;

    // Prefill sadad number
    String initialSadad = rec?.sadadNumber ?? file.customsDutySadadNo ?? '';
    if (initialSadad.isEmpty) {
      initialSadad = 'SADAD-${DateTime.now().year}-${file.importFileId.toString().padLeft(4, '0')}';
    }
    _sadadNumberController = TextEditingController(text: initialSadad);

    // Prefill receipt number
    _receiptNumberController = TextEditingController(
      text: rec?.bankReceiptNo ?? file.customsDutyReceiptNo ?? '',
    );

    // Prefill duty paid amount
    double initialAmount = 0.0;
    if (rec != null && rec.actualDutyTotal > 0) {
      initialAmount = rec.actualDutyTotal;
    } else if (rec != null && rec.dutyPaidAmount > 0) {
      initialAmount = rec.dutyPaidAmount;
    } else if (rec != null && rec.estimatedDutyTotal > 0) {
      initialAmount = rec.estimatedDutyTotal;
    } else if (file.customsDutyPaidAmount > 0) {
      initialAmount = file.customsDutyPaidAmount;
    }
    _dutyPaidAmountController = TextEditingController(
      text: initialAmount > 0 ? initialAmount.toStringAsFixed(2) : '',
    );

    // Prefill payment method
    // Legacy rows hold the old ar/en label; map it to its code.
    final storedMethod = rec?.paymentMethod.trim() ?? '';
    if (storedMethod.isNotEmpty) {
      _paymentMethod = DomainEnums.initialCode(DomainEnumType.paymentMethod, storedMethod, storedMethod);
    }
    final storedBank = rec?.payingBankName?.trim() ?? '';
    if (storedBank.isNotEmpty) {
      _bankName = DomainEnums.initialCode(DomainEnumType.dutyBank, storedBank, storedBank);
    }

    _receiptFileUrlController = TextEditingController(
      text: rec?.receiptFileUrl ?? '',
    );

    _notesController = TextEditingController(
      text: rec?.notes ?? '',
    );

    if (rec?.paymentDate != null) {
      final parsed = DateTime.tryParse(rec!.paymentDate!);
      if (parsed != null) _paymentDate = parsed;
    } else if (file.customsDutyPaymentDate != null) {
      final parsed = DateTime.tryParse(file.customsDutyPaymentDate!);
      if (parsed != null) _paymentDate = parsed;
    }
  }

  @override
  void dispose() {
    _sadadNumberController.dispose();
    _receiptNumberController.dispose();
    _dutyPaidAmountController.dispose();
    _receiptFileUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
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
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _submitDutyPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_dutyPaidAmountController.text.trim());
      final payload = {
        'import_file_id': widget.file.importFileId,
        'clearance_id': widget.clearanceRecord?.clearanceId,
        'sadad_number': _sadadNumberController.text.trim(),
        'bank_receipt_no': _receiptNumberController.text.trim(),
        'payment_method': _paymentMethod,
        'payment_date': _paymentDate.toIso8601String(),
        'duty_paid_amount': amount,
        'paying_bank_name': _bankName,
        'receipt_file_url': _receiptFileUrlController.text.trim().isNotEmpty
            ? _receiptFileUrlController.text.trim()
            : null,
        'payment_notes': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      };

      await ref
          .read(customsClearanceProvider.notifier)
          .recordDutyPayment(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم تسجيل سداد الرسوم الجمركية بنجاح برقم سداد (${_sadadNumberController.text.trim()}) ومبلغ (${amount.toStringAsFixed(2)} ج.م). تم الانتقال للمرحلة التالية: إذن الإفراج النهائي (CL-04).',
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
            content: Text('حدث خطأ أثناء تسجيل سداد الرسوم: $e'),
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
    final claimNo = rec?.nafezaClaimNumber ?? '-';
    final assessedTotal = (rec != null && rec.actualDutyTotal > 0)
        ? rec.actualDutyTotal
        : (rec != null && rec.estimatedDutyTotal > 0)
            ? rec.estimatedDutyTotal
            : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            _buildDialogHeader(file, decl46, claimNo),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Financial Summary Banner
                      _buildFinancialSummaryBanner(assessedTotal),
                      const SizedBox(height: 20),

                      // Form Fields
                      _buildPaymentFormSection(),
                      const SizedBox(height: 20),

                      // Documentation & Receipt Attachment Section
                      _buildAttachmentAndNotesSection(),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            _buildDialogFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(ImportFileModel file, String decl46, String claimNo) {
    return Container(
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppTheme.emerald,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'سداد الرسوم والضرائب الجمركية عبر سداد / E-Finance (CL-03)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildHeaderChip(Icons.folder_outlined, file.importFileCode),
                    _buildHeaderChip(Icons.description_outlined, 'إقرار 46: $decl46'),
                    _buildHeaderChip(Icons.payment_outlined, 'مطالبة: $claimNo'),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'إغلاق',
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryBanner(double assessedTotal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // Light emerald tint
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: AppTheme.emerald, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إجمالي الرسوم المعتمدة بمطالبة نافذة MTS',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  assessedTotal > 0
                      ? '${assessedTotal.toStringAsFixed(2)} ج.م'
                      : 'في انتظار الاحتساب المالي',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.emerald,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.emerald,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_clock_rounded, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'مرحلة السداد المالي (CL-03)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentFormSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_rounded, size: 18, color: AppTheme.cobalt),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'بيانات السداد الإلكتروني والبنكي',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sadad Number
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'رقم سداد الإلكتروني (Sadad Number) *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('sadadNumberField'),
                      controller: _sadadNumberController,
                      decoration: InputDecoration(
                        hintText: 'مثال: SADAD-2026-0042',
                        prefixIcon: const Icon(Icons.pin_rounded, size: 18),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.autorenew_rounded, size: 18),
                          tooltip: 'توليد تلقائي',
                          onPressed: () {
                            setState(() {
                              _sadadNumberController.text =
                                  'SADAD-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'رقم سداد إلزامي' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Receipt Number
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'رقم إشعار / إيصال السداد البنكي *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('dutyReceiptNumberField'),
                      controller: _receiptNumberController,
                      decoration: InputDecoration(
                        hintText: 'مثال: REC-EFIN-998877',
                        prefixIcon: const Icon(Icons.receipt_rounded, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'رقم الإيصال إلزامي' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Duty Paid Amount
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'المبلغ المسدد فعلياً (ج.م) *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('dutyPaidAmountField'),
                      controller: _dutyPaidAmountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.payments_rounded, size: 18),
                        suffixText: 'ج.م',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'المبلغ المسدد إلزامي';
                        }
                        final val = double.tryParse(v.trim());
                        if (val == null || val <= 0) {
                          return 'يجب إدخال قيمة صحيحة أكبر من 0';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Payment Date Picker
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تاريخ السداد *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      key: const Key('dutyPaymentDatePicker'),
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded,
                                size: 18, color: AppTheme.cobalt),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_paymentDate.year}-${_paymentDate.month.toString().padLeft(2, '0')}-${_paymentDate.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down,
                                color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment Method
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'طريقة السداد *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: const Key('paymentMethodField'),
                      value: _paymentMethod,
                      isExpanded: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.credit_card_rounded, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _paymentMethods.map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text(DomainEnums.label(context.l10n, DomainEnumType.paymentMethod, m), style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _paymentMethod = v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Bank Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'البنك المسدد من خلاله *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: const Key('bankNameField'),
                      value: _bankName,
                      isExpanded: true,
                      decoration: InputDecoration(
                        prefixIcon:
                            const Icon(Icons.account_balance_outlined, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _bankNames.map((b) {
                        return DropdownMenuItem(
                          value: b,
                          child: Text(DomainEnums.label(context.l10n, DomainEnumType.dutyBank, b), style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _bankName = v);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentAndNotesSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.attachment_rounded, size: 18, color: AppTheme.cobalt),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'المرفقات والملاحظات الرقابية',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          // Receipt File URL / Reference
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'رابط أو مرجع ملف إيصال السداد الإلكتروني (Receipt File URL)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('receiptFileUrlField'),
                controller: _receiptFileUrlController,
                decoration: InputDecoration(
                  hintText: 'مثال: /uploads/receipts/sadad_rec_2026_01.pdf',
                  prefixIcon: const Icon(Icons.link_rounded, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Notes
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ملاحظات السداد والتحقق المالي',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('dutyPaymentNotesField'),
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'أي ملاحظات إضافية بخصوص إشعار السداد أو الخصم البنكي...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDialogFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('إلغاء'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              foregroundColor: AppTheme.charcoal,
              side: BorderSide(color: Colors.grey.shade400),
            ),
          ),
          ElevatedButton.icon(
            key: const Key('submitDutyPaymentBtn'),
            onPressed: _isSubmitting ? null : _submitDutyPayment,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.check_circle_rounded, size: 18),
            label: Text(
              _isSubmitting ? 'جاري الاعتماد...' : 'تأكيد وتسجيل سداد الرسوم (CL-03)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
