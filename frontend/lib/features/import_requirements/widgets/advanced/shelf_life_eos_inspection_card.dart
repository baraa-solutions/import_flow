import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';

/// ⏳ Shelf Life & Egyptian Standards (EOS) Inspection Card
///
/// Conditional inspection for commodities subject to expiration dates, ensuring
/// compliance with the 50% remaining shelf-life threshold upon port arrival,
/// Egyptian Organization for Standardization (EOS) specifications, and Arabic packaging labels.
class ShelfLifeEosInspectionCard extends StatefulWidget {
  final bool initialSubjectToShelfLife;
  final String? initialEosSpecNumber;
  final DateTime? initialProductionDate;
  final DateTime? initialExpiryDate;
  final DateTime? initialEtaDate;
  final String? initialBatchNumber;
  final bool initialArabicLabelingCompliant;
  final String? initialComplianceStatus;
  final bool readOnly;
  final ValueChanged<ShelfLifeEosData>? onChanged;

  const ShelfLifeEosInspectionCard({
    super.key,
    this.initialSubjectToShelfLife = false,
    this.initialEosSpecNumber,
    this.initialProductionDate,
    this.initialExpiryDate,
    this.initialEtaDate,
    this.initialBatchNumber,
    this.initialArabicLabelingCompliant = false,
    this.initialComplianceStatus = 'Obtained',
    this.readOnly = false,
    this.onChanged,
  });

  @override
  State<ShelfLifeEosInspectionCard> createState() => _ShelfLifeEosInspectionCardState();
}

class ShelfLifeEosData {
  final bool isSubjectToShelfLife;
  final String eosSpecNumber;
  final DateTime? productionDate;
  final DateTime? expiryDate;
  final DateTime? etaDate;
  final String batchNumber;
  final bool isArabicLabelingCompliant;
  final String complianceStatus;
  final double remainingRatioPercent;

  const ShelfLifeEosData({
    required this.isSubjectToShelfLife,
    required this.eosSpecNumber,
    this.productionDate,
    this.expiryDate,
    this.etaDate,
    required this.batchNumber,
    required this.isArabicLabelingCompliant,
    required this.complianceStatus,
    required this.remainingRatioPercent,
  });

  bool get isCompliant =>
      !isSubjectToShelfLife ||
      (remainingRatioPercent >= 50.0 && isArabicLabelingCompliant);
}

class _ShelfLifeEosInspectionCardState extends State<ShelfLifeEosInspectionCard> {
  late bool _isSubject;
  late final TextEditingController _eosSpecCtrl;
  late final TextEditingController _batchCtrl;
  DateTime? _productionDate;
  DateTime? _expiryDate;
  DateTime? _etaDate;
  late bool _isArabicLabeling;
  late String _complianceStatus;

  @override
  void initState() {
    super.initState();
    _isSubject = widget.initialSubjectToShelfLife;
    _eosSpecCtrl = TextEditingController(text: widget.initialEosSpecNumber ?? '');
    _batchCtrl = TextEditingController(text: widget.initialBatchNumber ?? '');
    _productionDate = widget.initialProductionDate;
    _expiryDate = widget.initialExpiryDate;
    _etaDate = widget.initialEtaDate ?? DateTime.now().add(const Duration(days: 15));
    _isArabicLabeling = widget.initialArabicLabelingCompliant;
    _complianceStatus = widget.initialComplianceStatus ?? 'Obtained';
  }

  @override
  void dispose() {
    _eosSpecCtrl.dispose();
    _batchCtrl.dispose();
    super.dispose();
  }

  double _calculateRemainingRatio() {
    if (_productionDate == null || _expiryDate == null) return 100.0;
    final totalDays = _expiryDate!.difference(_productionDate!).inDays;
    if (totalDays <= 0) return 0.0;
    final refDate = _etaDate ?? DateTime.now();
    final remainingDays = _expiryDate!.difference(refDate).inDays;
    if (remainingDays <= 0) return 0.0;
    final ratio = (remainingDays / totalDays) * 100.0;
    return ratio > 100.0 ? 100.0 : ratio;
  }

  void _notifyChange() {
    widget.onChanged?.call(
      ShelfLifeEosData(
        isSubjectToShelfLife: _isSubject,
        eosSpecNumber: _eosSpecCtrl.text.trim(),
        productionDate: _productionDate,
        expiryDate: _expiryDate,
        etaDate: _etaDate,
        batchNumber: _batchCtrl.text.trim(),
        isArabicLabelingCompliant: _isArabicLabeling,
        complianceStatus: _complianceStatus,
        remainingRatioPercent: _calculateRemainingRatio(),
      ),
    );
  }

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    if (widget.readOnly) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() => onPicked(picked));
      _notifyChange();
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppTheme.isDark(context);
    final remainingRatio = _calculateRemainingRatio();
    final isCompliant = !_isSubject || remainingRatio >= 50.0;

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.charcoalSurface : AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !_isSubject
                ? AppTheme.cloudWhite
                : (isCompliant ? AppTheme.emerald.withValues(alpha: 0.5) : AppTheme.crimson.withValues(alpha: 0.6)),
            width: _isSubject ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isSubject
                          ? (isCompliant
                              ? AppTheme.emerald.withValues(alpha: 0.12)
                              : AppTheme.crimson.withValues(alpha: 0.12))
                          : AppTheme.cobalt.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.schedule_outlined,
                      color: _isSubject
                          ? (isCompliant ? AppTheme.emerald : AppTheme.crimson)
                          : AppTheme.cobalt,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.shelfLifeEosHeader,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.white : AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.shelfLifeEosSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isSubject) ...[
                    const SizedBox(width: 8),
                    AppStatusBadge(
                      label: isCompliant
                          ? l10n.shelfLifeCompliantBadge
                          : l10n.shelfLifeCriticalWarningBadge,
                      severity: isCompliant ? AppSeverity.success : AppSeverity.danger,
                      icon: isCompliant ? Icons.check_circle : Icons.warning_amber_rounded,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 14),

              // Subject Checkbox Toggle
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.charcoal : AppTheme.cloudWhite.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    dense: true,
                    title: Text(
                      l10n.shelfLifeSubjectCheckbox,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    value: _isSubject,
                    onChanged: widget.readOnly
                        ? null
                        : (v) {
                            setState(() => _isSubject = v ?? false);
                            _notifyChange();
                          },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ),

              if (_isSubject) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Spec Number & Compliance Status Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _eosSpecCtrl,
                        readOnly: widget.readOnly,
                        onChanged: (_) => _notifyChange(),
                        decoration: InputDecoration(
                          labelText: l10n.shelfLifeEosSpecLabel,
                          hintText: 'EOS XXXX',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.bookmark_outline, size: 18, color: AppTheme.cobalt),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: l10n.shelfLifeCopyBatchTooltip,
                            onPressed: () => CopyHelper.copy(
                              context,
                              _eosSpecCtrl.text,
                              customMessage: l10n.shelfLifeBatchCopiedSuccess,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SearchableDropdownField<String>(
                        labelText: l10n.shelfLifeEosCertStatusLabel,
                        value: _complianceStatus,
                        items: const [
                          SearchableDropdownItem(value: 'Obtained', label: 'معتمد ومستوفى'),
                          SearchableDropdownItem(value: 'Under Review', label: 'قيد الفحص والدراسة'),
                          SearchableDropdownItem(value: 'Exempt', label: 'معفى قانوناً'),
                          SearchableDropdownItem(value: 'Non-Conforming', label: 'غير مطابق للمواصفة'),
                        ],
                        onChanged: widget.readOnly
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _complianceStatus = val);
                                  _notifyChange();
                                }
                              },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Dates Row (Production, Expiry, ETA)
                Row(
                  children: [
                    Expanded(
                      child: _buildDateTile(
                        label: l10n.shelfLifeProductionDateLabel,
                        date: _productionDate,
                        icon: Icons.event,
                        onTap: () => _pickDate(
                          context: context,
                          initial: _productionDate,
                          onPicked: (d) => _productionDate = d,
                        ),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDateTile(
                        label: l10n.shelfLifeExpiryDateLabel,
                        date: _expiryDate,
                        icon: Icons.event_busy,
                        onTap: () => _pickDate(
                          context: context,
                          initial: _expiryDate,
                          onPicked: (d) => _expiryDate = d,
                        ),
                        isDark: isDark,
                        isAlert: remainingRatio < 50.0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDateTile(
                        label: l10n.shelfLifeEtaArrivalHint,
                        date: _etaDate,
                        icon: Icons.directions_boat_outlined,
                        onTap: () => _pickDate(
                          context: context,
                          initial: _etaDate,
                          onPicked: (d) => _etaDate = d,
                        ),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Batch Number & Ratio Indicator Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _batchCtrl,
                        readOnly: widget.readOnly,
                        onChanged: (_) => _notifyChange(),
                        decoration: InputDecoration(
                          labelText: l10n.shelfLifeBatchNumberLabel,
                          hintText: 'LOT-XXXX / BATCH-XXXX',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.qr_code, size: 18, color: AppTheme.cobalt),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: l10n.shelfLifeCopyBatchTooltip,
                            onPressed: () => CopyHelper.copy(
                              context,
                              _batchCtrl.text,
                              customMessage: l10n.shelfLifeBatchCopiedSuccess,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: remainingRatio >= 50.0
                              ? AppTheme.emerald.withValues(alpha: 0.1)
                              : AppTheme.crimson.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: remainingRatio >= 50.0
                                ? AppTheme.emerald.withValues(alpha: 0.4)
                                : AppTheme.crimson.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.shelfLifeRemainingRatioLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondaryOf(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${remainingRatio.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: remainingRatio >= 50.0 ? AppTheme.emerald : AppTheme.crimson,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Arabic Labeling Checkbox
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.charcoal : AppTheme.cloudWhite.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: CheckboxListTile(
                      dense: true,
                      title: Text(
                        l10n.shelfLifeArabicLabelCheckbox,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      value: _isArabicLabeling,
                      onChanged: widget.readOnly
                          ? null
                          : (v) {
                              setState(() => _isArabicLabeling = v ?? false);
                              _notifyChange();
                            },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ),

                // Critical Alert if ratio is below 50%
                if (remainingRatio < 50.0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.crimson.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.crimson, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.shelfLifeCriticalWarningBadge,
                            style: const TextStyle(
                              color: AppTheme.crimson,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTile({
    required String label,
    required DateTime? date,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    bool isAlert = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAlert
                ? AppTheme.crimson.withValues(alpha: 0.6)
                : (isDark ? AppTheme.charcoal : AppTheme.cloudWhite),
          ),
          color: isAlert
              ? AppTheme.crimson.withValues(alpha: 0.05)
              : (isDark ? AppTheme.charcoal : AppTheme.white),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isAlert
                    ? AppTheme.crimson
                    : AppTheme.textSecondaryOf(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, size: 15, color: isAlert ? AppTheme.crimson : AppTheme.cobalt),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatDate(date),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isAlert
                          ? AppTheme.crimson
                          : (isDark ? AppTheme.white : AppTheme.charcoal),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
