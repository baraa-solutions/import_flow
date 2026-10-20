import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';

void showGOEICVerificationDialog(BuildContext context, WidgetRef ref, {
  required int supplierId,
  required String supplierName,
}) {
  showDialog(
    context: context,
    builder: (ctx) => GOEICVerificationDialog(
      supplierId: supplierId,
      supplierName: supplierName,
    ),
  );
}

class GOEICVerificationDialog extends ConsumerStatefulWidget {
  final int supplierId;
  final String supplierName;

  const GOEICVerificationDialog({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  ConsumerState<GOEICVerificationDialog> createState() => _GOEICVerificationDialogState();
}

class _GOEICVerificationDialogState extends ConsumerState<GOEICVerificationDialog> {
  final _hsCodeController = TextEditingController();
  final _coiAgencyController = TextEditingController();
  final _coiNumberController = TextEditingController();
  bool _hasCoi = false;
  bool _isChecking = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _hsCodeController.dispose();
    _coiAgencyController.dispose();
    _coiNumberController.dispose();
    super.dispose();
  }

  Future<void> _checkCompliance() async {
    final hsCode = _hsCodeController.text.trim();
    if (hsCode.isEmpty) {
      setState(() => _error = context.l10n.goeicHsCodeFieldLabel);
      return;
    }

    setState(() {
      _isChecking = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final payload = {
        'supplier_id': widget.supplierId,
        'hs_code': _hsCodeController.text.trim(),
        'has_coi_certificate': _hasCoi,
        if (_hasCoi) 'coi_agency': _coiAgencyController.text.trim(),
        if (_hasCoi) 'coi_number': _coiNumberController.text.trim(),
      };

      final res = await dio.post('/integrations/goeic/verify-compliance', data: payload);
      if (mounted) {
        setState(() {
          _result = res.data is Map<String, dynamic> ? res.data : null;
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: Container(
        width: 780,
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
                      color: AppTheme.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_user_outlined, color: AppTheme.emerald, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.goeicHubDialogTitle,
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                        ),
                        Text(
                          '${l10n.supplierCompanyNameLabel}: ${widget.supplierName}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Inputs Form
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _hsCodeController,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText: l10n.goeicHsCodeFieldLabel,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _hasCoi,
                              onChanged: (val) => setState(() => _hasCoi = val ?? false),
                            ),
                            Text(l10n.goeicCoiCertificateCheckbox, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isChecking ? null : _checkCompliance,
                          icon: _isChecking
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.search, size: 18),
                          label: Text(l10n.goeicCheckComplianceBtn),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cobalt,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                    if (_hasCoi) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _coiAgencyController,
                              decoration: InputDecoration(
                                labelText: l10n.goeicInspectionAgencyFieldLabel,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _coiNumberController,
                              decoration: InputDecoration(
                                labelText: l10n.goeicCoiNumberFieldLabel,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Results
              if (_isChecking)
                const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.crimson),
                  ),
                  child: Text('خطأ في الفحص: $_error', style: const TextStyle(color: AppTheme.crimson)),
                )
              else if (_result != null)
                _buildVerdictCard(context, _result!),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildVerdictCard(BuildContext context, Map<String, dynamic> res) {
    final l10n = context.l10n;
    final verdict = res['overall_compliance_verdict'] ?? '';
    final isDecree43 = res['is_decree_43_mandated'] == true;
    final isRegistered = res['is_factory_registered'] == true;
    final regNo = res['factory_registration_number'] ?? l10n.goeicFactoryNotAvailable;
    final warning = res['warning_message_ar'] as String?;
    final action = res['recommended_action_ar'] ?? '';

    Color verdictColor;
    IconData verdictIcon;
    String verdictTitle;

    if (verdict == 'BLOCKED_DECREE_43_VIOLATION') {
      verdictColor = AppTheme.crimson;
      verdictIcon = Icons.gpp_bad_outlined;
      verdictTitle = '⛔ ${l10n.goeicVerdictBlocked}';
    } else if (verdict == 'PENDING_COI_CERTIFICATE') {
      verdictColor = AppTheme.orange;
      verdictIcon = Icons.pending_actions_outlined;
      verdictTitle = '⚠️ ${l10n.goeicVerdictPending}';
    } else {
      verdictColor = AppTheme.emerald;
      verdictIcon = Icons.verified_outlined;
      verdictTitle = '✅ ${l10n.goeicVerdictApproved}';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: verdictColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: verdictColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(verdictIcon, color: verdictColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  verdictTitle,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: verdictColor),
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: Text('${l10n.goeicSubjectToDecree43} ${isDecree43 ? l10n.goeicDecree43MandatoryYes : l10n.goeicDecree43MandatoryNo}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
              Expanded(
                child: Text('${l10n.goeicFactoryRegistrationStatus} ${isRegistered ? "${l10n.goeicFactoryRegisteredYes} ($regNo)" : l10n.goeicFactoryRegisteredNo}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ],
          ),
          if (warning != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: verdictColor.withValues(alpha: 0.4)),
              ),
              child: Text(warning, style: TextStyle(color: verdictColor, fontSize: 13, height: 1.4)),
            ),
          ],
          const SizedBox(height: 12),
          Text('\${l10n.goeicRecommendedActionLabel} $action',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade900)),
        ],
      ),
    );
  }
}
