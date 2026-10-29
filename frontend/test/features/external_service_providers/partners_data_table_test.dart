import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/buttons/app_button.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/widgets/partners_data_table.dart';
import 'package:frontend/features/external_service_providers/widgets/partner_registration_dialog.dart';
import '../../helpers/localized_app.dart';

void main() {
  final samplePartners = [
    PartnerModel(
      providerId: 1,
      partnerCode: 'PRT-001',
      partnerName: 'National Bank of Egypt',
      partnerType: 'Bank',
      swiftCode: 'NBEGEGCX',
      bankCode: '001',
      taxId: '100-200-300',
      commercialRegister: 'CR-998877',
      isActive: true,
    ),
    PartnerModel(
      providerId: 2,
      partnerCode: 'PRT-002',
      partnerName: 'Alexandria Customs Agency',
      partnerType: 'Customs Broker',
      clearanceLicenseNumber: 'LIC-2026',
      taxId: '200-300-400',
      isActive: true,
    ),
  ];

  testWidgets('PartnersDataTable renders partner rows and selection area', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    PartnerModel? editedPartner;

    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            height: 900,
            child: PartnersDataTable(
              partners: samplePartners,
              onEdit: (p) => editedPartner = p,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('National Bank of Egypt'), findsOneWidget);
    expect(find.text('Alexandria Customs Agency'), findsOneWidget);
    expect(find.byType(PartnersDataTable), findsOneWidget);
    expect(find.byType(SelectionArea), findsAtLeastNWidgets(1));
  });

  testWidgets('PartnerRegistrationDialog renders with SelectionArea and AppButtons', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: localizedApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    PartnerRegistrationDialog.show(context);
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.byType(PartnerRegistrationDialog), findsOneWidget);
    expect(find.byType(SelectionArea), findsAtLeastNWidgets(1));
    expect(find.byType(AppButton), findsAtLeastNWidgets(2)); // Cancel and Save buttons
  });
}
