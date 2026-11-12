import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../models/air_freight_models.dart';
import '../providers/air_freight_provider.dart';
import 'awb_record_form_dialog.dart';
import 'draft_awb_review_view.dart';

/// Air freight workspace of one import file: AWB records (weights, airport storage counter) and the draft AWB
/// review of the selected record. Hosted by the Multimodal Freight screen (route 82, Air mode).
class AirFreightPanel extends ConsumerStatefulWidget {
  final int importFileId;

  const AirFreightPanel({super.key, required this.importFileId});

  @override
  ConsumerState<AirFreightPanel> createState() => _AirFreightPanelState();
}

class _AirFreightPanelState extends ConsumerState<AirFreightPanel> {
  int? _selectedRecordId;

  @override
  void initState() {
    super.initState();
    // Live reload on mount (no stale cache when the user comes back to the screen).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(airShipmentRecordsProvider(widget.importFileId));
    });
  }

  Future<void> _openForm([AirShipmentRecord? record]) async {
    final saved = await AwbRecordFormDialog.show(context, importFileId: widget.importFileId, record: record);
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ بيانات البوليصة الجوية')));
    }
  }

  Future<void> _delete(AirShipmentRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف البوليصة الجوية'),
        content: Text('سيتم حذف السجل ${record.code} (حذف منطقي يمكن استرجاعه). هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(airFreightRepositoryProvider).deleteRecord(record.id);
      if (_selectedRecordId == record.id) setState(() => _selectedRecordId = null);
      ref.invalidate(airShipmentRecordsProvider(widget.importFileId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiErrorText.of(context.l10n, e)), backgroundColor: AppTheme.crimson));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(airShipmentRecordsProvider(widget.importFileId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(ApiErrorText.of(context.l10n, e), style: const TextStyle(color: AppTheme.crimson)),
      ),
      data: (records) {
        final selected = records.where((r) => r.id == _selectedRecordId).firstOrNull ?? records.firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'بوالص الشحن الجوي (${records.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  AppButton(label: 'بوليصة جديدة', icon: Icons.add, onPressed: () => _openForm()),
                ],
              ),
            ),
            if (records.isEmpty)
              const Expanded(child: Center(child: Text('لا توجد بوالص شحن جوي مسجلة لهذا الملف بعد.')))
            else
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      SizedBox(height: 210, child: _recordsTable(records, selected)),
                      const TabBar(
                        tabs: [
                          Tab(icon: Icon(Icons.fact_check_outlined), text: 'مراجعة مسودة البوليصة'),
                          Tab(icon: Icon(Icons.warehouse_outlined), text: 'التخزين بالمطار'),
                        ],
                      ),
                      Expanded(
                        child: selected == null
                            ? const SizedBox.shrink()
                            : TabBarView(
                                children: [
                                  DraftAwbReviewView(record: selected),
                                  _storageCard(selected),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _recordsTable(List<AirShipmentRecord> records, AirShipmentRecord? selected) {
    String kg(double? v) => v == null ? '-' : '${v.toStringAsFixed(2)} kg';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('الكود')),
            DataColumn(label: Text('MAWB')),
            DataColumn(label: Text('النمط')),
            DataColumn(label: Text('الرحلة')),
            DataColumn(label: Text('الطرود')),
            DataColumn(label: Text('القائم')),
            DataColumn(label: Text('الحجمي')),
            DataColumn(label: Text('المحاسب')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final r in records)
              DataRow(
                selected: r.id == selected?.id,
                onSelectChanged: (_) => setState(() => _selectedRecordId = r.id),
                cells: [
                  DataCell(Text(r.code)),
                  DataCell(Text(r.displayAwb, textDirection: TextDirection.ltr)),
                  DataCell(Text(r.shipmentMode == 'COURIER' ? 'بريد سريع' : 'جوي')),
                  DataCell(Text(r.flightNumber ?? '-', textDirection: TextDirection.ltr)),
                  DataCell(Text('${r.piecesCount ?? '-'}')),
                  DataCell(Text(kg(r.grossWeightKg), textDirection: TextDirection.ltr)),
                  DataCell(Text(kg(r.volumetricWeightKg), textDirection: TextDirection.ltr)),
                  DataCell(
                    Text(
                      kg(r.chargeableWeightKg),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'تعديل',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openForm(r),
                        ),
                        IconButton(
                          tooltip: 'حذف',
                          icon: const Icon(Icons.delete_outline, color: AppTheme.crimson),
                          onPressed: () => _delete(r),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _storageCard(AirShipmentRecord record) {
    final s = record.storage;
    if (s == null || s.status == 'NOT_STARTED') {
      return const Center(child: Text('لم يبدأ احتساب التخزين بالمطار بعد (أدخل تاريخ بداية التخزين).'));
    }
    final (color, text) = switch (s.status) {
      'FREE' => (AppTheme.emerald, 'متبقي ${s.daysRemaining} يوم من فترة التخزين المجانية'),
      'LAST_DAY' => (AppTheme.orange, 'اليوم هو آخر يوم تخزين مجاني'),
      _ => (AppTheme.crimson, 'تجاوز فترة التخزين المجانية بـ ${s.chargeableDays} يوم (أيام مستحقة الرسوم)'),
    };
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined, color: color, size: 40),
              const SizedBox(height: 8),
              Text(
                text,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text('أيام التخزين المجانية: ${s.freeDays} — حتى ${isoDate(s.freeUntil) ?? '-'}'),
            ],
          ),
        ),
      ),
    );
  }
}
