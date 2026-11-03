import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/customs_tariff_model.dart';
import '../providers/customs_tariff_provider.dart';

double _numToDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? fallback;
  return fallback;
}

int _numToInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is int) return val;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? fallback;
  return fallback;
}

class HsCodeHistoryTab extends ConsumerWidget {
  final CustomsTariffModel tariff;

  const HsCodeHistoryTab({super.key, required this.tariff});

  Widget _reqChip(String label, bool isRequired) {
    return Chip(
      avatar: Icon(
        isRequired ? Icons.check_circle : Icons.cancel,
        size: 16,
        color: isRequired ? AppTheme.emerald : Colors.grey,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isRequired ? FontWeight.bold : FontWeight.normal,
          color: isRequired ? AppTheme.charcoal : Colors.grey.shade600,
        ),
      ),
      backgroundColor: isRequired ? AppTheme.emerald.withValues(alpha: 0.1) : Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;

    return FutureBuilder<Map<String, dynamic>?>(
      future: ref.read(customsTariffProvider.notifier).fetchTariffHistory(tariff.hsCode),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState.section();
        }

        final data = snapshot.data;
        final versions = (data?['versions'] as List?) ?? [];
        final auditLogs = (data?['audit_logs'] as List?) ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: AppTheme.orange, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.hsHistorySummaryTitle(tariff.hsCode),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            versions.length > 1
                                ? l.hsHistoryMultipleVersionsDesc(versions.length)
                                : l.hsHistorySingleVersionDesc,
                            style: const TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade400),
                      ),
                      child: Text(
                        l.hsVersionsCountTag(versions.length),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.charcoal),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section 1: Version Timeline
              Text(
                l.hsTimelineSectionTitle,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
              ),
              const SizedBox(height: 10),

              if (versions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Text(l.hsNoHistoricalVersions),
                  ),
                )
              else
                ...versions.map((ver) {
                  final isActive = ver['is_current_active'] == true;
                  final effFrom = ver['effective_from'] ?? '—';
                  final effTo = ver['effective_to'] ?? l.hsDatePresentOngoing;
                  final duty = ver['customs_duty_rate'] ?? 0.0;
                  final vat = ver['vat_rate'] ?? 0.0;
                  final sched = ver['schedule_tax_rate'] ?? 0.0;
                  final dev = ver['development_fee_rate'] ?? 0.0;
                  final agCount = ver['agreements_count'] ?? 0;
                  final createdAt = ver['created_at'] != null ? ver['created_at'].toString().split('T').first : '—';
                  final stageLabel = ver['stage_label'] as String?;
                  final requiresAcid = ver['requires_acid'] == true;
                  final requiresCoo = ver['requires_coo'] == true;
                  final requiresInspection = ver['requires_inspection'] == true;
                  final authority = ver['regulatory_authority'] as String?;
                  final priorApproval = ver['prior_approval_note'] as String?;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: isActive ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isActive ? AppTheme.emerald : Colors.grey.shade300,
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    color: isActive ? Colors.white : Colors.grey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isActive ? Icons.check_circle : Icons.history_toggle_off,
                                    color: isActive ? AppTheme.emerald : Colors.grey,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isActive ? l.hsActiveLiveVersionBadge : l.hsArchivedSnapshotBadge,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isActive ? AppTheme.emerald : Colors.grey.shade700,
                                    ),
                                  ),
                                  if (stageLabel != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.blue.shade300),
                                      ),
                                      child: Text(
                                        stageLabel,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isActive ? Colors.green.shade50 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l.hsRegistrationDatePrefix(createdAt),
                                  style: TextStyle(fontSize: 10, color: isActive ? Colors.green.shade800 : Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.hsValidityPeriodPrefix(effFrom, effTo),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l.hsApprovedDescPrefix(ver['hs_description'] ?? '—'),
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Chip(
                                label: Text('${l.hsTaxImportDutyTitle}: $duty%'),
                                backgroundColor: Colors.blue.shade50,
                                labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              Chip(
                                label: Text('${l.hsTaxVatTitle}: $vat%'),
                                backgroundColor: Colors.green.shade50,
                                labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              if (sched > 0)
                                Chip(
                                  label: Text('${l.hsTaxScheduleTitle}: $sched%'),
                                  backgroundColor: Colors.purple.shade50,
                                  labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              if (dev > 0)
                                Chip(
                                  label: Text('${l.hsTaxDevFeeTitle}: $dev%'),
                                  backgroundColor: Colors.orange.shade50,
                                  labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              Chip(
                                label: Text(l.hsLinkedAgreementsTag(agCount)),
                                backgroundColor: Colors.teal.shade50,
                                labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _reqChip(l.hsReqAcidSystem, requiresAcid),
                              _reqChip(l.hsReqCertificateOfOrigin, requiresCoo),
                              _reqChip(l.hsReqQualityInspection, requiresInspection),
                              if (authority != null && authority.isNotEmpty)
                                Chip(
                                  avatar: const Icon(Icons.account_balance, size: 14, color: Colors.purple),
                                  label: Text(authority),
                                  backgroundColor: Colors.purple.shade50,
                                  labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple),
                                ),
                            ],
                          ),
                          if (priorApproval != null && priorApproval.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 14, color: AppTheme.orange),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      priorApproval,
                                      style: const TextStyle(fontSize: 10, color: AppTheme.charcoal),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),

              // Section 1.5: Comparative Version Diffs Timeline
              if (versions.length > 1) ...[
                const SizedBox(height: 16),
                Text(
                  l.hsVersionDiffsSummaryHeader,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                ),
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  List<Widget> diffWidgets = [];
                  for (int i = 0; i < versions.length - 1; i++) {
                    final newer = versions[i];
                    final older = versions[i + 1];

                    final newerDate = newer['effective_from'] ?? l.hsDateToday;
                    final olderDate = older['effective_from'] ?? l.hsDateInitial;

                    final nDuty = _numToDouble(newer['customs_duty_rate']);
                    final oDuty = _numToDouble(older['customs_duty_rate']);

                    final nVat = _numToDouble(newer['vat_rate']);
                    final oVat = _numToDouble(older['vat_rate']);

                    final nSched = _numToDouble(newer['schedule_tax_rate']);
                    final oSched = _numToDouble(older['schedule_tax_rate']);

                    final nAg = _numToInt(newer['agreements_count']);
                    final oAg = _numToInt(older['agreements_count']);

                    List<String> changeDetails = [];
                    if (nDuty != oDuty) {
                      changeDetails.add(l.hsDiffDutyChanged(oDuty, nDuty));
                    }
                    if (nVat != oVat) {
                      changeDetails.add(l.hsDiffVatChanged(oVat, nVat));
                    }
                    if (nSched != oSched) {
                      changeDetails.add(l.hsDiffScheduleChanged(oSched, nSched));
                    }
                    if (nAg != oAg) {
                      changeDetails.add(l.hsDiffAgreementsChanged(oAg, nAg));
                    }
                    if (changeDetails.isEmpty) {
                      changeDetails.add(l.hsDiffMetadataChanged);
                    }

                    diffWidgets.add(
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.compare_arrows, color: AppTheme.cobalt, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  l.hsDiffTitle(olderDate, newerDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...changeDetails.map((detail) => Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                      Expanded(
                                        child: Text(
                                          detail,
                                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(children: diffWidgets);
                }),
              ],

              const SizedBox(height: 20),

              // Section 2: Audit Logs Trail
              Text(
                l.hsAuditTrailSectionTitle,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
              ),
              const SizedBox(height: 10),

              if (auditLogs.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Text(l.hsNoAuditLogsFound),
                  ),
                )
              else
                ...auditLogs.map((log) {
                  final action = log['action'] ?? 'ACTIVITY';
                  final performedBy = log['performed_by'] ?? 'System';
                  final createdAt = log['created_at'] != null ? log['created_at'].toString().replaceFirst('T', ' ') : '—';
                  final summary = log['changes_summary'] ?? l.hsActionExecuted;

                  Color actionColor = AppTheme.cobalt;
                  if (action == 'CREATE') actionColor = AppTheme.emerald;
                  if (action == 'UPDATE') actionColor = AppTheme.orange;
                  if (action == 'DELETE') actionColor = AppTheme.crimson;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: actionColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: actionColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            action,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: actionColor),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summary,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l.hsAuditPerformedBy(performedBy, createdAt),
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
