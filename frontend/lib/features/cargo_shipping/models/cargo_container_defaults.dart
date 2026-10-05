import '../../../core/utils/container_requirement_engine.dart';
import 'cargo_shipping_model.dart';

/// Empty container row: no container / seal / VGM numbers and zero weights are ever invented.
/// The user (or the linked freight booking) supplies the real values.
ContainerLoadingModel blankContainer({
  String containerType = '40HC',
  int quantity = 1,
  String? assignmentDateIso,
  double grossWeightKg = 0,
}) {
  return ContainerLoadingModel(
    containerType: containerType,
    quantity: quantity,
    containerNo: '',
    sealNo: '',
    grossWeightKg: grossWeightKg,
    vgmStatus: 'Pending',
    containerAssignmentDate: assignmentDateIso,
    trackingStatus: 'ASSIGNED',
    individualUnits: blankUnits(quantity),
  );
}

/// [count] individual container slots with empty numbers.
List<Map<String, String>> blankUnits(int count) => [
      for (var i = 0; i < count; i++) {'container_no': '', 'seal_no': ''},
    ];

/// Container recommendation from REAL cargo metrics only. Returns null when the file has no
/// CBM and no weight (nothing to compute with; the UI shows "missing").
ContainerDualRecommendationResult? dualRecommendationOrNull({
  required double totalCbm,
  required double totalWeightKg,
}) {
  if (totalCbm <= 0 && totalWeightKg <= 0) return null;
  return ContainerRequirementEngine.calculateBoth(totalCbm: totalCbm, totalWeightKg: totalWeightKg);
}
