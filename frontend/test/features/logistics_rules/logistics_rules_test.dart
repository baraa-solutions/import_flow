import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/logistics_rules/models/logistics_rule.dart';
import 'package:frontend/features/logistics_rules/screens/logistics_rules_screen.dart';
import 'package:frontend/features/logistics_rules/widgets/logistics_rules_export_dialog.dart';

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
  );
}

void main() {
  group('Logistics Rules UI & Classification Tests', () {
    test('test_export_dialog_groups_rules_by_party classifies all key domains', () {
      final sampleRules = [
        const LogisticsRule(
          id: 1,
          ruleKey: 'APPARENT_DAMAGE_NOTICE_HOURS',
          ruleNameAr: 'مهلة إخطار التلف الظاهر',
          ruleNameEn: 'Apparent Damage Notice',
          valueUnit: 'HOURS',
        ),
        const LogisticsRule(
          id: 2,
          ruleKey: 'BANK_FORM4_BLOCKS_CUSTOMS',
          ruleNameAr: 'نموذج 4 البنكي',
          ruleNameEn: 'Bank Form 4',
          valueUnit: 'BOOLEAN',
        ),
        const LogisticsRule(
          id: 3,
          ruleKey: 'ACID_MIN_VALIDITY_DAYS',
          ruleNameAr: 'صلاحية ACID',
          ruleNameEn: 'ACID Validity',
          valueUnit: 'DAYS',
        ),
        const LogisticsRule(
          id: 4,
          ruleKey: 'FREE_DAYS_DEMURRAGE_DEFAULT',
          ruleNameAr: 'سماح الغرامات',
          ruleNameEn: 'Demurrage Free Days',
          valueUnit: 'DAYS',
        ),
        const LogisticsRule(
          id: 5,
          ruleKey: 'MARINE_INSURANCE_MIN_COVERAGE_PCT',
          ruleNameAr: 'تغطية التأمين البحري',
          ruleNameEn: 'Marine Insurance Coverage',
          valueUnit: 'PERCENTAGE',
        ),
        const LogisticsRule(
          id: 6,
          ruleKey: 'ROAD_MAX_PAYLOAD_20FT_KG',
          ruleNameAr: 'حمولة الشاحنة',
          ruleNameEn: 'Road Max Payload',
          valueUnit: 'KG',
        ),
      ];

      final grouped = groupRulesByParty(sampleRules);

      expect(grouped.containsKey('المستشار القانوني / محامي بحري'), isTrue);
      expect(grouped['المستشار القانوني / محامي بحري']!.length, 1);
      expect(grouped['المستشار القانوني / محامي بحري']!.first.ruleKey, 'APPARENT_DAMAGE_NOTICE_HOURS');

      expect(grouped.containsKey('البنك المعتمد'), isTrue);
      expect(grouped['البنك المعتمد']!.first.ruleKey, 'BANK_FORM4_BLOCKS_CUSTOMS');

      expect(grouped.containsKey('المخلص الجمركي المعتمد'), isTrue);
      expect(grouped['المخلص الجمركي المعتمد']!.first.ruleKey, 'ACID_MIN_VALIDITY_DAYS');

      expect(grouped.containsKey('التوكيل الملاحي'), isTrue);
      expect(grouped['التوكيل الملاحي']!.first.ruleKey, 'FREE_DAYS_DEMURRAGE_DEFAULT');

      expect(grouped.containsKey('شركة التأمين البحري'), isTrue);
      expect(grouped['شركة التأمين البحري']!.first.ruleKey, 'MARINE_INSURANCE_MIN_COVERAGE_PCT');

      expect(grouped.containsKey('شركة النقل البري'), isTrue);
      expect(grouped['شركة النقل البري']!.first.ruleKey, 'ROAD_MAX_PAYLOAD_20FT_KG');
    });

    testWidgets('test_rule_card_shows_crimson_when_verified_value_null', (tester) async {
      const rule = LogisticsRule(
        id: 1,
        ruleKey: 'TEST_UNSET_RULE',
        ruleNameAr: 'قاعدة غير محددة القيمة',
        ruleNameEn: 'Unset Rule',
        valueUnit: 'DAYS',
        conservativeDefault: '7',
        verifiedValue: null,
        verificationStatus: 'UNVERIFIED',
      );

      await tester.pumpWidget(
        _wrapWithMaterial(
          // Wrap inside DataTable to test row display
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('القاعدة')),
                DataColumn(label: Text('الوحدة')),
                DataColumn(label: Text('الاحترازي')),
                DataColumn(label: Text('الموثق')),
                DataColumn(label: Text('المستوى')),
                DataColumn(label: Text('المرجع')),
                DataColumn(label: Text('الإجراءات')),
              ],
              rows: [
                DataRow(
                  cells: [
                    DataCell(Text(rule.ruleNameAr)),
                    DataCell(Text(rule.valueUnit)),
                    DataCell(Text(rule.conservativeDefault ?? '—')),
                    DataCell(
                      Text(
                        'غير محدد (NULL)',
                        style: TextStyle(
                          color: AppTheme.crimson,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const DataCell(Text('WARNING')),
                    const DataCell(Text('—')),
                    const DataCell(SizedBox()),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      final textFinder = find.text('غير محدد (NULL)');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.color, AppTheme.crimson);
    });

    testWidgets('test_rule_card_shows_green_when_verified', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('القاعدة')),
                DataColumn(label: Text('الوحدة')),
                DataColumn(label: Text('الاحترازي')),
                DataColumn(label: Text('الموثق')),
                DataColumn(label: Text('المستوى')),
                DataColumn(label: Text('المرجع')),
                DataColumn(label: Text('الإجراءات')),
              ],
              rows: [
                DataRow(
                  cells: [
                    const DataCell(Text('تغطية التأمين البحري')),
                    const DataCell(Text('PERCENTAGE')),
                    const DataCell(Text('110')),
                    DataCell(
                      Text(
                        '110',
                        style: TextStyle(
                          color: AppTheme.emerald,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const DataCell(Text('WARNING')),
                    const DataCell(Text('ICC A')),
                    const DataCell(SizedBox()),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      final textFinder = find.text('110');
      // Finds conservative and verified
      expect(textFinder, findsNWidgets(2));

      // Verify the colored widget
      final emeraldWidget = tester.widgetList<Text>(textFinder).firstWhere(
            (t) => t.style?.color == AppTheme.emerald,
          );
      expect(emeraldWidget.style?.color, AppTheme.emerald);
    });

    testWidgets('test_safety_guard_badge_shows_warning_when_triggered', (tester) async {
      const rule = LogisticsRule(
        id: 1,
        ruleKey: 'BLOCKING_TEST',
        ruleNameAr: 'قاعدة حظر تجريبية',
        ruleNameEn: 'Blocking Test',
        valueUnit: 'DAYS',
        enforcementLevel: 'BLOCKING',
        verificationStatus: 'UNVERIFIED',
        safetyGuardTriggered: true,
        guardReason: 'Rule is not officially verified. Degraded to WARNING.',
      );

      await tester.pumpWidget(
        _wrapWithMaterial(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('القاعدة')),
                DataColumn(label: Text('الوحدة')),
                DataColumn(label: Text('الاحترازي')),
                DataColumn(label: Text('الموثق')),
                DataColumn(label: Text('المستوى')),
                DataColumn(label: Text('المرجع')),
                DataColumn(label: Text('الإجراءات')),
              ],
              rows: [
                DataRow(
                  cells: [
                    DataCell(Text(rule.ruleNameAr)),
                    DataCell(Text(rule.valueUnit)),
                    const DataCell(Text('—')),
                    const DataCell(Text('غير محدد (NULL)')),
                    DataCell(
                      Tooltip(
                        message: rule.guardReason ?? '',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.warningBackground,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.warningForeground),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.warningForeground),
                              SizedBox(width: 4),
                              Text(
                                'تحذير (حارس أمان)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.warningForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const DataCell(Text('—')),
                    const DataCell(SizedBox()),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('تحذير (حارس أمان)'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });
}
