import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/payment_pathway_status_model.dart';
import '../../providers/payment_pathway_provider.dart';

/// 🏦 PaymentPathwayGuard — the file's exclusive payment pathway (SWIFT advance /
/// LC / CAD / Open Account), its completed and pending banking milestones, the
/// lifecycle gates they unlock and the reasons the next transition is blocked.
///
/// Data comes live from `paymentPathwayStatusProvider` (autoDispose: refetched on
/// every mount; the refresh button invalidates it).
class PaymentPathwayGuard extends ConsumerWidget {
  final int importFileId;
  final bool isAr;
  final bool isDark;

  const PaymentPathwayGuard({
    super.key,
    required this.importFileId,
    required this.isAr,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paymentPathwayStatusProvider(importFileId));
    return async.when(
      loading: () => _frame(
        context,
        accent: AppTheme.cobalt,
        child: const Padding(
          key: ValueKey('payment-pathway-loading'),
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (e, _) => _frame(
        context,
        accent: AppTheme.crimson,
        trailing: _refreshButton(ref),
        child: Text(
          isAr ? 'تعذر تحميل بوابات مسار الدفع.' : 'Could not load payment pathway gates.',
          style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
        ),
      ),
      data: (status) => _content(context, ref, status),
    );
  }

  Widget _refreshButton(WidgetRef ref) => IconButton(
        key: const ValueKey('payment-pathway-refresh'),
        tooltip: isAr ? 'تحديث' : 'Refresh',
        icon: const Icon(Icons.refresh, size: 18),
        onPressed: () => ref.invalidate(paymentPathwayStatusProvider(importFileId)),
      );

  Widget _content(BuildContext context, WidgetRef ref, PaymentPathwayStatus status) {
    if (!status.isPathwaySet) {
      return _frame(
        context,
        accent: AppTheme.orange,
        trailing: _refreshButton(ref),
        child: Text(
          isAr
              ? 'لم يتم تحديد مسار الدفع للشحنة بعد — البوابات المصرفية غير مفعّلة حتى يتم اختياره أو توريثه من أمر الشراء.'
              : 'No payment pathway set yet — banking gates stay inactive until one is chosen or inherited from the PO.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
        ),
      );
    }

    final accent = status.isBlocked ? AppTheme.crimson : AppTheme.emerald;
    final pathwayLabel = context.l10n.domainEnumLabel(DomainEnumType.paymentTerm, status.paymentTerm!) ??
        status.paymentTerm!;

    return _frame(
      context,
      accent: accent,
      trailing: _refreshButton(ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _chip(pathwayLabel, AppTheme.cobalt, key: const ValueKey('payment-pathway-label')),
              _chip(
                isAr
                    ? '${status.completedCount}/${status.totalCount} مكتمل'
                    : '${status.completedCount}/${status.totalCount} completed',
                accent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: status.progress,
              minHeight: 5,
              color: accent,
              backgroundColor: accent.withValues(alpha: 0.15),
            ),
          ),
          if (status.isBlocked) ...[
            const SizedBox(height: 10),
            _blockingBanner(status),
          ],
          const SizedBox(height: 10),
          for (final m in status.milestones) _milestoneRow(context, m),
          if (status.gates.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final g in status.gates) _gateChip(g)],
            ),
          ],
        ],
      ),
    );
  }

  Widget _blockingBanner(PaymentPathwayStatus status) {
    return Container(
      key: const ValueKey('payment-pathway-blocked'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.crimson.withValues(alpha: isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.crimsonBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.block, size: 16, color: AppTheme.crimson),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isAr ? 'الانتقال التالي محظور حتى استيفاء:' : 'Next transition blocked until:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.crimson),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final reason in status.blockingReasons(isAr))
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 22, top: 2),
              child: Text('• $reason', style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _milestoneRow(BuildContext context, PaymentMilestoneStatus m) {
    final color = m.isCompleted ? AppTheme.emerald : AppTheme.orange;
    final before = m.requiredBeforeLabel(isAr);
    return Padding(
      key: ValueKey('payment-milestone-${m.code}'),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(m.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.label(isAr), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                Text(
                  [
                    m.evidence(isAr),
                    if (before != null) isAr ? 'مطلوب قبل: $before' : 'Required before: $before',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gateChip(PaymentGateStatus g) {
    final Color color;
    final IconData icon;
    if (g.isWaived) {
      color = Colors.grey;
      icon = Icons.remove_circle_outline;
    } else if (g.isBlocking) {
      color = AppTheme.crimson;
      icon = Icons.lock;
    } else if (g.isPassed) {
      color = AppTheme.emerald;
      icon = Icons.check;
    } else {
      color = AppTheme.cobalt;
      icon = Icons.lock_open;
    }
    return Container(
      key: ValueKey('payment-gate-${g.gate}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(g.label(isAr), style: TextStyle(fontSize: 11, color: color))),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color, {Key? key}) => Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _frame(BuildContext context, {required Color accent, required Widget child, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAr ? 'حارس مسار الدفع والبوابات المصرفية' : 'Payment Pathway Guard',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
