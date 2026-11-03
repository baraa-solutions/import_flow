import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';

/// 🔬 Testing Laboratories & Regulatory Track Card
///
/// Manages laboratory sample drawing protocols, testing fees, under-bond release
/// under quarantine (LOG-BOND-003), and formal conforming/non-conforming test certifications.
class TestingLaboratoriesTrackCard extends StatefulWidget {
  final String? initialLaboratory;
  final String? initialSamplingRecordNo;
  final DateTime? initialSamplingDate;
  final int initialSamplesCount;
  final double initialLabFees;
  final String? initialTestResult; // 'CONFORMING', 'PENDING', 'NON_CONFORMING'
  final bool initialUnderBondRelease;
  final String? initialCertificateNo;
  final bool readOnly;
  final ValueChanged<TestingLabTrackData>? onChanged;

  const TestingLaboratoriesTrackCard({
    super.key,
    this.initialLaboratory = 'GOEIC_LAB',
    this.initialSamplingRecordNo,
    this.initialSamplingDate,
    this.initialSamplesCount = 1,
    this.initialLabFees = 0.0,
    this.initialTestResult = 'PENDING',
    this.initialUnderBondRelease = false,
    this.initialCertificateNo,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  State<TestingLaboratoriesTrackCard> createState() => _TestingLaboratoriesTrackCardState();
}

class TestingLabTrackData {
  final String assignedLaboratory;
  final String samplingRecordNo;
  final DateTime? samplingDate;
  final int samplesCount;
  final double labFees;
  final String testResult;
  final bool isUnderBondRelease;
  final String certificateNo;

  const TestingLabTrackData({
    required this.assignedLaboratory,
    required this.samplingRecordNo,
    this.samplingDate,
    required this.samplesCount,
    required this.labFees,
    required this.testResult,
    required this.isUnderBondRelease,
    required this.certificateNo,
  });

  bool get isApproved => testResult == 'CONFORMING';
}

class _TestingLaboratoriesTrackCardState extends State<TestingLaboratoriesTrackCard> {
  late String _assignedLab;
  late final TextEditingController _samplingRecordCtrl;
  DateTime? _samplingDate;
  late int _samplesCount;
  late final TextEditingController _labFeesCtrl;
  late String _testResult;
  late bool _underBondRelease;
  late final TextEditingController _certificateCtrl;

  @override
  void initState() {
    super.initState();
    _assignedLab = widget.initialLaboratory ?? 'GOEIC_LAB';
    _samplingRecordCtrl = TextEditingController(text: widget.initialSamplingRecordNo ?? '');
    _samplingDate = widget.initialSamplingDate ?? DateTime.now();
    _samplesCount = widget.initialSamplesCount;
    _labFeesCtrl = TextEditingController(
      text: widget.initialLabFees > 0 ? widget.initialLabFees.toStringAsFixed(2) : '',
    );
    _testResult = widget.initialTestResult ?? 'PENDING';
    _underBondRelease = widget.initialUnderBondRelease;
    _certificateCtrl = TextEditingController(text: widget.initialCertificateNo ?? '');
  }

  @override
  void dispose() {
    _samplingRecordCtrl.dispose();
    _labFeesCtrl.dispose();
    _certificateCtrl.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onChanged?.call(
      TestingLabTrackData(
        assignedLaboratory: _assignedLab,
        samplingRecordNo: _samplingRecordCtrl.text.trim(),
        samplingDate: _samplingDate,
        samplesCount: _samplesCount,
        labFees: double.tryParse(_labFeesCtrl.text.trim()) ?? 0.0,
        testResult: _testResult,
        isUnderBondRelease: _underBondRelease,
        certificateNo: _certificateCtrl.text.trim(),
      ),
    );
  }

  Future<void> _pickSamplingDate(BuildContext context) async {
    if (widget.readOnly) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _samplingDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _samplingDate = picked);
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
    final isConforming = _testResult == 'CONFORMING';
    final isNonConforming = _testResult == 'NON_CONFORMING';

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.charcoalSurface : AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isConforming
                ? AppTheme.emerald.withValues(alpha: 0.5)
                : (isNonConforming
                    ? AppTheme.crimson.withValues(alpha: 0.6)
                    : AppTheme.cloudWhite),
            width: isConforming || isNonConforming ? 1.5 : 1.0,
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
                      color: isConforming
                          ? AppTheme.emerald.withValues(alpha: 0.12)
                          : (isNonConforming
                              ? AppTheme.crimson.withValues(alpha: 0.12)
                              : AppTheme.cobalt.withValues(alpha: 0.12)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.science_outlined,
                      color: isConforming
                          ? AppTheme.emerald
                          : (isNonConforming ? AppTheme.crimson : AppTheme.cobalt),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.testingLabsTrackHeader,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.white : AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.testingLabsTrackSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(l10n),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Lab Selection & Test Result Row
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SearchableDropdownField<String>(
                      labelText: l10n.testingLabAssignedLabel,
                      value: _assignedLab,
                      items: const [
                        SearchableDropdownItem(
                          value: 'GOEIC_LAB',
                          label: 'معامل الرقابة على الصادرات والواردات',
                        ),
                        SearchableDropdownItem(
                          value: 'NFSA_LAB',
                          label: 'معامل الهيئة القومية لسلامة الغذاء',
                        ),
                        SearchableDropdownItem(
                          value: 'HEALTH_LAB',
                          label: 'معامل وزارة الصحة المركزية',
                        ),
                        SearchableDropdownItem(
                          value: 'ATOMIC_LAB',
                          label: 'معامل هيئة الطاقة الذرية والفحص الإشعاعي',
                        ),
                        SearchableDropdownItem(
                          value: 'NTRA_LAB',
                          label: 'معامل الجهاز القومي لتنظيم الاتصالات',
                        ),
                        SearchableDropdownItem(
                          value: 'INDUSTRIAL_LAB',
                          label: 'معامل مصلحة الرقابة الصناعية',
                        ),
                      ],
                      onChanged: widget.readOnly
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() => _assignedLab = val);
                                _notifyChange();
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SearchableDropdownField<String>(
                      labelText: l10n.testingLabResultStatusLabel,
                      value: _testResult,
                      items: [
                        SearchableDropdownItem(
                          value: 'PENDING',
                          label: l10n.testingLabResultPending,
                        ),
                        SearchableDropdownItem(
                          value: 'CONFORMING',
                          label: l10n.testingLabResultConforming,
                        ),
                        SearchableDropdownItem(
                          value: 'NON_CONFORMING',
                          label: l10n.testingLabResultNonConforming,
                        ),
                      ],
                      onChanged: widget.readOnly
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() => _testResult = val);
                                _notifyChange();
                              }
                            },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Sampling Record, Sampling Date, Samples Count Row
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _samplingRecordCtrl,
                      readOnly: widget.readOnly,
                      onChanged: (_) => _notifyChange(),
                      decoration: InputDecoration(
                        labelText: l10n.testingLabSamplingRecordLabel,
                        hintText: 'SMP-2026-XXXX',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.receipt_long, size: 18, color: AppTheme.cobalt),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l10n.testingLabCopyRecordTooltip,
                          onPressed: () => CopyHelper.copy(
                            context,
                            _samplingRecordCtrl.text,
                            customMessage: l10n.testingLabRecordCopiedSuccess,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () => _pickSamplingDate(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppTheme.charcoal : AppTheme.cloudWhite),
                          color: isDark ? AppTheme.charcoal : AppTheme.white,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.testingLabSamplingDateLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondaryOf(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.event, size: 15, color: AppTheme.cobalt),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _formatDate(_samplingDate),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.white : AppTheme.charcoal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SearchableDropdownField<int>(
                      labelText: l10n.testingLabSamplesCountLabel,
                      value: _samplesCount,
                      items: List.generate(10, (index) => index + 1)
                          .map(
                            (count) => SearchableDropdownItem(
                              value: count,
                              label: '$count',
                            ),
                          )
                          .toList(),
                      onChanged: widget.readOnly
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() => _samplesCount = val);
                                _notifyChange();
                              }
                            },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Fees & Certificate Number Row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _labFeesCtrl,
                      readOnly: widget.readOnly,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _notifyChange(),
                      decoration: InputDecoration(
                        labelText: l10n.testingLabFeesLabel,
                        hintText: '0.00 EGP',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.payments_outlined, size: 18, color: AppTheme.cobalt),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _certificateCtrl,
                      readOnly: widget.readOnly,
                      onChanged: (_) => _notifyChange(),
                      decoration: InputDecoration(
                        labelText: l10n.testingLabCertificateNoLabel,
                        hintText: 'LAB-CERT-XXXX',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.verified, size: 18, color: AppTheme.emerald),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l10n.testingLabCopyRecordTooltip,
                          onPressed: () => CopyHelper.copy(
                            context,
                            _certificateCtrl.text,
                            customMessage: l10n.testingLabRecordCopiedSuccess,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Under-Bond Release Checkbox (LOG-BOND-003)
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
                      l10n.testingLabUnderBondReleaseCheck,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    value: _underBondRelease,
                    onChanged: widget.readOnly
                        ? null
                        : (v) {
                            setState(() => _underBondRelease = v ?? false);
                            _notifyChange();
                          },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ),

              // Non-Conforming Rejection Banner
              if (isNonConforming) ...[
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
                      const Icon(Icons.cancel_outlined, color: AppTheme.crimson, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.testingLabResultNonConforming,
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
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AppLocalizations l10n) {
    switch (_testResult) {
      case 'CONFORMING':
        return AppStatusBadge(
          label: l10n.testingLabResultConforming,
          severity: AppSeverity.success,
          icon: Icons.check_circle,
        );
      case 'NON_CONFORMING':
        return AppStatusBadge(
          label: l10n.testingLabResultNonConforming,
          severity: AppSeverity.danger,
          icon: Icons.cancel,
        );
      case 'PENDING':
      default:
        return AppStatusBadge(
          label: l10n.testingLabResultPending,
          severity: AppSeverity.warning,
          icon: Icons.hourglass_top,
        );
    }
  }
}
