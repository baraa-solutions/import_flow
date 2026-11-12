import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_date_picker_field.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../models/air_freight_models.dart';
import '../providers/air_freight_provider.dart';
import '../utils/air_weight_calculator.dart';

/// Create / edit one Air Waybill record. Airline and airports come from master data (searchable dropdowns);
/// the chargeable weight preview is recomputed locally while typing and authoritatively by the server on save.
class AwbRecordFormDialog extends ConsumerStatefulWidget {
  final int importFileId;
  final AirShipmentRecord? record;

  const AwbRecordFormDialog({super.key, required this.importFileId, this.record});

  static Future<bool?> show(BuildContext context, {required int importFileId, AirShipmentRecord? record}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AwbRecordFormDialog(importFileId: importFileId, record: record),
    );
  }

  @override
  ConsumerState<AwbRecordFormDialog> createState() => _AwbRecordFormDialogState();
}

class _PackageRow {
  final TextEditingController length = TextEditingController();
  final TextEditingController width = TextEditingController();
  final TextEditingController height = TextEditingController();
  final TextEditingController quantity = TextEditingController(text: '1');
  final TextEditingController gross = TextEditingController();
  String dimensionUnit = 'cm';
  String weightUnit = 'kg';

  _PackageRow();

  _PackageRow.from(AirPackageInput p) {
    length.text = _fmt(p.length);
    width.text = _fmt(p.width);
    height.text = _fmt(p.height);
    quantity.text = '${p.quantity}';
    gross.text = p.grossWeight == 0 ? '' : _fmt(p.grossWeight);
    dimensionUnit = p.dimensionUnit;
    weightUnit = p.weightUnit;
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  AirPackageInput toInput() => AirPackageInput(
    length: double.tryParse(length.text) ?? 0,
    width: double.tryParse(width.text) ?? 0,
    height: double.tryParse(height.text) ?? 0,
    dimensionUnit: dimensionUnit,
    quantity: int.tryParse(quantity.text) ?? 1,
    grossWeight: double.tryParse(gross.text) ?? 0,
    weightUnit: weightUnit,
  );

  void dispose() {
    for (final c in [length, width, height, quantity, gross]) {
      c.dispose();
    }
  }
}

class _AwbRecordFormDialogState extends ConsumerState<AwbRecordFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _mode = widget.record?.shipmentMode ?? 'AIR';
  late String? _subMode = widget.record?.shipmentSubMode;
  late int? _airlineId = widget.record?.airlineId;
  late int? _originId = widget.record?.originAirportId;
  late int? _destinationId = widget.record?.destinationAirportId;
  late DateTime? _flightDate = widget.record?.flightDate;
  late DateTime? _arrivalDate = widget.record?.arrivalDate;
  late DateTime? _storageStart = widget.record?.airportStorageStartDate;
  late final _mawb = TextEditingController(text: widget.record?.mawbNumber == null ? '' : widget.record!.displayAwb);
  late final _hawb = TextEditingController(text: widget.record?.hawbNumber ?? '');
  late final _flight = TextEditingController(text: widget.record?.flightNumber ?? '');
  late final _gross = TextEditingController(text: widget.record?.grossWeightKg?.toString() ?? '');
  late final _pieces = TextEditingController(text: widget.record?.piecesCount?.toString() ?? '');
  late final _release = TextEditingController(text: widget.record?.airReleaseNo ?? '');
  late final _freeDays = TextEditingController(text: widget.record?.freeStorageDays?.toString() ?? '');
  late final _description = TextEditingController(text: widget.record?.goodsDescription ?? '');
  late final _notes = TextEditingController(text: widget.record?.notes ?? '');
  late final List<_PackageRow> _packages = widget.record?.packageLines.map(_PackageRow.from).toList() ?? [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Master data is reloaded live each time the dialog opens (no stale cache).
    ref.invalidate(airportOptionsProvider);
    ref.invalidate(airlineOptionsProvider);
    _gross.addListener(_refreshPreview);
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_mawb, _hawb, _flight, _gross, _pieces, _release, _freeDays, _description, _notes]) {
      c.dispose();
    }
    for (final p in _packages) {
      p.dispose();
    }
    super.dispose();
  }

  /// The stored divisor while the mode is unchanged; otherwise the standard one of the selected mode
  /// (the server applies the configured value on save).
  double get _divisor {
    final record = widget.record;
    if (record != null && record.shipmentMode == _mode && record.volumetricDivisor != null) {
      return record.volumetricDivisor!;
    }
    return _mode == 'COURIER' ? 5000 : 6000;
  }

  ChargeableWeightPreview get _preview => AirWeightCalculator.calculate(
    _packages.map((p) => p.toInput()).toList(),
    divisor: _divisor,
    totalGrossKg: double.tryParse(_gross.text),
  );

  String? _optionalNumber(String? v, {bool integer = false}) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null;
    final value = integer ? int.tryParse(text)?.toDouble() : double.tryParse(text);
    if (value == null || value < 0) return 'قيمة رقمية غير صحيحة';
    return null;
  }

  Map<String, dynamic> _payload() {
    String? text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    return {
      if (widget.record == null) 'import_file_id': widget.importFileId,
      'shipment_mode': _mode,
      'shipment_sub_mode': _subMode,
      'mawb_number': text(_mawb),
      'hawb_number': text(_hawb),
      'airline_id': _airlineId,
      'origin_airport_id': _originId,
      'destination_airport_id': _destinationId,
      'flight_number': text(_flight),
      'flight_date': isoDate(_flightDate),
      'arrival_date': isoDate(_arrivalDate),
      'pieces_count': int.tryParse(_pieces.text.trim()),
      'gross_weight_kg': double.tryParse(_gross.text.trim()),
      'package_lines': _packages.map((p) => p.toInput().toJson()).toList(),
      'air_release_no': text(_release),
      'airport_storage_start_date': isoDate(_storageStart),
      'free_storage_days': int.tryParse(_freeDays.text.trim()),
      'goods_description': text(_description),
      'notes': text(_notes),
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(airFreightRepositoryProvider);
    try {
      if (widget.record == null) {
        await repo.createRecord(_payload());
      } else {
        await repo.updateRecord(widget.record!.id, _payload());
      }
      ref.invalidate(airShipmentRecordsProvider(widget.importFileId));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiErrorText.of(context.l10n, e)), backgroundColor: AppTheme.crimson));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<SearchableDropdownItem<int>> _items(AsyncValue<List<AirMasterOption>> async) =>
      (async.asData?.value ?? const <AirMasterOption>[])
          .map((o) => SearchableDropdownItem<int>(value: o.id, label: o.label, subtitle: o.subtitle))
          .toList();

  Widget _row(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: children[i]),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final airports = _items(ref.watch(airportOptionsProvider));
    final airlines = _items(ref.watch(airlineOptionsProvider));
    final preview = _preview;
    final subModes = airSubModes[_mode] ?? const <String>[];

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flight_land, color: AppTheme.cobalt),
                title: Text(widget.record == null ? 'تسجيل بوليصة شحن جوي (AWB)' : 'تعديل ${widget.record!.code}'),
                subtitle: const Text(
                  'الوزن المحاسب = الأكبر بين الوزن القائم والوزن الحجمي (الطول × العرض × الارتفاع ÷ المعامل)',
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'AIR', label: Text('شحن جوي'), icon: Icon(Icons.flight)),
                            ButtonSegment(value: 'COURIER', label: Text('بريد سريع'), icon: Icon(Icons.local_shipping)),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (s) => setState(() {
                            _mode = s.first;
                            if (!(airSubModes[_mode] ?? const []).contains(_subMode)) _subMode = null;
                          }),
                        ),
                      ),
                      _row([
                        SearchableDropdownField<String>(
                          value: _subMode,
                          labelText: 'النمط الفرعي',
                          items: subModes
                              .map(
                                (s) => SearchableDropdownItem(value: s, label: subModeLabelsAr[s] ?? s, searchValue: s),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _subMode = v),
                        ),
                        SearchableDropdownField<int>(
                          value: _airlineId,
                          labelText: 'شركة الطيران / الناقل',
                          items: airlines,
                          onChanged: (v) => setState(() => _airlineId = v),
                        ),
                      ]),
                      _row([
                        CustomTextField(
                          controller: _mawb,
                          label: 'رقم البوليصة الرئيسية (MAWB)',
                          hint: '176-12345675',
                          textDirection: TextDirection.ltr,
                          validator: (v) => switch (AwbNumber.validationCode(v)) {
                            'AIR_AWB_FORMAT_INVALID' => 'يجب أن يتكون من 11 رقماً (3 أرقام كود الناقل + 8 أرقام)',
                            'AIR_AWB_CHECK_DIGIT_INVALID' => 'رقم التحقق (الخانة الأخيرة) غير صحيح',
                            _ => null,
                          },
                        ),
                        CustomTextField(
                          controller: _hawb,
                          label: 'رقم البوليصة الفرعية (HAWB)',
                          textDirection: TextDirection.ltr,
                        ),
                      ]),
                      _row([
                        SearchableDropdownField<int>(
                          value: _originId,
                          labelText: 'مطار القيام',
                          items: airports,
                          onChanged: (v) => setState(() => _originId = v),
                        ),
                        SearchableDropdownField<int>(
                          value: _destinationId,
                          labelText: 'مطار الوصول',
                          items: airports,
                          onChanged: (v) => setState(() => _destinationId = v),
                          validator: (v) =>
                              v != null && v == _originId ? 'مطار الوصول لا يمكن أن يكون نفس مطار القيام' : null,
                        ),
                      ]),
                      _row([
                        CustomTextField(controller: _flight, label: 'رقم الرحلة', textDirection: TextDirection.ltr),
                        AppDatePickerField(
                          label: 'تاريخ الرحلة',
                          value: _flightDate,
                          onChanged: (d) => setState(() => _flightDate = d),
                        ),
                        AppDatePickerField(
                          label: 'تاريخ الوصول',
                          value: _arrivalDate,
                          onChanged: (d) => setState(() => _arrivalDate = d),
                          validator: (d) => d != null && _flightDate != null && d.isBefore(_flightDate!)
                              ? 'تاريخ الوصول يسبق تاريخ الرحلة'
                              : null,
                        ),
                      ]),
                      _row([
                        CustomTextField(
                          controller: _gross,
                          label: 'الوزن القائم الإجمالي (كجم)',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textDirection: TextDirection.ltr,
                          validator: _optionalNumber,
                        ),
                        CustomTextField(
                          controller: _pieces,
                          label: 'عدد الطرود',
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          validator: (v) => _optionalNumber(v, integer: true),
                        ),
                      ]),
                      _buildPackages(),
                      _buildPreview(preview),
                      const SizedBox(height: 12),
                      _row([
                        CustomTextField(controller: _release, label: 'رقم إذن الإفراج من المطار'),
                        AppDatePickerField(
                          label: 'بداية التخزين بالمطار',
                          value: _storageStart,
                          onChanged: (d) => setState(() => _storageStart = d),
                        ),
                        CustomTextField(
                          controller: _freeDays,
                          label: 'أيام التخزين المجانية (فارغ = الافتراضي)',
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          validator: (v) => _optionalNumber(v, integer: true),
                        ),
                      ]),
                      CustomTextField(controller: _description, label: 'وصف البضاعة', maxLines: 2),
                      const SizedBox(height: 12),
                      CustomTextField(controller: _notes, label: 'ملاحظات', maxLines: 2),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: 'إلغاء',
                      variant: AppButtonVariant.secondary,
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 8),
                    AppButton(label: 'حفظ', icon: Icons.save, isLoading: _saving, onPressed: _saving ? null : _save),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackages() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('أبعاد الطرود (لحساب الوزن الحجمي)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة سطر'),
                  onPressed: () => setState(() => _packages.add(_PackageRow())),
                ),
              ],
            ),
            for (var i = 0; i < _packages.length; i++) _buildPackageRow(i),
          ],
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, {bool integer = false}) => TextFormField(
    controller: c,
    textDirection: TextDirection.ltr,
    keyboardType: TextInputType.numberWithOptions(decimal: !integer),
    decoration: InputDecoration(labelText: label, isDense: true),
    onChanged: (_) => setState(() {}),
    validator: (v) {
      final value = integer ? int.tryParse(v ?? '')?.toDouble() : double.tryParse(v ?? '');
      if (value == null) return 'مطلوب';
      if (integer ? value < 1 : value < 0) return 'غير صحيح';
      return null;
    },
  );

  Widget _buildPackageRow(int index) {
    final p = _packages[index];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _numField(p.length, 'الطول')),
          const SizedBox(width: 6),
          Expanded(child: _numField(p.width, 'العرض')),
          const SizedBox(width: 6),
          Expanded(child: _numField(p.height, 'الارتفاع')),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: p.dimensionUnit,
            items: const ['mm', 'cm', 'm'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
            onChanged: (u) => setState(() => p.dimensionUnit = u ?? 'cm'),
          ),
          const SizedBox(width: 6),
          Expanded(child: _numField(p.quantity, 'العدد', integer: true)),
          const SizedBox(width: 6),
          Expanded(
            child: TextFormField(
              controller: p.gross,
              textDirection: TextDirection.ltr,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'وزن الطرد', isDense: true),
              onChanged: (_) => setState(() {}),
              validator: (v) => _optionalNumber(v),
            ),
          ),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: p.weightUnit,
            items: const ['kg', 'lb'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
            onChanged: (u) => setState(() => p.weightUnit = u ?? 'kg'),
          ),
          IconButton(
            tooltip: 'حذف السطر',
            icon: const Icon(Icons.delete_outline, color: AppTheme.crimson),
            onPressed: () => setState(() => _packages.removeAt(index).dispose()),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(ChargeableWeightPreview preview) {
    Widget metric(String label, String value, {bool highlight = false}) => Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.charcoal)),
          const SizedBox(height: 4),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: highlight ? 18 : 14,
              color: highlight ? AppTheme.cobalt : AppTheme.charcoal,
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cobaltLight,
        border: Border.all(color: AppTheme.cobaltBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          metric('الوزن القائم', '${preview.grossKg} kg'),
          metric('الحجم', '${preview.volumeCbm} CBM'),
          metric('الوزن الحجمي (÷${_divisor.toStringAsFixed(0)})', '${preview.volumetricKg} kg'),
          metric(
            preview.isVolumetricBasis ? 'المحاسب (حجمي)' : 'المحاسب (قائم)',
            '${preview.chargeableKg} kg',
            highlight: true,
          ),
        ],
      ),
    );
  }
}
