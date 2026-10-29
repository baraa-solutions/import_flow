import 'package:flutter/material.dart';

enum ReportTemplateMode {
  custom,
  eco,
  scas,
}

class DynamicReportColumn {
  final String id;
  final String categoryId;
  bool isVisible;

  DynamicReportColumn({
    required this.id,
    required this.categoryId,
    this.isVisible = true,
  });
}

class ReportColumnCategory {
  final String id;
  final IconData icon;

  const ReportColumnCategory({
    required this.id,
    required this.icon,
  });
}
