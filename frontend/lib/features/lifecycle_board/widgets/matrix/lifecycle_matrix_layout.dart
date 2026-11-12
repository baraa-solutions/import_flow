import '../../../../core/localization/app_localizations.dart';
import '../../../import_files/models/payment_pathway_status_model.dart';
import '../../models/lifecycle_board_model.dart';

/// Hard ceiling of step rows any column of the lifecycle overview matrix may hold.
const int kMatrixMaxStepsPerTier = 3;

/// Fixed geometry of the capped 3-step matrix (all cards share the same height).
const double kMatrixHeaderHeight = 32.0;
const double kMatrixStepRowHeight = 22.0;
const double kMatrixBodyPadding = 3.0;
const double kMatrixCardGap = 6.0;
const double kMatrixTierGap = 3.0;
const double kMatrixResetCardWidth = 92.0;

/// Minimum width of one 3-step sub-column before the strip falls back to scrolling.
const double kMatrixMinTierWidth = 84.0;

/// Height of every card in the matrix: header + 3 step rows + body padding.
const double kMatrixCardHeight =
    kMatrixHeaderHeight + kMatrixStepRowHeight * kMatrixMaxStepsPerTier + kMatrixBodyPadding * 2 + 2;

/// How a phase is rendered inside the matrix.
enum MatrixPhaseKind {
  /// One column of up to 3 step rows (e.g. phase 1, 4, 6).
  standard,

  /// One column holding two single-step blocks stacked vertically (e.g. phase 2: finance over ACID).
  stackedDual,

  /// A phase longer than 3 steps split into side-by-side sub-columns of at most 3 steps each.
  split,
}

/// Layout plan of one phase: its step tiers (sub-columns), each holding at most 3 steps.
class MatrixPhaseBlock {
  final PhaseSummaryModel phase;
  final List<List<String>> tiers;

  const MatrixPhaseBlock({required this.phase, required this.tiers});

  MatrixPhaseKind get kind {
    if (tiers.length > 1) return MatrixPhaseKind.split;
    return tiers.first.length == 2 ? MatrixPhaseKind.stackedDual : MatrixPhaseKind.standard;
  }

  int get tierCount => tiers.length;
}

/// Splits [stepCodes] into tiers of at most [kMatrixMaxStepsPerTier] steps.
///
/// The remainder tier comes first so the short (stacked) column precedes the full
/// 3-step columns, e.g. 8 steps → [2, 3, 3], 6 steps → [3, 3], 3 steps → [3].
List<List<String>> splitStepsIntoTiers(List<String> stepCodes) {
  if (stepCodes.length <= kMatrixMaxStepsPerTier) return [List<String>.of(stepCodes)];
  final tiers = <List<String>>[];
  final remainder = stepCodes.length % kMatrixMaxStepsPerTier;
  var index = 0;
  if (remainder > 0) {
    tiers.add(stepCodes.sublist(0, remainder));
    index = remainder;
  }
  while (index < stepCodes.length) {
    tiers.add(stepCodes.sublist(index, index + kMatrixMaxStepsPerTier));
    index += kMatrixMaxStepsPerTier;
  }
  return tiers;
}

/// Builds the matrix plan for the board phases (order preserved).
List<MatrixPhaseBlock> planLifecycleMatrix(List<PhaseSummaryModel> phases) => [
      for (final phase in phases) MatrixPhaseBlock(phase: phase, tiers: splitStepsIntoTiers(phase.stepCodes)),
    ];

/// Total number of sub-columns of a plan (drives the flex widths of the strip).
int matrixTierCount(List<MatrixPhaseBlock> blocks) => blocks.fold(0, (sum, b) => sum + b.tierCount);

/// Minimum width the strip needs to fit without horizontal scrolling.
double matrixMinimumWidth(List<MatrixPhaseBlock> blocks) {
  final tierCount = matrixTierCount(blocks);
  final innerTierGaps = blocks.fold<int>(0, (sum, b) => sum + b.tierCount - 1);
  return tierCount * kMatrixMinTierWidth +
      innerTierGaps * kMatrixTierGap +
      blocks.length * kMatrixCardGap +
      kMatrixResetCardWidth;
}

/// Payment-pathway gates and skipped (waived) stages of the focused import file,
/// projected onto the matrix cells. Empty when no single file is in focus.
class LifecycleMatrixGateState {
  final String? importFileCode;
  final PaymentPathwayStatus? pathway;
  final Set<String> skippedStepCodes;

  const LifecycleMatrixGateState({
    this.importFileCode,
    this.pathway,
    this.skippedStepCodes = const {},
  });

  static const LifecycleMatrixGateState empty = LifecycleMatrixGateState();

  bool isStepWaived(String stepCode) =>
      skippedStepCodes.contains(stepCode) ||
      (pathway?.gates.any((g) => g.gate == stepCode && g.isWaived) ?? false);

  bool isPhaseBlocked(int phaseId) => pathway?.isPhaseBlocked(phaseId) ?? false;

  bool isStepBlocked(String stepCode) => !isStepWaived(stepCode) && (pathway?.isGateBlocked(stepCode) ?? false);

  /// Tooltip text explaining why entering phase [phaseId] is locked, or null.
  String? phaseBlockReason(int phaseId, AppLocalizations l10n) =>
      isPhaseBlocked(phaseId) ? _gateReason('PHASE_$phaseId', l10n) : null;

  /// Tooltip text explaining why entering step [stepCode] is locked, or null.
  String? stepBlockReason(String stepCode, AppLocalizations l10n) =>
      isStepBlocked(stepCode) ? _gateReason(stepCode, l10n) : null;

  String? _gateReason(String gateCode, AppLocalizations l10n) {
    final status = pathway;
    if (status == null) return null;
    final isAr = l10n.isArabic;
    final gate = status.gates.firstWhere((g) => g.gate == gateCode);
    final labelsByCode = {for (final m in status.milestones) m.code: m.label(isAr)};
    final missing = gate.missingMilestones.map((code) => labelsByCode[code] ?? code).join(isAr ? '، ' : ', ');
    final fileCode = importFileCode ?? status.importFileCode ?? '';
    final header = l10n.matrixPaymentGateLocked(gate.label(isAr), fileCode);
    return missing.isEmpty ? header : '$header\n${l10n.matrixPendingMilestones(missing)}';
  }
}
