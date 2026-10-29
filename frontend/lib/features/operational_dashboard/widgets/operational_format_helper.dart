import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/localization/app_localizations.dart';

/// Helper formatting functions for Operational Dashboard stages, steps, and priorities.
class OperationalFormatHelper {
  OperationalFormatHelper._();

  static String formatStageName(String? stage, {bool isArabic = true}) {
    if (stage == null || stage.trim().isEmpty) return '';
    final s = stage.trim();

    if (s.toUpperCase().startsWith('STEP_') || s.toLowerCase().startsWith('step')) {
      return DisplayNameResolver.resolveStepName(s, isArabic: isArabic);
    }
    if (s.toLowerCase().contains('phase') || s.contains('المرحلة') || s.toUpperCase().startsWith('P')) {
      return DisplayNameResolver.resolvePhaseName(s, isArabic: isArabic);
    }

    final step = DisplayNameResolver.resolveStepName(s, isArabic: isArabic);
    if (step != s && step != '-') return step;

    final phase = DisplayNameResolver.resolvePhaseName(s, isArabic: isArabic);
    if (phase != s && phase != '-') return phase;

    return s;
  }

  static String formatActionName(String nextAction, String currentModule, {bool isArabic = true}) {
    final action = DisplayNameResolver.resolveActionTitle(nextAction, isArabic: isArabic);
    final current = formatStageName(currentModule, isArabic: isArabic);
    if (action.trim().toLowerCase() == current.trim().toLowerCase()) {
      if (currentModule.contains('STEP_07') || currentModule.contains('Container') || currentModule.contains('تخصيص')) {
        return isArabic ? 'مراجعة واعتماد مسودات مستندات الشحن' : 'Review & Approve Shipping Drafts';
      }
      if (currentModule.contains('STEP_01') || currentModule.contains('Freight') || currentModule.contains('نولون')) {
        return isArabic ? 'الدراسات والاستشارات الجمركية' : 'Customs Studies';
      }
    }
    return action;
  }

  static String getPriorityLabel(String priority, AppLocalizations l) {
    switch (priority) {
      case 'All':
        return l.priorityAll;
      case 'Low':
        return l.priorityLow;
      case 'Medium':
        return l.priorityMedium;
      case 'High':
        return l.priorityHigh;
      case 'Critical':
        return l.priorityCritical;
      default:
        return priority;
    }
  }
}
