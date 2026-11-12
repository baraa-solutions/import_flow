import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/integration_status_model.dart';
import '../providers/integration_status_provider.dart';

/// Production Mock Guard (NLv0Dpj5): unmistakable banner shown wherever Nafeza / CargoX / PKI
/// statuses appear while the backend runs those integrations in simulation (MOCK) mode.
class SimulationModeBanner extends StatelessWidget {
  final List<String> simulatedProviders;

  const SimulationModeBanner({super.key, required this.simulatedProviders});

  static const String titleAr = 'وضع المحاكاة — لم يتم الإرسال فعلياً إلى نافذة / CargoX';
  static const String titleEn = 'Simulation mode - not sent to Nafeza/CargoX';

  @override
  Widget build(BuildContext context) {
    if (simulatedProviders.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: titleEn,
      container: true,
      child: Container(
        key: const Key('simulation_mode_banner'),
        width: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 14, 8),
        decoration: BoxDecoration(
          color: AppTheme.orange.withValues(alpha: 0.14),
          border: const BorderDirectional(
            start: BorderSide(color: AppTheme.orange, width: 4),
            bottom: BorderSide(color: AppTheme.orange),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.science_outlined, color: AppTheme.orange, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    titleAr,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                  ),
                  Text(
                    '$titleEn (${simulatedProviders.join(', ')})',
                    style: const TextStyle(fontSize: 11, color: AppTheme.charcoal),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small per-record badge for an envelope / result flagged `is_simulated`.
class SimulatedBadge extends StatelessWidget {
  const SimulatedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: SimulationModeBanner.titleEn,
      child: Container(
        key: const Key('simulated_badge'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.orange),
        ),
        child: const Text(
          'محاكاة / SIMULATED',
          style: TextStyle(color: AppTheme.orange, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// Reads the live integration status and shows [SimulationModeBanner] for the given providers.
/// While loading or on error it assumes simulation: a result is never presented as real by default.
class IntegrationSimulationBanner extends ConsumerWidget {
  final List<String> providers;

  const IntegrationSimulationBanner({
    super.key,
    this.providers = const ['NAFEZA', 'CARGOX', 'PKI'],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(integrationStatusProvider);
    final simulated = statusAsync.maybeWhen(
      data: (status) => status.simulatedAmong(providers).map((p) => p.provider).toList(),
      orElse: () => providers,
    );
    return SimulationModeBanner(simulatedProviders: simulated);
  }
}

/// Integration Status panel (settings / system health): one row per provider with its mode.
class IntegrationStatusPanel extends ConsumerWidget {
  const IntegrationStatusPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(integrationStatusProvider);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: statusAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('تعذر تحميل حالة التكاملات / Could not load integration status: $err',
              style: const TextStyle(color: AppTheme.crimson)),
          data: (status) => IntegrationStatusTable(status: status),
        ),
      ),
    );
  }
}

class IntegrationStatusTable extends StatelessWidget {
  final IntegrationStatus status;

  const IntegrationStatusTable({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('حالة التكاملات الخارجية / Integration Status',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal)),
        const SizedBox(height: 10),
        for (final p in status.providers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(p.provider, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                _ModeChip(provider: p),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(p.message,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IntegrationProviderStatus provider;

  const _ModeChip({required this.provider});

  @override
  Widget build(BuildContext context) {
    final Color color = !provider.isAvailable
        ? AppTheme.crimson
        : (provider.isSimulated ? AppTheme.orange : AppTheme.emerald);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        provider.isAvailable ? provider.integrationMode : '${provider.integrationMode} - BLOCKED',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
