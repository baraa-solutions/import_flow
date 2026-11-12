/// Production Mock Guard (NLv0Dpj5): integration mode reported by
/// GET /api/v1/integrations/status for each external provider.
class IntegrationProviderStatus {
  final String provider;
  final String integrationMode;
  final bool isSimulated;
  final bool isAvailable;
  final String message;

  const IntegrationProviderStatus({
    required this.provider,
    required this.integrationMode,
    required this.isSimulated,
    required this.isAvailable,
    required this.message,
  });

  factory IntegrationProviderStatus.fromJson(Map<String, dynamic> json) {
    final mode = (json['integration_mode'] as String? ?? 'MOCK').toUpperCase();
    return IntegrationProviderStatus(
      provider: json['provider'] as String? ?? '',
      integrationMode: mode,
      // Unknown means simulated: never present a result as real without the server saying so.
      isSimulated: json['is_simulated'] as bool? ?? true,
      isAvailable: json['is_available'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}

class IntegrationStatus {
  final bool isProductionBuild;
  final bool anySimulated;
  final List<IntegrationProviderStatus> providers;

  const IntegrationStatus({
    required this.isProductionBuild,
    required this.anySimulated,
    required this.providers,
  });

  factory IntegrationStatus.fromJson(Map<String, dynamic> json) {
    final providers = (json['providers'] as List<dynamic>? ?? const [])
        .map((e) => IntegrationProviderStatus.fromJson(e as Map<String, dynamic>))
        .toList();
    return IntegrationStatus(
      isProductionBuild: json['is_production_build'] as bool? ?? false,
      anySimulated: json['any_simulated'] as bool? ?? providers.any((p) => p.isSimulated),
      providers: providers,
    );
  }

  /// Simulated providers among [names] (e.g. NAFEZA, CARGOX, PKI).
  List<IntegrationProviderStatus> simulatedAmong(Iterable<String> names) {
    final wanted = names.map((n) => n.toUpperCase()).toSet();
    return providers.where((p) => p.isSimulated && wanted.contains(p.provider)).toList();
  }
}
