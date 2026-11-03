import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/customs_consultation_model.dart';
import '../consultation_calc/consultation_calc_coordinator.dart';

/// Tab 0: Customs Duties Workspace, Consultation Calculator and Landed Cost Breakdown.
///
/// Refactored Coordinator Widget decomposing the previous 2,695-line monolith
/// into dedicated, high-cohesion sub-components in `widgets/consultation_calc/`.
class CustomsConsultationCalcTab extends ConsumerStatefulWidget {
  final bool isTaxReviewMode;
  final ValueChanged<bool>? onDirtyChanged;
  final ValueChanged<int?>? onImportFileChanged;
  final ValueChanged<CustomsConsultationModel>? onSaved;

  const CustomsConsultationCalcTab({
    super.key,
    this.isTaxReviewMode = false,
    this.onDirtyChanged,
    this.onImportFileChanged,
    this.onSaved,
  });

  @override
  ConsumerState<CustomsConsultationCalcTab> createState() =>
      CustomsConsultationCalcTabState();
}

class CustomsConsultationCalcTabState
    extends ConsumerState<CustomsConsultationCalcTab> {
  late final ConsultationCalcCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    _coordinator = ConsultationCalcCoordinator(
      ref: ref,
      isTaxReviewMode: widget.isTaxReviewMode,
      onDirtyChanged: widget.onDirtyChanged,
      onImportFileChanged: widget.onImportFileChanged,
      onSaved: widget.onSaved,
      onApiError: (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              ApiErrorText.of(context.l10n, e),
              severity: AppSeverity.danger,
            ),
          );
        }
      },
      setState: setState,
      getContext: () => context,
      isMounted: () => mounted,
    );
    _coordinator.init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coordinator.didChangeDependencies(context);
  }

  @override
  void didUpdateWidget(CustomsConsultationCalcTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _coordinator.didUpdateWidget(
      oldWidget.isTaxReviewMode,
      widget.isTaxReviewMode,
      context,
    );
  }

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  /// Public method to load a consultation session into the workspace.
  void loadConsultation(CustomsConsultationModel session) {
    _coordinator.loadConsultation(session);
  }

  /// Public method to reset the consultation calculator form.
  void resetForm() {
    _coordinator.resetForm();
  }

  @override
  Widget build(BuildContext context) {
    return _coordinator.build(context);
  }
}
