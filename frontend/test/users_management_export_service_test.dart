import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/auth/providers/users_provider.dart';
import 'package:frontend/features/auth/services/users_management_export_service.dart';

Widget _buildTestWidget({Locale locale = const Locale('en')}) {
  return MaterialApp(
    home: AppLocalizationsProvider(
      locale: locale,
      child: const Scaffold(body: SizedBox()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleUsers = [
    UserDetail(
      userId: 1,
      username: 'ahmed_admin',
      email: 'ahmed@company.com',
      fullName: 'Ahmed Sorour',
      role: 'ADMIN',
      isActive: true,
      createdAt: '2026-09-01T10:00:00Z',
    ),
    UserDetail(
      userId: 2,
      username: 'salah_manager',
      email: 'salah@company.com',
      fullName: 'Salah Mohamed',
      role: 'MANAGER',
      isActive: true,
      createdAt: '2026-09-02T11:00:00Z',
    ),
    UserDetail(
      userId: 3,
      username: 'karim_op',
      email: 'karim@company.com',
      fullName: 'Karim Ali',
      role: 'OPERATOR',
      isActive: false,
      createdAt: '2026-09-03T12:00:00Z',
    ),
  ];

  group('Screen 66: Users Management Export Service Tests', () {
    testWidgets('toRowSummary generates valid single-line summary with localizations', (tester) async {
      await tester.pumpWidget(_buildTestWidget(locale: const Locale('ar')));
      final BuildContext context = tester.element(find.byType(Scaffold));
      final l = AppLocalizations.of(context);

      final summaryAr = UsersManagementExportService.toRowSummary(sampleUsers[0], l);
      expect(summaryAr, contains(sampleUsers[0].fullName));
      expect(summaryAr, contains('@ahmed_admin'));
      expect(summaryAr, contains('ahmed@company.com'));
      expect(summaryAr, contains(l.usersMgmtRoleAdminLabel));
      expect(summaryAr, contains(l.usersMgmtStatusActive));
      expect(summaryAr.contains('\n'), isFalse);
    });

    testWidgets('exportUsersToTsv includes UTF-8 BOM, tab separators, and all rows', (tester) async {
      await tester.pumpWidget(_buildTestWidget(locale: const Locale('ar')));
      final BuildContext context = tester.element(find.byType(Scaffold));
      final l = AppLocalizations.of(context);

      final tsv = UsersManagementExportService.exportUsersToTsv(sampleUsers, l);

      // Verify UTF-8 BOM
      expect(tsv.startsWith('\uFEFF'), isTrue);

      final lines = tsv.substring(1).trim().split('\n');
      // 1 header + 3 rows = 4 lines
      expect(lines.length, 4);

      // Header line checks
      final headers = lines[0].split('\t');
      expect(headers[0].trim(), '#');
      expect(headers[1].trim(), l.usersMgmtColFullName);
      expect(headers[2].trim(), l.usersMgmtColUsername);
      expect(headers[3].trim(), l.usersMgmtColEmail);
      expect(headers[4].trim(), l.usersMgmtColRole);
      expect(headers[5].trim(), l.usersMgmtColStatus);
      expect(headers[6].trim(), l.usersMgmtColCreatedAt);

      // Data rows check
      for (int i = 0; i < sampleUsers.length; i++) {
        final row = lines[i + 1].split('\t');
        expect(row[0].trim(), '${i + 1}');
        expect(row[1].trim(), sampleUsers[i].fullName);
        expect(row[2].trim(), '@${sampleUsers[i].username}');
        expect(row[3].trim(), sampleUsers[i].email);
      }
    });

    testWidgets('exportUsersToCsv includes UTF-8 BOM, commas, and escapes', (tester) async {
      await tester.pumpWidget(_buildTestWidget(locale: const Locale('en')));
      final BuildContext context = tester.element(find.byType(Scaffold));
      final l = AppLocalizations.of(context);

      final csv = UsersManagementExportService.exportUsersToCsv(sampleUsers, l);

      // Verify UTF-8 BOM
      expect(csv.startsWith('\uFEFF'), isTrue);

      final lines = csv.substring(1).trim().split('\n');
      expect(lines.length, 4);

      // Check commas present
      expect(lines[0].contains(','), isTrue);
      expect(lines[1].contains('Ahmed Sorour'), isTrue);
    });

    testWidgets('buildUsersDossier outputs structured dossier with KPIs and records', (tester) async {
      await tester.pumpWidget(_buildTestWidget(locale: const Locale('ar')));
      final BuildContext context = tester.element(find.byType(Scaffold));
      final l = AppLocalizations.of(context);

      final dossier = UsersManagementExportService.buildUsersDossier(sampleUsers, l);

      expect(dossier, contains(l.usersMgmtDossierHeader));
      expect(dossier, contains(l.usersMgmtDossierKpiSummary));
      expect(dossier, contains(l.usersMgmtDossierRecordsDetails));
      expect(dossier, contains(l.usersMgmtDossierFooter));

      // Check counts
      expect(dossier, contains('${l.usersMgmtStatAll}: 3'));
      expect(dossier, contains('${l.usersMgmtStatActive}: 2'));
      expect(dossier, contains('${l.usersMgmtStatusInactive}: 1'));
      expect(dossier, contains('${l.usersMgmtStatAdmin}: 1'));
      expect(dossier, contains('${l.usersMgmtStatManager}: 1'));
      expect(dossier, contains('${l.usersMgmtStatOperator}: 1'));

      // Check records
      expect(dossier, contains('1. '));
      expect(dossier, contains('2. '));
      expect(dossier, contains('3. '));
    });
  });
}
