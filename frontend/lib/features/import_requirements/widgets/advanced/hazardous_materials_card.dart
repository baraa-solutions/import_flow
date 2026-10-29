import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';

/// ⚠️ Hazardous Materials & Dangerous Goods (DG / IMDG) Card
///
/// Ensures compliance with international maritime hazardous cargo standards (IMO/IMDG),
/// UN Dangerous Goods numbering, Egyptian Civil Protection approvals, and direct port discharge protocols.
class HazardousMaterialsCard extends StatefulWidget {
  final bool initialIsHazardous;
  final String? initialUnNumber;
  final String? initialImdgClass;
  final String? initialPackingGroup;
  final double? initialFlashPoint;
  final String? initialMsdsStatus;
  final String? initialCivilProtectionNo;
  final String? initialPortHandlingMode;
  final String? initialEmergencyPhone;
  final bool readOnly;
  final ValueChanged<HazardousMaterialsData>? onChanged;

  const HazardousMaterialsCard({
    super.key,
    this.initialIsHazardous = false,
    this.initialUnNumber,
    this.initialImdgClass = 'CLASS_3',
    this.initialPackingGroup = 'PG_II',
    this.initialFlashPoint,
    this.initialMsdsStatus = 'OBTAINED',
    this.initialCivilProtectionNo,
    this.initialPortHandlingMode = 'DIRECT_DISCHARGE',
    this.initialEmergencyPhone,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  State<HazardousMaterialsCard> createState() => _HazardousMaterialsCardState();
}

class HazardousMaterialsData {
  final bool isHazardous;
  final String unNumber;
  final String imdgClass;
  final String packingGroup;
  final double? flashPoint;
  final String msdsStatus;
  final String civilProtectionNo;
  final String portHandlingMode;
  final String emergencyPhone;

  const HazardousMaterialsData({
    required this.isHazardous,
    required this.unNumber,
    required this.imdgClass,
    required this.packingGroup,
    this.flashPoint,
    required this.msdsStatus,
    required this.civilProtectionNo,
    required this.portHandlingMode,
    required this.emergencyPhone,
  });

  bool get isCompliant =>
      !isHazardous ||
      (unNumber.isNotEmpty &&
          msdsStatus == 'OBTAINED' &&
          civilProtectionNo.isNotEmpty);
}

class _HazardousMaterialsCardState extends State<HazardousMaterialsCard> {
  late bool _isHazardous;
  late final TextEditingController _unNumberCtrl;
  late String _imdgClass;
  late String _packingGroup;
  late final TextEditingController _flashPointCtrl;
  late String _msdsStatus;
  late final TextEditingController _civilProtectionCtrl;
  late String _portHandlingMode;
  late final TextEditingController _emergencyPhoneCtrl;

  @override
  void initState() {
    super.initState();
    _isHazardous = widget.initialIsHazardous;
    _unNumberCtrl = TextEditingController(text: widget.initialUnNumber ?? '');
    _imdgClass = widget.initialImdgClass ?? 'CLASS_3';
    _packingGroup = widget.initialPackingGroup ?? 'PG_II';
    _flashPointCtrl = TextEditingController(
      text: widget.initialFlashPoint != null ? widget.initialFlashPoint!.toStringAsFixed(1) : '',
    );
    _msdsStatus = widget.initialMsdsStatus ?? 'OBTAINED';
    _civilProtectionCtrl = TextEditingController(text: widget.initialCivilProtectionNo ?? '');
    _portHandlingMode = widget.initialPortHandlingMode ?? 'DIRECT_DISCHARGE';
    _emergencyPhoneCtrl = TextEditingController(text: widget.initialEmergencyPhone ?? '');
  }

  @override
  void dispose() {
    _unNumberCtrl.dispose();
    _flashPointCtrl.dispose();
    _civilProtectionCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onChanged?.call(
      HazardousMaterialsData(
        isHazardous: _isHazardous,
        unNumber: _unNumberCtrl.text.trim(),
        imdgClass: _imdgClass,
        packingGroup: _packingGroup,
        flashPoint: double.tryParse(_flashPointCtrl.text.trim()),
        msdsStatus: _msdsStatus,
        civilProtectionNo: _civilProtectionCtrl.text.trim(),
        portHandlingMode: _portHandlingMode,
        emergencyPhone: _emergencyPhoneCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppTheme.isDark(context);
    final isReady = !_isHazardous ||
        (_unNumberCtrl.text.trim().isNotEmpty &&
            _msdsStatus == 'OBTAINED' &&
            _civilProtectionCtrl.text.trim().isNotEmpty);

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.charcoalSurface : AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !_isHazardous
                ? AppTheme.cloudWhite
                : (isReady
                    ? AppTheme.orange.withValues(alpha: 0.5)
                    : AppTheme.crimson.withValues(alpha: 0.6)),
            width: _isHazardous ? 1.5 : 1.0,
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
                      color: _isHazardous
                          ? AppTheme.orange.withValues(alpha: 0.12)
                          : AppTheme.cobalt.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: _isHazardous ? AppTheme.orange : AppTheme.cobalt,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.hazardousMaterialsHeader,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.white : AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.hazardousMaterialsSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isHazardous) ...[
                    const SizedBox(width: 8),
                    AppStatusBadge(
                      label: isReady ? 'جاهز ومعتمد' : 'يتطلب تصريح الحماية',
                      severity: isReady ? AppSeverity.warning : AppSeverity.danger,
                      icon: isReady ? Icons.check_circle : Icons.warning_amber,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 14),

              // Hazardous Cargo Toggle
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
                      l10n.hazardousSubjectCheckbox,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    value: _isHazardous,
                    onChanged: widget.readOnly
                        ? null
                        : (v) {
                            setState(() => _isHazardous = v ?? false);
                            _notifyChange();
                          },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ),

              if (_isHazardous) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // UN Number & IMDG Class Row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _unNumberCtrl,
                        readOnly: widget.readOnly,
                        onChanged: (_) => _notifyChange(),
                        decoration: InputDecoration(
                          labelText: l10n.hazardousUnNumberLabel,
                          hintText: 'UN XXXX',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.emergency_outlined, size: 18, color: AppTheme.orange),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: l10n.hazardousCopyUnTooltip,
                            onPressed: () => CopyHelper.copy(
                              context,
                              _unNumberCtrl.text,
                              customMessage: l10n.hazardousUnCopiedSuccess,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: SearchableDropdownField<String>(
                        labelText: l10n.hazardousImdgClassLabel,
                        value: _imdgClass,
                        items: const [
                          SearchableDropdownItem(value: 'CLASS_1', label: 'الفئة 1: متفجرات'),
                          SearchableDropdownItem(value: 'CLASS_2', label: 'الفئة 2: غازات مضغوطة ومسالة'),
                          SearchableDropdownItem(value: 'CLASS_3', label: 'الفئة 3: سوائل قابلة للاشتعال'),
                          SearchableDropdownItem(value: 'CLASS_4', label: 'الفئة 4: مواد صلبة قابلة للاشتعال'),
                          SearchableDropdownItem(value: 'CLASS_5', label: 'الفئة 5: مواد مؤكسدة وبيروكسيدات'),
                          SearchableDropdownItem(value: 'CLASS_6', label: 'الفئة 6: مواد سامة ومعدية'),
                          SearchableDropdownItem(value: 'CLASS_7', label: 'الفئة 7: مواد مشعة'),
                          SearchableDropdownItem(value: 'CLASS_8', label: 'الفئة 8: مواد أكالة'),
                          SearchableDropdownItem(value: 'CLASS_9', label: 'الفئة 9: بضائع ومواد خطرة متنوعة'),
                        ],
                        onChanged: widget.readOnly
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _imdgClass = val);
                                  _notifyChange();
                                }
                              },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Packing Group, Flash Point, MSDS Status Row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SearchableDropdownField<String>(
                        labelText: l10n.hazardousPackingGroupLabel,
                        value: _packingGroup,
                        items: const [
                          SearchableDropdownItem(value: 'PG_I', label: 'مجموعة 1: خطورة عالية'),
                          SearchableDropdownItem(value: 'PG_II', label: 'مجموعة 2: خطورة متوسطة'),
                          SearchableDropdownItem(value: 'PG_III', label: 'مجموعة 3: خطورة منخفضة'),
                        ],
                        onChanged: widget.readOnly
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _packingGroup = val);
                                  _notifyChange();
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _flashPointCtrl,
                        readOnly: widget.readOnly,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _notifyChange(),
                        decoration: InputDecoration(
                          labelText: l10n.hazardousFlashPointLabel,
                          hintText: '°C',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.local_fire_department_outlined, size: 18, color: AppTheme.crimson),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SearchableDropdownField<String>(
                        labelText: l10n.hazardousMsdsStatusLabel,
                        value: _msdsStatus,
                        items: const [
                          SearchableDropdownItem(value: 'OBTAINED', label: 'معتمدة ومستوفاة'),
                          SearchableDropdownItem(value: 'UNDER_REVIEW', label: 'قيد التدقيق الفني'),
                          SearchableDropdownItem(value: 'EXPIRED', label: 'منتهية الصلاحية'),
                          SearchableDropdownItem(value: 'MISSING', label: 'غير متوفرة'),
                        ],
                        onChanged: widget.readOnly
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _msdsStatus = val);
                                  _notifyChange();
                                }
                              },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Civil Protection Approval, Port Handling Mode, Emergency Phone Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _civilProtectionCtrl,
                        readOnly: widget.readOnly,
                        onChanged: (_) => _notifyChange(),
                        decoration: InputDecoration(
                          labelText: l10n.hazardousCivilProtectionLabel,
                          hintText: 'CP-FIRE-XXXX',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.local_police_outlined, size: 18, color: AppTheme.cobalt),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: l10n.hazardousCopyUnTooltip,
                            onPressed: () => CopyHelper.copy(
                              context,
                              _civilProtectionCtrl.text,
                              customMessage: l10n.hazardousUnCopiedSuccess,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: SearchableDropdownField<String>(
                        labelText: l10n.hazardousPortHandlingLabel,
                        value: _portHandlingMode,
                        items: [
                          SearchableDropdownItem(
                            value: 'DIRECT_DISCHARGE',
                            label: l10n.hazardousHandlingDirectDischarge,
                          ),
                          SearchableDropdownItem(
                            value: 'HAZARDOUS_YARD',
                            label: l10n.hazardousHandlingHazardousYard,
                          ),
                        ],
                        onChanged: widget.readOnly
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _portHandlingMode = val);
                                  _notifyChange();
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _emergencyPhoneCtrl,
                        readOnly: widget.readOnly,
                        onChanged: (_) => _notifyChange(),
                        decoration: InputDecoration(
                          labelText: l10n.hazardousEmergencyPhoneLabel,
                          hintText: '+20...',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.phone_in_talk, size: 18, color: AppTheme.emerald),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // High Risk Demurrage & Safety Alert Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.report_problem_outlined, color: AppTheme.orange, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.hazardousHighRiskWarning,
                          style: const TextStyle(
                            color: AppTheme.orange,
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
          ),
        ),
      ),
    );
  }
}
