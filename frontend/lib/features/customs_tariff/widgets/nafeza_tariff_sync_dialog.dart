import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../providers/customs_tariff_provider.dart';

import 'tariff_form_dialog.dart';

void showNafezaTariffSyncDialog(BuildContext context, WidgetRef ref) {
  showTariffDialog(context, ref, initialModeIndex: 0);
}

class NafezaTariffSyncDialog extends ConsumerStatefulWidget {
  const NafezaTariffSyncDialog({super.key});

  @override
  ConsumerState<NafezaTariffSyncDialog> createState() => _NafezaTariffSyncDialogState();
}

class _NafezaTariffSyncDialogState extends ConsumerState<NafezaTariffSyncDialog> {
  final _rawTextController = TextEditingController(
    text: '''بند التعريفة: 8415.10.00.00
الوصف: أجهزة تكييف الهواء للجدران أو النوافذ
ضريبة الوارد: 30%
ضريبة القيمة المضافة: 14%
رسم التنمية: 5%
ضريبة الجدول: 8%
اتفاقية أغادير: 0%
الاتفاقية الأوروبية (مصر-الاتحاد الأوروبي): 0%
ملاحظات: يلزم موافقة مسبقة من الهيئة المصرية العامة للمواصفات والجودة (EOS).''',
  );

  bool _isSyncing = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _rawTextController.dispose();
    super.dispose();
  }

  Future<void> _syncNafezaText() async {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    if (_rawTextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'يرجى لصق نص صفحة نافذة' : 'Please paste Nafeza raw text')),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final payload = {'raw_text': _rawTextController.text.trim()};
      final res = await dio.post('/integrations/nafeza/tariffs/parse-and-sync', data: payload);

      if (mounted) {
        setState(() {
          _result = res.data is Map<String, dynamic> ? res.data : null;
          _isSyncing = false;
        });

        // Invalidate tariff providers to refresh UI live
        ref.invalidate(customsTariffProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emerald,
            content: Text(isArabic
                ? 'تم استخراج البيانات ومزامنة جدول التعريفة والاتفاقيات بنجاح ✅'
                : 'Data extracted and tariff schedule synced successfully ✅'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: Container(
          width: 820,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.sync_alt, color: AppTheme.cobalt, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic
                                ? 'محلل ومزامن نصوص نافذة الذكي'
                                : 'Smart Nafeza Tariff & FX Gateway',
                            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                          ),
                          Text(
                            isArabic
                                ? 'الصق النص الخام المنسوخ من موقع نافذة لاستخراج بنود الضرائب والاتفاقيات التفضيلية آلياً'
                                : 'Paste raw text copied from Nafeza portal to automatically extract tariff rates and agreements',
                            style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
                const SizedBox(height: 18),

                // Text Area Input
                TextFormField(
                  controller: _rawTextController,
                  maxLines: 7,
                  decoration: InputDecoration(
                    labelText: isArabic
                        ? 'النص المنسوخ من نافذة (بند التعريفة، الضرائب، الاتفاقيات)'
                        : 'Raw Nafeza Text (HS Code, Duties, Agreements)',
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),

                // Action button
                ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _syncNafezaText,
                  icon: _isSyncing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, color: Colors.white),
                  label: Text(
                    isArabic
                        ? 'تحليل النص ومزامنة جدول التعريفة والاتفاقيات التفضيلية'
                        : 'Parse Text & Sync Tariff Schedule and Preferential Agreements',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cobalt,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 18),

                // Results Card
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.crimson),
                    ),
                    child: Text(
                      isArabic ? '❌ خطأ في المعالجة: $_error' : '❌ Processing Error: $_error',
                      style: const TextStyle(color: AppTheme.crimson),
                    ),
                  )
                else if (_result != null)
                  _buildSyncResultCard(_result!, isArabic),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncResultCard(Map<String, dynamic> data, bool isArabic) {
    final hsCode = data['hs_code'] ?? '';
    final desc = data['description_ar'] ?? '';
    final duty = data['duty_rate_pct'] ?? 0;
    final vat = data['vat_rate_pct'] ?? 0;
    final sched = data['schedule_tax_rate_pct'] ?? 0;
    final dev = data['development_fee_rate_pct'] ?? 0;
    final agreements = (data['preferential_agreements'] as List<dynamic>?) ?? [];
    final approvals = (data['prior_approvals_required'] as List<dynamic>?) ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.emerald),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.emerald, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'تمت المزامنة بنجاح: بند التعريفة $hsCode' : 'Successfully Synced: HS Code $hsCode',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.emerald),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 20),
                tooltip: isArabic ? 'نسخ نتائج المزامنة' : 'Copy Sync Results',
                onPressed: () {
                  final text = isArabic
                      ? 'بند التعريفة: $hsCode\nالوصف: $desc\nضريبة الوارد: $duty%\nالقيمة المضافة: $vat%\nضريبة الجدول: $sched%\nرسم التنمية: $dev%\nالاتفاقيات: ${agreements.map((a) => "${a['agreement_name']}: ${a['duty_rate_pct']}%").join(", ")}'
                      : 'HS Code: $hsCode\nDescription: $desc\nImport Duty: $duty%\nVAT: $vat%\nSchedule Tax: $sched%\nDev Fee: $dev%\nAgreements: ${agreements.map((a) => "${a['agreement_name']}: ${a['duty_rate_pct']}%").join(", ")}';
                  CopyHelper.copy(
                    context,
                    text,
                    customMessage: isArabic
                        ? 'تم نسخ بيانات التعريفة الجمركية بنجاح!'
                        : 'Tariff details copied successfully!',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(fontSize: 13, color: AppTheme.charcoal, fontWeight: FontWeight.w500)),
          const Divider(height: 18),

          // Rates Row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildRateChip(isArabic ? 'ضريبة الوارد' : 'Import Duty', '$duty%'),
              _buildRateChip(isArabic ? 'القيمة المضافة' : 'VAT', '$vat%'),
              _buildRateChip(isArabic ? 'ضريبة الجدول' : 'Schedule Tax', '$sched%'),
              _buildRateChip(isArabic ? 'رسم التنمية' : 'Dev Fee', '$dev%'),
            ],
          ),
          const SizedBox(height: 12),

          // Agreements
          if (agreements.isNotEmpty) ...[
            Text(
              isArabic ? '🌐 الاتفاقيات التفضيلية المستخرجة:' : '🌐 Extracted Preferential Agreements:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 4),
            ...agreements.map((a) => Text(
              '• ${a['agreement_name']}: ${a['duty_rate_pct']}%',
              style: const TextStyle(fontSize: 12, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
            )),
          ],

          // Prior Approvals
          if (approvals.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              isArabic ? '🏛️ الجهات الرقابية والموافقات المسبقة المطلوبة:' : '🏛️ Regulatory Authorities & Prior Approvals:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 4),
            ...approvals.map((app) => Text('• $app', style: const TextStyle(fontSize: 12, color: AppTheme.crimson))),
          ],
        ],
      ),
    );
  }

  Widget _buildRateChip(String label, String rate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '$label: $rate',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
      ),
    );
  }
}
