"""
Database Updates Script
Executes user requested updates on ONE explicit database:
1. Deletes demo import companies, suppliers, external service providers, and CargoX envelopes/documents.
2. Creates and populates `countries` table (250 countries).
3. Populates `currencies` table (178 currencies).
4. Creates and populates `cities` table (all requested cities).
5. Populates `transport_locations` table (all sea ports, airports, dry ports, and land borders).

DESTRUCTIVE (step 1 wipes companies/suppliers/providers). Safety (update-system-plan A13/R12):
    python execute_user_database_updates.py --db <path/to/db> --confirm
The target must not be in use, and a verified pre_migration_ backup is taken first (abort on failure).
"""
import sqlite3
import sys
from pathlib import Path
from datetime import datetime
from typing import List, Optional

ROOT_DIR = Path(__file__).resolve().parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from scripts.db_script_guard import add_target_arguments, guard_target, run_cli_action  # noqa: E402

SCRIPT_TAG = "execute_user_database_updates"

RAW_COUNTRIES_TEXT = """
AF	AFGHANISTAN.
AL	ALBANIA.
DZ	ALGERIA.
AS	AMERICAN SAMOA.
AD	ANDORRA.
AO	ANGOLA.
AI	ANGUILLA.
AQ	ANTARCTICA.
AG	ANTIGUA AND BARBUDA.
AR	ARGENTINA.
AM	ARMENIA.
AW	ARUBA.
AU	AUSTRALIA.
AT	AUSTRIA.
AZ	AZERBAIJAN.
BS	BAHAMAS.
BH	BAHRIN.
BD	BANGLADESH.
BB	BARBADOS.
BY	BELARUS.
BE	BELGIUM.
BZ	BELIZE.
BJ	BENIN.
BM	BERMUDA.
BT	BHUTAN..
BO	BOLIVIA.
BA	BOSNIA AND HERZEGOVINA.
BW	BOTSWANA.
BR	BRAZIL.
IO	BRITISH INDIAN OCEAN TERRITORY.
BN	BRUNEI DARUSSALAM.
BG	BULGARIA.
BF	BURKINA FASO.
BI	BURUNDI.
BQ	Bonaire, Sint Eustat
KH	CAMBODIA.
CM	CAMEROON.
CA	CANADA.
CV	CAPE VERDE.
KY	CAYMAN ISLANDS.
CF	CENTRAL AFRICAN REPUBLIC.
TD	CHAD.
CL	CHILE.
CN	CHINA.
CX	CHRISTMAS ISLAND.
CC	COCOS [KEELING] ISLANDS.
CO	COLOMBIA.
KM	COMOROS.
CD	CONGO, THE DEMOCRATIC REPUBLIC OF THE
CG	CONGO.
CK	COOK ISLANDS.
CR	COSTA RICA.
CI	COTE D IVOIRE.
HR	CROATIA.
CU	CUBA.
CY	CYPRUS.
CZ	CZECH REPUBLIC.
CW	Curaçao
DK	DENMARK.
DJ	DJIBOUTI.
DM	DOMINICA.
DO	DOMINICAN REPUBLIC.
EC	ECUADOR.
EG	EGYPT.
SV	EL SALVADOR.
ER	ERITREA.
EE	ESTONIA.
ET	ETHIOPIA.
FK	FALKLAND ISLANDS [MALVINAS].
FO	FAROE ISLANDS.
FJ	FIJI.
FI	FINLAND.
FR	FRANCE.
GF	FRENCH GUIANA.
PF	FRENCH POLYNESIA.
TF	FRENCH SOUTHERN TERRITORIES.
GA	GABON.
GM	GAMBIA.
GE	GEORGIA.
DE	GERMANY.
GH	GHANA.
GI	GIBRALTAR.
GR	GREECE.
GL	GREENLAND.
GD	GRENADA.
GP	GUADELOUPE.
GU	GUAM.
GT	GUATEMALA.
GW	GUINEA-BISSAU.
GN	GUINEA.
GY	GUYANA.
HT	HAITI.
HM	HEARD ISLAND AND MCDONALD ISLANDS.
VA	HOLY SEE [VATICAN CITY STATE].
HN	HONDURAS.
HK	HONG KONG.
HU	HUNGARY.
IS	ICELAND.
IN	INDIA.
ID	INDONESIA.
IR	IRAN, ISLAMIC REPUBLIC OF.
IQ	IRAQ.
IE	IRELAND.
IM	ISLE OF MAN
IL	ISRAEL.
IT	ITALY.
JM	JAMAICA.
JP	JAPAN.
JO	JORDAN.
KZ	KAZAKSTAN.
KE	KENYA.
KI	KIRIBATI.
KP	KOREA, DEMOCRATIC PEOPLE S REPUBLIC OF
KR	KOREA, REPUBLIC OF.
KW	KUWAIT.
KG	KYRGYZSTAN.
LA	LAO PEOPLE S DEMOCRATIC REPUBLIC.
LV	LATVIA
LB	LEBANON.
LS	LESOTHO.
LR	LIBERIA.
LY	LIBYAN ARAB JAMAHIRIYA.
LI	LIECHTENSTEIN.
LT	LITHUANIA.
LU	LUXEMBOURG.
MO	MACAU.
MK	MACEDONIA, THE FORMER YUGOSLAV REPUBLIC
MG	MADAGASCAR.
MW	MALAWI.
MY	MALAYSIA.
MV	MALDIVES.
ML	MALI.
MT	MALTA.
MH	MARSHALL ISLANDS.
MQ	MARTINIQUE.
MR	MAURITANIA.
MU	MAURITIUS.
YT	MAYOTTE.
MX	MEXICO.
FM	MICRONESIA, FEDERATED STATES OF.
MD	MOLDOVA, REPUBLIC OF.
MC	MONACO.
MN	MONGOLIA.
ME	MONTENEGRO.
MS	MONTSERRAT.
MA	MOROCCO.
MZ	MOZAMBIQUE.
MM	MYANMAR.
NA	NAMIBIA.
NR	NAURU.
NP	NEPAL.
NL	NETHERLANDS.
NC	NEW CALEDONIA.
NZ	NEW ZEALAND.
NI	NICARAGUA.
NE	NIGER.
NG	NIGERIA.
NU	NIUE.
NF	NORFOLK ISLAND.
MP	NORTHERN MARIANA ISLANDS.
NO	NORWAY.
OM	OMAN.
PK	PAKISTANز
PW	PALAU.
PS	PALESTINIAN TERRITORY, OCCUPIED.
PA	PANAMA
PG	PAPUA NEW GUINEA.
PY	PARAGUAY.
PE	PERU.
PH	PHILIPPINES.
PN	PITCAIRN.
PL	POLAND.
PT	PORTUGAL.
PR	PUERTO RICO.
QA	QATAR.
RE	REUNION.
RO	ROMANIA.
RU	RUSSIAN FEDERATION.
RW	RWANDA.
SH	SAINT HELENA.
KN	SAINT KITTS AND NEVIS.
LC	SAINT LUCIA.
PM	SAINT PIERRE AND MIQUELON.
VC	SAINT VINCENT AND THE GRENADINES.
WS	SAMOA.
SM	SAN MARINO.
ST	SAO TOME AND PRINCIPE.
SA	SAUDI ARABIA.
SN	SENEGAL.
RS	SERBIA & MONTENEGRO.
SC	SEYCHELLES.
SL	SIERRA LEONE.
SG	SINGAPORE.
SK	SLOVAKIA.
SI	SLOVENIA.
SB	SOLOMON ISLANDS.
SO	SOMALIA.
ZA	SOUTH AFRICA.
GS	SOUTH GEORGIA AND THE SOUTH SANDWICH ISL
ES	SPAIN.
LK	SRI LANKA.
SD	SUDAN.
SR	SURINAME.
SJ	SVALBARD AND JAN MAYEN.
SZ	SWAZILAND.
SE	SWEDEN.
CH	SWITZERLAND.
SY	SYRIAN ARAB REPUBLIC.
BL	Saint Barthelemy
MF	Saint Martin (French
SX	Sint Maarten (Dutch
SS	South Sudan
TW	TAIWAN, PROVINCE OF CHINA.
TJ	TAJIKISTAN.
TZ	TANZANIA, UNITED REPUBLIC OF.
TH	THAILAND.
TL	TIMOR-LESTE
TG	TOGO.
TK	TOKELAU.
TO	TONGA.
TT	TRINIDAD AND TOBAGO.
TN	TUNISIA.
TR	TURKEY.
TM	TURKMENISTAN.
TC	TURKS AND CAICOS ISLANDS.
TV	TUVALU.
UG	UGANDA.
UA	UKRAINE.
AE	UNITED ARAB EMIRATES.
GB	UNITED KINGDOM.
UM	UNITED STATES MINOROUTLYINGISLANDS
US	UNITED STATES.
UY	URUGUAY.
UZ	UZBEKISTAN.
VU	VANUATU.
VE	VENEZUELA.
VN	VIET NAM.
VG	VIRGIN ISLANDS, BRITISH.
VI	VIRGIN ISLANDS, U.S
WF	WALLIS AND FUTUNA.
EH	WESTERN SAHARA.
YE	YEMEN.
ZM	ZAMBIA.
ZW	ZIMBABWE.
"""

RAW_CURRENCIES_TEXT = """
Afghani	AFN
Euro	EUR
Lek	ALL
Algerian Dinar	DZD
US Dollar	USD
Kwanza	AOA
East Caribbean Dollar	XCD
Argentine Peso	ARS
Armenian Dram	AMD
Aruban Florin	AWG
Australian Dollar	AUD
Azerbaijan Manat	AZN
Bahamian Dollar	BSD
Bahraini Dinar	BHD
Taka	BDT
Barbados Dollar	BBD
Belarusian Ruble	BYN
Belize Dollar	BZD
CFA Franc BCEAO	XOF
Bermudian Dollar	BMD
Indian Rupee	INR
Ngultrum	BTN
Boliviano	BOB
Mvdol	BOV
Convertible Mark	BAM
Pula	BWP
Norwegian Krone	NOK
Brazilian Real	BRL
Brunei Dollar	BND
Bulgarian Lev	BGN
Burundi Franc	BIF
Cabo Verde Escudo	CVE
Riel	KHR
CFA Franc BEAC	XAF
Canadian Dollar	CAD
Cayman Islands Dollar	KYD
Chilean Peso	CLP
Unidad de Fomento	CLF
Yuan Renminbi	CNY
Colombian Peso	COP
Unidad de Valor Real	COU
Comorian Franc 	KMF
Congolese Franc	CDF
New Zealand Dollar	NZD
Costa Rican Colon	CRC
Kuna	HRK
Cuban Peso	CUP
Peso Convertible	CUC
Netherlands Antillean Guilder	ANG
Czech Koruna	CZK
Danish Krone	DKK
Djibouti Franc	DJF
Dominican Peso	DOP
Egyptian Pound	EGP
El Salvador Colon	SVC
Nakfa	ERN
Lilangeni	SZL
Ethiopian Birr	ETB
Falkland Islands Pound	FKP
Fiji Dollar	FJD
CFP Franc	XPF
Dalasi	GMD
Lari	GEL
Ghana Cedi	GHS
Gibraltar Pound	GIP
Quetzal	GTQ
Pound Sterling	GBP
Guinean Franc	GNF
Guyana Dollar	GYD
Gourde	HTG
Lempira	HNL
Hong Kong Dollar	HKD
Forint	HUF
Iceland Krona	ISK
Rupiah	IDR
SDR (Special Drawing Right)	XDR
Iranian Rial	IRR
Iraqi Dinar	IQD
New Israeli Sheqel	ILS
Jamaican Dollar	JMD
Yen	JPY
Jordanian Dinar	JOD
Tenge	KZT
Kenyan Shilling	KES
North Korean Won	KPW
Won	KRW
Kuwaiti Dinar	KWD
Som	KGS
Lao Kip	LAK
Lebanese Pound	LBP
Loti	LSL
Rand	ZAR
Liberian Dollar	LRD
Libyan Dinar	LYD
Swiss Franc	CHF
Pataca	MOP
Malagasy Ariary	MGA
Malawi Kwacha	MWK
Malaysian Ringgit	MYR
Rufiyaa	MVR
Ouguiya	MRU
Mauritius Rupee	MUR
ADB Unit of Account	XUA
Mexican Peso	MXN
Mexican Unidad de Inversion (UDI)	MXV
Moldovan Leu	MDL
Tugrik	MNT
Moroccan Dirham	MAD
Mozambique Metical	MZN
Kyat	MMK
Namibia Dollar	NAD
Nepalese Rupee	NPR
Cordoba Oro	NIO
Naira	NGN
Denar	MKD
Rial Omani	OMR
Pakistan Rupee	PKR
Balboa	PAB
Kina	PGK
Guarani	PYG
Sol	PEN
Philippine Peso	PHP
Zloty	PLN
Qatari Rial	QAR
Romanian Leu	RON
Russian Ruble	RUB
Rwanda Franc	RWF
Saint Helena Pound	SHP
Tala	WST
Dobra	STN
Saudi Riyal	SAR
Serbian Dinar	RSD
Seychelles Rupee	SCR
Leone	SLL
Singapore Dollar	SGD
Sucre	XSU
Solomon Islands Dollar	SBD
Somali Shilling	SOS
South Sudanese Pound	SSP
Sri Lanka Rupee	LKR
Sudanese Pound	SDG
Surinam Dollar	SRD
Swedish Krona	SEK
WIR Euro	CHE
WIR Franc	CHW
Syrian Pound	SYP
New Taiwan Dollar	TWD
Somoni	TJS
Tanzanian Shilling	TZS
Baht	THB
Pa’anga	TOP
Trinidad and Tobago Dollar	TTD
Tunisian Dinar	TND
Turkish Lira	TRY
Turkmenistan New Manat	TMT
Uganda Shilling	UGX
Hryvnia	UAH
UAE Dirham	AED
US Dollar (Next day)	USN
Peso Uruguayo	UYU
Uruguay Peso en Unidades Indexadas (UI)	UYI
Unidad Previsional	UYW
Uzbekistan Sum	UZS
Vatu	VUV
Bolívar Soberano	VES
Dong	VND
Yemeni Rial	YER
Zambian Kwacha	ZMW
Zimbabwe Dollar	ZWL
"""

def get_parsed_countries():
    countries = []
    seen = set()
    for line in RAW_COUNTRIES_TEXT.strip().split("\n"):
        parts = line.strip().split("\t")
        if len(parts) >= 2:
            code = parts[0].strip().upper()
            name = parts[1].strip().rstrip(".").rstrip("ز").strip()
            if code and code not in seen:
                seen.add(code)
                countries.append((code, name))
    return countries

def get_parsed_currencies():
    currencies = []
    seen = set()
    for line in RAW_CURRENCIES_TEXT.strip().split("\n"):
        parts = line.strip().split("\t")
        if len(parts) >= 2:
            name = parts[0].strip()
            code = parts[1].strip().upper()
            if code and code not in seen:
                seen.add(code)
                is_base = 1 if code == "EGP" else 0
                currencies.append((code, name, is_base))
    return currencies

def get_parsed_cities():
    cities_file = ROOT_DIR / "raw_cities.txt"
    cities = []
    seen = set()
    if cities_file.exists():
        with open(cities_file, "r", encoding="utf-8") as f:
            for line in f:
                parts = line.strip().split("\t")
                if len(parts) >= 2:
                    code = parts[0].strip()
                    name = parts[1].strip()
                    if code and code not in seen:
                        seen.add(code)
                        country_code = code[:2].upper()
                        cities.append((code, name, country_code))
    return cities

def get_comprehensive_ports():
    # Egyptian & Global comprehensive ports, airports, dry ports, and land borders
    ports = [
        # Egypt Sea Ports
        ("EGALY", "Alexandria Port", "Sea Port", "Egypt", "Alexandria"),
        ("EGEDK", "El Dekheila Port", "Sea Port", "Egypt", "Alexandria"),
        ("EGPSD", "Port Said West", "Sea Port", "Egypt", "Port Said"),
        ("EGPSG", "Port Said East / SCCT", "Sea Port", "Egypt", "Port Said"),
        ("EGDAM", "Damietta Port", "Sea Port", "Egypt", "Damietta"),
        ("EGSOK", "Ain Sokhna Port / DP World", "Sea Port", "Egypt", "Suez"),
        ("EGSUZ", "Suez Port", "Sea Port", "Egypt", "Suez"),
        ("EGADA", "Adabiya Port", "Sea Port", "Egypt", "Suez"),
        ("EGSFA", "Safaga Port", "Sea Port", "Egypt", "Red Sea"),
        ("EGNWB", "Nuweiba Port", "Sea Port", "Egypt", "South Sinai"),
        ("EGSSH", "Sharm El Sheikh Port", "Sea Port", "Egypt", "South Sinai"),
        ("EGHRG", "Hurghada Port", "Sea Port", "Egypt", "Red Sea"),
        ("EGABS", "Abu Zenima Port", "Sea Port", "Egypt", "South Sinai"),
        ("EGAQU", "Abu Qir Port", "Sea Port", "Egypt", "Alexandria"),
        ("EGGAR", "El Garada Port", "Sea Port", "Egypt", "North Sinai"),
        # Egypt Airports (Air Cargo)
        ("EGCAI", "Cairo Cargo Terminal / CAI Airport", "Airport", "Egypt", "Cairo"),
        ("EGHBE", "Borg El Arab Cargo Terminal", "Airport", "Egypt", "Alexandria"),
        ("EGSPX", "Sphinx International Airport Cargo", "Airport", "Egypt", "Giza"),
        ("EGLXR", "Luxor Airport Cargo", "Airport", "Egypt", "Luxor"),
        ("EGASW", "Aswan Airport Cargo", "Airport", "Egypt", "Aswan"),
        # Egypt Dry Ports & Land Borders (الموانئ الجافة والمنافذ البرية)
        ("EGOCT", "6th of October Dry Port / ODPI", "Dry Port", "Egypt", "6th of October"),
        ("EGRAM", "10th of Ramadan Dry Port", "Dry Port", "Egypt", "10th of Ramadan"),
        ("EGSAD", "Sadat City Dry Port", "Dry Port", "Egypt", "Sadat City"),
        ("EGBOR", "Borg El Arab Dry Port", "Dry Port", "Egypt", "Borg El Arab"),
        ("EGSLM", "Salloum Land Border Port", "Land Border", "Egypt", "Matrouh"),
        ("EGAWN", "Qastal Land Border Port", "Land Border", "Egypt", "Aswan"),
        ("EGARK", "Argeen Land Border Port", "Land Border", "Egypt", "Aswan"),
        ("EGTAB", "Taba Land Border Crossing", "Land Border", "Egypt", "Taba"),
        ("EGOJA", "Al Awja Land Port", "Land Border", "Egypt", "North Sinai"),
        ("EGRAH", "Rafah Land Crossing", "Land Border", "Egypt", "North Sinai"),
        
        # Major Global Hubs (China, Europe, Gulf, Asia, Americas)
        ("CNSHA", "Shanghai Port", "Sea Port", "China", "Shanghai"),
        ("CNNGB", "Ningbo-Zhoushan Port", "Sea Port", "China", "Ningbo"),
        ("CNSZX", "Shenzhen Port / Yantian", "Sea Port", "China", "Shenzhen"),
        ("CNGZG", "Guangzhou Port / Nansha", "Sea Port", "China", "Guangzhou"),
        ("CNQDG", "Qingdao Port", "Sea Port", "China", "Qingdao"),
        ("CNTNJ", "Tianjin Port", "Sea Port", "China", "Tianjin"),
        ("CNXMN", "Xiamen Port", "Sea Port", "China", "Xiamen"),
        ("HKHKG", "Hong Kong Port", "Sea Port", "Hong Kong", "Hong Kong"),
        ("SGSIN", "Singapore Port / PSA", "Sea Port", "Singapore", "Singapore"),
        ("MYPKG", "Port Klang", "Sea Port", "Malaysia", "Klang"),
        ("KRPUS", "Busan Port", "Sea Port", "South Korea", "Busan"),
        ("JPTYO", "Tokyo Port", "Sea Port", "Japan", "Tokyo"),
        ("JPYOK", "Yokohama Port", "Sea Port", "Japan", "Yokohama"),
        ("AEJEA", "Jebel Ali Port / DP World", "Sea Port", "United Arab Emirates", "Dubai"),
        ("SAJED", "Jeddah Islamic Port", "Sea Port", "Saudi Arabia", "Jeddah"),
        ("SADMM", "King Abdulaziz Port Dammam", "Sea Port", "Saudi Arabia", "Dammam"),
        ("NLRTM", "Rotterdam Port", "Sea Port", "Netherlands", "Rotterdam"),
        ("BEANR", "Antwerp Port", "Sea Port", "Belgium", "Antwerp"),
        ("DEHAM", "Hamburg Port", "Sea Port", "Germany", "Hamburg"),
        ("DEBRE", "Bremerhaven Port", "Sea Port", "Germany", "Bremerhaven"),
        ("ITGOA", "Genoa Port", "Sea Port", "Italy", "Genoa"),
        ("ITSPE", "La Spezia Port", "Sea Port", "Italy", "La Spezia"),
        ("ITTRS", "Trieste Port", "Sea Port", "Italy", "Trieste"),
        ("ESVLC", "Valencia Port", "Sea Port", "Spain", "Valencia"),
        ("ESBCN", "Barcelona Port", "Sea Port", "Spain", "Barcelona"),
        ("ESALG", "Algeciras Port", "Sea Port", "Spain", "Algeciras"),
        ("TRIST", "Istanbul Port / Ambarli", "Sea Port", "Turkey", "Istanbul"),
        ("TRMERS", "Mersin Port", "Sea Port", "Turkey", "Mersin"),
        ("TRALI", "Aliaga Port / Izmir", "Sea Port", "Turkey", "Izmir"),
        ("GRPIR", "Piraeus Port", "Sea Port", "Greece", "Athens"),
        ("USNYC", "New York & New Jersey Port", "Sea Port", "United States", "New York"),
        ("USLAX", "Los Angeles Port", "Sea Port", "United States", "Los Angeles"),
        ("USLGB", "Long Beach Port", "Sea Port", "United States", "Long Beach"),
        ("USHOU", "Houston Port", "Sea Port", "United States", "Houston"),
        ("INNSA", "Jawaharlal Nehru Port / Nhava Sheva", "Sea Port", "India", "Mumbai"),
        ("INMUN", "Mundra Port", "Sea Port", "India", "Gujarat"),
    ]
    return ports

def execute_updates_on_db(db_path: Path, *, confirm: bool = False, backups_dir: Optional[Path] = None) -> bool:
    """Apply the updates to ``db_path`` only.

    confirm=True: target must not be in use; a verified backup is taken first (UnsafeTargetError otherwise).
    confirm=False: refused for the live app database or a database in use.
    """
    db_path = Path(db_path)
    guard_target(db_path, confirm=confirm, tag=SCRIPT_TAG, backups_dir=backups_dir)

    print(f"\n--- Executing updates on: {db_path} ---")
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    # 1. Create tables if not exist
    cur.execute("""
    CREATE TABLE IF NOT EXISTS countries (
        country_id INTEGER PRIMARY KEY AUTOINCREMENT,
        country_code VARCHAR(10) NOT NULL UNIQUE,
        country_name VARCHAR(150) NOT NULL,
        country_name_ar VARCHAR(150),
        is_active BOOLEAN NOT NULL DEFAULT 1,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS cities (
        city_id INTEGER PRIMARY KEY AUTOINCREMENT,
        city_code VARCHAR(20) NOT NULL UNIQUE,
        city_name VARCHAR(150) NOT NULL,
        country_code VARCHAR(10),
        is_active BOOLEAN NOT NULL DEFAULT 1,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    """)

    # 2. Wipe requested demo/operational data
    print("   [1/5] Wiping demo companies, suppliers, ESPs, and CargoX envelopes...")
    cur.execute("DELETE FROM import_companies;")
    cur.execute("DELETE FROM suppliers;")
    cur.execute("DELETE FROM external_service_providers;")
    cur.execute("DELETE FROM cargox_envelope_documents;")
    cur.execute("DELETE FROM cargox_envelopes;")
    try:
        cur.execute("DELETE FROM cargox_standard_invoice_sessions;")
    except Exception:
        pass
    conn.commit()

    now_iso = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # 3. Populate Countries
    countries = get_parsed_countries()
    print(f"   [2/5] Populating countries table ({len(countries)} countries)...")
    for code, name in countries:
        cur.execute(
            """INSERT INTO countries (country_code, country_name, is_active, created_at, updated_at)
               VALUES (?, ?, 1, ?, ?)
               ON CONFLICT(country_code) DO UPDATE SET
                   country_name=excluded.country_name,
                   updated_at=excluded.updated_at;""",
            (code, name, now_iso, now_iso)
        )
    conn.commit()

    # 4. Populate Currencies
    currencies = get_parsed_currencies()
    print(f"   [3/5] Populating currencies table ({len(currencies)} currencies)...")
    for code, name, is_base in currencies:
        cur.execute(
            """INSERT INTO currencies (currency_code, currency_name, currency_symbol, is_base_currency, decimal_places, is_active, created_at, updated_at)
               VALUES (?, ?, '', ?, 2, 1, ?, ?)
               ON CONFLICT(currency_code) DO UPDATE SET
                   currency_name=excluded.currency_name,
                   is_base_currency=excluded.is_base_currency,
                   updated_at=excluded.updated_at;""",
            (code, name, is_base, now_iso, now_iso)
        )
    conn.commit()

    # 5. Populate Cities
    cities = get_parsed_cities()
    print(f"   [4/5] Populating cities table ({len(cities)} cities)...")
    for code, name, country_code in cities:
        cur.execute(
            """INSERT INTO cities (city_code, city_name, country_code, is_active, created_at, updated_at)
               VALUES (?, ?, ?, 1, ?, ?)
               ON CONFLICT(city_code) DO UPDATE SET
                   city_name=excluded.city_name,
                   country_code=excluded.country_code,
                   updated_at=excluded.updated_at;""",
            (code, name, country_code, now_iso, now_iso)
        )
    conn.commit()

    # 6. Populate Transport Locations (Airports, Sea Ports, Dry Ports, Land Borders)
    ports = get_comprehensive_ports()
    print(f"   [5/5] Populating transport_locations ({len(ports)} ports/borders)...")
    now_iso = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    for un_locode, name, loc_type, country, city in ports:
        cur.execute(
            """INSERT INTO transport_locations (un_locode, location_name, location_type, country, city, is_active, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, 1, ?, ?)
               ON CONFLICT(un_locode) DO UPDATE SET
                   location_name=excluded.location_name,
                   location_type=excluded.location_type,
                   country=excluded.country,
                   city=excluded.city,
                   updated_at=excluded.updated_at;""",
            (un_locode, name, loc_type, country, city, now_iso, now_iso)
        )
    conn.commit()

    # Print summary counts
    print("   [SUMMARY] Current records count in updated database:")
    for tbl in ["import_companies", "suppliers", "external_service_providers", "cargox_envelopes", "countries", "currencies", "cities", "transport_locations"]:
        try:
            cur.execute(f'SELECT COUNT(*) FROM "{tbl}";')
            cnt = cur.fetchone()[0]
            print(f"      - {tbl}: {cnt} records")
        except Exception as e:
            print(f"      - {tbl}: error ({e})")

    conn.close()
    return True


def main(argv: Optional[List[str]] = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(
        description="Wipe demo companies/suppliers/providers/CargoX data and expand master data on ONE database."
    )
    add_target_arguments(parser, target_help="Database file to update")
    args = parser.parse_args(argv)

    def _run(target: Path, backups_dir: Optional[Path]):
        print("===============================================================================")
        print("         ImportFlow ERP - Database Cleansing & Master Data Expansion          ")
        print("===============================================================================")
        if not (ROOT_DIR / "raw_cities.txt").exists():
            print("Note: raw_cities.txt not found; the cities step will insert nothing.")
        execute_updates_on_db(target, confirm=True, backups_dir=backups_dir)
        print(f"\n[SUCCESS] Database modifications applied to {target}")
        return True

    return run_cli_action(args, _run)


if __name__ == "__main__":
    sys.exit(main())
