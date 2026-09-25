import os
import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from modules.transport_locations.model import TransportLocation
from modules.customs_tariff.model import CustomsTariff
from modules.currencies.model import Currency, ExchangeRate

MASTER_DB_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "sorour_logistics.db"))
master_engine = create_engine(f"sqlite:///{MASTER_DB_PATH}")
MasterSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=master_engine)


# This suite audits the reference data seeded into the local operational database. It only runs where
# that database exists (a developer / production machine), never in CI, and must not create the file.
@unittest.skipUnless(os.path.exists(MASTER_DB_PATH), f"operational database not present at {MASTER_DB_PATH}")
class TestMD09PortsTariffExchangeAudit(unittest.TestCase):
    def setUp(self):
        self.db = MasterSessionLocal()
        # The startup master-data sync seeds only a small baseline (currencies, ~10 tariffs). Transport
        # locations come solely from the populate scripts, so an empty table means this database never had
        # the full reference data loaded - an environment state, not a data regression.
        if self.db.query(TransportLocation).count() == 0:
            self.db.close()
            self.skipTest("reference data not populated in this database (transport_locations is empty)")

    def tearDown(self):
        self.db.close()

    def test_ports_and_transport_locations_audit(self):
        """Verify readiness of Egyptian and international ports, UN/LOCODEs, and categories."""
        locations = self.db.query(TransportLocation).filter(TransportLocation.is_active == True).all()
        self.assertGreaterEqual(len(locations), 100, "Should have at least 100 active transport locations")

        # Check key Egyptian Sea Ports
        egypt_locodes = {l.un_locode: l for l in locations if l.country == 'Egypt'}
        required_eg_sea_ports = ['EGALY', 'EGSOK', 'EGDAM', 'EGPSD', 'EGDKH']
        for locode in required_eg_sea_ports:
            self.assertIn(locode, egypt_locodes, f"Required Egyptian Sea Port {locode} is missing")
            self.assertEqual(egypt_locodes[locode].location_type, 'Sea Port')

        # Check key Egyptian Air Ports
        self.assertIn('EGCAI', egypt_locodes, "Cairo International Airport (EGCAI) is missing")
        self.assertEqual(egypt_locodes['EGCAI'].location_type, 'Airport')

        # Check key Egyptian Dry Ports
        self.assertIn('EG6OCT', egypt_locodes, "6th of October Dry Port (EG6OCT) is missing")
        self.assertEqual(egypt_locodes['EG6OCT'].location_type, 'Dry Port')

        # Check key International Departure Ports (China, Europe, Gulf)
        int_locodes = {l.un_locode: l for l in locations}
        required_int_ports = ['CNSHA', 'CNNGB', 'CNTAO', 'DEHAM', 'ITGOA', 'AEJEA']
        for locode in required_int_ports:
            self.assertIn(locode, int_locodes, f"Required International Departure Port {locode} is missing")

    def test_customs_tariffs_audit(self):
        """Verify Egyptian Customs tariff schedule, duty rates, VAT, and exemptions."""
        tariffs = self.db.query(CustomsTariff).filter(CustomsTariff.is_active == True).all()
        self.assertGreaterEqual(len(tariffs), 50, "Should have at least 50 standard Egyptian HS code tariffs")

        tariff_map = {t.hs_code: t for t in tariffs}

        # Check essential HS codes
        self.assertIn('8471.30.00', tariff_map, "Laptop/PC HS Code 8471.30.00 missing")
        self.assertIn('8517.13.00', tariff_map, "Smartphones HS Code 8517.13.00 missing")
        self.assertIn('3004.90.90', tariff_map, "Medicaments HS Code 3004.90.90 missing")

        # Check rates validity
        for t in tariffs:
            self.assertGreaterEqual(t.customs_duty_rate, 0.0)
            self.assertLessEqual(t.customs_duty_rate, 3000.0)
            self.assertGreaterEqual(t.vat_rate, 0.0)
            self.assertLessEqual(t.vat_rate, 100.0)

        # Medicaments should be exempt from duty and VAT under Egyptian law
        med = tariff_map['3004.90.90']
        self.assertEqual(med.customs_duty_rate, 0.0)
        self.assertEqual(med.vat_rate, 0.0)

    def test_currencies_and_exchange_rates_audit(self):
        """Verify currencies, base EGP currency, and active commercial & customs exchange rates."""
        currencies = self.db.query(Currency).filter(Currency.is_active == True).all()
        self.assertGreaterEqual(len(currencies), 8, "Should have at least 8 active currencies")

        curr_map = {c.currency_code: c for c in currencies}
        required_codes = ['EGP', 'USD', 'EUR', 'GBP', 'CNY', 'SAR', 'AED']
        for code in required_codes:
            self.assertIn(code, curr_map, f"Required currency {code} is missing")

        # Verify exchange rates exist for all core currencies
        for code in required_codes:
            c = curr_map[code]
            latest_rate = self.db.query(ExchangeRate).filter(
                ExchangeRate.currency_id == c.currency_id,
                ExchangeRate.is_active == True
            ).order_by(ExchangeRate.effective_date.desc()).first()

            self.assertIsNotNone(latest_rate, f"Currency {code} has no active exchange rate")
            self.assertGreater(latest_rate.commercial_rate, 0.0)
            self.assertGreater(latest_rate.customs_rate, 0.0)

            if code == 'EGP':
                self.assertEqual(latest_rate.commercial_rate, 1.0)
                self.assertEqual(latest_rate.customs_rate, 1.0)


if __name__ == '__main__':
    unittest.main()

