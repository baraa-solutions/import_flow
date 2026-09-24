"""
Wipe Projects, Fix Currencies, and Populate All World Transport Locations on ONE explicit database.

DESTRUCTIVE (deletes every project). Safety (update-system-plan A13/R12):
    python populate_all_world_transport_locations.py --db <path/to/db> --confirm
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

SCRIPT_TAG = "populate_all_world_transport_locations"

CURRENCY_SYMBOLS = {
    "USD": "$", "EUR": "€", "GBP": "£", "EGP": "E£", "JPY": "¥", "CNY": "¥",
    "SAR": "SAR", "AED": "AED", "KWD": "KD", "QAR": "QR", "BHD": "BD",
    "OMR": "OMR", "JOD": "JD", "CHF": "CHF", "CAD": "CA$", "AUD": "A$",
    "NZD": "NZ$", "INR": "₹", "RUB": "₽", "TRY": "₺", "BRL": "R$",
    "ZAR": "R", "KRW": "₩", "SEK": "kr", "NOK": "kr", "DKK": "kr",
    "PLN": "zł", "THB": "฿", "IDR": "Rp", "MYR": "RM", "SGD": "S$",
    "HKD": "HK$", "TWD": "NT$", "MXN": "Mex$", "ARS": "ARS", "CLP": "CLP",
    "COP": "COP", "PEN": "S/.", "VND": "₫", "PHP": "₱", "PKR": "₨",
    "BDT": "৳", "NGN": "₦", "KES": "KSh", "GHS": "GH₵", "MAD": "MAD",
    "DZD": "DZD", "TND": "DT", "IQD": "IQD", "LYD": "LD", "LBP": "LL",
    "SYP": "LS", "YER": "YR", "SDG": "SDG", "AFN": "", "ALL": "L",
    "AMD": "֏", "AOA": "Kz", "AZN": "₼", "BAM": "KM", "BBD": "Bds$",
    "BIF": "FBu", "BMD": "BD$", "BND": "B$", "BOB": "Bs.", "BSD": "B$",
    "BTN": "Nu.", "BWP": "P", "BYN": "Br", "BZD": "BZ$", "CDF": "FC",
    "CRC": "₡", "CUP": "₱", "CVE": "Esc", "CZK": "Kč", "DJF": "Fdj",
    "DOP": "RD$", "ERN": "Nfk", "ETB": "Br", "FJD": "FJ$", "FKP": "FK£",
    "GEL": "₾", "GIP": "GIP", "GMD": "D", "GNF": "FG", "GTQ": "Q",
    "GYD": "G$", "HNL": "L", "HRK": "kn", "HTG": "G", "HUF": "Ft",
    "ILS": "₪", "ISK": "kr", "JMD": "J$", "KGS": "с", "KHR": "៛",
    "KMF": "CF", "KPW": "₩", "KZT": "₸", "LAK": "₭", "LKR": "Rs",
    "LRD": "L$", "LSL": "M", "MDL": "L", "MGA": "Ar", "MKD": "ден",
    "MMK": "K", "MNT": "₮", "MOP": "MOP$", "MRU": "UM", "MUR": "Rs",
    "MVR": "Rf", "MWK": "MK", "MZN": "MT", "NAD": "N$", "NIO": "C$",
    "NPR": "Rs", "PAB": "B/.", "PGK": "K", "PYG": "₲", "RON": "lei",
    "RSD": "дин.", "RWF": "RF", "SBD": "SI$", "SCR": "SR", "SHP": "SH£",
    "SLL": "Le", "SOS": "Sh", "SRD": "Sr$", "SSP": "SS£", "STN": "Db",
    "SVC": "₡", "SZL": "L", "TJS": "SM", "TMT": "T", "TOP": "T$",
    "TTD": "TT$", "TZS": "TSh", "UAH": "₴", "UGX": "USh", "UYU": "$U",
    "UZS": "so'm", "VES": "Bs.S", "VUV": "VT", "WST": "WS$", "XAF": "FCFA",
    "XCD": "EC$", "XOF": "CFA", "XPF": "CFPF", "ZMW": "ZK", "ZWL": "Z$",
}

# Major Global Hubs and Ports dataset
MAJOR_PORTS_AIRPORTS_BORDERS = [
    # --- EGYPT (Complete Comprehensive Ports, Airports, Dry Ports, Land Borders) ---
    ("EGALY", "Alexandria Port", "Sea Port", "Egypt", "Alexandria"),
    ("EGEDK", "El Dekheila Port", "Sea Port", "Egypt", "Alexandria"),
    ("EGPSD", "Port Said West", "Sea Port", "Egypt", "Port Said"),
    ("EGPSG", "Port Said East / SCCT", "Sea Port", "Egypt", "Port Said"),
    ("EGDAM", "Damietta Port", "Sea Port", "Egypt", "Damietta"),
    ("EGSOK", "Ain Sokhna Port / DP World", "Sea Port", "Egypt", "Suez"),
    ("EGSUZ", "Suez Port / Port Tawfiq", "Sea Port", "Egypt", "Suez"),
    ("EGADA", "Adabiya Port", "Sea Port", "Egypt", "Suez"),
    ("EGSFA", "Safaga Port", "Sea Port", "Egypt", "Red Sea"),
    ("EGNWB", "Nuweiba Port", "Sea Port", "Egypt", "South Sinai"),
    ("EGSSH", "Sharm El Sheikh Port", "Sea Port", "Egypt", "South Sinai"),
    ("EGHRG", "Hurghada Port", "Sea Port", "Egypt", "Red Sea"),
    ("EGABS", "Abu Zenima Port", "Sea Port", "Egypt", "South Sinai"),
    ("EGAQU", "Abu Qir Port", "Sea Port", "Egypt", "Alexandria"),
    ("EGGAR", "El Garada / Arish Port", "Sea Port", "Egypt", "North Sinai"),
    ("EGMTR", "Mersa Matruh Port", "Sea Port", "Egypt", "Matrouh"),
    ("EGBER", "Berenice Port", "Sea Port", "Egypt", "Red Sea"),
    ("EGSKR", "Sidi Kerir Offshore Terminal", "Sea Port", "Egypt", "Alexandria"),
    ("EGRGH", "Ras Ghareb Terminal", "Sea Port", "Egypt", "Red Sea"),
    ("EGRSH", "Ras Shukheir Terminal", "Sea Port", "Egypt", "Red Sea"),
    ("EGHMD", "El Hamra Oil Port", "Sea Port", "Egypt", "Matrouh"),
    
    # Egypt Cargo Airports
    ("EGCAI", "Cairo Cargo Terminal / CAI Airport", "Airport", "Egypt", "Cairo"),
    ("EGHBE", "Borg El Arab Cargo Airport", "Airport", "Egypt", "Alexandria"),
    ("EGSPX", "Sphinx International Cargo Airport", "Airport", "Egypt", "Giza"),
    ("EGLXR", "Luxor Cargo Airport", "Airport", "Egypt", "Luxor"),
    ("EGASW", "Aswan Cargo Airport", "Airport", "Egypt", "Aswan"),
    ("EGHRK", "Hurghada International Cargo", "Airport", "Egypt", "Red Sea"),
    ("EGSSZ", "Sharm El Sheikh Cargo Airport", "Airport", "Egypt", "South Sinai"),
    ("EGDBB", "El Dabaa / Al Alamein Cargo Airport", "Airport", "Egypt", "Matrouh"),
    ("EGTBA", "Taba International Airport", "Airport", "Egypt", "South Sinai"),
    
    # Egypt Dry Ports & Logistics Centers (الموانئ الجافة والمراكز اللوجستية)
    ("EGOCT", "6th of October Dry Port / ODPI", "Dry Port", "Egypt", "6th of October"),
    ("EGRAM", "10th of Ramadan Dry Port", "Dry Port", "Egypt", "10th of Ramadan"),
    ("EGSAD", "Sadat City Dry Port", "Dry Port", "Egypt", "Sadat City"),
    ("EGBOR", "Borg El Arab Dry Port", "Dry Port", "Egypt", "Borg El Arab"),
    ("EGSHG", "Sohag Dry Port", "Dry Port", "Egypt", "Sohag"),
    ("EGBNS", "Beni Suef Dry Port", "Dry Port", "Egypt", "Beni Suef"),
    ("EGFYM", "Fayoum Dry Port", "Dry Port", "Egypt", "Fayoum"),
    ("EGBAD", "Badr Logistics City / Dry Port", "Dry Port", "Egypt", "Cairo"),
    
    # Egypt Land Borders & Border Crossings (المنافذ البرية والمعابر الحدودية)
    ("EGSLM", "Salloum Land Border Crossing", "Land Border", "Egypt", "Matrouh"),
    ("EGAWN", "Qastal Land Border Crossing", "Land Border", "Egypt", "Aswan"),
    ("EGARK", "Argeen Land Border Crossing", "Land Border", "Egypt", "Aswan"),
    ("EGTAB", "Taba Land Border Port", "Land Border", "Egypt", "Taba"),
    ("EGOJA", "Al Awja Land Cargo Port", "Land Border", "Egypt", "North Sinai"),
    ("EGRAH", "Rafah Land Crossing", "Land Border", "Egypt", "North Sinai"),
    ("EGHDB", "Ras Hadarba Land Crossing", "Land Border", "Egypt", "Red Sea"),

    # --- CHINA (Major Sea Ports & Airports) ---
    ("CNSHA", "Shanghai Port / Yangshan", "Sea Port", "China", "Shanghai"),
    ("CNNGB", "Ningbo-Zhoushan Port", "Sea Port", "China", "Ningbo"),
    ("CNSZX", "Shenzhen Port / Yantian / Shekou", "Sea Port", "China", "Shenzhen"),
    ("CNGZG", "Guangzhou Port / Nansha", "Sea Port", "China", "Guangzhou"),
    ("CNQDG", "Qingdao Port", "Sea Port", "China", "Qingdao"),
    ("CNTNJ", "Tianjin Port / Xingang", "Sea Port", "China", "Tianjin"),
    ("CNXMN", "Xiamen Port", "Sea Port", "China", "Xiamen"),
    ("CNDAL", "Dalian Port", "Sea Port", "China", "Dalian"),
    ("CNLYG", "Lianyungang Port", "Sea Port", "China", "Lianyungang"),
    ("CNFOC", "Fuzhou Port", "Sea Port", "China", "Fuzhou"),
    ("CNPVG", "Shanghai Pudong Cargo Airport", "Airport", "China", "Shanghai"),
    ("CNCAN", "Guangzhou Baiyun Cargo Airport", "Airport", "China", "Guangzhou"),
    ("CNPEK", "Beijing Capital Cargo Airport", "Airport", "China", "Beijing"),
    ("CNSZXA", "Shenzhen Bao'an Cargo Airport", "Airport", "China", "Shenzhen"),
    ("CNHKG", "Hong Kong Port", "Sea Port", "Hong Kong", "Hong Kong"),
    ("HKHKG", "Hong Kong International Cargo Airport", "Airport", "Hong Kong", "Hong Kong"),

    # --- ARAB GULF & MIDDLE EAST ---
    ("AEJEA", "Jebel Ali Port / DP World", "Sea Port", "United Arab Emirates", "Dubai"),
    ("AEKHL", "Khalifa Port / Abu Dhabi", "Sea Port", "United Arab Emirates", "Abu Dhabi"),
    ("AESHJ", "Sharjah Port / Port Khalid", "Sea Port", "United Arab Emirates", "Sharjah"),
    ("AEFJR", "Fujairah Port / Oil Bunkering", "Sea Port", "United Arab Emirates", "Fujairah"),
    ("AEDXB", "Dubai International Cargo Airport", "Airport", "United Arab Emirates", "Dubai"),
    ("AEDWC", "Al Maktoum Cargo Airport / DWC", "Airport", "United Arab Emirates", "Dubai"),
    ("AEAUH", "Abu Dhabi International Cargo", "Airport", "United Arab Emirates", "Abu Dhabi"),
    ("AEGHW", "Al Ghuwaifat Land Border Crossing", "Land Border", "United Arab Emirates", "Abu Dhabi"),

    ("SAJED", "Jeddah Islamic Port", "Sea Port", "Saudi Arabia", "Jeddah"),
    ("SADMM", "King Abdulaziz Port Dammam", "Sea Port", "Saudi Arabia", "Dammam"),
    ("SAJUB", "Jubail Commercial Port", "Sea Port", "Saudi Arabia", "Jubail"),
    ("SAYAN", "Yanbu Commercial & Industrial Port", "Sea Port", "Saudi Arabia", "Yanbu"),
    ("SAKAP", "King Abdullah Port / KAEC", "Sea Port", "Saudi Arabia", "Rabigh"),
    ("SARUH", "Riyadh King Khalid Cargo Airport", "Airport", "Saudi Arabia", "Riyadh"),
    ("SAJED2", "Jeddah King Abdulaziz Cargo Airport", "Airport", "Saudi Arabia", "Jeddah"),
    ("SABTH", "Al Batha Land Border", "Land Border", "Saudi Arabia", "Eastern Province"),
    ("SAKHA", "Khafji Land Border", "Land Border", "Saudi Arabia", "Eastern Province"),
    ("SAHAL", "Halat Ammar Land Border", "Land Border", "Saudi Arabia", "Tabuk"),

    ("KWSWK", "Shuwaikh Port", "Sea Port", "Kuwait", "Kuwait City"),
    ("KWSAA", "Shuaiba Port", "Sea Port", "Kuwait", "Shuaiba"),
    ("KWKWI", "Kuwait International Cargo Airport", "Airport", "Kuwait", "Kuwait City"),
    ("KWNWS", "Nuwaiseeb Land Border", "Land Border", "Kuwait", "Ahmadi"),
    ("KWSLM", "Salmi Land Border", "Land Border", "Kuwait", "Jahra"),

    ("QAHMD", "Hamad Port / Doha", "Sea Port", "Qatar", "Doha"),
    ("QADOH", "Doha Hamad International Cargo", "Airport", "Qatar", "Doha"),
    ("QAABU", "Abu Samra Land Border", "Land Border", "Qatar", "Abu Samra"),

    ("OMSOH", "Sohar Port", "Sea Port", "Oman", "Sohar"),
    ("OMSLH", "Salalah Port", "Sea Port", "Oman", "Salalah"),
    ("OMDQM", "Duqm Port", "Sea Port", "Oman", "Duqm"),
    ("OMMCT", "Muscat International Cargo", "Airport", "Oman", "Muscat"),
    ("OMWJG", "Wajajah Land Border", "Land Border", "Oman", "Batinah"),

    ("BHKBS", "Khalifa Bin Salman Port", "Sea Port", "Bahrain", "Hidd"),
    ("BHBAH", "Bahrain International Cargo Airport", "Airport", "Bahrain", "Muharraq"),
    ("BHKFD", "King Fahd Causeway Border", "Land Border", "Bahrain", "Jasra"),

    ("JOAQB", "Aqaba Container Terminal / ACT", "Sea Port", "Jordan", "Aqaba"),
    ("JOAMM", "Queen Alia International Cargo", "Airport", "Jordan", "Amman"),
    ("JOOMR", "Al Omari Land Border Crossing", "Land Border", "Jordan", "Zarqa"),
    ("JOJAB", "Jaber Land Border Crossing", "Land Border", "Jordan", "Mafraq"),

    ("LBBYR", "Beirut Port", "Sea Port", "Lebanon", "Beirut"),
    ("LBTRP", "Tripoli Port", "Sea Port", "Lebanon", "Tripoli"),
    ("LBBEY", "Beirut Rafic Hariri Cargo Airport", "Airport", "Lebanon", "Beirut"),
    ("LBMAS", "Masnaa Border Crossing", "Land Border", "Lebanon", "Bekaa"),

    ("IQBSR", "Umm Qasr Port", "Sea Port", "Iraq", "Basra"),
    ("IQFAW", "Al Faw Grand Port", "Sea Port", "Iraq", "Basra"),
    ("IQBGW", "Baghdad International Cargo", "Airport", "Iraq", "Baghdad"),
    ("IQSFW", "Safwan Land Border Crossing", "Land Border", "Iraq", "Basra"),
    ("IQTRB", "Trebil Land Border", "Land Border", "Iraq", "Anbar"),

    # --- EUROPE (Major Sea Ports & Airports) ---
    ("NLRTM", "Rotterdam Port / Maasvlakte", "Sea Port", "Netherlands", "Rotterdam"),
    ("NLAMS", "Amsterdam Port", "Sea Port", "Netherlands", "Amsterdam"),
    ("NLSPL", "Amsterdam Schiphol Cargo Airport", "Airport", "Netherlands", "Amsterdam"),

    ("BEANR", "Antwerp-Bruges Port", "Sea Port", "Belgium", "Antwerp"),
    ("BEZEE", "Zeebrugge Port", "Sea Port", "Belgium", "Zeebrugge"),
    ("BEBRU", "Brussels Airport Cargo", "Airport", "Belgium", "Brussels"),
    ("BELGG", "Liege Cargo Airport / Hub", "Airport", "Belgium", "Liege"),

    ("DEHAM", "Hamburg Port", "Sea Port", "Germany", "Hamburg"),
    ("DEBRE", "Bremerhaven Port", "Sea Port", "Germany", "Bremerhaven"),
    ("DEWVN", "Wilhelmshaven JadeWeserPort", "Sea Port", "Germany", "Wilhelmshaven"),
    ("DEFRA", "Frankfurt Cargo City", "Airport", "Germany", "Frankfurt"),
    ("DELEJ", "Leipzig/Halle DHL Air Cargo Hub", "Airport", "Germany", "Leipzig"),
    ("DEMUC", "Munich Cargo Airport", "Airport", "Germany", "Munich"),

    ("ITGOA", "Genoa Port", "Sea Port", "Italy", "Genoa"),
    ("ITSPE", "La Spezia Port", "Sea Port", "Italy", "La Spezia"),
    ("ITTRS", "Trieste Port", "Sea Port", "Italy", "Trieste"),
    ("ITLIV", "Livorno Port", "Sea Port", "Italy", "Livorno"),
    ("ITNAP", "Naples Port", "Sea Port", "Italy", "Naples"),
    ("ITGIT", "Gioia Tauro Port", "Sea Port", "Italy", "Gioia Tauro"),
    ("ITMXP", "Milan Malpensa Cargo Airport", "Airport", "Italy", "Milan"),
    ("ITFCO", "Rome Fiumicino Cargo", "Airport", "Italy", "Rome"),

    ("ESVLC", "Valencia Port", "Sea Port", "Spain", "Valencia"),
    ("ESBCN", "Barcelona Port", "Sea Port", "Spain", "Barcelona"),
    ("ESALG", "Algeciras Port", "Sea Port", "Spain", "Algeciras"),
    ("ESBIL", "Bilbao Port", "Sea Port", "Spain", "Bilbao"),
    ("ESMAD", "Madrid Barajas Cargo Airport", "Airport", "Spain", "Madrid"),

    ("FRMRS", "Marseille-Fos Port", "Sea Port", "France", "Marseille"),
    ("FRLEH", "Le Havre Port / HAROPA", "Sea Port", "France", "Le Havre"),
    ("FRDUN", "Dunkirk Port", "Sea Port", "France", "Dunkirk"),
    ("FRCDG", "Paris Charles de Gaulle Cargo", "Airport", "France", "Paris"),

    ("GBFXT", "Felixstowe Port", "Sea Port", "United Kingdom", "Felixstowe"),
    ("GBSOU", "Southampton Port", "Sea Port", "United Kingdom", "Southampton"),
    ("GBLON", "London Gateway Port", "Sea Port", "United Kingdom", "London"),
    ("GBLHR", "London Heathrow Cargo Airport", "Airport", "United Kingdom", "London"),
    ("GBEMA", "East Midlands Air Cargo Hub", "Airport", "United Kingdom", "Derby"),

    ("TRIST", "Istanbul Ambarli Port", "Sea Port", "Turkey", "Istanbul"),
    ("TRMERS", "Mersin International Port", "Sea Port", "Turkey", "Mersin"),
    ("TRALI", "Aliaga Port / Izmir", "Sea Port", "Turkey", "Izmir"),
    ("TRISG", "Gebze / Yilport", "Sea Port", "Turkey", "Kocaeli"),
    ("TRISL", "Istanbul Grand Airport Cargo", "Airport", "Turkey", "Istanbul"),
    ("TRKPK", "Kapikule Land Border Crossing", "Land Border", "Turkey", "Edirne"),
    ("TRGBL", "Gurbulak Land Border Crossing", "Land Border", "Turkey", "Agri"),

    ("GRPIR", "Piraeus Port / COSCO", "Sea Port", "Greece", "Athens"),
    ("GRSKG", "Thessaloniki Port", "Sea Port", "Greece", "Thessaloniki"),
    ("GRATH", "Athens Eleftherios Venizelos Cargo", "Airport", "Greece", "Athens"),

    ("RUMOW", "Novorossiysk Black Sea Port", "Sea Port", "Russian Federation", "Novorossiysk"),
    ("RUSPT", "Saint Petersburg Port", "Sea Port", "Russian Federation", "Saint Petersburg"),
    ("RUVVO", "Vladivostok Pacific Port", "Sea Port", "Russian Federation", "Vladivostok"),
    ("RUSVO", "Moscow Sheremetyevo Cargo", "Airport", "Russian Federation", "Moscow"),

    # --- AMERICAS (USA, Canada, Brazil, Mexico, etc.) ---
    ("USNYC", "Port of New York and New Jersey", "Sea Port", "United States", "New York"),
    ("USLAX", "Port of Los Angeles", "Sea Port", "United States", "Los Angeles"),
    ("USLGB", "Port of Long Beach", "Sea Port", "United States", "Long Beach"),
    ("USHOU", "Port of Houston", "Sea Port", "United States", "Houston"),
    ("USSAV", "Port of Savannah", "Sea Port", "United States", "Savannah"),
    ("USCHS", "Port of Charleston", "Sea Port", "United States", "Charleston"),
    ("USORF", "Port of Virginia / Norfolk", "Sea Port", "United States", "Norfolk"),
    ("USSEA", "Port of Seattle", "Sea Port", "United States", "Seattle"),
    ("USOAK", "Port of Oakland", "Sea Port", "United States", "Oakland"),
    ("USMEM", "Memphis FedEx World Cargo Hub", "Airport", "United States", "Memphis"),
    ("USORD", "Chicago O'Hare Cargo Airport", "Airport", "United States", "Chicago"),
    ("USMIA", "Miami Americas Cargo Gateway", "Airport", "United States", "Miami"),
    ("USJFK", "New York JFK Cargo Airport", "Airport", "United States", "New York"),
    ("USLAXA", "Los Angeles LAX Cargo", "Airport", "United States", "Los Angeles"),
    ("USLAR", "Laredo World Trade Land Bridge", "Land Border", "United States", "Texas"),
    ("USDET", "Ambassador Bridge Land Border", "Land Border", "United States", "Detroit"),

    ("CAVAN", "Port of Vancouver", "Sea Port", "Canada", "Vancouver"),
    ("CAMTR", "Port of Montreal", "Sea Port", "Canada", "Montreal"),
    ("CAPRR", "Prince Rupert Port", "Sea Port", "Canada", "Prince Rupert"),
    ("CAYYZ", "Toronto Pearson Cargo Airport", "Airport", "Canada", "Toronto"),

    ("MXMZT", "Manzanillo Port", "Sea Port", "Mexico", "Manzanillo"),
    ("MXLZC", "Lazaro Cardenas Port", "Sea Port", "Mexico", "Lazaro Cardenas"),
    ("MXVER", "Veracruz Port", "Sea Port", "Mexico", "Veracruz"),
    ("MXMEX", "Mexico City Cargo Airport", "Airport", "Mexico", "Mexico City"),
    ("MXNLD", "Nuevo Laredo Land Border", "Land Border", "Mexico", "Tamaulipas"),

    ("BRSSZ", "Santos Port", "Sea Port", "Brazil", "Santos"),
    ("BRPNG", "Paranagua Port", "Sea Port", "Brazil", "Paranagua"),
    ("BRRIO", "Rio de Janeiro Port", "Sea Port", "Brazil", "Rio de Janeiro"),
    ("BRGRU", "Sao Paulo Guarulhos Cargo Airport", "Airport", "Brazil", "Sao Paulo"),

    # --- ASIA & OCEANIA (India, Japan, South Korea, Singapore, Malaysia, Australia) ---
    ("INNSA", "Jawaharlal Nehru Port / Nhava Sheva", "Sea Port", "India", "Mumbai"),
    ("INMUN", "Mundra Port / Adani Ports", "Sea Port", "India", "Gujarat"),
    ("INMAA", "Chennai Port", "Sea Port", "India", "Chennai"),
    ("INCCU", "Kolkata Syama Prasad Port", "Sea Port", "India", "Kolkata"),
    ("INCOK", "Cochin Port / Vallarpadam", "Sea Port", "India", "Kochi"),
    ("INDEL", "Delhi Indira Gandhi Cargo Airport", "Airport", "India", "Delhi"),
    ("INBOM", "Mumbai Chhatrapati Shivaji Cargo", "Airport", "India", "Mumbai"),

    ("JPTYO", "Tokyo Port / Oi Terminal", "Sea Port", "Japan", "Tokyo"),
    ("JPYOK", "Yokohama Port", "Sea Port", "Japan", "Yokohama"),
    ("JPNGO", "Nagoya Port", "Sea Port", "Japan", "Nagoya"),
    ("JPKOB", "Kobe Port", "Sea Port", "Japan", "Kobe"),
    ("JPOSA", "Osaka Port", "Sea Port", "Japan", "Osaka"),
    ("JPNRT", "Tokyo Narita Cargo Airport", "Airport", "Japan", "Tokyo"),
    ("JPKIX", "Kansai International Cargo Airport", "Airport", "Japan", "Osaka"),

    ("KRPUS", "Busan Port / PNC", "Sea Port", "South Korea", "Busan"),
    ("KRINC", "Incheon Port", "Sea Port", "South Korea", "Incheon"),
    ("KRGYA", "Gwangyang Port", "Sea Port", "South Korea", "Gwangyang"),
    ("KRICH", "Incheon International Cargo Hub", "Airport", "South Korea", "Incheon"),

    ("SGSIN", "Singapore Port / PSA Terminals", "Sea Port", "Singapore", "Singapore"),
    ("SGSIN2", "Singapore Changi Air Cargo Center", "Airport", "Singapore", "Singapore"),

    ("MYPKG", "Port Klang / Westports / Northport", "Sea Port", "Malaysia", "Klang"),
    ("MYTPP", "Tanjung Pelepas Port", "Sea Port", "Malaysia", "Johor"),
    ("MYKUL", "Kuala Lumpur International Cargo", "Airport", "Malaysia", "Kuala Lumpur"),

    ("VNSGN", "Ho Chi Minh City / Cat Lai Port", "Sea Port", "Vietnam", "Ho Chi Minh"),
    ("VNHPH", "Haiphong Port / Lach Huyen", "Sea Port", "Vietnam", "Haiphong"),
    ("VNCMT", "Cai Mep Deep Sea Port", "Sea Port", "Vietnam", "Vung Tau"),
    ("VNHAN", "Hanoi Noi Bai Cargo Airport", "Airport", "Vietnam", "Hanoi"),

    ("IDJKT", "Jakarta Tanjung Priok Port", "Sea Port", "Indonesia", "Jakarta"),
    ("IDSUB", "Surabaya Tanjung Perak", "Sea Port", "Indonesia", "Surabaya"),
    ("IDCGK", "Jakarta Soekarno-Hatta Cargo", "Airport", "Indonesia", "Jakarta"),

    ("THBKK", "Bangkok Klong Toey Port", "Sea Port", "Thailand", "Bangkok"),
    ("THLCH", "Laem Chabang Port", "Sea Port", "Thailand", "Chonburi"),
    ("THBKK2", "Bangkok Suvarnabhumi Cargo Airport", "Airport", "Thailand", "Bangkok"),

    ("AUBNE", "Port of Brisbane", "Sea Port", "Australia", "Brisbane"),
    ("AUSYD", "Port Botany / Sydney", "Sea Port", "Australia", "Sydney"),
    ("AUMEL", "Port of Melbourne", "Sea Port", "Australia", "Melbourne"),
    ("AUFRE", "Fremantle Port / Perth", "Sea Port", "Australia", "Perth"),
    ("AUADL", "Port Adelaide", "Sea Port", "Australia", "Adelaide"),
    ("AUSYDA", "Sydney Kingsford Smith Cargo", "Airport", "Australia", "Sydney"),

    # --- AFRICA (North Africa, West Africa, East Africa, South Africa) ---
    ("MATNG", "Tanger Med Port", "Sea Port", "Morocco", "Tangier"),
    ("MACAS", "Casablanca Port", "Sea Port", "Morocco", "Casablanca"),
    ("MACMN", "Casablanca Mohammed V Cargo Airport", "Airport", "Morocco", "Casablanca"),
    ("MAGUR", "Guerguerat Border Crossing", "Land Border", "Morocco", "Guerguerat"),

    ("DZALG", "Algiers Port", "Sea Port", "Algeria", "Algiers"),
    ("DZORN", "Oran Port", "Sea Port", "Algeria", "Oran"),
    ("DZAAE", "Annaba Port", "Sea Port", "Algeria", "Annaba"),
    ("DZALG2", "Algiers Houari Boumediene Cargo", "Airport", "Algeria", "Algiers"),
    ("DZTAL", "Taleb Larbi Land Border", "Land Border", "Algeria", "El Oued"),

    ("TNRAD", "Rades Port", "Sea Port", "Tunisia", "Tunis"),
    ("TNBIZ", "Bizerte Port", "Sea Port", "Tunisia", "Bizerte"),
    ("TNTUN", "Tunis Carthage Cargo Airport", "Airport", "Tunisia", "Tunis"),
    ("TNRAS", "Ras Jedir Land Border Crossing", "Land Border", "Tunisia", "Medenine"),

    ("LYTIP", "Tripoli Port", "Sea Port", "Libyan Arab Jamahiriya", "Tripoli"),
    ("LYBEN", "Benghazi Port", "Sea Port", "Libyan Arab Jamahiriya", "Benghazi"),
    ("LYMRA", "Misurata Free Zone Port", "Sea Port", "Libyan Arab Jamahiriya", "Misurata"),
    ("LYKHO", "Khoms Port", "Sea Port", "Libyan Arab Jamahiriya", "Khoms"),
    ("LYMGD", "Musaid Land Border Crossing", "Land Border", "Libyan Arab Jamahiriya", "Musaid"),

    ("SDPZU", "Port Sudan", "Sea Port", "Sudan", "Port Sudan"),
    ("SDOSM", "Prince Osman Digna Port / Suakin", "Sea Port", "Sudan", "Suakin"),
    ("SDPZUA", "Port Sudan International Cargo", "Airport", "Sudan", "Port Sudan"),
    ("SDKRT", "Khartoum International Cargo", "Airport", "Sudan", "Khartoum"),
    ("SDASH", "Ashkeet Land Border Crossing", "Land Border", "Sudan", "Wadi Halfa"),
    ("SDARG", "Argeen Sudan Land Border", "Land Border", "Sudan", "Northern State"),

    ("DJJIB", "Djibouti Port / Doraleh", "Sea Port", "Djibouti", "Djibouti"),
    ("DJJIB2", "Djibouti Ambouli Cargo Airport", "Airport", "Djibouti", "Djibouti"),

    ("ZADUR", "Durban Port", "Sea Port", "South Africa", "Durban"),
    ("ZACPT", "Cape Town Port", "Sea Port", "South Africa", "Cape Town"),
    ("ZAPLZ", "Port Elizabeth / Ngqura", "Sea Port", "South Africa", "Port Elizabeth"),
    ("ZAJNB", "Johannesburg O.R. Tambo Cargo", "Airport", "South Africa", "Johannesburg"),

    ("NGAPP", "Lagos Apapa Port", "Sea Port", "Nigeria", "Lagos"),
    ("NGTIN", "Tin Can Island Port", "Sea Port", "Nigeria", "Lagos"),
    ("NGLOS", "Lagos Murtala Muhammed Cargo", "Airport", "Nigeria", "Lagos"),

    ("KEKPA", "Mombasa Port / Kilindini", "Sea Port", "Kenya", "Mombasa"),
    ("KENBO", "Nairobi Jomo Kenyatta Cargo", "Airport", "Kenya", "Nairobi"),

    ("TZDAR", "Dar es Salaam Port", "Sea Port", "Tanzania", "Dar es Salaam"),
    ("GHTEM", "Tema Port", "Sea Port", "Ghana", "Tema"),
    ("CIABJ", "Abidjan Port", "Sea Port", "Cote D Ivoire", "Abidjan"),
    ("SNDKR", "Dakar Port", "Sea Port", "Senegal", "Dakar"),
]

def execute_all_updates(db_path: Path, *, confirm: bool = False, backups_dir: Optional[Path] = None) -> bool:
    """confirm=True: in-use check + verified backup first. confirm=False: never the live app DB."""
    db_path = Path(db_path)
    guard_target(db_path, confirm=confirm, tag=SCRIPT_TAG, backups_dir=backups_dir)

    print(f"\n=======================================================")
    print(f" Executing updates on: {db_path.name}")
    print(f"=======================================================")
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    now_iso = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # 1. Wipe all projects
    print("   [1/4] Wiping all projects...")
    cur.execute("DELETE FROM projects;")
    conn.commit()

    # 2. Fix currency symbols for all currencies
    print("   [2/4] Fixing currency symbols for all currencies...")
    cur.execute("SELECT currency_id, currency_code FROM currencies;")
    all_currs = cur.fetchall()
    for c_id, code in all_currs:
        sym = CURRENCY_SYMBOLS.get(code, code)
        cur.execute(
            "UPDATE currencies SET currency_symbol = ?, updated_at = ? WHERE currency_id = ?;",
            (sym, now_iso, c_id)
        )
    conn.commit()

    # 3. Populate Major Global & Regional Sea Ports, Airports, Dry Ports, and Land Borders
    print(f"   [3/4] Populating major global ports, airports, and borders ({len(MAJOR_PORTS_AIRPORTS_BORDERS)} entries)...")
    for un_locode, name, loc_type, country, city in MAJOR_PORTS_AIRPORTS_BORDERS:
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

    # 4. Integrate world cities as international transport terminals/customs ports
    print("   [4/4] Integrating world cities and terminals into transport locations...")
    cur.execute("SELECT city_code, city_name, country_code FROM cities;")
    cities = cur.fetchall()
    
    # Map country codes to country names
    cur.execute("SELECT country_code, country_name FROM countries;")
    c_map = {row[0]: row[1] for row in cur.fetchall()}

    added_from_cities = 0
    for code, name, c_code in cities:
        country_name = c_map.get(c_code, c_code or "International")
        loc_type = "Port / Terminal"
        if "Port" in name or "Harbour" in name or "Marina" in name or "Terminal" in name or "FPSO" in name:
            loc_type = "Sea Port"
        elif "Apt" in name or "Airport" in name:
            loc_type = "Airport"
        elif "Border" in name or "Crossing" in name:
            loc_type = "Land Border"

        cur.execute(
            """INSERT OR IGNORE INTO transport_locations (un_locode, location_name, location_type, country, city, is_active, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, 1, ?, ?);""",
            (code, f"{name} ({code})", loc_type, country_name, name, now_iso, now_iso)
        )
        if cur.rowcount > 0:
            added_from_cities += 1

    conn.commit()

    # Stats Summary
    cur.execute("SELECT COUNT(*) FROM projects;")
    prj_cnt = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM currencies WHERE currency_symbol = '' OR currency_symbol IS NULL;")
    empty_syms = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM transport_locations;")
    ports_cnt = cur.fetchone()[0]
    print(f"   [SUMMARY] Projects: {prj_cnt} records | Empty Symbols: {empty_syms} | Transport Locations: {ports_cnt} total ports/airports/borders")
    conn.close()
    return True


def main(argv: Optional[List[str]] = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(
        description="Wipe projects, fix currency symbols and populate world transport locations on ONE database."
    )
    add_target_arguments(parser, target_help="Database file to update")
    args = parser.parse_args(argv)

    def _run(target: Path, backups_dir: Optional[Path]):
        execute_all_updates(target, confirm=True, backups_dir=backups_dir)
        print("\n[SUCCESS] Successfully wiped projects, fixed currency symbols, and populated all world transport locations!")
        return True

    return run_cli_action(args, _run)


if __name__ == "__main__":
    sys.exit(main())
