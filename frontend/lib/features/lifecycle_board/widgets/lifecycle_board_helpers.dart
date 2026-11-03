import 'package:flutter/material.dart';
import '../models/lifecycle_board_model.dart';

/// Mapping between step codes and their containing phase ID (1..6)
const Map<String, String> kLifecycleStepPhases = {
  'STEP_01': '1', 'STEP_02': '1', 'STEP_03': '1',
  'STEP_04': '2', 'STEP_05': '2',
  'STEP_06': '3', 'STEP_07': '3', 'STEP_08': '3',
  'STEP_08_PO': '3', 'STEP_08_BL': '3', 'STEP_08_MATCH': '3', 'STEP_08_COO': '3', 'STEP_08_COC': '3',
  'STEP_09': '3',
  'STEP_10': '4', 'STEP_11': '4', 'STEP_12': '4',
  'STEP_13': '5', 'STEP_14': '5', 'STEP_15': '5', 'STEP_16': '5', 'STEP_17': '5', 'STEP_18': '5',
  'STEP_19': '6', 'STEP_20': '6', 'STEP_21': '6',
};

/// Parses a hex color string into a Flutter [Color].
Color parseHexColor(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

/// Checks whether a stepCode belongs to the given phaseId in the phases list.
bool isStepInPhase(String stepCode, int phaseId, List<PhaseSummaryModel> phases) {
  try {
    final p = phases.firstWhere((ph) => ph.phaseId == phaseId);
    return p.stepCodes.contains(stepCode);
  } catch (_) {
    return false;
  }
}
