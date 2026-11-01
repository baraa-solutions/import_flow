import 'package:flutter/material.dart';

enum DashboardCardType {
  todaysTasks,
  pendingTasks,
  upcomingShipments,
  arrivingThisWeek,
  etaChanges,
  waitingForPayment,
  waitingForForm4,
  pendingRequirements,
  highPriorityAlerts,
}

class DrillDownItem {
  final String id;
  final String title;
  final String? subtitle;
  final String? shipmentCode;
  final String? shipmentTitle;
  final String who;
  final String byWhen;
  final String status;
  final String? statusColorType; // info, warning, danger, success
  final String? nextAction;
  final String? amount;
  final List<String> dataGaps;
  final VoidCallback? onAction;
  final String? actionLabel;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionLabel;

  DrillDownItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.shipmentCode,
    this.shipmentTitle,
    required this.who,
    required this.byWhen,
    required this.status,
    this.statusColorType,
    this.nextAction,
    this.amount,
    this.dataGaps = const [],
    this.onAction,
    this.actionLabel,
    this.onSecondaryAction,
    this.secondaryActionLabel,
  });
}
