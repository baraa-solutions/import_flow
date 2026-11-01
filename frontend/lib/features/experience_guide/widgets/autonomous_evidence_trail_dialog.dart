import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../models/guide_entry_model.dart';
import '../providers/experience_guide_provider.dart';
import 'evidence/evidence_trail_action_handlers.dart';
import 'evidence/evidence_trail_contributing_files.dart';
import 'evidence/evidence_trail_header.dart';
import 'evidence/evidence_trail_metrics_panel.dart';

class AutonomousEvidenceTrailDialog extends ConsumerStatefulWidget {
  final int entryId;
  final String? initialTitle;
  /// Evidence / reason already rendered in the user's language from the entry's message code;
  /// they win over the provenance texts, which are stored in English.
  final String? initialEvidence;
  final String? initialReason;
  final VoidCallback? onStateChanged;

  const AutonomousEvidenceTrailDialog({
    super.key,
    required this.entryId,
    this.initialTitle,
    this.initialEvidence,
    this.initialReason,
    this.onStateChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required int entryId,
    String? initialTitle,
    String? initialEvidence,
    String? initialReason,
    VoidCallback? onStateChanged,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AutonomousEvidenceTrailDialog(
        entryId: entryId,
        initialTitle: initialTitle,
        initialEvidence: initialEvidence,
        initialReason: initialReason,
        onStateChanged: onStateChanged,
      ),
    );
  }

  @override
  ConsumerState<AutonomousEvidenceTrailDialog> createState() =>
      _AutonomousEvidenceTrailDialogState();
}

class _AutonomousEvidenceTrailDialogState
    extends ConsumerState<AutonomousEvidenceTrailDialog> {
  ProvenanceModel? _provenance;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _loadProvenance();
  }

  Future<void> _loadProvenance() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(experienceGuideProvider.notifier);
      final data = await notifier.fetchEntryProvenance(widget.entryId);
      if (mounted) {
        setState(() {
          _provenance = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل في تحميل مسار الأدلة: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePromote() async {
    final confirmed = await EvidenceTrailActionHandlers.confirmPromote(context);
    if (confirmed != true) return;

    setState(() => _isProcessingAction = true);
    try {
      final notifier = ref.read(experienceGuideProvider.notifier);
      final res = await notifier.promoteInferredEntry(
        widget.entryId,
        promotedBy: 'Authorized Staff',
      );
      if (mounted) {
        setState(() => _isProcessingAction = false);
        if (res != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, '✅ تم اعتماد النمط بنجاح كمرجعية مؤسسية ثابتة', severity: AppSeverity.success),
          );
          widget.onStateChanged?.call();
          _loadProvenance();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingAction = false);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, '❌ حدث خطأ أثناء الاعتماد: $e', severity: AppSeverity.danger),
        );
      }
    }
  }

  Future<void> _handleReject() async {
    final reason = await EvidenceTrailActionHandlers.promptRejectionReason(context);
    if (reason == null) return;

    setState(() => _isProcessingAction = true);
    try {
      final notifier = ref.read(experienceGuideProvider.notifier);
      final res = await notifier.rejectInferredEntry(
        widget.entryId,
        rejectionReason: reason,
      );
      if (mounted) {
        setState(() => _isProcessingAction = false);
        if (res != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, 'تم استبعاد الاستنتاج وحجبه من الظهور التشغيلي'),
          );
          widget.onStateChanged?.call();
          _loadProvenance();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingAction = false);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, '❌ حدث خطأ أثناء الاستبعاد: $e', severity: AppSeverity.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SelectionArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780, maxHeight: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              EvidenceTrailHeader(
                title: widget.initialTitle ?? _provenance?.title ?? 'استنتاج آلي ذاتي',
                onClose: () => Navigator.pop(context),
              ),

              // Content Body
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.cobalt),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.crimson)),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                EvidenceTrailMetricsPanel(provenance: _provenance!),
                                const SizedBox(height: 20),
                                EvidenceTrailContributingFiles(
                                  provenance: _provenance!,
                                  initialReason: widget.initialReason,
                                  initialEvidence: widget.initialEvidence,
                                ),
                              ],
                            ),
                          ),
              ),

              // Bottom Actions Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    if (_provenance != null &&
                        _provenance!.sourceType == 'SYSTEM_INFERRED' &&
                        !_provenance!.isConfirmed &&
                        !_provenance!.isRejected) ...[
                      AppButton(
                        label: 'اعتماد كمرجعية مؤسسية مؤكدة',
                        icon: Icons.verified_rounded,
                        variant: AppButtonVariant.success,
                        size: AppButtonSize.small,
                        isLoading: _isProcessingAction,
                        onPressed: _handlePromote,
                      ),
                      const SizedBox(width: 8),
                      AppButton(
                        label: 'استبعاد هذا النمط',
                        icon: Icons.cancel_outlined,
                        variant: AppButtonVariant.danger,
                        size: AppButtonSize.small,
                        isLoading: _isProcessingAction,
                        onPressed: _handleReject,
                      ),
                    ],
                    const Spacer(),
                    AppButton(
                      label: 'إغلاق',
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
