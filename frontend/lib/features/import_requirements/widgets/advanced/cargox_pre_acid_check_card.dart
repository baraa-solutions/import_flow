import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';

/// 🛡️ CargoX Pre-ACID Verification Card
///
/// Ensures the foreign exporter is verified and active on the CargoX blockchain
/// platform BEFORE issuing the Nafeza ACID number, preventing customs rejection
/// and supply chain hold-ups.
class CargoXPreAcidCheckCard extends StatefulWidget {
  final String? supplierName;
  final String? supplierCountry;
  final String? initialCargoxId;
  final String? initialStatus; // 'VERIFIED', 'PENDING', 'NOT_REGISTERED'
  final bool initialBlockchainActive;
  final bool initialAccountAuthorized;
  final bool initialEnvelopeReady;
  final String? initialNotes;
  final bool readOnly;
  final VoidCallback? onVerifyRequested;
  final ValueChanged<CargoXPreAcidData>? onChanged;

  const CargoXPreAcidCheckCard({
    super.key,
    this.supplierName,
    this.supplierCountry,
    this.initialCargoxId,
    this.initialStatus = 'PENDING',
    this.initialBlockchainActive = false,
    this.initialAccountAuthorized = false,
    this.initialEnvelopeReady = false,
    this.initialNotes,
    this.readOnly = false,
    this.onVerifyRequested,
    this.onChanged,
  });

  @override
  State<CargoXPreAcidCheckCard> createState() => _CargoXPreAcidCheckCardState();
}

class CargoXPreAcidData {
  final String cargoxPlatformId;
  final String status;
  final bool isBlockchainActive;
  final bool isAccountAuthorized;
  final bool isEnvelopeReady;
  final String notes;

  const CargoXPreAcidData({
    required this.cargoxPlatformId,
    required this.status,
    required this.isBlockchainActive,
    required this.isAccountAuthorized,
    required this.isEnvelopeReady,
    required this.notes,
  });

  bool get isReadyForAcid =>
      status == 'VERIFIED' && isBlockchainActive && isAccountAuthorized;
}

class _CargoXPreAcidCheckCardState extends State<CargoXPreAcidCheckCard> {
  late final TextEditingController _idController;
  late final TextEditingController _notesController;
  late String _status;
  late bool _isBlockchainActive;
  late bool _isAccountAuthorized;
  late bool _isEnvelopeReady;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.initialCargoxId ?? '');
    _notesController = TextEditingController(text: widget.initialNotes ?? '');
    _status = widget.initialStatus ?? 'PENDING';
    _isBlockchainActive = widget.initialBlockchainActive;
    _isAccountAuthorized = widget.initialAccountAuthorized;
    _isEnvelopeReady = widget.initialEnvelopeReady;
  }

  @override
  void didUpdateWidget(covariant CargoXPreAcidCheckCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCargoxId != null &&
        widget.initialCargoxId != oldWidget.initialCargoxId &&
        _idController.text != widget.initialCargoxId) {
      _idController.text = widget.initialCargoxId!;
    }
    if (widget.initialStatus != null && widget.initialStatus != oldWidget.initialStatus) {
      _status = widget.initialStatus!;
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onChanged?.call(
      CargoXPreAcidData(
        cargoxPlatformId: _idController.text.trim(),
        status: _status,
        isBlockchainActive: _isBlockchainActive,
        isAccountAuthorized: _isAccountAuthorized,
        isEnvelopeReady: _isEnvelopeReady,
        notes: _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppTheme.isDark(context);
    final isVerified = _status == 'VERIFIED';
    final isNotRegistered = _status == 'NOT_REGISTERED';

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.charcoalSurface : AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isNotRegistered
                ? AppTheme.crimson.withValues(alpha: 0.6)
                : (isVerified ? AppTheme.emerald.withValues(alpha: 0.5) : AppTheme.cloudWhite),
            width: isNotRegistered || isVerified ? 1.5 : 1.0,
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
                      color: isVerified
                          ? AppTheme.emerald.withValues(alpha: 0.12)
                          : (isNotRegistered
                              ? AppTheme.crimson.withValues(alpha: 0.12)
                              : AppTheme.cobalt.withValues(alpha: 0.12)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isVerified ? Icons.verified_user : Icons.shield_outlined,
                      color: isVerified
                          ? AppTheme.emerald
                          : (isNotRegistered ? AppTheme.crimson : AppTheme.cobalt),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.cargoXPreAcidHeader,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.white : AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.cargoXPreAcidSubtitle,
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

              // Supplier & Platform ID Info Row
              if (widget.supplierName != null && widget.supplierName!.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.business_outlined, size: 16, color: AppTheme.cobalt),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.supplierName! +
                            (widget.supplierCountry != null && widget.supplierCountry!.isNotEmpty
                                ? ' — ${widget.supplierCountry}'
                                : ''),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.white : AppTheme.charcoal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // CargoX ID Input & Action
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _idController,
                      readOnly: widget.readOnly,
                      onChanged: (_) => _notifyChange(),
                      decoration: InputDecoration(
                        labelText: l10n.cargoXPlatformIdLabel,
                        hintText: 'CX-XXXXX',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.tag, size: 18, color: AppTheme.cobalt),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l10n.cargoXCopyIdTooltip,
                          onPressed: () => CopyHelper.copy(
                            context,
                            _idController.text,
                            customMessage: l10n.cargoXIdCopiedSuccess,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SearchableDropdownField<String>(
                      labelText: l10n.cargoXExporterStatusLabel,
                      value: _status,
                      items: [
                        SearchableDropdownItem(
                          value: 'VERIFIED',
                          label: l10n.cargoXStatusVerified,
                        ),
                        SearchableDropdownItem(
                          value: 'PENDING',
                          label: l10n.cargoXStatusPending,
                        ),
                        SearchableDropdownItem(
                          value: 'NOT_REGISTERED',
                          label: l10n.cargoXStatusNotRegistered,
                        ),
                      ],
                      onChanged: widget.readOnly
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() {
                                  _status = val;
                                  if (val == 'VERIFIED') {
                                    _isBlockchainActive = true;
                                    _isAccountAuthorized = true;
                                  } else if (val == 'NOT_REGISTERED') {
                                    _isBlockchainActive = false;
                                    _isAccountAuthorized = false;
                                  }
                                });
                                _notifyChange();
                              }
                            },
                    ),
                  ),
                  if (widget.onVerifyRequested != null) ...[
                    const SizedBox(width: 8),
                    AppButton(
                      label: l10n.cargoXVerifyAccountBtn,
                      icon: Icons.sync,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      onPressed: widget.onVerifyRequested,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 14),

              // Checklist Checkboxes
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.charcoal : AppTheme.cloudWhite.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildChecklistTile(
                      title: l10n.cargoXChecklistBlockchainActive,
                      value: _isBlockchainActive,
                      onChanged: widget.readOnly
                          ? null
                          : (v) {
                              setState(() => _isBlockchainActive = v ?? false);
                              _notifyChange();
                            },
                    ),
                    _buildChecklistTile(
                      title: l10n.cargoXChecklistAccountAuthorized,
                      value: _isAccountAuthorized,
                      onChanged: widget.readOnly
                          ? null
                          : (v) {
                              setState(() => _isAccountAuthorized = v ?? false);
                              _notifyChange();
                            },
                    ),
                    _buildChecklistTile(
                      title: l10n.cargoXChecklistEnvelopeReady,
                      value: _isEnvelopeReady,
                      onChanged: widget.readOnly
                          ? null
                          : (v) {
                              setState(() => _isEnvelopeReady = v ?? false);
                              _notifyChange();
                            },
                    ),
                  ],
                ),
              ),

              // Critical Alert Banner if unverified or unregistered
              if (!isVerified) ...[
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
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.cargoXUnverifiedWarning,
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
    switch (_status) {
      case 'VERIFIED':
        return AppStatusBadge(
          label: l10n.cargoXStatusVerified,
          severity: AppSeverity.success,
          icon: Icons.check_circle,
        );
      case 'NOT_REGISTERED':
        return AppStatusBadge(
          label: l10n.cargoXStatusNotRegistered,
          severity: AppSeverity.danger,
          icon: Icons.cancel,
        );
      case 'PENDING':
      default:
        return AppStatusBadge(
          label: l10n.cargoXStatusPending,
          severity: AppSeverity.warning,
          icon: Icons.hourglass_top,
        );
    }
  }

  Widget _buildChecklistTile({
    required String title,
    required bool value,
    required ValueChanged<bool?>? onChanged,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
        ),
        value: value,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}
