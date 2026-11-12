import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../models/air_freight_models.dart';
import '../providers/air_freight_provider.dart';
import '../utils/air_weight_calculator.dart';

/// Draft AWB review of one record: enter the draft received from the airline / forwarder, run the server-side
/// comparison (checklist + blocking discrepancies) and approve or reject the latest version.
class DraftAwbReviewView extends ConsumerStatefulWidget {
  final AirShipmentRecord record;

  const DraftAwbReviewView({super.key, required this.record});

  @override
  ConsumerState<DraftAwbReviewView> createState() => _DraftAwbReviewViewState();
}

class _DraftAwbReviewViewState extends ConsumerState<DraftAwbReviewView> {
  final _formKey = GlobalKey<FormState>();
  final _awb = TextEditingController();
  final _shipper = TextEditingController();
  final _consignee = TextEditingController();
  final _origin = TextEditingController();
  final _destination = TextEditingController();
  final _pieces = TextEditingController();
  final _gross = TextEditingController();
  final _chargeable = TextEditingController();
  final _description = TextEditingController();
  bool _running = false;
  String? _deciding;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(draftAwbReviewsProvider(widget.record.id));
    });
  }

  @override
  void dispose() {
    for (final c in [_awb, _shipper, _consignee, _origin, _destination, _pieces, _gross, _chargeable, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  void _error(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ApiErrorText.of(context.l10n, e)), backgroundColor: AppTheme.crimson));
  }

  String? _text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _runReview() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _running = true);
    try {
      await ref.read(airFreightRepositoryProvider).createReview(widget.record.id, {
        'awb_number': _text(_awb),
        'shipper_name': _text(_shipper),
        'consignee_name': _text(_consignee),
        'origin_airport_code': _text(_origin),
        'destination_airport_code': _text(_destination),
        'pieces_count': int.tryParse(_pieces.text.trim()),
        'gross_weight_kg': double.tryParse(_gross.text.trim()),
        'chargeable_weight_kg': double.tryParse(_chargeable.text.trim()),
        'goods_description': _text(_description),
      });
      ref.invalidate(draftAwbReviewsProvider(widget.record.id));
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _decide(DraftAwbReview review, String decision) async {
    setState(() => _deciding = decision);
    try {
      await ref.read(airFreightRepositoryProvider).decideReview(review.id, decision);
      ref.invalidate(draftAwbReviewsProvider(widget.record.id));
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _deciding = null);
    }
  }

  String? _number(String? v, {bool integer = false}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = integer ? int.tryParse(t)?.toDouble() : double.tryParse(t);
    return n == null || n < 0 ? 'قيمة رقمية غير صحيحة' : null;
  }

  @override
  Widget build(BuildContext context) {
    final reviews = ref.watch(draftAwbReviewsProvider(widget.record.id));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 380, child: _draftForm()),
        const VerticalDivider(width: 1),
        Expanded(
          child: reviews.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(ApiErrorText.of(context.l10n, e), style: const TextStyle(color: AppTheme.crimson)),
            ),
            data: (list) => list.isEmpty
                ? const Center(child: Text('لم تتم مراجعة أي مسودة لهذه البوليصة بعد.'))
                : _reviewResult(list.first, list.length),
          ),
        ),
      ],
    );
  }

  Widget _draftForm() {
    Widget gap() => const SizedBox(height: 10);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('بيانات مسودة البوليصة الواردة', style: TextStyle(fontWeight: FontWeight.bold)),
          gap(),
          CustomTextField(
            controller: _awb,
            label: 'رقم البوليصة',
            isRequired: true,
            textDirection: TextDirection.ltr,
            validator: (v) {
              if ((v ?? '').trim().isEmpty) return 'رقم البوليصة مطلوب';
              return AwbNumber.validationCode(v) == null ? null : 'رقم البوليصة غير صحيح (11 رقماً مع رقم تحقق)';
            },
          ),
          gap(),
          CustomTextField(controller: _shipper, label: 'الشاحن (Shipper)'),
          gap(),
          CustomTextField(controller: _consignee, label: 'المرسل إليه (Consignee)'),
          gap(),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _origin,
                  label: 'مطار القيام (CAI / EGCAI)',
                  textDirection: TextDirection.ltr,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomTextField(
                  controller: _destination,
                  label: 'مطار الوصول',
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ),
          gap(),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _pieces,
                  label: 'عدد الطرود',
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.number,
                  validator: (v) => _number(v, integer: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomTextField(
                  controller: _gross,
                  label: 'الوزن القائم (كجم)',
                  textDirection: TextDirection.ltr,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _number,
                ),
              ),
            ],
          ),
          gap(),
          CustomTextField(
            controller: _chargeable,
            label: 'الوزن المحاسب في المسودة (كجم)',
            textDirection: TextDirection.ltr,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: _number,
          ),
          gap(),
          CustomTextField(controller: _description, label: 'وصف البضاعة', maxLines: 2),
          gap(),
          AppButton(
            label: 'تشغيل المراجعة والمقارنة',
            icon: Icons.fact_check,
            isLoading: _running,
            onPressed: _running ? null : _runReview,
          ),
        ],
      ),
    );
  }

  Widget _reviewResult(DraftAwbReview review, int versions) {
    final (color, label) = switch (review.status) {
      'APPROVED' => (AppTheme.emerald, 'معتمدة'),
      'REJECTED' => (AppTheme.crimson, 'مرفوضة'),
      'REVISION_REQUIRED' => (AppTheme.crimson, 'تحتاج تصحيح (${review.openDiscrepanciesCount} اختلاف جوهري)'),
      _ => (AppTheme.cobalt, 'تمت المراجعة — بانتظار الاعتماد'),
    };
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Text(
              '${review.code} — الإصدار ${review.versionNumber} من $versions',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Chip(
              label: Text(label, style: const TextStyle(color: AppTheme.cloudWhite)),
              backgroundColor: color,
            ),
            const Spacer(),
            if (!review.isDecided) ...[
              AppButton(
                label: 'رفض',
                variant: AppButtonVariant.secondary,
                isLoading: _deciding == 'REJECT',
                onPressed: _deciding != null ? null : () => _decide(review, 'REJECT'),
              ),
              const SizedBox(width: 8),
              AppButton(
                label: 'اعتماد',
                icon: Icons.verified,
                isLoading: _deciding == 'APPROVE',
                onPressed: _deciding != null || review.hasBlockingMismatch ? null : () => _decide(review, 'APPROVE'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        DataTable(
          columns: const [
            DataColumn(label: Text('البند')),
            DataColumn(label: Text('النتيجة')),
            DataColumn(label: Text('في المسودة')),
            DataColumn(label: Text('في سجل الشحنة')),
          ],
          rows: [
            for (final item in review.checklist)
              DataRow(
                cells: [
                  DataCell(Text(awbCheckLabelsAr[item.check] ?? item.check)),
                  DataCell(_statusBadge(item)),
                  DataCell(Text(item.draftValue ?? '-')),
                  DataCell(Text(item.systemValue ?? '-')),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _statusBadge(AwbChecklistItem item) {
    final (color, icon, text) = switch (item.status) {
      'MATCH' => (AppTheme.emerald, Icons.check_circle, 'مطابق'),
      'MISSING' => (AppTheme.crimson, Icons.help_outline, 'غير موجود'),
      'MISMATCH' => (AppTheme.crimson, Icons.cancel, 'غير مطابق'),
      _ => (AppTheme.orange, Icons.warning_amber, 'تنبيه'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 4),
        Text(item.blocking ? '$text (يمنع الاعتماد)' : text, style: TextStyle(color: color)),
      ],
    );
  }
}
